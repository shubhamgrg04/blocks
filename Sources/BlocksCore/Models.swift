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
/// Something that pulled at you mid-session and was written down instead of acted on.
public struct Distraction: Codable, Identifiable, Equatable {
    public var id: UUID = UUID()
    public var at: Date
    public var text: String
    public var resolved: Bool = false
}
/// Work deliberately planned for a later block. Distinct from a Distraction, which is
/// deliberately *not* acted on: these are intents waiting for a block to run in.
public struct PendingIntent: Codable, Identifiable, Equatable {
    public var id: UUID = UUID()
    public var at: Date
    public var text: String
    public init(id: UUID = UUID(), at: Date, text: String) { self.id = id; self.at = at; self.text = text }
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
/// The same shape for pending intents that were removed rather than started.
public struct IntentEvent: Codable, Identifiable {
    public var id: UUID = UUID()
    public var intent: PendingIntent
    public var archivedAt: Date
    public var disposition: String
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
    public var blockMinutes: Int = 25
    public var dailyTarget: Int = 9
    /// Where a running session's clock lives. Only ever one of the two, because two clocks
    /// ticking in the same glance is noise rather than reassurance: while the notch bar is up
    /// the menu bar keeps its icon and drops the digits.
    public var notchTimerMode: NotchTimerMode = .bar
    public var notchTimerEnabled: Bool { notchTimerMode == .bar }
    // Carbon modifier masks: command 256, shift 512, option 2048, control 4096.
    public var hotkeyCode: UInt32 = 44 // slash — command-slash captures a distraction
    public var hotkeyModifiers: UInt32 = 256
    public var startHotkeyCode: UInt32 = 44 // slash — shift-command-slash starts a block
    public var startHotkeyModifiers: UInt32 = 768
    public var extendHotkeyCode: UInt32 = 14 // e — shift-command-e extends a finished session
    public var extendHotkeyModifiers: UInt32 = 768
    public init() {}
    private enum CodingKeys: String, CodingKey {
        case blockMinutes, dailyTarget, notchTimerMode, notchTimerEnabled, companionEnabled, sessionLength, customMinutes,
             hotkeyCode, hotkeyModifiers, startHotkeyCode, startHotkeyModifiers, extendHotkeyCode, extendHotkeyModifiers
    }
    /// Blocks rewrites this file constantly and reads files written by older builds, so a key
    /// added since must fall back to its default rather than fail the whole decode. Retired keys
    /// — the soundscape, its volume, the turtle companion, the three named session lengths —
    /// are read where they still mean something and ignored where they do not.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = Preferences()
        // A file from the build that named its lengths stored the kind as well as the minutes;
        // "custom" is the only one whose minutes lived under a different key.
        let storedMinutes = try container.decodeIfPresent(Int.self, forKey: .blockMinutes)
        let namedLength = try container.decodeIfPresent(String.self, forKey: .sessionLength)
        let customMinutes = try container.decodeIfPresent(Int.self, forKey: .customMinutes)
        let minutes = namedLength == "custom" ? (customMinutes ?? storedMinutes) : storedMinutes
        blockMinutes = min(Preferences.lengthRange.upperBound,
                           max(Preferences.lengthRange.lowerBound, minutes ?? fallback.blockMinutes))
        dailyTarget = try container.decodeIfPresent(Int.self, forKey: .dailyTarget) ?? fallback.dailyTarget
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
        extendHotkeyCode = try container.decodeIfPresent(UInt32.self, forKey: .extendHotkeyCode) ?? fallback.extendHotkeyCode
        extendHotkeyModifiers = try container.decodeIfPresent(UInt32.self, forKey: .extendHotkeyModifiers) ?? fallback.extendHotkeyModifiers
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(blockMinutes, forKey: .blockMinutes)
        try container.encode(dailyTarget, forKey: .dailyTarget)
        // Written in the older builds' spelling, which this build still reads: a file moved
        // between two versions of Blocks should not cost anyone their setting.
        try container.encode(notchTimerMode == .bar ? "always" : "off", forKey: .notchTimerMode)
        // Written for builds that predate the three-way setting, which read only this key.
        try container.encode(notchTimerEnabled, forKey: .notchTimerEnabled)
        try container.encode(hotkeyCode, forKey: .hotkeyCode)
        try container.encode(hotkeyModifiers, forKey: .hotkeyModifiers)
        try container.encode(startHotkeyCode, forKey: .startHotkeyCode)
        try container.encode(startHotkeyModifiers, forKey: .startHotkeyModifiers)
        try container.encode(extendHotkeyCode, forKey: .extendHotkeyCode)
        try container.encode(extendHotkeyModifiers, forKey: .extendHotkeyModifiers)
    }
}
public struct LiveState: Codable {
    public var phase: Phase = .idle
    public var block: Block?
    public var remaining: Double = 0
    public var warned: Bool = false
    public var distractions: [Distraction] = []
    public var pending: [PendingIntent] = []
    public var tasks: [FocusTask] = []
    public var preferences = Preferences()
    public var pendingBlocks: [Block] = []
    public var pendingDistractionEvents: [DistractionEvent] = []
    public var pendingIntentEvents: [IntentEvent] = []
    public init() {}
    private enum CodingKeys: String, CodingKey {
        // The stored names predate the rename to "distraction". Renaming a key would orphan
        // every state file Blocks has already written, so only the Swift names moved.
        case tasks, phase, block, remaining, warned, pending, preferences, pendingBlocks, pendingIntentEvents
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
        pending = try container.decodeIfPresent([PendingIntent].self, forKey: .pending) ?? []
        preferences = try container.decodeIfPresent(Preferences.self, forKey: .preferences) ?? Preferences()
        pendingBlocks = try container.decodeIfPresent([Block].self, forKey: .pendingBlocks) ?? []
        pendingDistractionEvents = try container.decodeIfPresent([DistractionEvent].self, forKey: .pendingDistractionEvents) ?? []
        pendingIntentEvents = try container.decodeIfPresent([IntentEvent].self, forKey: .pendingIntentEvents) ?? []
    }
}

