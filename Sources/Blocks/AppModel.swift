import AppKit
import Combine
import BlocksCore
import ServiceManagement

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()
    @Published private(set) var engine = Engine()
    @Published private(set) var history: [Block] = []
    @Published var error: String?
    @Published var hotkeyError: String?
    @Published var loginMessage: String?
    @Published private(set) var launchAtLogin = false
    @Published var sleeping = false
    /// The session whose clock has been moved by hand, and where it was moved to. Doing it by
    /// hand is about this session rather than about the setting: the next session starts back
    /// wherever the setting says, and the menu bar carries the clock whenever the bar is away.
    @Published private(set) var notchBarSession: UUID?
    @Published private(set) var notchBarWanted: Bool?
    /// Where this session's clock is meant to be — the setting, unless this session was told
    /// otherwise. Whether the bar is actually up is Surfaces's answer, not this one.
    var notchBarShowing: Bool {
        if state.block?.id == notchBarSession, let wanted = notchBarWanted { return wanted }
        return state.preferences.notchTimerEnabled
    }
    func setNotchBar(_ showing: Bool) {
        notchBarSession = state.block?.id
        notchBarWanted = showing
        surfaces?.refresh()
    }
    func toggleNotchBar() { setNotchBar(!notchBarShowing) }
    private var sleepReasons = Set<String>()
    private let testDirectory = ProcessInfo.processInfo.environment["BLOCKS_TEST_DATA_DIRECTORY"]
    private var storage: Storage?
    private var timer: Timer?
    private let completionAudio: any CompletionAudioPlaying
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private var observers: [NSObjectProtocol] = []
    var surfaces: Surfaces!
    var hotkey: Hotkey!
    var state: LiveState { engine.state }
    var clock: String {
        let seconds = Int(ceil(state.remaining))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
    var totalSessionTime: String { focusTime(state.block?.plannedSeconds ?? 0) }
    var pendingTasks: [QueuedTask] { state.pendingTasks }
    var completedQueuedTasks: [QueuedTask] { state.queuedTasks.filter { $0.completed } }
    var canStartTask: Bool { [.idle, .finished].contains(state.phase) && error == nil }
    var todayFocusSeconds: Double { engine.dailyFocusSeconds(history: history, on: Date()) }
    var dailyFocusTargetSeconds: Double { Double(state.preferences.dailyFocusHours) * 3600 }
    init(completionAudio: (any CompletionAudioPlaying)? = nil) {
        self.completionAudio = completionAudio ?? CompletionAudio()
        do {
            let directory: URL
            if let testDirectory { directory = URL(fileURLWithPath: testDirectory, isDirectory: true) }
            else {
                directory = try Storage.migrateLegacyDirectory(
                    in: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0],
                    legacyAppRunning: NSWorkspace.shared.runningApplications.contains {
                        $0.bundleIdentifier == "local.park.focus" && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
                    })
                let defaults = UserDefaults.standard
                if !defaults.bool(forKey: "blocksDefaultsMigrated") {
                    let legacy = defaults.persistentDomain(forName: "local.park.focus") ?? [:]
                    for key in ["parkingShortcutMigratedToSlash"] where defaults.object(forKey: key) == nil {
                        if let value = legacy[key] { defaults.set(value, forKey: key) }
                    }
                    defaults.set(true, forKey: "blocksDefaultsMigrated")
                }
            }
            let store = try Storage(directory: directory)
            storage = store
            engine = Engine(state: try store.readState())
            // Recovery preserves remaining work, never charges time while the app was absent.
            // A state file from a build that still had breaks decodes as idle; a finished
            // block left behind by it is logged rather than dropped or double-counted.
            if engine.state.phase == .idle, let stale = engine.state.block {
                if stale.outcome != nil { engine.state.pendingBlocks.append(stale) }
                engine.state.block = nil
            }
            engine.migrateTasks(history: try store.blocks())
            migrateCaptureShortcut()
            try flush()
            history = try store.blocks()
            Projects.register(projects)
        } catch { self.error = "Blocks could not load its data. Your files have been preserved. \(error.localizedDescription)" }
    }
    /// Shift-command-P was the original capture default and was never chosen by anyone, so a
    /// preference still sitting on it is moved to command-slash exactly once. A combination
    /// deliberately set later is left alone, because the migration has already run.
    private func migrateCaptureShortcut() {
        let key = "parkingShortcutMigratedToSlash"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        guard engine.state.preferences.hotkeyCode == 35, engine.state.preferences.hotkeyModifiers == 768 else { return }
        engine.state.preferences.hotkeyCode = Preferences().hotkeyCode
        engine.state.preferences.hotkeyModifiers = Preferences().hotkeyModifiers
    }
    func launch() {
        guard surfaces == nil else { return }
        surfaces = Surfaces(model: self)
        hotkey = Hotkey { [weak self] action in
            switch action {
            case .capture: self?.surfaces.capture()
            case .start: self?.surfaces.start()
            }
        }
        registerHotkeys()
        let center = NSWorkspace.shared.notificationCenter
        for (notification, reason, asleep) in [
            (NSWorkspace.willSleepNotification, "system", true),
            (NSWorkspace.didWakeNotification, "system", false),
            (NSWorkspace.screensDidSleepNotification, "display", true),
            (NSWorkspace.screensDidWakeNotification, "display", false)
        ] {
            observers.append(center.addObserver(forName: notification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.sleepChanged(reason: reason, asleep: asleep) }
            })
        }
        timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer!, forMode: .common)
        surfaces.refresh()
        configureLaunchAtLogin()
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshLaunchAtLogin() }
        })
    }
    private var canRegisterLogin: Bool {
        testDirectory == nil && Bundle.main.bundleURL.pathExtension == "app"
    }
    private func configureLaunchAtLogin() {
        guard canRegisterLogin else { refreshLaunchAtLogin(); return }
        let defaults = UserDefaults.standard
        // This marker belongs to Blocks; Park's registration never registered this app.
        if defaults.object(forKey: "launchAtLogin") == nil {
            switch SMAppService.mainApp.status {
            case .notRegistered, .notFound: setLaunchAtLogin(true)
            case .enabled, .requiresApproval: defaults.set(true, forKey: "launchAtLogin")
            default: break
            }
        }
        refreshLaunchAtLogin()
    }
    func refreshLaunchAtLogin() {
        guard canRegisterLogin else {
            launchAtLogin = false
            loginMessage = "Launch the installed Blocks app to manage startup."
            return
        }
        let status = SMAppService.mainApp.status
        launchAtLogin = status == .enabled
        if status == .requiresApproval {
            loginMessage = "Allow Blocks in System Settings → General → Login Items to run at startup."
        } else if status == .enabled {
            loginMessage = nil
        }
    }
    func setLaunchAtLogin(_ enabled: Bool) {
        guard canRegisterLogin else { refreshLaunchAtLogin(); return }
        do {
            let service = SMAppService.mainApp
            if enabled {
                if service.status != .enabled && service.status != .requiresApproval { try service.register() }
            } else if service.status == .enabled || service.status == .requiresApproval {
                try service.unregister()
            }
            UserDefaults.standard.set(enabled, forKey: "launchAtLogin")
            loginMessage = nil
            refreshLaunchAtLogin()
        } catch {
            refreshLaunchAtLogin()
            loginMessage = "Startup setting could not be changed: \(error.localizedDescription)"
        }
    }
    func openLoginSettings() { SMAppService.openSystemSettingsLoginItems() }
    private func sleepChanged(reason: String, asleep: Bool) {
        if asleep { if sleepReasons.isEmpty { tick() }; sleepReasons.insert(reason) }
        else { sleepReasons.remove(reason) }
        sleeping = !sleepReasons.isEmpty
        lastTick = ProcessInfo.processInfo.systemUptime
        surfaces.refresh()
    }
    private func flush() throws {
        guard let storage else { return }
        for block in state.pendingBlocks { try storage.append(block) }
        for event in state.pendingDistractionEvents { try storage.append(event) }
        engine.state.pendingBlocks = []; engine.state.pendingDistractionEvents = []
        try storage.save(state)
    }
    func change(_ action: (inout Engine) -> Void) {
        guard error == nil, let storage else { return }
        let previousPhase = state.phase
        var next = engine
        action(&next)
        do {
            // Write-ahead state contains archive records until their append is durable.
            try storage.save(next.state)
            if next.state.block?.id != state.block?.id {
                notchBarSession = nil
                notchBarWanted = nil
            }
            engine = next
            let hadRecords = !state.pendingBlocks.isEmpty || !state.pendingDistractionEvents.isEmpty
            try flush()
            if hadRecords {
                history = try storage.blocks()
            }
            // A project that has just been created or renamed takes its colour here, before
            // anything is drawn with it.
            Projects.register(projects)
            if previousPhase == .running, state.phase == .finished, state.preferences.soundNotificationEnabled {
                completionAudio.play(state.preferences.completionSound)
            } else if previousPhase == .finished, state.phase != .finished {
                completionAudio.stop()
            }
        } catch { self.error = "Blocks paused because it could not save your data. Free disk space or check the Blocks data folder, then quit and reopen. \(error.localizedDescription)" }
        surfaces?.refresh()
    }
    func tick() {
        let uptime = ProcessInfo.processInfo.systemUptime
        let elapsed = max(0, uptime - lastTick); lastTick = uptime
        guard !sleeping, error == nil else { return }
        change { engine in
            _ = engine.tick(seconds: elapsed, now: Date())
        }
    }
    /// Queue removal and session creation share the same durable state change.
    func start(_ intent: String, project: String = "", minutes: Int? = nil, queuedID: UUID? = nil) {
        guard canStartTask else { return }
        lastTick = ProcessInfo.processInfo.systemUptime
        change { _ = $0.start(intent, now: Date(), project: project, minutes: minutes, queuedID: queuedID) }
    }
    var projects: [String] { Array(Set(state.tasks.map(\.project).filter { !$0.isEmpty })).sorted() }
    /// The last three tasks worked on, newest first.
    var recentTasks: [FocusTask] {
        Array(state.tasks.sorted { $0.lastUsedAt > $1.lastUsedAt }.prefix(3))
    }

    /// Project choices ordered by the most recent work.
    var recentProjects: [String] {
        var seen = Set<String>()
        return state.tasks.sorted { $0.lastUsedAt > $1.lastUsedAt }.map(\.project)
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }
    var projectIndex: ProjectIndex { state.projectIndex }
    /// The task a recorded session belongs to, so a session can be retagged from wherever it is
    /// shown in the reports timeline.
    func task(for block: Block) -> FocusTask? {
        if let id = block.taskID { return state.tasks.first { $0.id == id } }
        return state.tasks.first { block.belongs(to: $0) }
    }
    /// Accepting the offer at the boundary adds time to the session that just ended; it never
    /// opens a second one, because a task has exactly one session.
    func extend(minutes: Int = Engine.extendMinutes) {
        lastTick = ProcessInfo.processInfo.systemUptime
        change { $0.extend(now: Date(), minutes: minutes) }
    }
    func extendTimer() {
        tick()
        change { engine in
            // The clock may have reached zero between opening the popup and choosing this.
            if engine.state.phase == .finished { engine.extend(now: Date()) }
            else { engine.extendActive() }
        }
    }
    func finishNow() { change { $0.commitFinished(now: Date()) } }
    func completeTask() {
        tick()
        change { $0.completeTask(now: Date()) }
    }
    /// Seconds left to accept the offer, for the countdown the popover shows.
    var extendRemaining: TimeInterval? {
        engine.extendDeadline.map { max(0, $0.timeIntervalSince(Date())) }
    }
    func updateTask(_ id: UUID, project: String? = nil, completed: Bool? = nil) {
        change { $0.updateTask(id, project: project, completed: completed) }
    }
    func stop(_ reason: String) { tick(); change { if let b = $0.stop(reason: reason, now: Date()) { $0.state.pendingBlocks.append(b) } } }
    /// Hold the clock. No prompt, no reason, nothing spent: the session stays open and the time
    /// simply stops being counted until it is let go again.
    func hold() { tick(); change { $0.hold(now: Date()) } }
    func resume() { lastTick = ProcessInfo.processInfo.systemUptime; change { $0.resume() } }
    func abandon(_ reason: String) { tick(); change { if let b = $0.abandon(reason: reason, now: Date()) { $0.state.pendingBlocks.append(b) } } }
    func enqueue(_ title: String) { change { $0.enqueue(title, now: Date()) } }
    func setQueuedTaskCompleted(_ id: UUID, completed: Bool) { change { $0.setQueuedTaskCompleted(id, completed: completed) } }
    func removeQueuedTask(_ id: UUID) { change { $0.removeQueuedTask(id) } }
    func previewCompletionSound() { completionAudio.play(state.preferences.completionSound) }
    func stopCompletionSound() { completionAudio.stop() }
    func setPreferences(_ value: Preferences) {
        let previous = state.preferences
        let changes: [(Hotkey.Action, (UInt32, UInt32), (UInt32, UInt32))] = [
            (.capture, (value.hotkeyCode, value.hotkeyModifiers), (previous.hotkeyCode, previous.hotkeyModifiers)),
            (.start, (value.startHotkeyCode, value.startHotkeyModifiers), (previous.startHotkeyCode, previous.startHotkeyModifiers))
        ].filter { $0.1 != $0.2 }
        for (action, next, old) in changes {
            if let message = hotkey?.register(action, code: next.0, modifiers: next.1) {
                // Put every shortcut back the way it was, so a rejected combination cannot
                // leave Blocks with one working shortcut and one silently unregistered.
                _ = hotkey?.register(action, code: old.0, modifiers: old.1)
                hotkeyError = message
                return
            }
        }
        if !changes.isEmpty { hotkeyError = nil }
        if previous.notchTimerMode != value.notchTimerMode {
            notchBarSession = nil
            notchBarWanted = nil
        }
        change { $0.state.preferences = value }
        if previous.theme != state.preferences.theme { surfaces?.applyTheme() }
        if !state.preferences.soundNotificationEnabled || previous.completionSound != state.preferences.completionSound {
            completionAudio.stop()
        }
    }
    func registerHotkeys() {
        guard let hotkey else { return }
        let capture = hotkey.register(.capture, code: state.preferences.hotkeyCode, modifiers: state.preferences.hotkeyModifiers)
        let start = hotkey.register(.start, code: state.preferences.startHotkeyCode, modifiers: state.preferences.startHotkeyModifiers)
        hotkeyError = capture ?? start
    }
    func quit() { tick(); NSApp.terminate(nil) }
}

/// Retained for the lifetime of playback; previews replace sounds instead of queueing it.
@MainActor
protocol CompletionAudioPlaying {
    func stop()
    func play(_ option: CompletionSound)
}

@MainActor
private final class CompletionAudio: CompletionAudioPlaying {
    private var sound: NSSound?
    func stop() { sound?.stop(); sound = nil }
    func play(_ option: CompletionSound) {
        stop()
        sound = NSSound(data: option.wavData())
        sound?.volume = 0.55
        sound?.play()
    }
}
