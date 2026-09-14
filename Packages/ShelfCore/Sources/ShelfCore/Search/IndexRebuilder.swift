import Foundation

/// Rebuilds disposable indexes after restore or interruption; originals remain readable throughout.
public actor IndexRebuilder {
    private let vault: any DocumentVault
    private let indexes: any TextIndexPersistence
    private let inspector: any DocumentInspecting
    private let repository: LibraryRepository
    public init(vault: any DocumentVault, indexes: any TextIndexPersistence,
                inspector: any DocumentInspecting, repository: LibraryRepository) {
        self.vault = vault; self.indexes = indexes
        self.inspector = inspector; self.repository = repository
    }
    @discardableResult
    public func rebuildMissing() async -> Int {
        guard let snapshot = try? await repository.snapshot() else { return 0 }
        var failures = 0
        for book in snapshot.activeBooks {
            if Task.isCancelled { break }
            if (try? indexes.read(id: book.id)) != nil { continue }
            do {
                let inspection = try await inspector.inspect(vault.originalURL(for: book.id))
                try indexes.write(inspection.index, id: book.id)
                try await repository.updateBook(id: book.id) { $0.indexStatus = inspection.status }
            } catch { failures += 1 }
        }
        return failures
    }
}
