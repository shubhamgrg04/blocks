import Foundation

public enum Phase: String, Codable {
    case idle, running, paused, checking, finished
    /// A state file written by an older build can name a phase that no longer exists
    /// (the break). Falling back to idle keeps a stale file from disabling the app.
    public init(from decoder: Decoder) throws {
        self = Phase(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .idle
    }
}
public enum Outcome: String, Codable { case completed, abandoned, reset }
public enum Honesty: String, Codable, CaseIterable { case yes, partly, no }
/// A stretch of a session where the clock was not running. A reason is only there when the
/// pause was the deliberate, reasoned kind; simply holding the clock asks for nothing.
public struct Pause: Codable, Equatable {
    public var at: Date
    public var seconds: Double
    public var reason: String?
    public init(at: Date, seconds: Double, reason: String? = nil) {
        self.at = at; self.seconds = seconds; self.reason = reason
    }
}
/// Work saved for later. Completed items stay available to reopen until explicitly removed.
public struct QueuedTask: Codable, Identifiable, Equatable {
    public var id: UUID = UUID()
    public var title: String
    public var createdAt: Date
    public var completed: Bool = false
    public init(id: UUID = UUID(), title: String, createdAt: Date, completed: Bool = false) {
        self.id = id; self.title = title; self.createdAt = createdAt; self.completed = completed
    }
}
/// Legacy data only: retained so existing session records and pending archive writes survive.
/// Something that pulled at you mid-session and was written down instead of acted on.
public struct Distraction: Codable, Identifiable, Equatable {
    public var id: UUID = UUID()
    public var at: Date
    public var text: String
    public var resolved: Bool = false
    public var resolvedAt: Date? = nil
}
/// Archive records are append-only, so an item leaving the archive is a *new* event rather
/// than a deletion. Whether something is currently archived is the disposition of its latest
/// event, which is why each event carries its own id: one item accrues several over time.
public struct DistractionEvent: Codable, Identifiable {
    public var id: UUID = UUID()
    public var item: Distraction
    public var archivedAt: Date
    public var disposition: String
    private enum CodingKeys: String, CodingKey { case id, item, archivedAt, disposition }
    public init(id: UUID = UUID(), item: Distraction, archivedAt: Date, disposition: String) {
        self.id = id; self.item = item; self.archivedAt = archivedAt; self.disposition = disposition
    }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        item = try container.decode(Distraction.self, forKey: .item)
        archivedAt = try container.decode(Date.self, forKey: .archivedAt)
        disposition = try container.decode(String.self, forKey: .disposition)
    }
}
public struct FocusTask: Codable, Identifiable, Equatable {
    public var id: UUID
    public var title: String
    public var project: String
    public var createdAt: Date
    public var lastUsedAt: Date
    public var completed: Bool
    public var legacySessionIDs: [UUID]?
    public init(id: UUID = UUID(), title: String, project: String = "", now: Date) {
        self.id = id; self.title = title; self.project = project
        createdAt = now; lastUsedAt = now; completed = false
    }
}

public struct Block: Codable, Identifiable {
    public var id: UUID = UUID()
    public var start: Date
    public var end: Date?
    public var intent: String
    public var plannedSeconds: Double
    public var outcome: Outcome?
    public var check: Honesty?
    public var pauses: [Pause] = []
    /// Whether this session has spent its one reasoned pause. Quiet holds are not counted:
    /// holding the clock is not the act that a session only gets to do once.
    public var pauseUsed: Bool { pauses.contains { $0.reason?.isEmpty == false } }
    public var distractions: [Distraction] = []
    public var reason: String?
    public var taskID: UUID?
    public var project: String?
    public var focusedSeconds: Double?
}
/// Where a running session's clock lives. One question with one answer: the bar at the notch,
/// or the digits in the menu bar. The menu bar is the fallback the app can always fall back to —
/// it needs no particular hardware and cannot be closed — so every way of putting the bar away
/// lands there.
public enum NotchTimerMode: String, Codable, CaseIterable, Sendable {
    /// A black bar across the top of the screen, grown out of the notch where there is one.
    case bar
    /// The clock stays where the app's icon already is.
    case menuBar
    /// Files written by the builds that offered automatic, always and off. Automatic and always
    /// both asked for the bar; off asked for the menu bar.
    public init?(stored raw: String) {
        switch raw {
        case "bar", "auto", "always": self = .bar
        case "menuBar", "off": self = .menuBar
        default: return nil
        }
    }
}

