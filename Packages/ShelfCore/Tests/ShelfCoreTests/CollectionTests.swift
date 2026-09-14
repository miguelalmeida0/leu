import XCTest
@testable import ShelfCore

final class CollectionTests: XCTestCase {
    func testCreatesTrimmedCollection() async throws {
        let repo = LibraryRepository(persistence: MemoryStore())
        let c = try await repo.createCollection(name: "  Study  "); XCTAssertEqual(c.name, "Study")
    }
    func testEmptyCollectionRejected() async throws {
        let repo = LibraryRepository(persistence: MemoryStore())
        do { _ = try await repo.createCollection(name: " "); XCTFail("Must fail") }
        catch { XCTAssertEqual(error as? ShelfError, .emptyTitle) }
    }
    func testDuplicateNamesIgnoreCaseAndAccents() async throws {
        let repo = LibraryRepository(persistence: MemoryStore()); _ = try await repo.createCollection(name: "Café")
        do { _ = try await repo.createCollection(name: "CAFE"); XCTFail("Must fail") }
        catch { XCTAssertEqual(error as? ShelfError, .duplicateCollection) }
    }
    func testDeletingCollectionRetainsDocument() async throws {
        let repo = LibraryRepository(persistence: MemoryStore()); let c = try await repo.createCollection(name: "React")
        var book = fixtureBook(); book.collectionIDs = [c.id]; _ = try await repo.insertImported(book)
        try await repo.deleteCollection(id: c.id)
        let snapshot = try await repo.snapshot()
        XCTAssertEqual(snapshot.books.count, 1); XCTAssertEqual(snapshot.books[0].collectionIDs, [])
    }
    func testReorderUsesEveryCollectionExactlyOnce() async throws {
        let repo = LibraryRepository(persistence: MemoryStore())
        let a = try await repo.createCollection(name: "A"), b = try await repo.createCollection(name: "B")
        try await repo.reorderCollections(ids: [b.id, a.id])
        let state = try await repo.snapshot()
        XCTAssertEqual(state.collections.first { $0.id == b.id }?.order, 0)
    }
    func testInvalidReorderRejected() async throws {
        let repo = LibraryRepository(persistence: MemoryStore()); let c = try await repo.createCollection(name: "A")
        do { try await repo.reorderCollections(ids: [c.id, c.id]); XCTFail("Must reject duplicate") } catch {}
    }
    func testRenameCollisionRejected() async throws {
        let repo = LibraryRepository(persistence: MemoryStore())
        _ = try await repo.createCollection(name: "A"); let b = try await repo.createCollection(name: "B")
        do { try await repo.renameCollection(id: b.id, name: "a"); XCTFail("Must reject") }
        catch { XCTAssertEqual(error as? ShelfError, .duplicateCollection) }
    }
}
