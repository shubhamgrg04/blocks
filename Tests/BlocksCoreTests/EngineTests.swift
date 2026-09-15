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
        expectEqual(engine.state.phase, .checking)
        expectEqual(engine.state.block?.end, now.addingTimeInterval(1500))
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
    func testNoStillCompletesAndAnswerEndsTheBlock() {
        var engine = Engine(); engine.start("Focus", now: now)
        _ = engine.tick(seconds: 1500, now: now.addingTimeInterval(1500))
        expectEqual(engine.state.phase, .checking)
        let block = engine.answer(.no, now: now.addingTimeInterval(1520))
        expectEqual(block?.outcome, .completed)
        expectEqual(block?.check, .no)
        // The boundary, not the answer, is when the time was served.
        expectEqual(block?.end, now.addingTimeInterval(1500))
        expectEqual(engine.state.phase, .idle)
        expectNil(engine.state.block)
        expectNil(engine.answer(.yes, now: now))
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
    func testParkingResolutionAndExactExpiry() {
        var engine = Engine(); engine.park("idle thought", now: now)
        engine.start("Focus", now: now); engine.park("Look up a book", now: now)
        let id = engine.state.parked.last!.id
        expectTrue(engine.resolve(id, now: now)!.item.resolved)
        expectTrue(engine.state.block!.parked[0].resolved)
        expectTrue(engine.expire(now: now.addingTimeInterval(604_799)).isEmpty)
        expectEqual(engine.expire(now: now.addingTimeInterval(604_800)).count, 1)
        expectTrue(engine.state.parked.isEmpty)
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

        engine.park("Look up a book", now: now)
        let expired = engine.expire(now: now.addingTimeInterval(604_800))
        expectEqual(expired.count, 1)
        expectTrue(engine.state.parked.isEmpty)
        let later = now.addingTimeInterval(700_000)
        let revived = engine.restoreParked(expired[0].item, now: later)
        expectEqual(revived?.disposition, "restored")
        // A restored thought needs a fresh clock or the next tick expires it again.
        expectEqual(engine.state.parked.first?.at, later)
        expectTrue(engine.expire(now: later.addingTimeInterval(604_799)).isEmpty)
        // Archive events are per-event, never per-item: one thought accrues several.
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
        tests.testNoStillCompletesAndAnswerEndsTheBlock()
        try tests.testLiveStateFileMissingLaterKeysStillLoads()
        tests.testParkingResolutionAndExactExpiry()
        tests.testQueueConsumesOnlyTheIntentStarted()
        tests.testTypedIntentLeavesTheQueueAloneAndQueueSurvivesAbandon()
        tests.testRestoreFromArchive()
        try tests.testQueueSurvivesRelaunch()
        try tests.testRecoveryDoesNotChargeDowntimeAndPendingAppendIsIdempotent()
        try tests.testCorruptionIsReportedAndPreserved()
        try tests.testStateFileFromABuildWithBreaksDecodesAsIdle()
        try tests.testBrandMigrationPreservesDataAndNeverOverwritesBlocks()
        print("PASS: 14 lifecycle, queue, parking, and persistence checks")
    }
}
