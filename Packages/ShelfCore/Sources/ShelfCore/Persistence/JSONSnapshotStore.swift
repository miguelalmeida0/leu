import Foundation

/// Atomic metadata commits plus one validated previous generation. Never silently resets corruption.
public struct JSONSnapshotStore: SnapshotPersistence {
    public let root: URL
    public init(root: URL) { self.root = root }
    public var currentURL: URL { root.appendingPathComponent("library.json") }
    public var previousURL: URL { root.appendingPathComponent("library.previous.json") }

    public func load() throws -> SnapshotLoad {
        let fm = FileManager.default
        guard fm.fileExists(atPath: currentURL.path) else {
            if fm.fileExists(atPath: previousURL.path) { return try recover() }
            let originals = root.appendingPathComponent("Originals")
            if let files = try? fm.contentsOfDirectory(atPath: originals.path), !files.isEmpty {
                throw ShelfError.corruptLibrary("Metadata is missing, but original files still exist.")
            }
            return SnapshotLoad(snapshot: LibrarySnapshot())
        }
        do { return SnapshotLoad(snapshot: try decode(currentURL)) }
        catch ShelfError.unsupportedVersion(let version) { throw ShelfError.unsupportedVersion(version) }
        catch {
            guard fm.fileExists(atPath: previousURL.path) else {
                throw ShelfError.corruptLibrary("No readable metadata checkpoint is available.")
            }
            return try recover()
        }
    }

    public func save(_ snapshot: LibrarySnapshot) throws {
        _ = try snapshot.validated()
        let fm = FileManager.default
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(snapshot)
        guard data.count <= 32 * 1_024 * 1_024 else {
            throw ShelfError.corruptLibrary("Metadata exceeds the 32 MB safety limit. Export a backup before adding more notes.")
        }
        if fm.fileExists(atPath: currentURL.path), (try? decode(currentURL)) != nil {
            try Data(contentsOf: currentURL).write(to: previousURL, options: .atomic)
        }
        try data.write(to: currentURL, options: .atomic)
    }

    private func decode(_ url: URL) throws -> LibrarySnapshot {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= 32 * 1_024 * 1_024 else {
            throw ShelfError.corruptLibrary("The metadata file exceeds the safety limit.")
        }
        return try JSONDecoder().decode(LibrarySnapshot.self, from: Data(contentsOf: url)).validated()
    }

    private func recover() throws -> SnapshotLoad {
        let snapshot: LibrarySnapshot
        do { snapshot = try decode(previousURL) }
        catch { throw ShelfError.corruptLibrary("Neither metadata checkpoint could be read.") }
        let fm = FileManager.default
        if fm.fileExists(atPath: currentURL.path) {
            let preserved = root.appendingPathComponent("library.corrupt-\(UUID().uuidString).json")
            try fm.copyItem(at: currentURL, to: preserved)
        }
        try Data(contentsOf: previousURL).write(to: currentURL, options: .atomic)
        return SnapshotLoad(snapshot: snapshot, recoveredFromPrevious: true)
    }
}
