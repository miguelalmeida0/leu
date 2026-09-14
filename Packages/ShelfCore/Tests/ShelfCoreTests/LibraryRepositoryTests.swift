import XCTest
@testable import ShelfCore

final class LibraryRepositoryTests: XCTestCase {
    func testNewLibraryIsEmpty() async throws {
        let repository = LibraryRepository(persistence: MemoryStore())
        let snapshot = try await repository.open(); XCTAssertEqual(snapshot.books.count, 0)
    }
    func testInsertAndLookup() async throws {
        let repo = LibraryRepository(persistence: MemoryStore()); let book = fixtureBook()
        _ = try await repo.insertImported(book)
        let found = try await repo.book(id: book.id); XCTAssertEqual(found, book)
    }
    func testDuplicateFingerprintKeepsIdentity() async throws {
        let repo = LibraryRepository(persistence: MemoryStore()); let book = fixtureBook()
        _ = try await repo.insertImported(book)
        let duplicate = try await repo.insertImported(fixtureBook(title: "Different filename"))
        XCTAssertEqual(duplicate.id, book.id)
        let state = try await repo.snapshot(); XCTAssertEqual(state.books.count, 1)
    }
    func testDuplicateRestoresTrashWithoutLosingNotes() async throws {
        let repo = LibraryRepository(persistence: MemoryStore()); let book = fixtureBook()
        _ = try await repo.insertImported(book)
        try await repo.addAnnotations([StudyAnnotation(bookID: book.id, pageIndex: 2, kind: .review, note: "Keep")])
        try await repo.trashBook(id: book.id)
        let result = try await repo.insertImported(fixtureBook()); XCTAssertNil(result.trashedAt)
        let state = try await repo.snapshot(); XCTAssertEqual(state.annotations.count, 1)
    }
    func testRenameTrimsWhitespace() async throws {
        let repo = LibraryRepository(persistence: MemoryStore()); let book = fixtureBook()
        _ = try await repo.insertImported(book)
        try await repo.updateBook(id: book.id) { $0.title = "  New title  " }
        let renamed = try await repo.book(id: book.id); XCTAssertEqual(renamed.title, "New title")
        XCTAssertEqual(renamed.originalFilename, book.originalFilename)
    }
    func testEmptyRenameDoesNotCommit() async throws {
        let repo = LibraryRepository(persistence: MemoryStore()); let book = fixtureBook()
        _ = try await repo.insertImported(book)
        do { try await repo.updateBook(id: book.id) { $0.title = " " }; XCTFail("Must reject") }
        catch { XCTAssertEqual(error as? ShelfError, .emptyTitle) }
        let found = try await repo.book(id: book.id); XCTAssertEqual(found.title, book.title)
    }
    func testFailedWriteDoesNotLeakState() async throws {
        let store = MemoryStore(); let repo = LibraryRepository(persistence: store); let book = fixtureBook()
        _ = try await repo.insertImported(book); store.failWrites()
        do { try await repo.updateBook(id: book.id) { $0.isFavorite = true }; XCTFail("Must fail") } catch {}
        let found = try await repo.book(id: book.id); XCTAssertFalse(found.isFavorite)
    }
    func testConcurrentTogglesAreSerialized() async throws {
        let repo = LibraryRepository(persistence: MemoryStore()); let book = fixtureBook()
        _ = try await repo.insertImported(book)
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<100 { group.addTask { try await repo.updateBook(id: book.id) { $0.isFavorite.toggle() } } }
            try await group.waitForAll()
        }
        let found = try await repo.book(id: book.id); XCTAssertFalse(found.isFavorite)
    }
    func testMissingBookThrows() async throws {
        let repo = LibraryRepository(persistence: MemoryStore())
        do { _ = try await repo.book(id: UUID()); XCTFail("Must fail") }
        catch { XCTAssertEqual(error as? ShelfError, .notFound) }
    }
    func testSamplesFlagPersists() async throws {
        let store = MemoryStore(); let repo = LibraryRepository(persistence: store)
        try await repo.markSamplesSeeded()
        let reloaded = try await LibraryRepository(persistence: store).snapshot()
        XCTAssertTrue(reloaded.didSeedSamples)
    }
}
