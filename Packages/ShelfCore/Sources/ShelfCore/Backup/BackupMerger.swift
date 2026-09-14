import Foundation

public struct RestoreResult: Sendable {
    public let addedBooks: Int
    public let matchedBooks: Int
    public let addedAnnotations: Int
}

struct RestorePlan {
    var snapshot: LibrarySnapshot
    var copies: [(source: UUID, destination: UUID)]
    var result: RestoreResult
}

enum BackupMerger {
    /// Merge-only: preserve current titles, positions, trash state, and existing annotation edits.
    static func plan(current: LibrarySnapshot, incoming: LibrarySnapshot) throws -> RestorePlan {
        _ = try incoming.validated()
        var merged = current
        var collections: [UUID: UUID] = [:]
        for collection in incoming.collections.sorted(by: { $0.order < $1.order }) {
            if let match = merged.collections.first(where: { $0.name.normalizedSearch == collection.name.normalizedSearch }) {
                collections[collection.id] = match.id
            } else {
                var copy = collection
                if merged.collections.contains(where: { $0.id == copy.id }) { copy.id = UUID() }
                copy.order = merged.collections.count
                merged.collections.append(copy)
                collections[collection.id] = copy.id
            }
        }
        var bookIDs: [UUID: UUID] = [:]
        var copies: [(source: UUID, destination: UUID)] = []
        var matched = 0
        for book in incoming.books {
            let mappedCollections = Set(book.collectionIDs.compactMap { collections[$0] })
            if let index = merged.books.firstIndex(where: { $0.fingerprint == book.fingerprint }) {
                bookIDs[book.id] = merged.books[index].id
                merged.books[index].collectionIDs.formUnion(mappedCollections)
                matched += 1
            } else {
                var copy = book
                if merged.books.contains(where: { $0.id == copy.id }) { copy.id = UUID() }
                copy.collectionIDs = mappedCollections
                copy.indexStatus = .pending
                merged.books.append(copy)
                bookIDs[book.id] = copy.id
                copies.append((book.id, copy.id))
            }
        }
        let originalMarkCount = merged.annotations.count
        for mark in incoming.annotations {
            guard let bookID = bookIDs[mark.bookID] else { continue }
            var copy = mark; copy.bookID = bookID
            if let existing = merged.annotations.first(where: { $0.id == copy.id }) {
                if existing.bookID == bookID { continue }
                copy.id = UUID()
            }
            merged.annotations.append(copy)
        }
        for bookmark in incoming.bookmarks {
            guard let bookID = bookIDs[bookmark.bookID],
                  !merged.bookmarks.contains(where: { $0.bookID == bookID && $0.pageIndex == bookmark.pageIndex }) else { continue }
            var copy = bookmark; copy.bookID = bookID
            if merged.bookmarks.contains(where: { $0.id == copy.id }) { copy.id = UUID() }
            merged.bookmarks.append(copy)
        }
        merged.didSeedSamples = current.didSeedSamples || incoming.didSeedSamples
        return RestorePlan(snapshot: try merged.validated(), copies: copies,
            result: RestoreResult(addedBooks: copies.count, matchedBooks: matched,
                                  addedAnnotations: merged.annotations.count - originalMarkCount))
    }
}
