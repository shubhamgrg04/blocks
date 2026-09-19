import Foundation
import BlocksCore

final class EngineTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    func testIntentAndWarningBoundary() {
        var engine = Engine()
        engine.start(" \n", now: now)
        expectEqual(engine.state.phase, .idle)
        engine.start("Write the proposal", now: now)
        expectEqual(engine.state.remaining, 1500)
        expectFalse(engine.tick(seconds: 1469, now: now))
        expectTrue(engine.tick(seconds: 1, now: now))
        expectFalse(engine.tick(seconds: 29, now: now))
        expectEqual(engine.state.phase, .running)
        _ = engine.tick(seconds: 1, now: now.addingTimeInterval(1500))
        // The clock reaching zero no longer writes the session: the offer to extend stands first.
        expectEqual(engine.state.phase, .finished)
        expectEqual(engine.state.block?.end, now.addingTimeInterval(1500))
        engine.commitFinished(now: now.addingTimeInterval(1500))
        expectEqual(engine.state.phase, .idle)
        expectEqual(engine.state.pendingBlocks.last?.end, now.addingTimeInterval(1500))
    }
    /// Holding the clock asks for nothing, stops the count, and leaves the one reasoned pause
    /// unspent — so a session can be held as often as it likes without being reset.
    func testHoldStopsTheClockWithoutSpendingThePause() {
        var engine = Engine(); engine.start("Focus", now: now)
        _ = engine.tick(seconds: 60, now: now)
        engine.hold(now: now)
        expectEqual(engine.state.phase, .paused)
        _ = engine.tick(seconds: 120, now: now)
        expectEqual(engine.state.remaining, 1440)
        expectEqual(engine.state.block?.pauses.first?.seconds, 120)
        expectFalse(engine.state.block?.pauseUsed == true)
        engine.resume()
        engine.hold(now: now)
        expectEqual(engine.state.block?.pauses.count, 2)
        // The reasoned pause is still there to be spent, and it lands on the held stretch
        // rather than opening a third one.
        expectNil(engine.stop(reason: "Doorbell", now: now))
        expectEqual(engine.state.block?.pauses.count, 2)
        expectTrue(engine.state.block?.pauseUsed == true)
        expectEqual(engine.stop(reason: "Enough", now: now)?.outcome, .reset)
    }
    func testPauseRequiresReasonAndSecondStopResets() {
        var engine = Engine(); engine.start("Focus", now: now)
        expectNil(engine.stop(reason: "  ", now: now))
        expectEqual(engine.state.phase, .running)
        _ = engine.tick(seconds: 60, now: now)
        expectNil(engine.stop(reason: "Doorbell", now: now))
        _ = engine.tick(seconds: 90, now: now)
        expectEqual(engine.state.remaining, 1440)
        expectEqual(engine.state.block?.pauses.first?.seconds, 90)
        engine.resume()
        let block = engine.stop(reason: "Another interruption", now: now)
        expectEqual(block?.outcome, .reset)
        expectEqual(block?.reason, "Another interruption")
        expectEqual(engine.state.phase, .idle)
    }
    func testSecondStopWhilePausedAndAbandon() {
        var engine = Engine(); engine.start("Focus", now: now)
        _ = engine.stop(reason: "Door", now: now)
        expectEqual(engine.stop(reason: "Done", now: now)?.outcome, .reset)
        engine.start("Again", now: now)
        expectNil(engine.abandon(reason: "", now: now))
        let block = engine.abandon(reason: "Emergency", now: now)
        expectEqual(block?.outcome, .abandoned)
        expectNil(block?.check)
    }
    func testCompletionIsQuietAndExactlyOnce() {
        var engine = Engine(); engine.start("Focus", now: now)
        engine.queue("Next", now: now)
        _ = engine.tick(seconds: 1502, now: now.addingTimeInterval(1502))
        // Nothing is written while the offer to extend stands, and nothing is charged either.
        expectEqual(engine.state.phase, .finished)
        expectTrue(engine.state.pendingBlocks.isEmpty)
        expectEqual(engine.state.block?.focusDuration, 1500)
        // Ignored, it saves itself once the window closes.
        _ = engine.tick(seconds: 1, now: now.addingTimeInterval(1500 + Engine.extendWindow))
        let block = engine.state.pendingBlocks.first
        expectEqual(block?.outcome, .completed)
        expectNil(block?.check)
        expectEqual(block?.end, now.addingTimeInterval(1500))
        expectEqual(block?.focusDuration, 1500)
        expectEqual(engine.state.phase, .idle)
        expectNil(engine.state.block)
        _ = engine.tick(seconds: 50, now: now.addingTimeInterval(1552))
        expectEqual(engine.state.pendingBlocks.count, 1)
        expectEqual(engine.state.pending.count, 1)
    }
    /// A session that needs longer is extended in place. That is the only reason one task can
    /// hold more time than its kind promised, and it is still one record.
    func testExtendReopensTheSameSessionAndOfferExpires() {
        var engine = Engine(); engine.start("Focus", now: now)
        _ = engine.tick(seconds: 1500, now: now.addingTimeInterval(1500))
        expectEqual(engine.state.phase, .finished)
        let id = engine.state.block!.id
        expectTrue(engine.extend(now: now.addingTimeInterval(1510)))
        expectEqual(engine.state.phase, .running)
        expectEqual(engine.state.remaining, 1500)
        expectEqual(engine.state.block?.plannedSeconds, 3000)
        expectEqual(engine.state.block?.id, id)
        expectNil(engine.state.block?.end)
        expectTrue(engine.state.pendingBlocks.isEmpty)
        // Waiting out the second boundary writes one record covering both stretches.
        _ = engine.tick(seconds: 1500, now: now.addingTimeInterval(3010))
        _ = engine.tick(seconds: 1, now: now.addingTimeInterval(3011 + Engine.extendWindow))
        expectEqual(engine.state.pendingBlocks.count, 1)
        expectEqual(engine.state.pendingBlocks[0].id, id)
        expectEqual(engine.state.pendingBlocks[0].focusDuration, 3000)
        expectEqual(engine.state.pendingBlocks[0].outcome, .completed)
        // The offer only stands in the finished state, and only until it times out.
        expectFalse(engine.extend(now: now.addingTimeInterval(3020)))
        engine.start("Another", now: now.addingTimeInterval(3020))
        expectFalse(engine.extend(now: now.addingTimeInterval(3030)))
    }
    /// Starting is never a way back into a task that already had its session.
    func testEverySessionGetsItsOwnTask() {
        var engine = Engine()
        engine.start("Write", now: now, project: " Launch ")
        let first = engine.state.block!.taskID!
        expectEqual(engine.state.block?.project, "Launch")
        _ = engine.tick(seconds: 1500, now: now.addingTimeInterval(1500))
        // Starting the same words again is a second task, not a second session of the first.
        engine.start("Write", now: now.addingTimeInterval(1600), project: "Launch")
        expectEqual(engine.state.tasks.count, 2)
        expectTrue(engine.state.block?.taskID != first)
        expectEqual(engine.state.pendingBlocks.count, 1)
        // Retagging one leaves the other, and the running session, alone.
        engine.updateTask(first, project: "Next launch")
        expectEqual(engine.state.block?.project, "Launch")
        expectEqual(engine.state.tasks.first(where: { $0.id == first })?.project, "Next launch")
        let sessions = engine.state.pendingBlocks.filter { $0.taskID == first }
        expectEqual(sessions.count, 1)
    }
    /// Reports group by the task's current project, while the session keeps the snapshot it
    /// was recorded with: retagging is how a history gets organised, and the log stays honest.
    func testProjectIndexFollowsTheTaskNotTheSnapshot() {
        var engine = Engine()
        engine.start("Write", now: now, project: "Launch")
        _ = engine.tick(seconds: 1500, now: now.addingTimeInterval(1500))
        engine.commitFinished(now: now.addingTimeInterval(1500))
        let recorded = engine.state.pendingBlocks[0]
        expectEqual(engine.state.projectIndex.name(of: recorded), "Launch")
        engine.updateTask(recorded.taskID!, project: "Next launch")
        expectEqual(recorded.project, "Launch")
        expectEqual(engine.state.projectIndex.name(of: recorded), "Next launch")
        // Clearing the tag files the session under the one heading every report needs.
        engine.updateTask(recorded.taskID!, project: "")
        expectEqual(engine.state.projectIndex.name(of: recorded), "Untagged")
        expectEqual(engine.state.projectIndex.tag(of: recorded), "")
        // A legacy session carries no task ID; it is resolved through the task that adopted it.
        var legacy = recorded
        legacy.id = UUID(); legacy.taskID = nil; legacy.project = "Old name"
        var adopting = Engine(); adopting.migrateTasks(history: [legacy])
        adopting.updateTask(adopting.state.tasks[0].id, project: "Renamed")
        expectEqual(adopting.state.projectIndex.name(of: legacy), "Renamed")
        // A session whose task is gone falls back to the snapshot rather than losing its hours.
        expectEqual(Engine().state.projectIndex.name(of: legacy), "Old name")
    }
    func testSameTitleInDifferentProjectsStaysSeparate() {
        var engine = Engine()
        engine.start("Plan", now: now, project: "Work")
        _ = engine.tick(seconds: 1500, now: now)
        engine.start("Plan", now: now, project: "Home")
        expectEqual(engine.state.tasks.count, 2)
        expectTrue(engine.state.block?.taskID != engine.state.pendingBlocks[0].taskID)
    }
    func testFocusDurationExcludesPausesAndPreservesPartialWork() {
        var engine = Engine(); engine.start("Focus", now: now)
        _ = engine.tick(seconds: 125, now: now.addingTimeInterval(125))
        _ = engine.stop(reason: "Door", now: now.addingTimeInterval(125))
        _ = engine.tick(seconds: 500, now: now.addingTimeInterval(625))
        engine.resume()
        _ = engine.tick(seconds: 25, now: now.addingTimeInterval(650))
        let block = engine.abandon(reason: "Done for now", now: now.addingTimeInterval(650))!
        expectEqual(block.focusDuration, 150)
        expectEqual(block.pauses[0].seconds, 500)
    }
    func testLegacyHistoryMigrationAndRetaggingAreStable() throws {
        var old = Engine(); old.start("Legacy task", now: now)
        _ = old.tick(seconds: 1500, now: now.addingTimeInterval(1500))
        old.commitFinished(now: now.addingTimeInterval(1500))
        var block = old.state.pendingBlocks[0]
        block.taskID = nil; block.project = nil; block.focusedSeconds = nil
        var engine = Engine(); engine.migrateTasks(history: [block])
        let id = engine.state.tasks[0].id
        engine.updateTask(id, project: "New project", completed: true)
        engine.migrateTasks(history: [block])
        expectEqual(engine.state.tasks.count, 1)
        expectTrue(engine.state.tasks[0].completed)
        expectTrue(block.belongs(to: engine.state.tasks[0]))
        expectEqual(block.focusDuration, 1500)
        let data = try JSONEncoder().encode(engine.state)
        let decoded = try JSONDecoder().decode(LiveState.self, from: data)
        expectEqual(decoded.tasks[0].legacySessionIDs, [block.id])
    }
    func testLegacyCheckingCheckpointFinishesWithoutPrompt() {
        var engine = Engine(); engine.start("Previous build", now: now)
        engine.state.phase = .checking; engine.state.remaining = 0
        engine.state.block?.focusedSeconds = nil
        engine.state.block?.end = now.addingTimeInterval(1500)
        engine.migrateTasks(history: [])
        expectEqual(engine.state.phase, .idle)
        expectEqual(engine.state.pendingBlocks.count, 1)
        expectEqual(engine.state.pendingBlocks[0].focusDuration, 1500)
        engine.migrateTasks(history: [])
        expectEqual(engine.state.pendingBlocks.count, 1)
    }
    func testNewPreferencesAndTaskSurviveRelaunch() throws {
        var engine = Engine(); engine.start("Keep going", now: now, project: "Blocks")
        engine.state.preferences.blockMinutes = 40
        engine.state.preferences.notchTimerMode = .bar
        let decoded = try JSONDecoder().decode(LiveState.self, from: JSONEncoder().encode(engine.state))
        expectEqual(decoded.tasks, engine.state.tasks)
        expectEqual(decoded.preferences, engine.state.preferences)
        expectEqual(decoded.preferences.blockMinutes, 40)
        expectEqual(decoded.block?.taskID, engine.state.block?.taskID)
        expectEqual(decoded.block?.project, "Blocks")
    }
    func testStateFileFromABuildWithBreaksDecodesAsIdle() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = try Storage(directory: directory)
        let legacy = #"{"breakRemaining":281.6,"breakVisibleSeconds":18.4,"parked":[],"pendingBlocks":[],"pendingParking":[],"phase":"onBreak","preferences":{"blockMinutes":25,"breakMinutes":6,"dailyTarget":9,"hotkeyCode":35,"hotkeyModifiers":768},"remaining":0,"warned":true}"#
        try Data(legacy.utf8).write(to: directory.appendingPathComponent("state.json"))
        // A retired phase must not brick the app; the removed keys are simply ignored.
        let recovered = try storage.readState()
        expectEqual(recovered.phase, .idle)
        expectEqual(recovered.preferences.blockMinutes, 25)
        expectEqual(recovered.preferences.dailyTarget, 9)
        // Keys added after that file was written fall back to their defaults rather than
        // failing the decode, which would disable Blocks on the file it wrote itself.
        expectEqual(recovered.preferences.hotkeyCode, 35)
        expectEqual(recovered.preferences.startHotkeyCode, 44)
        expectEqual(recovered.preferences.startHotkeyModifiers, 768)
        expectTrue(recovered.pending.isEmpty)
    }
    func testLiveStateFileMissingLaterKeysStillLoads() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = try Storage(directory: directory)
        // The exact shape Blocks had on disk before the queue and the start shortcut existed.
        let onDisk = #"{"parked":[],"pendingBlocks":[],"pendingParking":[],"phase":"idle","preferences":{"blockMinutes":25,"dailyTarget":9,"hotkeyCode":44,"hotkeyModifiers":256},"remaining":0,"warned":true}"#
        try Data(onDisk.utf8).write(to: directory.appendingPathComponent("state.json"))
        let recovered = try storage.readState()
        expectTrue(recovered.pending.isEmpty)
        expectEqual(recovered.preferences.hotkeyCode, 44)
        expectEqual(recovered.preferences.hotkeyModifiers, 256)
        expectEqual(recovered.preferences.startHotkeyCode, 44)
        expectEqual(recovered.preferences.startHotkeyModifiers, 768)
        expectEqual(recovered.phase, .idle)
    }
    func testSessionLengthComesFromTheOneDefault() throws {
        var engine = Engine()
        // The default is 25 minutes and nothing at the start prompt can change it.
        engine.start("Default length", now: now)
        expectEqual(engine.state.block?.plannedSeconds, 1500)
        _ = engine.abandon(reason: "next", now: now)
        // Changing it in Settings changes every session after this one.
        engine.state.preferences.blockMinutes = 50
        engine.start("New default", now: now)
        expectEqual(engine.state.block?.plannedSeconds, 3000)
        _ = engine.abandon(reason: "next", now: now)
        func decodePreferences(_ json: String) throws -> Preferences {
            try JSONDecoder().decode(Preferences.self, from: Data(json.utf8))
        }
        // A length outside the range cannot produce an empty session.
        expectEqual(try decodePreferences(#"{"blockMinutes":0}"#).blockMinutes, 1)
        expectEqual(try decodePreferences(#"{"blockMinutes":900}"#).blockMinutes, 180)
        expectEqual(try decodePreferences(#"{"dailyTarget":9}"#).blockMinutes, 25)
        // The build that named three kinds stored the kind beside the minutes; a custom one
        // kept its minutes under their own key and must come back as the length it was.
        expectEqual(try decodePreferences(#"{"sessionLength":"hour","blockMinutes":60}"#).blockMinutes, 60)
        let named = try decodePreferences(#"{"sessionLength":"custom","blockMinutes":25,"customMinutes":40,"companionEnabled":false}"#)
        expectEqual(named.blockMinutes, 40)
        // The retired turtle toggle is the same setting as the notch timer, under its old name.
        expectFalse(named.notchTimerEnabled)
        expectEqual(named.notchTimerMode, .menuBar)
        // A file that only ever knew the switch comes back asking for the bar, and the three
        // placements the setting used to offer collapse onto the two it offers now.
        expectEqual(try decodePreferences(#"{"notchTimerEnabled":true}"#).notchTimerMode, .bar)
        expectEqual(try decodePreferences(#"{"notchTimerMode":"always"}"#).notchTimerMode, .bar)
        expectEqual(try decodePreferences(#"{"notchTimerMode":"auto"}"#).notchTimerMode, .bar)
        expectEqual(try decodePreferences(#"{"notchTimerMode":"off"}"#).notchTimerMode, .menuBar)
        // A build that predates the setting still finds the key it reads.
        let written = String(data: try JSONEncoder().encode(Preferences()), encoding: .utf8) ?? ""
        expectTrue(written.contains("\"notchTimerEnabled\":true"))
        // And in the spelling those builds understand, so a file can move between versions.
        expectTrue(written.contains("\"notchTimerMode\":\"always\""))
    }
    func testDistractionResolutionAndExactExpiry() {
        var engine = Engine(); engine.capture("idle thought", now: now)
        engine.start("Focus", now: now); engine.capture("Look up a book", now: now)
        let id = engine.state.distractions.last!.id
        expectTrue(engine.resolve(id, now: now)!.item.resolved)
        expectTrue(engine.state.block!.distractions[0].resolved)
        expectTrue(engine.expire(now: now.addingTimeInterval(604_799)).isEmpty)
        expectEqual(engine.expire(now: now.addingTimeInterval(604_800)).count, 1)
        expectTrue(engine.state.distractions.isEmpty)
    }
    func testQueueConsumesOnlyTheIntentStarted() {
        var engine = Engine()
        engine.queue("  ", now: now)
        expectTrue(engine.state.pending.isEmpty)
        engine.queue("Sync layer", now: now)
        engine.queue("Review the ADR", now: now)
        engine.queue("Answer Priya", now: now)
        expectEqual(engine.state.pending.count, 3)
        let second = engine.state.pending[1]
        engine.start(second.text, now: now, consuming: second.id)
        expectEqual(engine.state.block?.intent, "Review the ADR")
        // Only the one started leaves; skipping past the first must not discard it.
        expectEqual(engine.state.pending.map(\.text), ["Sync layer", "Answer Priya"])
    }
    func testTypedIntentLeavesTheQueueAloneAndQueueSurvivesAbandon() {
        var engine = Engine()
        engine.queue("Sync layer", now: now)
        engine.start("Something else entirely", now: now)
        expectEqual(engine.state.pending.count, 1)
        expectNil(engine.abandon(reason: "Fire alarm", now: now)?.check)
        expectEqual(engine.state.phase, .idle)
        // Abandoning a block must not throw away what was planned after it.
        expectEqual(engine.state.pending.first?.text, "Sync layer")
        let removal = engine.removePending(engine.state.pending[0].id, now: now)
        expectEqual(removal?.disposition, "removed")
        expectTrue(engine.state.pending.isEmpty)
    }
    func testRestoreFromArchive() {
        var engine = Engine()
        engine.queue("Sync layer", now: now)
        let removed = engine.removePending(engine.state.pending[0].id, now: now)!
        expectTrue(engine.state.pending.isEmpty)
        let back = engine.restorePending(removed.intent, now: now)
        expectEqual(back?.disposition, "restored")
        expectEqual(engine.state.pending.first?.text, "Sync layer")
        // Restoring twice must not duplicate the entry.
        expectNil(engine.restorePending(removed.intent, now: now))
        expectEqual(engine.state.pending.count, 1)

        engine.capture("Look up a book", now: now)
        let expired = engine.expire(now: now.addingTimeInterval(604_800))
        expectEqual(expired.count, 1)
        expectTrue(engine.state.distractions.isEmpty)
        let later = now.addingTimeInterval(700_000)
        let revived = engine.restoreDistraction(expired[0].item, now: later)
        expectEqual(revived?.disposition, "restored")
        // A restored distraction needs a fresh clock or the next tick expires it again.
        expectEqual(engine.state.distractions.first?.at, later)
        expectTrue(engine.expire(now: later.addingTimeInterval(604_799)).isEmpty)
        // Archive events are per-event, never per-item: one distraction accrues several.
        expectTrue(expired[0].id != revived!.id)
    }
    func testQueueSurvivesRelaunch() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = try Storage(directory: directory)
        var engine = Engine()
        engine.queue("Sync layer", now: now)
        try storage.save(engine.state)
        let recovered = try storage.readState()
        expectEqual(recovered.pending.count, 1)
        expectEqual(recovered.pending.first?.text, "Sync layer")
        expectEqual(recovered.preferences.hotkeyCode, 44)
        expectEqual(recovered.preferences.hotkeyModifiers, 256)
        expectEqual(recovered.preferences.startHotkeyCode, 44)
        expectEqual(recovered.preferences.startHotkeyModifiers, 768)
    }
    func testRecoveryDoesNotChargeDowntimeAndPendingAppendIsIdempotent() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = try Storage(directory: directory)
        var engine = Engine(); engine.start("Focus", now: now)
        _ = engine.tick(seconds: 100, now: now)
        try storage.save(engine.state)
        let recovered = Engine(state: try storage.readState())
        expectEqual(recovered.state.remaining, 1400)
        expectEqual(recovered.state.phase, .running)
        let block = engine.abandon(reason: "Test", now: now)!
        engine.state.pendingBlocks.append(block)
        try storage.save(engine.state)
        try storage.append(block)
        let replay = try storage.readState()
        try storage.append(replay.pendingBlocks[0])
        expectEqual(try storage.blocks().count, 1)
        let data = try String(contentsOf: directory.appendingPathComponent("blocks.jsonl"))
        expectTrue(data.contains("\"check\":null"))
        expectEqual(data.split(separator: "\n").count, 1)
    }
    func testBrandMigrationPreservesDataAndNeverOverwritesBlocks() throws {
        let support = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: support) }
        let legacy = try Storage(directory: support.appendingPathComponent("Park"))
        var engine = Engine(); engine.queue("Keep this intent", now: now)
        try legacy.save(engine.state)
        let archive = Data("{original archive}\n".utf8)
        try archive.write(to: legacy.directory.appendingPathComponent("parking.jsonl"))
        let destination = try Storage.migrateLegacyDirectory(in: support)
        let migrated = try Storage(directory: destination)
        expectEqual(try migrated.readState().pending.first?.text, "Keep this intent")
        expectEqual(try Data(contentsOf: destination.appendingPathComponent("parking.jsonl")), archive)
        expectEqual(try legacy.readState().pending.first?.text, "Keep this intent")
        try migrated.save(LiveState())
        _ = try Storage.migrateLegacyDirectory(in: support)
        expectTrue(try migrated.readState().pending.isEmpty)
        let freshSupport = support.appendingPathComponent("fresh")
        expectEqual(try Storage.migrateLegacyDirectory(in: freshSupport), freshSupport.appendingPathComponent("Blocks", isDirectory: true))
    }
    func testCorruptionIsReportedAndPreserved() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = try Storage(directory: directory)
        let url = directory.appendingPathComponent("state.json")
        let broken = Data("{broken".utf8)
        try broken.write(to: url)
        expectError(try storage.readState())
        expectEqual(try Data(contentsOf: url), broken)
    }
}

// Command Line Tools omit XCTest. These checks deliberately need only Foundation.
func expectEqual<T: Equatable>(_ actual: @autoclosure () throws -> T, _ expected: T, file: StaticString = #filePath, line: UInt = #line) {
    do { let value = try actual(); precondition(value == expected, "Expected \(expected), got \(value) at \(file):\(line)") }
    catch { fatalError("Unexpected error: \(error) at \(file):\(line)") }
}
func expectTrue(_ value: Bool, file: StaticString = #filePath, line: UInt = #line) { precondition(value, "Expected true at \(file):\(line)") }
func expectFalse(_ value: Bool, file: StaticString = #filePath, line: UInt = #line) { precondition(!value, "Expected false at \(file):\(line)") }
func expectNil<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) { precondition(value == nil, "Expected nil at \(file):\(line)") }
func expectError<T>(_ action: @autoclosure () throws -> T) { do { _ = try action() } catch { return }; fatalError("Expected an error") }
@main enum Checks {
    static func main() throws {
        let tests = EngineTests()
        tests.testIntentAndWarningBoundary()
        tests.testPauseRequiresReasonAndSecondStopResets()
        tests.testSecondStopWhilePausedAndAbandon()
        tests.testCompletionIsQuietAndExactlyOnce()
        tests.testExtendReopensTheSameSessionAndOfferExpires()
        tests.testEverySessionGetsItsOwnTask()
        tests.testProjectIndexFollowsTheTaskNotTheSnapshot()
        tests.testSameTitleInDifferentProjectsStaysSeparate()
        tests.testFocusDurationExcludesPausesAndPreservesPartialWork()
        try tests.testLegacyHistoryMigrationAndRetaggingAreStable()
        tests.testLegacyCheckingCheckpointFinishesWithoutPrompt()
        try tests.testNewPreferencesAndTaskSurviveRelaunch()
        try tests.testLiveStateFileMissingLaterKeysStillLoads()
        try tests.testSessionLengthComesFromTheOneDefault()
        tests.testDistractionResolutionAndExactExpiry()
        tests.testQueueConsumesOnlyTheIntentStarted()
        tests.testTypedIntentLeavesTheQueueAloneAndQueueSurvivesAbandon()
        tests.testRestoreFromArchive()
        try tests.testQueueSurvivesRelaunch()
        try tests.testRecoveryDoesNotChargeDowntimeAndPendingAppendIsIdempotent()
        try tests.testCorruptionIsReportedAndPreserved()
        try tests.testStateFileFromABuildWithBreaksDecodesAsIdle()
        try tests.testBrandMigrationPreservesDataAndNeverOverwritesBlocks()
        print("PASS: 22 lifecycle, session length, extension, task, migration, and persistence checks")
    }
}
