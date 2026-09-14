import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

public protocol LearningSnapshotPersistence: Sendable {
    func load() throws -> LearningSnapshot
    func save(_ snapshot: LearningSnapshot) throws
}

public final class FileLearningSnapshotStore: LearningSnapshotPersistence, @unchecked Sendable {
    private let directory: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let lock = NSRecursiveLock()

    public init(root: URL, fileManager: FileManager = .default) {
        self.directory = root.appendingPathComponent("Learning", isDirectory: true)
        self.fileManager = fileManager
        encoder = JSONEncoder(); decoder = JSONDecoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    public func load() throws -> LearningSnapshot {
        lock.lock(); defer { lock.unlock() }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let current = directory.appendingPathComponent("learning.json")
        let previous = directory.appendingPathComponent("learning.previous.json")

        if fileManager.fileExists(atPath: current.path) {
            do { return try decode(current) }
            catch let error as ShelfError {
                // A future schema must never be silently replaced with an empty local state.
                if case .unsupportedVersion = error { throw error }
                return try recoverAfterCorruption(current: current, previous: previous)
            } catch {
                return try recoverAfterCorruption(current: current, previous: previous)
            }
        }
        if fileManager.fileExists(atPath: previous.path) {
            do { return try decode(previous) }
            catch let error as ShelfError {
                if case .unsupportedVersion = error { throw error }
                quarantine(previous)
                return LearningSnapshot()
            } catch {
                quarantine(previous)
                return LearningSnapshot()
            }
        }
        return LearningSnapshot()
    }

    public func save(_ snapshot: LearningSnapshot) throws {
        let started = DispatchTime.now().uptimeNanoseconds
        var byteCount = 0
        defer { IntelligencePerformance.record("persistence", since: started, workCount: 1, bytes: byteCount) }
        lock.lock(); defer { lock.unlock() }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let current = directory.appendingPathComponent("learning.json")
        let previous = directory.appendingPathComponent("learning.previous.json")
        let data = try encoder.encode(snapshot)
        byteCount = data.count
        if fileManager.fileExists(atPath: current.path) {
            // Never replace a recoverable backup with an unreadable current file.
            _ = try decode(current)
            let backup = try Data(contentsOf: current)
            byteCount += backup.count
            try durableReplace(backup, at: previous)
        }
        try durableReplace(data, at: current)
    }

    /// Staging in the destination directory guarantees a same-volume rename.
    /// The committed pathname is never removed: readers see the old or new file.
    /// Orphaned staging files after interruption are never treated as committed.
    private func durableReplace(_ data: Data, at destination: URL) throws {
        let staging = directory.appendingPathComponent(".learning-next-\(UUID().uuidString).json")
        let descriptor = open(staging.path, O_WRONLY | O_CREAT | O_EXCL, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw posixError(staging) }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close(); try? fileManager.removeItem(at: staging) }
        try handle.write(contentsOf: data)
        try handle.synchronize()
        try handle.close()
        guard rename(staging.path, destination.path) == 0 else { throw posixError(destination) }
        let directoryDescriptor = open(directory.path, O_RDONLY)
        guard directoryDescriptor >= 0 else { throw posixError(directory) }
        defer { _ = close(directoryDescriptor) }
        guard fsync(directoryDescriptor) == 0 else { throw posixError(directory) }
    }

    private func posixError(_ url: URL) -> NSError {
        NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [NSFilePathErrorKey: url.path])
    }

    private func recoverAfterCorruption(current: URL, previous: URL) throws -> LearningSnapshot {
        if fileManager.fileExists(atPath: previous.path) {
            do {
                let recovered = try decode(previous)
                quarantine(current)
                return recovered
            } catch let error as ShelfError {
                if case .unsupportedVersion = error { throw error }
            } catch { }
        }
        quarantine(current)
        quarantine(previous)
        return LearningSnapshot()
    }

    private func decode(_ url: URL) throws -> LearningSnapshot {
        let started = DispatchTime.now().uptimeNanoseconds
        let data = try Data(contentsOf: url)
        defer { IntelligencePerformance.record("snapshot_decode", since: started, bytes: data.count) }
        let snapshot = try decoder.decode(LearningSnapshot.self, from: data)
        guard snapshot.schemaVersion <= 1 else { throw ShelfError.unsupportedVersion(snapshot.schemaVersion) }
        return snapshot
    }

    private func quarantine(_ url: URL) {
        guard fileManager.fileExists(atPath: url.path) else { return }
        let stamp = UUID().uuidString
        let destination = directory.appendingPathComponent(url.lastPathComponent + ".corrupt-" + stamp)
        try? fileManager.moveItem(at: url, to: destination)
    }
}
