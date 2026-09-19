import Foundation

public final class Storage {
    /// Copy the old data atomically on first launch; keep the original as a backup.
    public static func migrateLegacyDirectory(in support: URL) throws -> URL {
        let manager = FileManager.default
        let destination = support.appendingPathComponent("Blocks", isDirectory: true)
        let legacy = support.appendingPathComponent("Park", isDirectory: true)
        guard !manager.fileExists(atPath: destination.path), manager.fileExists(atPath: legacy.path) else { return destination }
        let staging = support.appendingPathComponent(".blocks-migration-" + UUID().uuidString, isDirectory: true)
        defer { try? manager.removeItem(at: staging) }
        try manager.copyItem(at: legacy, to: staging)
        try manager.moveItem(at: staging, to: destination)
        return destination
    }

    public let directory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    public init(directory: URL) throws {
        self.directory = directory
        encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.sortedKeys]
        decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    }
    public func readState() throws -> LiveState {
        let url = directory.appendingPathComponent("state.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return LiveState() }
        return try decoder.decode(LiveState.self, from: Data(contentsOf: url))
    }
    public func save(_ state: LiveState) throws {
        try encoder.encode(state).write(to: directory.appendingPathComponent("state.json"), options: .atomic)
    }
    public func blocks() throws -> [Block] { try readLines("blocks.jsonl") }
    /// The file keeps its original name: renaming it would orphan every record already written.
    public func distractionEvents() throws -> [DistractionEvent] { try readLines("parking.jsonl") }
    public func append(_ block: Block) throws {
        // A crash after append but before state commit must not duplicate a block.
        guard !(try blocks()).contains(where: { $0.id == block.id }) else { return }
        try appendLine(block, file: "blocks.jsonl")
    }
    public func append(_ event: DistractionEvent) throws {
        // Deduplicated per event, not per item: one distraction can be archived, restored and
        // archived again, and each of those is a separate durable record.
        guard !(try distractionEvents()).contains(where: { $0.id == event.id }) else { return }
        try appendLine(event, file: "parking.jsonl")
    }
    // `intents.jsonl` was the queue's archive. Nothing writes to it any more and it is left
    // on disk untouched, as every retired Blocks log is.
    private func readLines<T: Decodable>(_ name: String) throws -> [T] {
        let url = directory.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        // Never silently discard damaged records or overwrite an unreadable state.
        return try data.split(separator: 10).map { try decoder.decode(T.self, from: Data($0)) }
    }
    private func appendLine<T: Encodable>(_ value: T, file: String) throws {
        let url = directory.appendingPathComponent(file)
        if !FileManager.default.fileExists(atPath: url.path) {
            guard FileManager.default.createFile(atPath: url.path, contents: nil, attributes: [.posixPermissions: 0o600]) else {
                throw CocoaError(.fileWriteUnknown)
            }
        }
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        var data = try encoder.encode(value); data.append(10)
        try handle.write(contentsOf: data)
        try handle.synchronize()
    }
}
