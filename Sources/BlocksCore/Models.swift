import Foundation

public enum Phase: String, Codable {
    case idle, running, paused, checking
    /// A state file written by an older build can name a phase that no longer exists
    /// (the break). Falling back to idle keeps a stale file from disabling the app.
    public init(from decoder: Decoder) throws {
        self = Phase(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .idle
    }
}
public enum Outcome: String, Codable { case completed, abandoned, reset }
public enum Honesty: String, Codable, CaseIterable { case yes, partly, no }
public struct Pause: Codable, Equatable {
    public var at: Date
    public var seconds: Double
    public var reason: String
}
public struct ParkedItem: Codable, Identifiable, Equatable {
    public var id: UUID = UUID()
    public var at: Date
    public var text: String
    public var resolved: Bool = false
}
/// Work deliberately planned for a later block. Distinct from a ParkedItem, which is a
/// distraction deliberately *not* acted on: these are intents waiting for a block to run in.
public struct PendingIntent: Codable, Identifiable, Equatable {
    public var id: UUID = UUID()
    public var at: Date
    public var text: String
    public init(id: UUID = UUID(), at: Date, text: String) { self.id = id; self.at = at; self.text = text }
}
/// Archive records are append-only, so an item leaving the archive is a *new* event rather
/// than a deletion. Whether something is currently archived is the disposition of its latest
/// event, which is why each event carries its own id: one item accrues several over time.
public struct ParkingEvent: Codable, Identifiable {
    public var id: UUID = UUID()
    public var item: ParkedItem
    public var archivedAt: Date
    public var disposition: String
    private enum CodingKeys: String, CodingKey { case id, item, archivedAt, disposition }
    public init(id: UUID = UUID(), item: ParkedItem, archivedAt: Date, disposition: String) {
        self.id = id; self.item = item; self.archivedAt = archivedAt; self.disposition = disposition
    }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        item = try container.decode(ParkedItem.self, forKey: .item)
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
public struct Block: Codable, Identifiable {
    public var id: UUID = UUID()
    public var start: Date
    public var end: Date?
    public var intent: String
    public var plannedSeconds: Double
    public var outcome: Outcome?
    public var check: Honesty?
    public var pauses: [Pause] = []
    public var parked: [ParkedItem] = []
    public var reason: String?
}
public struct Preferences: Codable, Equatable {
    public var blockMinutes: Int = 25
    public var dailyTarget: Int = 9
    // Carbon modifier masks: command 256, shift 512, option 2048, control 4096.
    public var hotkeyCode: UInt32 = 44 // slash — command-slash parks a thought
    public var hotkeyModifiers: UInt32 = 256
    public var startHotkeyCode: UInt32 = 44 // slash — shift-command-slash starts a block
    public var startHotkeyModifiers: UInt32 = 768
    public init() {}
    private enum CodingKeys: String, CodingKey {
        case blockMinutes, dailyTarget, hotkeyCode, hotkeyModifiers, startHotkeyCode, startHotkeyModifiers
    }
    /// Blocks rewrites this file constantly and reads files written by older builds, so a key
    /// added since must fall back to its default rather than fail the whole decode.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = Preferences()
        blockMinutes = try container.decodeIfPresent(Int.self, forKey: .blockMinutes) ?? fallback.blockMinutes
        dailyTarget = try container.decodeIfPresent(Int.self, forKey: .dailyTarget) ?? fallback.dailyTarget
        hotkeyCode = try container.decodeIfPresent(UInt32.self, forKey: .hotkeyCode) ?? fallback.hotkeyCode
        hotkeyModifiers = try container.decodeIfPresent(UInt32.self, forKey: .hotkeyModifiers) ?? fallback.hotkeyModifiers
        startHotkeyCode = try container.decodeIfPresent(UInt32.self, forKey: .startHotkeyCode) ?? fallback.startHotkeyCode
        startHotkeyModifiers = try container.decodeIfPresent(UInt32.self, forKey: .startHotkeyModifiers) ?? fallback.startHotkeyModifiers
    }
}
public struct LiveState: Codable {
    public var phase: Phase = .idle
    public var block: Block?
    public var remaining: Double = 0
    public var warned: Bool = false
    public var parked: [ParkedItem] = []
    public var pending: [PendingIntent] = []
    public var preferences = Preferences()
    public var pendingBlocks: [Block] = []
    public var pendingParking: [ParkingEvent] = []
    public var pendingIntentEvents: [IntentEvent] = []
    public init() {}
    private enum CodingKeys: String, CodingKey {
        case phase, block, remaining, warned, parked, pending, preferences, pendingBlocks, pendingParking, pendingIntentEvents
    }
    /// Same contract as Preferences: a missing key means a build that predates it, not damage.
    /// Only genuinely malformed JSON should surface as an error the user has to act on.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        phase = try container.decodeIfPresent(Phase.self, forKey: .phase) ?? .idle
        block = try container.decodeIfPresent(Block.self, forKey: .block)
        remaining = try container.decodeIfPresent(Double.self, forKey: .remaining) ?? 0
        warned = try container.decodeIfPresent(Bool.self, forKey: .warned) ?? false
        parked = try container.decodeIfPresent([ParkedItem].self, forKey: .parked) ?? []
        pending = try container.decodeIfPresent([PendingIntent].self, forKey: .pending) ?? []
        preferences = try container.decodeIfPresent(Preferences.self, forKey: .preferences) ?? Preferences()
        pendingBlocks = try container.decodeIfPresent([Block].self, forKey: .pendingBlocks) ?? []
        pendingParking = try container.decodeIfPresent([ParkingEvent].self, forKey: .pendingParking) ?? []
        pendingIntentEvents = try container.decodeIfPresent([IntentEvent].self, forKey: .pendingIntentEvents) ?? []
    }
}

