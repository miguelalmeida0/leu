import Foundation

/// Portable, uncompressed streaming archive. The format is documented; originals remain ordinary PDFs.
public struct BackupWriter: Sendable {
    public init() {}
    public func write(snapshot: LibrarySnapshot, vault: any DocumentVault, to destination: URL) throws {
        _ = try snapshot.validated()
        let files = snapshot.books.map { BackupFile(id: $0.id, size: $0.byteCount, fingerprint: $0.fingerprint) }
        let manifest = BackupManifest(library: snapshot, originals: files)
        let data = try JSONEncoder().encode(manifest)
        guard data.count <= BackupFormat.manifestLimit else {
            throw ShelfError.invalidBackup("Metadata exceeds the archive safety limit.")
        }
        let fm = FileManager.default
        try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        let staging = destination.appendingPathExtension(UUID().uuidString + ".partial")
        guard fm.createFile(atPath: staging.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        defer { try? fm.removeItem(at: staging) }
        let output = try FileHandle(forWritingTo: staging)
        defer { try? output.close() }
        try output.write(contentsOf: BackupFormat.magic)
        try output.write(contentsOf: BackupFormat.encodeLength(UInt64(data.count)))
        try output.write(contentsOf: data)
        for file in files {
            try Task.checkCancellation()
            let source = vault.originalURL(for: file.id)
            guard vault.contains(id: file.id) else {
                throw ShelfError.missingOriginal(file.id.uuidString)
            }
            let actualSize = try source.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? -1
            guard Int64(actualSize) == file.size, try FileDigest.sha256(url: source) == file.fingerprint else {
                throw ShelfError.invalidBackup("An original PDF failed its integrity check.")
            }
            try copy(source, size: file.size, to: output)
        }
        try output.synchronize()
        // The caller uses a fresh destination; never overwrite an existing user-owned backup.
        guard !fm.fileExists(atPath: destination.path) else { throw CocoaError(.fileWriteFileExists) }
        try fm.moveItem(at: staging, to: destination)
    }

    private func copy(_ source: URL, size: Int64, to output: FileHandle) throws {
        let input = try FileHandle(forReadingFrom: source)
        defer { try? input.close() }
        var remaining = size
        while remaining > 0 {
            try Task.checkCancellation()
            let chunk = try BackupFormat.readExactly(input, count: Int(min(remaining, Int64(BackupFormat.chunkSize))))
            try output.write(contentsOf: chunk)
            remaining -= Int64(chunk.count)
        }
    }
}