public struct Preferences: Codable, Equatable {
    /// One length, and it is a setting rather than a question asked at every start. Changing it
    /// here changes the default for every session after this one; a session that wants something
    /// else is a deliberate trip to Settings, not a decision in the way of starting.
    public static let lengthRange = 1...180
    public var soundNotificationEnabled: Bool = true
    public var completionSound: CompletionSound = .softBell
    public var blockMinutes: Int = 25
    public static let dailyFocusHoursRange = 1...24
    public var dailyFocusHours: Int = 5
    /// Where a running session's clock lives. Only ever one of the two, because two clocks
    /// ticking in the same glance is noise rather than reassurance: while the notch bar is up
    /// the menu bar keeps its icon and drops the digits.
    public var notchTimerMode: NotchTimerMode = .bar
    public var notchTimerEnabled: Bool { notchTimerMode == .bar }
    // Carbon modifier masks: command 256, shift 512, option 2048, control 4096.
    public var hotkeyCode: UInt32 = 44 // slash — command-slash adds a task to To do
    public var hotkeyModifiers: UInt32 = 256
    public var startHotkeyCode: UInt32 = 44 // slash — shift-command-slash starts a block
    public var startHotkeyModifiers: UInt32 = 768
    public init() {}
    private enum CodingKeys: String, CodingKey {
        case voiceNotificationEnabled, soundNotificationEnabled, completionSound, blockMinutes, dailyFocusHours, notchTimerMode, notchTimerEnabled, companionEnabled, sessionLength, customMinutes,
             hotkeyCode, hotkeyModifiers, startHotkeyCode, startHotkeyModifiers
    }
    /// Blocks rewrites this file constantly and reads files written by older builds, so a key
    /// added since must fall back to its default rather than fail the whole decode. Retired keys
    /// — the soundscape, its volume, the turtle companion, the three named session lengths —
    /// are read where they still mean something and ignored where they do not.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = Preferences()
        soundNotificationEnabled = try container.decodeIfPresent(Bool.self, forKey: .soundNotificationEnabled)
            ?? container.decodeIfPresent(Bool.self, forKey: .voiceNotificationEnabled) ?? true
        completionSound = try container.decodeIfPresent(String.self, forKey: .completionSound)
            .flatMap(CompletionSound.init(rawValue:)) ?? .softBell
        // A file from the build that named its lengths stored the kind as well as the minutes;
        // "custom" is the only one whose minutes lived under a different key.
        let storedMinutes = try container.decodeIfPresent(Int.self, forKey: .blockMinutes)
        let namedLength = try container.decodeIfPresent(String.self, forKey: .sessionLength)
        let customMinutes = try container.decodeIfPresent(Int.self, forKey: .customMinutes)
        let minutes = namedLength == "custom" ? (customMinutes ?? storedMinutes) : storedMinutes
        blockMinutes = min(Preferences.lengthRange.upperBound,
                           max(Preferences.lengthRange.lowerBound, minutes ?? fallback.blockMinutes))
        // The retired session-count target has no time unit; existing installs start at five hours.
        let hours = try container.decodeIfPresent(Int.self, forKey: .dailyFocusHours) ?? fallback.dailyFocusHours
        dailyFocusHours = min(Self.dailyFocusHoursRange.upperBound, max(Self.dailyFocusHoursRange.lowerBound, hours))
        // A file from a build that had only a switch says on or off and nothing about where:
        // on becomes the automatic placement, which is what that switch meant on a notched Mac.
        let switched = try container.decodeIfPresent(Bool.self, forKey: .notchTimerEnabled)
            ?? container.decodeIfPresent(Bool.self, forKey: .companionEnabled)
        notchTimerMode = try container.decodeIfPresent(String.self, forKey: .notchTimerMode)
            .flatMap(NotchTimerMode.init(stored:))
            ?? switched.map { $0 ? .bar : .menuBar }
            ?? fallback.notchTimerMode
        hotkeyCode = try container.decodeIfPresent(UInt32.self, forKey: .hotkeyCode) ?? fallback.hotkeyCode
        hotkeyModifiers = try container.decodeIfPresent(UInt32.self, forKey: .hotkeyModifiers) ?? fallback.hotkeyModifiers
        startHotkeyCode = try container.decodeIfPresent(UInt32.self, forKey: .startHotkeyCode) ?? fallback.startHotkeyCode
        startHotkeyModifiers = try container.decodeIfPresent(UInt32.self, forKey: .startHotkeyModifiers) ?? fallback.startHotkeyModifiers
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(soundNotificationEnabled, forKey: .soundNotificationEnabled)
        try container.encode(completionSound, forKey: .completionSound)
        try container.encode(blockMinutes, forKey: .blockMinutes)
        try container.encode(dailyFocusHours, forKey: .dailyFocusHours)
        // Written in the older builds' spelling, which this build still reads: a file moved
        // between two versions of Blocks should not cost anyone their setting.
        try container.encode(notchTimerMode == .bar ? "always" : "off", forKey: .notchTimerMode)
        // Written for builds that predate the three-way setting, which read only this key.
        try container.encode(notchTimerEnabled, forKey: .notchTimerEnabled)
        try container.encode(hotkeyCode, forKey: .hotkeyCode)
        try container.encode(hotkeyModifiers, forKey: .hotkeyModifiers)
        try container.encode(startHotkeyCode, forKey: .startHotkeyCode)
        try container.encode(startHotkeyModifiers, forKey: .startHotkeyModifiers)
    }
}
public struct LiveState: Codable {
    public var phase: Phase = .idle
    public var block: Block?
    public var remaining: Double = 0
    public var warned: Bool = false
    public var queuedTasks: [QueuedTask] = []
    public var distractions: [Distraction] = [] // Legacy snapshot, never used as a live list.
    public var tasks: [FocusTask] = []
    public var preferences = Preferences()
    public var pendingBlocks: [Block] = []
    public var pendingDistractionEvents: [DistractionEvent] = []
    public init() {}
    private enum CodingKeys: String, CodingKey {
        // Keep the old capture snapshot and pending writes readable for migration.
        // The current queue has its own key so consumed entries cannot be migrated again.
        case queuedTasks, tasks, phase, block, remaining, warned, preferences, pendingBlocks
        case distractions = "parked"
        case pendingDistractionEvents = "pendingParking"
    }
    /// Same contract as Preferences: a missing key means a build that predates it, not damage.
    /// Only genuinely malformed JSON should surface as an error the user has to act on.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tasks = try container.decodeIfPresent([FocusTask].self, forKey: .tasks) ?? []
        phase = try container.decodeIfPresent(Phase.self, forKey: .phase) ?? .idle
        block = try container.decodeIfPresent(Block.self, forKey: .block)
        remaining = try container.decodeIfPresent(Double.self, forKey: .remaining) ?? 0
        warned = try container.decodeIfPresent(Bool.self, forKey: .warned) ?? false
        distractions = try container.decodeIfPresent([Distraction].self, forKey: .distractions) ?? []
        // Only migrate when the new key is absent. An empty queue must never resurrect old items.
        queuedTasks = try container.decodeIfPresent([QueuedTask].self, forKey: .queuedTasks)
            ?? distractions.map { QueuedTask(id: $0.id, title: $0.text, createdAt: $0.at, completed: $0.resolved) }
        preferences = try container.decodeIfPresent(Preferences.self, forKey: .preferences) ?? Preferences()
        pendingBlocks = try container.decodeIfPresent([Block].self, forKey: .pendingBlocks) ?? []
        pendingDistractionEvents = try container.decodeIfPresent([DistractionEvent].self, forKey: .pendingDistractionEvents) ?? []
    }
}

