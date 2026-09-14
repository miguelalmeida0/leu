import Foundation

/// Disposable derived data: an index failure must never make an original PDF inaccessible.
public struct FileTextIndexStore: TextIndexPersistence {
    public let root: URL
    public init(root: URL) { self.root = root.appendingPathComponent("Indexes") }
    public func read(id: UUID) throws -> BookTextIndex? {
        let url = fileURL(id)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= DocumentLimits.maxIndexBytes * 3 else { return nil }
        return try JSONDecoder().decode(BookTextIndex.self, from: Data(contentsOf: url))
    }
    public func write(_ index: BookTextIndex, id: UUID) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try JSONEncoder().encode(index).write(to: fileURL(id), options: .atomic)
    }
    public func remove(id: UUID) throws {
        let url = fileURL(id)
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
    private func fileURL(_ id: UUID) -> URL {
        root.appendingPathComponent(id.uuidString).appendingPathExtension("json")
    }
}
