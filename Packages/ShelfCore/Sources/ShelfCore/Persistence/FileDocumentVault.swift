import Foundation

/// Names are derived only from UUIDs, never from imported filenames or archive paths.
public struct FileDocumentVault: DocumentVault {
    public let root: URL
    public init(root: URL) { self.root = root }
    public func originalURL(for id: UUID) -> URL {
        root.appendingPathComponent("Originals", isDirectory: true)
            .appendingPathComponent(id.uuidString).appendingPathExtension("pdf")
    }
    public func contains(id: UUID) -> Bool {
        FileManager.default.fileExists(atPath: originalURL(for: id).path)
    }
    public func stageCopy(from source: URL, id: UUID) throws -> URL {
        let destination = originalURL(for: id)
        let fm = FileManager.default
        try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard !fm.fileExists(atPath: destination.path) else {
            throw ShelfError.invalidPDF("An internal identifier collision prevented import.")
        }
        let staging = destination.appendingPathExtension("staging")
        defer { try? fm.removeItem(at: staging) }
        try fm.copyItem(at: source, to: staging)
        try fm.moveItem(at: staging, to: destination)
        return destination
    }
    public func removeOriginal(id: UUID) throws {
        let url = originalURL(for: id)
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
}