/// Pure state machine. Only explicit awake elapsed time is charged to a block.
public struct Engine {
    public var state: LiveState
    public init(state: LiveState = LiveState()) { self.state = state }
    /// **One task, one session.** Starting the same words again is a new piece of work, never a
    /// second run at an existing task: a session that needs more time is extended, not repeated.
    ///
    /// `minutes` is this session's length only. Nothing here writes to preferences: the default
    /// stays where it is, so overriding a length is a decision about today rather than a change
    /// to how Blocks works. Out-of-range values are clamped rather than refused.
    ///
    /// A queued task is consumed only after a start is valid, retaining its identity and title.
    @discardableResult
    public mutating func start(_ intent: String, now: Date, project: String = "", minutes: Int? = nil, queuedID: UUID? = nil) -> Bool {
        guard [.idle, .finished].contains(state.phase) else { return false }
        let queued = queuedID.flatMap { id in state.queuedTasks.first { $0.id == id && !$0.completed } }
        guard queuedID == nil || queued != nil else { return false }
        let text = (queued?.title ?? intent).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return false }
        commitFinished(now: now)
        let tag = project.trimmingCharacters(in: .whitespacesAndNewlines)
        var task = FocusTask(id: queued?.id ?? UUID(), title: text, project: tag, now: now)
        task.createdAt = queued?.createdAt ?? now
        state.tasks.append(task)
        let length = min(Preferences.lengthRange.upperBound,
                         max(Preferences.lengthRange.lowerBound, minutes ?? state.preferences.blockMinutes))
        state.block = Block(start: now, intent: task.title, plannedSeconds: Double(length * 60), taskID: task.id, project: task.project, focusedSeconds: 0)
        state.remaining = state.block!.plannedSeconds
        state.warned = false
        state.phase = .running
        if let queuedID { state.queuedTasks.removeAll { $0.id == queuedID } }
        return true
    }
    /// Preserve append-only legacy logs; task matching uses their exact title and project.
    public mutating func migrateTasks(history: [Block]) {
        for block in history + state.pendingBlocks + (state.block.map { [$0] } ?? []) {
            var index = state.tasks.firstIndex { task in
                if let id = block.taskID { return task.id == id }
                return task.legacySessionIDs?.contains(block.id) == true || (task.title == block.intent && task.project == (block.project ?? ""))
            }
            if index == nil {
                state.tasks.append(FocusTask(id: block.taskID ?? block.id, title: block.intent, project: block.project ?? "", now: block.start))
                index = state.tasks.count - 1
            }
            if let index {
                state.tasks[index].lastUsedAt = max(state.tasks[index].lastUsedAt, block.start)
                if block.taskID == nil && state.tasks[index].legacySessionIDs?.contains(block.id) != true {
                    state.tasks[index].legacySessionIDs = (state.tasks[index].legacySessionIDs ?? []) + [block.id]
                }
            }
        }
        if let block = state.block {
            state.block?.taskID = block.taskID ?? state.tasks.first { $0.title == block.intent && $0.project == (block.project ?? "") }?.id
            state.block?.focusedSeconds = block.focusedSeconds ?? max(0, block.plannedSeconds - state.remaining)
        }
        // A session that ended while Blocks was closed keeps its boundary and is written now;
        // the offer to extend it does not survive a relaunch.
        if [.checking, .finished].contains(state.phase) {
            if let block = finish(outcome: .completed, reason: nil, now: state.block?.end ?? Date()) { state.pendingBlocks.append(block) }
        }
    }
    public mutating func updateTask(_ id: UUID, project: String? = nil, completed: Bool? = nil) {
        guard let index = state.tasks.firstIndex(where: { $0.id == id }) else { return }
        if let project { state.tasks[index].project = project.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let completed { state.tasks[index].completed = completed }
    }
    /// Returns true exactly once on entry to the 30-second warning.
    public mutating func tick(seconds: Double, now: Date) -> Bool {
        let elapsed = max(0, seconds)
        switch state.phase {
        case .running:
            let charged = min(state.remaining, elapsed)
            let focused = (state.block?.focusedSeconds ?? max(0, (state.block?.plannedSeconds ?? 0) - state.remaining)) + charged
            state.block?.focusedSeconds = focused
            state.remaining = max(0, state.remaining - elapsed)
            let warning = state.remaining <= 30 && !state.warned
            if warning { state.warned = true }
            if state.remaining == 0 {
                // The boundary is when the planned time ran out, not when this tick noticed it.
                state.block?.end = now.addingTimeInterval(-max(0, elapsed - charged))
                state.phase = .finished
            }
            return warning
        case .paused:
            if let count = state.block?.pauses.count, count > 0 {
                state.block?.pauses[count - 1].seconds += elapsed
            }
        case .finished:
            // Measured in wall clock from the boundary: a Mac that slept through the offer was
            // plainly not extended, so the session is written as the completed thing it is.
            if let deadline = extendDeadline, now >= deadline { commitFinished(now: now) }
        default: break
        }
        return false
    }
    /// How long the offer to extend stands after the clock reaches zero, and how much time
    /// accepting it adds. Nothing is charged while the offer stands.
    public static let extendWindow: TimeInterval = 300 // five minutes
    public static let extendMinutes = 25
    public var extendDeadline: Date? {
        guard state.phase == .finished, let end = state.block?.end else { return nil }
        return end.addingTimeInterval(Engine.extendWindow)
    }
    /// Adds time to the session that just ended, rather than opening a second one.
    /// Existing controls use twenty-five minutes; the start popup passes the saved default.
    /// The record keeps one start, one end, and the length it actually took.
    @discardableResult public mutating func extend(now: Date, minutes: Int = Engine.extendMinutes) -> Bool {
        guard state.phase == .finished, state.block != nil else { return false }
        let seconds = Double(min(Preferences.lengthRange.upperBound, max(Preferences.lengthRange.lowerBound, minutes)) * 60)
        state.block?.end = nil
        state.block?.plannedSeconds += seconds
        state.remaining = seconds
        state.warned = false
        state.phase = .running
        return true
    }
    /// Add time without restarting the clock or changing whether the session is paused.
    @discardableResult public mutating func extendActive() -> Bool {
        guard [.running, .paused].contains(state.phase), state.block != nil else { return false }
        let seconds = Double(Engine.extendMinutes * 60)
        state.block?.plannedSeconds += seconds
        state.remaining += seconds
        state.warned = false
        return true
    }
    /// Explicitly completing the task saves immediately, retaining the planned ceiling and
    /// the focused time already charged. Also accepts a clock that just reached its boundary.
    public mutating func completeTask(now: Date) {
        guard [.running, .paused, .finished].contains(state.phase), let block = state.block else { return }
        if let id = block.taskID { updateTask(id, completed: true) }
        if state.phase != .finished { state.block?.end = now }
        if let completed = finish(outcome: .completed, reason: nil, now: now) {
            state.pendingBlocks.append(completed)
        }
    }
    /// Writing the finished session is deferred until the offer to extend has passed, because
    /// an extension has to reopen the same record rather than append a second one.
    public mutating func commitFinished(now: Date) {
        guard state.phase == .finished else { return }
        if let block = finish(outcome: .completed, reason: nil, now: now) { state.pendingBlocks.append(block) }
    }
    /// Holding the clock: the session stays open and nothing is asked for. This is the plain
    /// meaning of pause — the time simply stops being counted — and it is separate from the one
    /// reasoned pause below, which is about why the session broke rather than about the clock.
    public mutating func hold(now: Date) {
        guard state.phase == .running else { return }
        state.block?.pauses.append(Pause(at: now, seconds: 0))
        state.phase = .paused
    }
    /// A second stop (once the one reasoned pause is spent) terminates the block.
    public mutating func stop(reason: String, now: Date) -> Block? {
        guard [.running, .paused].contains(state.phase), !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        if state.block?.pauseUsed == false {
            // A session already held quietly is given the reason rather than a second pause, so
            // the held time stays one stretch and the reason lands on the stretch it explains.
            if state.phase == .paused, let count = state.block?.pauses.count, count > 0 {
                state.block?.pauses[count - 1].reason = reason
            } else {
                state.block?.pauses.append(Pause(at: now, seconds: 0, reason: reason))
                state.phase = .paused
            }
            return nil
        }
        return finish(outcome: .reset, reason: reason, now: now)
    }
    public mutating func resume() { if state.phase == .paused { state.phase = .running } }
    /// **The reason is optional.** Leaving a session early is the thing that has to stay cheap:
    /// what keeps the history honest is the abandoned record, not the sentence beside it, and a
    /// mandatory field is exactly the friction that makes quitting the app the easier exit. A
    /// blank reason is stored as none rather than as an empty string, so a record with nothing
    /// to say says nothing.
    public mutating func abandon(reason: String, now: Date) -> Block? {
        guard [.running, .paused, .checking].contains(state.phase) else { return nil }
        let text = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        return finish(outcome: .abandoned, reason: text.isEmpty ? nil : text, now: now)
    }
    private mutating func finish(outcome: Outcome, reason: String?, now: Date) -> Block? {
        guard var block = state.block else { return nil }
        block.outcome = outcome
        if outcome != .completed { block.end = now }
        block.reason = reason
        state.block = nil
        state.phase = .idle
        state.remaining = 0
        return block
    }
    public mutating func enqueue(_ title: String, now: Date) {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        state.queuedTasks.append(QueuedTask(title: clean, createdAt: now))
    }
    public mutating func setQueuedTaskCompleted(_ id: UUID, completed: Bool) {
        guard let index = state.queuedTasks.firstIndex(where: { $0.id == id }) else { return }
        state.queuedTasks[index].completed = completed
    }
    public mutating func removeQueuedTask(_ id: UUID) {
        state.queuedTasks.removeAll { $0.id == id }
    }

}