/// Pure state machine. Only explicit awake elapsed time is charged to a block.
public struct Engine {
    public var state: LiveState
    public init(state: LiveState = LiveState()) { self.state = state }
    /// Starting from a pending intent consumes that one and leaves the rest of the queue alone;
    /// a freshly typed intent consumes nothing.
    public mutating func start(_ intent: String, now: Date, consuming id: UUID? = nil) {
        let text = intent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard state.phase == .idle, !text.isEmpty else { return }
        state.block = Block(start: now, intent: text, plannedSeconds: Double(state.preferences.blockMinutes * 60))
        state.remaining = state.block!.plannedSeconds
        state.warned = false
        state.phase = .running
        if let id { state.pending.removeAll { $0.id == id } }
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
    public mutating func restoreParked(_ item: ParkedItem, now: Date) -> ParkingEvent? {
        guard !state.parked.contains(where: { $0.id == item.id }) else { return nil }
        var revived = item
        revived.at = now
        revived.resolved = false
        state.parked.append(revived)
        return ParkingEvent(item: revived, archivedAt: now, disposition: "restored")
    }
    /// Returns true exactly once on entry to the 30-second warning.
    public mutating func tick(seconds: Double, now: Date) -> Bool {
        let elapsed = max(0, seconds)
        switch state.phase {
        case .running:
            state.remaining = max(0, state.remaining - elapsed)
            let warning = state.remaining <= 30 && !state.warned
            if warning { state.warned = true }
            if state.remaining == 0 { state.phase = .checking; state.block?.end = now }
            return warning
        case .paused:
            if let count = state.block?.pauses.count, count > 0 {
                state.block?.pauses[count - 1].seconds += elapsed
            }
        default: break
        }
        return false
    }
    /// A second stop (including while already paused) terminates the block.
    public mutating func stop(reason: String, now: Date) -> Block? {
        guard [.running, .paused].contains(state.phase), !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        if state.block?.pauses.isEmpty == true {
            state.block?.pauses.append(Pause(at: now, seconds: 0, reason: reason))
            state.phase = .paused
            return nil
        }
        return finish(outcome: .reset, reason: reason, now: now)
    }
    public mutating func resume() { if state.phase == .paused { state.phase = .running } }
    public mutating func abandon(reason: String, now: Date) -> Block? {
        guard [.running, .paused, .checking].contains(state.phase), !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return finish(outcome: .abandoned, reason: reason, now: now)
    }
    /// The honesty check is the boundary: answering completes the block and returns to idle.
    public mutating func answer(_ check: Honesty, now: Date) -> Block? {
        guard state.phase == .checking else { return nil }
        state.block?.check = check
        return finish(outcome: .completed, reason: nil, now: now)
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
    public mutating func park(_ text: String, now: Date) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let item = ParkedItem(at: now, text: clean)
        state.parked.append(item)
        state.block?.parked.append(item)
    }
    public mutating func resolve(_ id: UUID, now: Date) -> ParkingEvent? {
        guard let index = state.parked.firstIndex(where: { $0.id == id }) else { return nil }
        var item = state.parked.remove(at: index)
        item.resolved = true
        if let i = state.block?.parked.firstIndex(where: { $0.id == id }) { state.block?.parked[i].resolved = true }
        return ParkingEvent(item: item, archivedAt: now, disposition: "resolved")
    }
    public static let parkedLifetime: TimeInterval = 604_800 // seven days
    public mutating func expire(now: Date) -> [ParkingEvent] {
        let stale = { (item: ParkedItem) in now.timeIntervalSince(item.at) >= Engine.parkedLifetime }
        let expired = state.parked.filter(stale)
        state.parked.removeAll(where: stale)
        return expired.map { ParkingEvent(item: $0, archivedAt: now, disposition: "expired") }
    }
}

extension Block {
    private enum CodingKeys: String, CodingKey {
        case id, start, end, intent, plannedSeconds, outcome, check, pauses, parked, reason
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(start, forKey: .start)
        try container.encode(end, forKey: .end)
        try container.encode(intent, forKey: .intent)
        try container.encode(plannedSeconds, forKey: .plannedSeconds)
        try container.encode(outcome, forKey: .outcome)
        try container.encode(check, forKey: .check)
        try container.encode(pauses, forKey: .pauses)
        try container.encode(parked, forKey: .parked)
        try container.encodeIfPresent(reason, forKey: .reason)
    }
}
