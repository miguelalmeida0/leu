import Foundation

public extension LibraryRepository {
    func addAnnotations(_ annotations: [StudyAnnotation]) throws {
        try transaction { snapshot in snapshot.annotations.append(contentsOf: annotations) }
    }
    func removeAnnotations(ids: Set<UUID>) throws {
        try transaction { $0.annotations.removeAll { ids.contains($0.id) } }
    }
    func removeAnnotation(id: UUID) throws {
        try transaction { $0.annotations.removeAll { $0.id == id } }
    }
    func updateAnnotation(id: UUID, note: String, kind: AnnotationKind) throws {
        try transaction { snapshot in
            guard let index = snapshot.annotations.firstIndex(where: { $0.id == id }) else { throw ShelfError.notFound }
            snapshot.annotations[index].note = String(note.prefix(100_000))
            snapshot.annotations[index].kind = kind
        }
    }
    @discardableResult
    func toggleBookmark(bookID: UUID, pageIndex: Int) throws -> Bool {
        try transaction { snapshot in
            guard let book = snapshot.books.first(where: { $0.id == bookID }),
                  (0..<book.pageCount).contains(pageIndex) else { throw ShelfError.notFound }
            if let index = snapshot.bookmarks.firstIndex(where: { $0.bookID == bookID && $0.pageIndex == pageIndex }) {
                snapshot.bookmarks.remove(at: index)
                return false
            }
            snapshot.bookmarks.append(PageBookmark(bookID: bookID, pageIndex: pageIndex,
                                                   title: "Page \(pageIndex + 1)"))
            return true
        }
    }
    func trashBook(id: UUID, at date: Date = Date()) throws {
        try updateBook(id: id) { $0.trashedAt = date }
    }
    func restoreBook(id: UUID) throws { try updateBook(id: id) { $0.trashedAt = nil } }

    /// Called only after explicit user confirmation. File removal is a separate vault operation.
    func forgetTrashedBook(id: UUID) throws {
        try transaction { snapshot in
            guard let book = snapshot.books.first(where: { $0.id == id }), book.isTrashed else {
                throw ShelfError.notFound
            }
            snapshot.books.removeAll { $0.id == id }
            snapshot.annotations.removeAll { $0.bookID == id }
            snapshot.bookmarks.removeAll { $0.bookID == id }
        }
    }
    func permanentlyDelete(id: UUID, vault: any DocumentVault, indexes: any TextIndexPersistence) throws {
        try forgetTrashedBook(id: id)
        // Advance the previous checkpoint before deleting any original bytes.
        try persistence.save(try open())
        try vault.removeOriginal(id: id)
        try indexes.remove(id: id)
    }

}
