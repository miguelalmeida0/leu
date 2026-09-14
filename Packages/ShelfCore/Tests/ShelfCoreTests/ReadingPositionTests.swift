import XCTest
@testable import ShelfCore

final class ReadingPositionTests: XCTestCase {
    func testNegativePageClampsToZero() { XCTAssertEqual(ReadingPosition(pageIndex: -4).clamped(toPageCount: 3).pageIndex, 0) }
    func testOverflowPageClampsToLast() { XCTAssertEqual(ReadingPosition(pageIndex: 99).clamped(toPageCount: 3).pageIndex, 2) }
    func testEmptyDocumentClampIsSafe() { XCTAssertEqual(ReadingPosition(pageIndex: 99).clamped(toPageCount: 0).pageIndex, 0) }
    func testNonFiniteCoordinatesAreRemoved() {
        let p = ReadingPosition(scaleRatio: .nan, pointX: .infinity, pointY: .nan).clamped(toPageCount: 5)
        XCTAssertEqual(p.scaleRatio, 1); XCTAssertNil(p.pointX); XCTAssertNil(p.pointY)
    }
    func testExtremeScaleIsClamped() {
        XCTAssertEqual(ReadingPosition(scaleRatio: 999).clamped(toPageCount: 3).scaleRatio, 8)
        XCTAssertEqual(ReadingPosition(scaleRatio: 0).clamped(toPageCount: 3).scaleRatio, 0.5)
    }
    func testStalePositionCannotOverwriteNewerPosition() async throws {
        let repo = LibraryRepository(persistence: MemoryStore()); let book = fixtureBook()
        _ = try await repo.insertImported(book)
        let newer = ReadingPosition(pageIndex: 5, updatedAt: .distantFuture)
        try await repo.savePosition(bookID: book.id, position: newer)
        try await repo.savePosition(bookID: book.id, position: ReadingPosition(pageIndex: 1, updatedAt: .distantPast))
        let state = try await repo.book(id: book.id); XCTAssertEqual(state.position.pageIndex, 5)
    }
    func testPositionIsPersistedAndClamped() async throws {
        let repo = LibraryRepository(persistence: MemoryStore()); let book = fixtureBook(pages: 3)
        _ = try await repo.insertImported(book)
        try await repo.savePosition(bookID: book.id, position: ReadingPosition(pageIndex: 900, updatedAt: .distantFuture))
        let state = try await repo.book(id: book.id); XCTAssertEqual(state.currentPageNumber, 3)
    }
}
