import Foundation

public struct LibrarySnapshot: Codable, Equatable, Sendable {
    public static let currentVersion = 1
    public var schemaVersion: Int
    public var books: [Book]
    public var collections: [BookCollection]
    public var annotations: [StudyAnnotation]
    public var bookmarks: [PageBookmark]
    public var didSeedSamples: Bool

    public init(books: [Book] = [], collections: [BookCollection] = [],
                annotations: [StudyAnnotation] = [], bookmarks: [PageBookmark] = [],
                didSeedSamples: Bool = false) {
        self.schemaVersion = Self.currentVersion
        self.books = books; self.collections = collections
        self.annotations = annotations; self.bookmarks = bookmarks
        self.didSeedSamples = didSeedSamples
    }

    public var activeBooks: [Book] { books.filter { !$0.isTrashed } }

    public func validated() throws -> LibrarySnapshot {
        guard schemaVersion == Self.currentVersion else {
            throw ShelfError.unsupportedVersion(schemaVersion)
        }
        let ids = Set(books.map(\.id))
        let collectionIDs = Set(collections.map(\.id))
        guard ids.count == books.count,
              collectionIDs.count == collections.count,
              Set(annotations.map(\.id)).count == annotations.count,
              Set(bookmarks.map(\.id)).count == bookmarks.count else {
            throw ShelfError.corruptLibrary("Duplicate identifiers.")
        }
        for book in books {
            guard book.pageCount > 0, book.pageCount <= 100_000,
                  book.byteCount > 0, book.byteCount <= DocumentLimits.maxBytes,
                  !book.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  book.title.count <= 500,
                  book.fingerprint.count == 64,
                  book.fingerprint.allSatisfy({ $0.isHexDigit && !$0.isUppercase }),
                  book.collectionIDs.isSubset(of: collectionIDs),
                  book.position == book.position.clamped(toPageCount: book.pageCount) else {
                throw ShelfError.corruptLibrary("Invalid document metadata.")
            }
        }
        let counts = Dictionary(uniqueKeysWithValues: books.map { ($0.id, $0.pageCount) })
        for mark in annotations {
            guard let count = counts[mark.bookID], (0..<count).contains(mark.pageIndex),
                  mark.rects.allSatisfy(\.isValid), mark.rects.count <= 10_000,
                  mark.note.count <= 100_000, mark.quote.count <= 100_000 else {
                throw ShelfError.invalidAnnotation
            }
        }
        for bookmark in bookmarks {
            guard let count = counts[bookmark.bookID],
                  (0..<count).contains(bookmark.pageIndex) else {
                throw ShelfError.corruptLibrary("Invalid bookmark.")
            }
        }
        return self
    }
}

public enum DocumentLimits {
    public static let maxBytes: Int64 = 1_073_741_824
    public static let maxIndexBytes = 8 * 1_024 * 1_024
}
