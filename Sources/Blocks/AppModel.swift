import AppKit
import Combine
import BlocksCore
import ServiceManagement

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()
    @Published private(set) var engine = Engine()
    @Published private(set) var history: [Block] = []
    @Published private(set) var archive: [DistractionEvent] = []
    @Published var error: String?
    @Published var hotkeyError: String?
    @Published var loginMessage: String?
    @Published var sleeping = false
    /// The session whose clock has been moved by hand, and where it was moved to. Doing it by
    /// hand is about this session rather than about the setting: the next session starts back
    /// wherever the setting says, and the menu bar carries the clock whenever the bar is away.
    @Published private(set) var notchBarSession: UUID?
    @Published private(set) var notchBarWanted = false
    /// Where this session's clock is meant to be — the setting, unless this session was told
    /// otherwise. Whether the bar is actually up is Surfaces's answer, not this one.
    var notchBarShowing: Bool {
        guard let id = state.block?.id else { return false }
        return id == notchBarSession ? notchBarWanted : state.preferences.notchTimerEnabled
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
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private var observers: [NSObjectProtocol] = []
    var surfaces: Surfaces!
    var hotkey: Hotkey!
    var state: LiveState { engine.state }
    var clock: String {
        let seconds = Int(ceil(state.remaining))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
    /// An item's current standing is the disposition of its most recent event; anything whose
    /// latest event is a restore is live again and must not still show as archived.
    private func latest<T, K: Hashable>(_ events: [T], id: (T) -> K, at: (T) -> Date) -> [T] {
        Dictionary(grouping: events, by: id).values.compactMap { $0.max(by: { at($0) < at($1) }) }
    }
    var archivedDistractions: [DistractionEvent] {
        latest(archive, id: { $0.item.id }, at: { $0.archivedAt })
            .filter { $0.disposition != "restored" }
            .sorted { $0.archivedAt > $1.archivedAt }
    }
    var todayCount: Int {
        history.filter { $0.outcome == .completed && $0.end.map { Calendar.current.isDateInToday($0) } == true }.count
    }
    init() {
        do {
            if testDirectory == nil, NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == "local.park.focus" }) {
                throw NSError(domain: "Blocks", code: 1, userInfo: [NSLocalizedDescriptionKey: "Quit the previous Park app, then reopen Blocks to safely transfer your data."])
            }
            let directory: URL
            if let testDirectory { directory = URL(fileURLWithPath: testDirectory, isDirectory: true) }
            else {
                directory = try Storage.migrateLegacyDirectory(in: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0])
                let defaults = UserDefaults.standard
                if !defaults.bool(forKey: "blocksDefaultsMigrated") {
                    let legacy = defaults.persistentDomain(forName: "local.park.focus") ?? [:]
                    for key in ["parkingShortcutMigratedToSlash", "loginRegistrationAttempted"] where defaults.object(forKey: key) == nil {
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
            history = try store.blocks(); archive = try store.distractionEvents()
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
            case .extend: self?.extend()
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
        if testDirectory == nil, Bundle.main.bundleURL.path == "/Applications/Blocks.app", !UserDefaults.standard.bool(forKey: "loginRegistrationAttempted") {
            do {
                try SMAppService.mainApp.register()
                UserDefaults.standard.set(true, forKey: "loginRegistrationAttempted")
                if SMAppService.mainApp.status == .requiresApproval { loginMessage = "Enable Blocks in System Settings → General → Login Items." }
            } catch { loginMessage = "Login launch could not be registered: \(error.localizedDescription)" }
        }
    }
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
        var next = engine
        action(&next)
        do {
            // Write-ahead state contains archive records until their append is durable.
            try storage.save(next.state)
            engine = next
            let hadRecords = !state.pendingBlocks.isEmpty || !state.pendingDistractionEvents.isEmpty
            try flush()
            if hadRecords {
                history = try storage.blocks(); archive = try storage.distractionEvents()
            }
            // A project that has just been created or renamed takes its colour here, before
            // anything is drawn with it.
            Projects.register(projects)
        } catch { self.error = "Blocks paused because it could not save your data. Free disk space or check the Blocks data folder, then quit and reopen. \(error.localizedDescription)" }
        surfaces?.refresh()
    }
    func tick() {
        let uptime = ProcessInfo.processInfo.systemUptime
        let elapsed = max(0, uptime - lastTick); lastTick = uptime
        guard !sleeping, error == nil else { return }
        change { engine in
            _ = engine.tick(seconds: elapsed, now: Date())
            engine.state.pendingDistractionEvents += engine.expire(now: Date())
        }
    }
    /// `minutes` is this session only; `resolving` is the distraction it answers, if it came
    /// off the list rather than out of the field.
    func start(_ intent: String, project: String = "", minutes: Int? = nil, resolving: UUID? = nil) {
        lastTick = ProcessInfo.processInfo.systemUptime
        change {
            if let event = $0.start(intent, now: Date(), project: project, minutes: minutes, resolving: resolving) {
                $0.state.pendingDistractionEvents.append(event)
            }
        }
    }
    var projects: [String] { Array(Set(state.tasks.map(\.project).filter { !$0.isEmpty })).sorted() }
    /// The tag you want next is nearly always one you used today, so the prompt can offer a
    /// couple of pills instead of a list: most recently worked in first.
    var recentProjects: [String] {
        var seen = Set<String>()
        return state.tasks.sorted { $0.lastUsedAt > $1.lastUsedAt }.map(\.project)
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }
    var projectIndex: ProjectIndex { state.projectIndex }
    /// The task a recorded session belongs to, so a session can be retagged from wherever it is
    /// shown rather than only from the task shelf.
    func task(for block: Block) -> FocusTask? {
        if let id = block.taskID { return state.tasks.first { $0.id == id } }
        return state.tasks.first { block.belongs(to: $0) }
    }
    /// Accepting the offer at the boundary adds time to the session that just ended; it never
    /// opens a second one, because a task has exactly one session.
    func extend() { lastTick = ProcessInfo.processInfo.systemUptime; change { $0.extend(now: Date()) } }
    func finishNow() { change { $0.commitFinished(now: Date()) } }
    /// Seconds left to accept the offer, for the countdown the popover shows.
    var extendRemaining: TimeInterval? {
        engine.extendDeadline.map { max(0, $0.timeIntervalSince(Date())) }
    }
    func updateTask(_ id: UUID, project: String? = nil, completed: Bool? = nil) {
        change { $0.updateTask(id, project: project, completed: completed) }
    }
    func restoreDistraction(_ item: Distraction) {
        change { if let event = $0.restoreDistraction(item, now: Date()) { $0.state.pendingDistractionEvents.append(event) } }
    }
    func stop(_ reason: String) { tick(); change { if let b = $0.stop(reason: reason, now: Date()) { $0.state.pendingBlocks.append(b) } } }
    /// Hold the clock. No prompt, no reason, nothing spent: the session stays open and the time
    /// simply stops being counted until it is let go again.
    func hold() { tick(); change { $0.hold(now: Date()) } }
    func resume() { lastTick = ProcessInfo.processInfo.systemUptime; change { $0.resume() } }
    func abandon(_ reason: String) { tick(); change { if let b = $0.abandon(reason: reason, now: Date()) { $0.state.pendingBlocks.append(b) } } }
    func capture(_ text: String) { change { $0.capture(text, now: Date()) } }
    func resolve(_ id: UUID) { change { if let event = $0.resolve(id, now: Date()) { $0.state.pendingDistractionEvents.append(event) } } }
    func setPreferences(_ value: Preferences) {
        let previous = state.preferences
        let changes: [(Hotkey.Action, (UInt32, UInt32), (UInt32, UInt32))] = [
            (.capture, (value.hotkeyCode, value.hotkeyModifiers), (previous.hotkeyCode, previous.hotkeyModifiers)),
            (.start, (value.startHotkeyCode, value.startHotkeyModifiers), (previous.startHotkeyCode, previous.startHotkeyModifiers)),
            (.extend, (value.extendHotkeyCode, value.extendHotkeyModifiers), (previous.extendHotkeyCode, previous.extendHotkeyModifiers))
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
        change { $0.state.preferences = value }
    }
    func registerHotkeys() {
        guard let hotkey else { return }
        let capture = hotkey.register(.capture, code: state.preferences.hotkeyCode, modifiers: state.preferences.hotkeyModifiers)
        let start = hotkey.register(.start, code: state.preferences.startHotkeyCode, modifiers: state.preferences.startHotkeyModifiers)
        let extend = hotkey.register(.extend, code: state.preferences.extendHotkeyCode, modifiers: state.preferences.extendHotkeyModifiers)
        hotkeyError = capture ?? start ?? extend
    }
    func quit() { tick(); NSApp.terminate(nil) }
}
