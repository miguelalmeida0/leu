import Foundation

/// One serialized transaction boundary. Views receive values, never mutable persistence objects.
public actor LibraryRepository {
    let persistence: any SnapshotPersistence
    var state: LibrarySnapshot?
    public private(set) var recoveredFromPrevious = false

    public init(persistence: any SnapshotPersistence) { self.persistence = persistence }

    @discardableResult
    public func open() throws -> LibrarySnapshot {
        if let state { return state }
        let loaded = try persistence.load()
        self.state = loaded.snapshot
        self.recoveredFromPrevious = loaded.recoveredFromPrevious
        return loaded.snapshot
    }

    public func snapshot() throws -> LibrarySnapshot { try open() }
    public func book(id: UUID) throws -> Book {
        guard let book = try open().books.first(where: { $0.id == id }) else { throw ShelfError.notFound }
        return book
    }

    /// Commit first, then publish; an I/O failure cannot leak uncommitted in-memory state.
    @discardableResult
    func transaction<T>(_ mutation: (inout LibrarySnapshot) throws -> T) throws -> T {
        var next = try open()
        let value = try mutation(&next)
        _ = try next.validated()
        try persistence.save(next)
        state = next
        return value
    }

    public func markSamplesSeeded() throws {
        try transaction { $0.didSeedSamples = true }
    }

    @discardableResult
    public func insertImported(_ book: Book) throws -> Book {
        try transaction { snapshot in
            if let index = snapshot.books.firstIndex(where: { $0.fingerprint == book.fingerprint }) {
                snapshot.books[index].trashedAt = nil
                return snapshot.books[index]
            }
            snapshot.books.append(book)
            return book
        }
    }

    public func updateBook(id: UUID, _ edit: @Sendable (inout Book) throws -> Void) throws {
        try transaction { snapshot in
            guard let index = snapshot.books.firstIndex(where: { $0.id == id }) else { throw ShelfError.notFound }
            try edit(&snapshot.books[index])
            let title = snapshot.books[index].title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { throw ShelfError.emptyTitle }
            snapshot.books[index].title = String(title.prefix(500))
        }
    }

    public func savePosition(bookID: UUID, position: ReadingPosition) throws {
        try updateBook(id: bookID) { book in
            guard position.updatedAt >= book.position.updatedAt else { return }
            book.position = position.clamped(toPageCount: book.pageCount)
        }
    }
    public func recordOpened(bookID: UUID, at date: Date = Date()) throws {
        try updateBook(id: bookID) { $0.lastOpenedAt = date }
    }
}