extension Block {
    private enum CodingKeys: String, CodingKey {
        // Preserve the legacy capture snapshot in old session records.
        case id, start, end, intent, plannedSeconds, outcome, check, pauses, reason, taskID, project, focusedSeconds
        case distractions = "parked"
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(taskID, forKey: .taskID)
        try container.encodeIfPresent(project, forKey: .project)
        try container.encodeIfPresent(focusedSeconds, forKey: .focusedSeconds)
        try container.encode(id, forKey: .id)
        try container.encode(start, forKey: .start)
        try container.encode(end, forKey: .end)
        try container.encode(intent, forKey: .intent)
        try container.encode(plannedSeconds, forKey: .plannedSeconds)
        try container.encode(outcome, forKey: .outcome)
        try container.encode(check, forKey: .check)
        try container.encode(pauses, forKey: .pauses)
        try container.encode(distractions, forKey: .distractions)
        try container.encodeIfPresent(reason, forKey: .reason)
    }
}

extension Block {
    public var focusDuration: Double {
        if let focusedSeconds { return max(0, focusedSeconds) }
        if outcome == .completed { return plannedSeconds }
        return max(0, min(plannedSeconds, (end ?? start).timeIntervalSince(start) - pauses.reduce(0) { $0 + $1.seconds }))
    }
    public func belongs(to task: FocusTask) -> Bool {
        if let taskID { return taskID == task.id }
        if let ids = task.legacySessionIDs { return ids.contains(id) }
        return intent == task.title && (project ?? "") == task.project
    }
}