/// Pure state machine. Only explicit awake elapsed time is charged to a block.
public struct Engine {
    public var state: LiveState
    public init(state: LiveState = LiveState()) { self.state = state }
    /// Starting from a pending intent consumes that one and leaves the rest of the queue alone;
    /// a freshly typed intent consumes nothing.
    ///
    /// **One task, one session.** Starting the same words again is a new piece of work, never a
    /// second run at an existing task: a session that needs more time is extended, not repeated.
    public mutating func start(_ intent: String, now: Date, consuming id: UUID? = nil, project: String = "") {
        // A session still holding its offer to extend is finished by the act of starting another.
        commitFinished(now: now)
        let text = intent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard state.phase == .idle, !text.isEmpty else { return }
        let tag = project.trimmingCharacters(in: .whitespacesAndNewlines)
        let task = FocusTask(title: text, project: tag, now: now)
        state.tasks.append(task)
        state.block = Block(start: now, intent: task.title, plannedSeconds: Double(max(1, state.preferences.blockMinutes) * 60), taskID: task.id, project: task.project, focusedSeconds: 0)
        state.remaining = state.block!.plannedSeconds
        state.warned = false
        state.phase = .running
        if let id { state.pending.removeAll { $0.id == id } }
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
    public mutating func queue(_ intent: String, now: Date) {
        let text = intent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        state.pending.append(PendingIntent(at: now, text: text))
    }
    /// Pending intents never expire; a plan does not go stale the way an impulse does.
    /// Removing one archives it rather than destroying it, so it can be put back.
    public mutating func removePending(_ id: UUID, now: Date) -> IntentEvent? {
        guard let index = state.pending.firstIndex(where: { $0.id == id }) else { return nil }
        let intent = state.pending.remove(at: index)
        return IntentEvent(intent: intent, archivedAt: now, disposition: "removed")
    }
    public mutating func restorePending(_ intent: PendingIntent, now: Date) -> IntentEvent? {
        guard !state.pending.contains(where: { $0.id == intent.id }) else { return nil }
        state.pending.append(intent)
        return IntentEvent(intent: intent, archivedAt: now, disposition: "restored")
    }
    /// Expiry is measured from capture, so a restored thought is given a fresh clock —
    /// otherwise it would be swept straight back into the archive on the next tick.
    public mutating func restoreDistraction(_ item: Distraction, now: Date) -> DistractionEvent? {
        guard !state.distractions.contains(where: { $0.id == item.id }) else { return nil }
        var revived = item
        revived.at = now
        revived.resolved = false
        state.distractions.append(revived)
        return DistractionEvent(item: revived, archivedAt: now, disposition: "restored")
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
    /// Adds another twenty-five minutes to the session that just ended, rather than opening a
    /// second one. The record keeps one start, one end, and the length it actually took.
    @discardableResult public mutating func extend(now: Date) -> Bool {
        guard state.phase == .finished, state.block != nil else { return false }
        let seconds = Double(Engine.extendMinutes * 60)
        state.block?.end = nil
        state.block?.plannedSeconds += seconds
        state.remaining = seconds
        state.warned = false
        state.phase = .running
        return true
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
    public mutating func abandon(reason: String, now: Date) -> Block? {
        guard [.running, .paused, .checking].contains(state.phase), !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return finish(outcome: .abandoned, reason: reason, now: now)
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
    /// Capturing is the whole mechanism: written down, it stops pulling.
    public mutating func capture(_ text: String, now: Date) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let item = Distraction(at: now, text: clean)
        state.distractions.append(item)
        state.block?.distractions.append(item)
    }
    public mutating func resolve(_ id: UUID, now: Date) -> DistractionEvent? {
        guard let index = state.distractions.firstIndex(where: { $0.id == id }) else { return nil }
        var item = state.distractions.remove(at: index)
        item.resolved = true
        if let i = state.block?.distractions.firstIndex(where: { $0.id == id }) { state.block?.distractions[i].resolved = true }
        return DistractionEvent(item: item, archivedAt: now, disposition: "resolved")
    }
    public static let distractionLifetime: TimeInterval = 604_800 // seven days
    public mutating func expire(now: Date) -> [DistractionEvent] {
        let stale = { (item: Distraction) in now.timeIntervalSince(item.at) >= Engine.distractionLifetime }
        let expired = state.distractions.filter(stale)
        state.distractions.removeAll(where: stale)
        return expired.map { DistractionEvent(item: $0, archivedAt: now, disposition: "expired") }
    }
}

extension Block {
    private enum CodingKeys: String, CodingKey {
        // `parked` is the stored name of what the app now calls distractions; see LiveState.
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
