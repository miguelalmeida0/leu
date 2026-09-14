import XCTest
@testable import ShelfCore

final class AnnotationTests: XCTestCase {
    func testAnnotationsAreSaved() async throws {
        let repo = LibraryRepository(persistence: MemoryStore()); let book = fixtureBook(); _ = try await repo.insertImported(book)
        let mark = StudyAnnotation(bookID: book.id, pageIndex: 1, kind: .review, note: "Explain this")
        try await repo.addAnnotations([mark]); let state = try await repo.snapshot(); XCTAssertEqual(state.annotations, [mark])
    }
    func testInvalidPageRejectedAtomically() async throws {
        let repo = LibraryRepository(persistence: MemoryStore()); let book = fixtureBook(); _ = try await repo.insertImported(book)
        do { try await repo.addAnnotations([StudyAnnotation(bookID: book.id, pageIndex: 99, kind: .highlight)]); XCTFail("Must fail") } catch {}
        let state = try await repo.snapshot(); XCTAssertTrue(state.annotations.isEmpty)
    }
    func testDuplicateAnnotationIDRejected() async throws {
        let repo = LibraryRepository(persistence: MemoryStore()); let book = fixtureBook(); _ = try await repo.insertImported(book)
        let mark = StudyAnnotation(bookID: book.id, pageIndex: 0, kind: .note)
        do { try await repo.addAnnotations([mark, mark]); XCTFail("Must fail") } catch {}
        let state = try await repo.snapshot(); XCTAssertTrue(state.annotations.isEmpty)
    }
    func testNaNGeometryRejected() async throws {
        let repo = LibraryRepository(persistence: MemoryStore()); let book = fixtureBook(); _ = try await repo.insertImported(book)
        let mark = StudyAnnotation(bookID: book.id, pageIndex: 0, kind: .highlight,
            rects: [PDFRect(x: .nan, y: 0, width: 10, height: 10)])
        do { try await repo.addAnnotations([mark]); XCTFail("Must reject") } catch {}
    }
    func testMultiPageRemovalIsAtomic() async throws {
        let repo = LibraryRepository(persistence: MemoryStore()); let book = fixtureBook(); _ = try await repo.insertImported(book)
        let marks = (0..<3).map { StudyAnnotation(bookID: book.id, pageIndex: $0, kind: .highlight) }
        try await repo.addAnnotations(marks)
        try await repo.removeAnnotations(ids: Set(marks.map(\.id)))
        let empty = try await repo.snapshot(); XCTAssertTrue(empty.annotations.isEmpty)
        try await repo.addAnnotations(marks)
        let restored = try await repo.snapshot(); XCTAssertEqual(restored.annotations, marks)
    }
    func testBookmarkToggle() async throws {
        let repo = LibraryRepository(persistence: MemoryStore()); let book = fixtureBook(); _ = try await repo.insertImported(book)
        let first = try await repo.toggleBookmark(bookID: book.id, pageIndex: 2); XCTAssertTrue(first)
        let second = try await repo.toggleBookmark(bookID: book.id, pageIndex: 2); XCTAssertFalse(second)
        let state = try await repo.snapshot(); XCTAssertTrue(state.bookmarks.isEmpty)
    }
    func testInvalidBookmarkPageRejected() async throws {
        let repo = LibraryRepository(persistence: MemoryStore()); let book = fixtureBook(); _ = try await repo.insertImported(book)
        do { _ = try await repo.toggleBookmark(bookID: book.id, pageIndex: -1); XCTFail("Must reject") } catch {}
    }
    func testTrashPreservesNotesAndPosition() async throws {
        let repo = LibraryRepository(persistence: MemoryStore()); let book = fixtureBook(); _ = try await repo.insertImported(book)
        try await repo.addAnnotations([StudyAnnotation(bookID: book.id, pageIndex: 1, kind: .note, note: "Keep me")])
        try await repo.savePosition(bookID: book.id, position: ReadingPosition(pageIndex: 4, updatedAt: .distantFuture))
        try await repo.trashBook(id: book.id)
        let trash = try await repo.snapshot(); XCTAssertTrue(trash.activeBooks.isEmpty); XCTAssertEqual(trash.annotations.count, 1)
        try await repo.restoreBook(id: book.id)
        let restored = try await repo.book(id: book.id); XCTAssertEqual(restored.position.pageIndex, 4)
    }
    func testActiveBookCannotBePermanentlyForgotten() async throws {
        let repo = LibraryRepository(persistence: MemoryStore()); let book = fixtureBook(); _ = try await repo.insertImported(book)
        do { try await repo.forgetTrashedBook(id: book.id); XCTFail("Must fail") } catch {}
    }
}
