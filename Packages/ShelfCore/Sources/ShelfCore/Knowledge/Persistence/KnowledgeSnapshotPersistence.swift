import Foundation

public protocol KnowledgeSnapshotPersistence: Sendable {
    func load() throws -> KnowledgeSnapshot
    func save(_ snapshot: KnowledgeSnapshot) throws
}

public final class FileKnowledgeSnapshotStore: KnowledgeSnapshotPersistence, @unchecked Sendable {
    private let directory: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(root: URL, fileManager: FileManager = .default) {
        directory = root.appendingPathComponent("Knowledge", isDirectory: true)
        self.fileManager = fileManager
        encoder = JSONEncoder(); decoder = JSONDecoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    public func load() throws -> KnowledgeSnapshot {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let current = directory.appendingPathComponent("knowledge.json")
        let previous = directory.appendingPathComponent("knowledge.previous.json")
        if fileManager.fileExists(atPath: current.path) {
            do { return try decode(current) }
            catch let error as ShelfError {
                if case .unsupportedVersion = error { throw error }
                return try recover(current: current, previous: previous)
            } catch { return try recover(current: current, previous: previous) }
        }
        if fileManager.fileExists(atPath: previous.path) {
            do { return try decode(previous) } catch { quarantine(previous); return KnowledgeSnapshot() }
        }
        return KnowledgeSnapshot()
    }

    public func save(_ snapshot: KnowledgeSnapshot) throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let current = directory.appendingPathComponent("knowledge.json")
        let previous = directory.appendingPathComponent("knowledge.previous.json")
        let next = directory.appendingPathComponent("knowledge.next.json")
        try encoder.encode(snapshot).write(to: next, options: .atomic)
        if fileManager.fileExists(atPath: current.path) {
            try? fileManager.removeItem(at: previous)
            try fileManager.copyItem(at: current, to: previous)
            try fileManager.removeItem(at: current)
        }
        try fileManager.moveItem(at: next, to: current)
    }

    private func decode(_ url: URL) throws -> KnowledgeSnapshot {
        let snapshot = try decoder.decode(KnowledgeSnapshot.self, from: Data(contentsOf: url))
        guard snapshot.schemaVersion <= 1 else { throw ShelfError.unsupportedVersion(snapshot.schemaVersion) }
        return snapshot
    }

    private func recover(current: URL, previous: URL) throws -> KnowledgeSnapshot {
        if fileManager.fileExists(atPath: previous.path), let recovered = try? decode(previous) {
            quarantine(current); return recovered
        }
        quarantine(current); quarantine(previous); return KnowledgeSnapshot()
    }

    private func quarantine(_ url: URL) {
        guard fileManager.fileExists(atPath: url.path) else { return }
        let suffix = String(Int(Date().timeIntervalSince1970))
        try? fileManager.moveItem(at: url, to: directory.appendingPathComponent(url.lastPathComponent + ".corrupt-" + suffix))
    }
}
