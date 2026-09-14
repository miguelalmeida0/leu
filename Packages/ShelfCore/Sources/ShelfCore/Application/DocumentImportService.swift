import Foundation

public struct ImportResult: Sendable {
    public let book: Book
    public let wasDuplicate: Bool
}

/// Owns the import transaction: copy -> inspect -> hash -> index -> durable metadata commit.
public actor DocumentImportService {
    private let repository: LibraryRepository
    private let vault: any DocumentVault
    private let inspector: any DocumentInspecting
    private let indexes: any TextIndexPersistence

    public init(repository: LibraryRepository, vault: any DocumentVault,
                inspector: any DocumentInspecting, indexes: any TextIndexPersistence) {
        self.repository = repository; self.vault = vault
        self.inspector = inspector; self.indexes = indexes
    }

    public func importDocument(at source: URL, originalFilename: String? = nil) async throws -> ImportResult {
        _ = try await repository.open()
        try Task.checkCancellation()
        let values = try source.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile == true else { throw ShelfError.invalidPDF("Choose a regular PDF file.") }
        let size = Int64(values.fileSize ?? 0)
        guard size > 0 else { throw ShelfError.invalidPDF("The file is empty.") }
        guard size <= DocumentLimits.maxBytes else { throw ShelfError.tooLarge }
        let id = UUID()
        let copied = try vault.stageCopy(from: source, id: id)
        var retained = false
        defer {
            if !retained { try? vault.removeOriginal(id: id); try? indexes.remove(id: id) }
        }
        let copiedSize = Int64(try copied.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
        guard copiedSize > 0 else { throw ShelfError.invalidPDF("The copied file is empty.") }
        guard copiedSize <= DocumentLimits.maxBytes else { throw ShelfError.tooLarge }
        let inspection = try await inspector.inspect(copied)
        guard inspection.pageCount > 0 else { throw ShelfError.invalidPDF("No readable pages were found.") }
        try Task.checkCancellation()
        let fingerprint = try FileDigest.sha256(url: copied)
        let filename = URL(fileURLWithPath: originalFilename ?? source.lastPathComponent).lastPathComponent
        let rawTitle = (filename as NSString).deletingPathExtension.replacingOccurrences(of: "_", with: " ")
        let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let seed = Int(fingerprint.prefix(2), radix: 16) ?? 0
        var book = Book(id: id, title: title.isEmpty ? "Untitled PDF" : String(title.prefix(500)),
                        originalFilename: filename, fingerprint: fingerprint,
                        pageCount: inspection.pageCount, byteCount: copiedSize,
                        palette: CoverPalette.allCases[seed % CoverPalette.allCases.count],
                        artwork: CoverArt.allCases[(seed / 7) % CoverArt.allCases.count],
                        indexStatus: inspection.status)
        do { try indexes.write(inspection.index, id: id) }
        catch { book.indexStatus = .pending }
        let inserted = try await repository.insertImported(book)
        retained = inserted.id == id
        return ImportResult(book: inserted, wasDuplicate: !retained)
    }
}
