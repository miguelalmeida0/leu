import Foundation

public struct StagedBackup: Sendable {
    public let snapshot: LibrarySnapshot
    public let root: URL
    public var vault: FileDocumentVault { FileDocumentVault(root: root) }
    public func discard() { try? FileManager.default.removeItem(at: root) }
}

/// Verifies every byte before exposing a restorable library. No archive-provided path is trusted.
public struct BackupReader: Sendable {
    public init() {}
    public func stage(_ source: URL, in temporaryDirectory: URL) throws -> StagedBackup {
        let input = try FileHandle(forReadingFrom: source)
        defer { try? input.close() }
        guard try BackupFormat.readExactly(input, count: BackupFormat.magic.count) == BackupFormat.magic else {
            throw ShelfError.invalidBackup("This is not a supported Shelf backup.")
        }
        let length = BackupFormat.decodeLength(try BackupFormat.readExactly(input, count: 8))
        guard length > 0, length <= BackupFormat.manifestLimit else {
            throw ShelfError.invalidBackup("Invalid metadata length.")
        }
        let manifest: BackupManifest
        do {
            manifest = try JSONDecoder().decode(BackupManifest.self,
                from: BackupFormat.readExactly(input, count: Int(length)))
        } catch { throw ShelfError.invalidBackup("The metadata is damaged.") }
        try validate(manifest)
        let root = temporaryDirectory.appendingPathComponent("restore-" + UUID().uuidString, isDirectory: true)
        let vault = FileDocumentVault(root: root)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Originals"),
                                                withIntermediateDirectories: true)
        var success = false
        defer { if !success { try? FileManager.default.removeItem(at: root) } }
        for file in manifest.originals {
            try Task.checkCancellation()
            let destination = vault.originalURL(for: file.id)
            try extract(file, input: input, destination: destination)
            guard try FileDigest.sha256(url: destination) == file.fingerprint else {
                throw ShelfError.invalidBackup("A PDF failed its checksum. No library changes were made.")
            }
        }
        if let trailing = try input.read(upToCount: 1), !trailing.isEmpty {
            throw ShelfError.invalidBackup("Unexpected data after the last PDF.")
        }
        success = true
        return StagedBackup(snapshot: manifest.library, root: root)
    }

    private func validate(_ manifest: BackupManifest) throws {
        guard manifest.version == 1 else { throw ShelfError.invalidBackup("Unsupported archive version.") }
        _ = try manifest.library.validated()
        let ids = Set(manifest.originals.map(\.id))
        guard ids.count == manifest.originals.count,
              ids == Set(manifest.library.books.map(\.id)), ids.count <= 100_000 else {
            throw ShelfError.invalidBackup("The document list is inconsistent.")
        }
        let books = Dictionary(uniqueKeysWithValues: manifest.library.books.map { ($0.id, $0) })
        for file in manifest.originals {
            guard let book = books[file.id], file.size == book.byteCount,
                  file.size > 0, file.size <= DocumentLimits.maxBytes,
                  file.fingerprint == book.fingerprint else {
                throw ShelfError.invalidBackup("Invalid document entry.")
            }
        }
    }

    private func extract(_ file: BackupFile, input: FileHandle, destination: URL) throws {
        guard FileManager.default.createFile(atPath: destination.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let output = try FileHandle(forWritingTo: destination)
        defer { try? output.close() }
        var remaining = file.size
        while remaining > 0 {
            try Task.checkCancellation()
            let count = Int(min(remaining, Int64(BackupFormat.chunkSize)))
            let data = try BackupFormat.readExactly(input, count: count)
            try output.write(contentsOf: data)
            remaining -= Int64(data.count)
        }
        try output.synchronize()
    }
}