/// Which project a session counts towards, resolved once for a whole report.
///
/// A block carries the project it was started under, but that snapshot is not what the totals
/// are grouped by: tagging is how a person organises their history, and a retag that left old
/// sessions filed under the old name would make the breakdown a record of past filing decisions
/// rather than of where the time went. So the current tag on the task wins, and the snapshot in
/// the append-only log is never rewritten — it stays as the honest record of the moment, and is
/// the fallback for a session whose task no longer exists.
public struct ProjectIndex {
    public static let untagged = "Untagged"
    private let byTask: [UUID: String]
    private let byLegacyBlock: [UUID: String]
    public init(tasks: [FocusTask]) {
        var tasksByID: [UUID: String] = [:]
        var legacy: [UUID: String] = [:]
        for task in tasks {
            tasksByID[task.id] = task.project
            for id in task.legacySessionIDs ?? [] { legacy[id] = task.project }
        }
        byTask = tasksByID; byLegacyBlock = legacy
    }
    /// The tag as stored: empty means the session belongs to no project.
    public func tag(of block: Block) -> String {
        if let id = block.taskID, let project = byTask[id] { return project }
        if let project = byLegacyBlock[block.id] { return project }
        return block.project ?? ""
    }
    /// The tag as shown, where every session has to land under some heading.
    public func name(of block: Block) -> String {
        let tag = tag(of: block)
        return tag.isEmpty ? Self.untagged : tag
    }
}

extension LiveState {
    public var projectIndex: ProjectIndex { ProjectIndex(tasks: tasks) }
}


extension Engine {
    /// Match reports' end-date grouping, including today's charged live session time.
    /// A record moving from live state through pending storage must only contribute once.
    public func dailyFocusSeconds(history: [Block], on day: Date, calendar: Calendar = .current) -> Double {
        var records: [UUID: Block] = [:]
        for block in history + state.pendingBlocks { records[block.id] = block }
        if let block = state.block { records[block.id] = block }
        return records.values.reduce(0) { total, block in
            guard calendar.isDate(block.end ?? day, inSameDayAs: day) else { return total }
            return total + block.focusDuration
        }
    }
}
