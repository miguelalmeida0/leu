import XCTest
@testable import ShelfCore

final class PersistenceTests: XCTestCase {
    func testRoundTrip() throws {
        let dir = try TestDirectory(); let store = JSONSnapshotStore(root: dir.url)
        let state = LibrarySnapshot(books: [fixtureBook()]); try store.save(state)
        XCTAssertEqual(try store.load().snapshot, state)
    }
    func testPreviousGenerationRecoversCorruption() throws {
        let dir = try TestDirectory(); let store = JSONSnapshotStore(root: dir.url)
        let a = LibrarySnapshot(books: [fixtureBook()]); try store.save(a)
        var b = a; b.books[0].title = "Second generation"; try store.save(b)
        try Data("broken".utf8).write(to: store.currentURL)
        let loaded = try store.load(); XCTAssertTrue(loaded.recoveredFromPrevious); XCTAssertEqual(loaded.snapshot, a)
        let names = try FileManager.default.contentsOfDirectory(atPath: dir.url.path)
        XCTAssertTrue(names.contains { $0.hasPrefix("library.corrupt-") })
    }
    func testCorruptFirstGenerationDoesNotReset() throws {
        let dir = try TestDirectory(); let store = JSONSnapshotStore(root: dir.url)
        try Data("broken".utf8).write(to: store.currentURL)
        XCTAssertThrowsError(try store.load())
        XCTAssertEqual(try Data(contentsOf: store.currentURL), Data("broken".utf8))
    }
    func testFutureVersionDoesNotRollBackToOlderSchema() throws {
        let dir = try TestDirectory(); let store = JSONSnapshotStore(root: dir.url)
        let state = LibrarySnapshot(books: [fixtureBook()]); try store.save(state); try store.save(state)
        var future = state; future.schemaVersion = 99
        try JSONEncoder().encode(future).write(to: store.currentURL)
        XCTAssertThrowsError(try store.load()) { XCTAssertEqual($0 as? ShelfError, .unsupportedVersion(99)) }
    }
    func testMissingCurrentUsesPrevious() throws {
        let dir = try TestDirectory(); let store = JSONSnapshotStore(root: dir.url)
        let state = LibrarySnapshot(books: [fixtureBook()]); try store.save(state); try store.save(state)
        try FileManager.default.removeItem(at: store.currentURL)
        XCTAssertTrue(try store.load().recoveredFromPrevious)
    }
    func testMissingMetadataWithOriginalsDoesNotReset() throws {
        let dir = try TestDirectory(); _ = try dir.file("Originals/orphan.pdf")
        XCTAssertThrowsError(try JSONSnapshotStore(root: dir.url).load())
    }
    func testInvalidStateNeverOverwritesValidState() throws {
        let dir = try TestDirectory(); let store = JSONSnapshotStore(root: dir.url)
        let state = LibrarySnapshot(books: [fixtureBook()]); try store.save(state)
        var invalid = state; invalid.books[0].pageCount = 0
        XCTAssertThrowsError(try store.save(invalid)); XCTAssertEqual(try store.load().snapshot, state)
    }
    func testVaultNeverUsesUntrustedFilename() throws {
        let dir = try TestDirectory(); let vault = FileDocumentVault(root: dir.url)
        let id = UUID(); let source = try dir.file("untrusted-name.pdf")
        let destination = try vault.stageCopy(from: source, id: id)
        XCTAssertEqual(destination.lastPathComponent, id.uuidString + ".pdf")
        XCTAssertEqual(destination.deletingLastPathComponent().lastPathComponent, "Originals")
    }
    func testVaultRefusesOverwrite() throws {
        let dir = try TestDirectory(); let vault = FileDocumentVault(root: dir.url)
        let id = UUID(); let source = try dir.file("source.pdf")
        _ = try vault.stageCopy(from: source, id: id)
        XCTAssertThrowsError(try vault.stageCopy(from: source, id: id))
    }
    func testPurgeAdvancesBothMetadataCheckpoints() async throws {
        let dir = try TestDirectory(); let store = JSONSnapshotStore(root: dir.url.appendingPathComponent("library"))
        let repo = LibraryRepository(persistence: store); _ = try await repo.open()
        let vault = FileDocumentVault(root: store.root)
        let book = try diskBook(directory: dir, vault: vault)
        _ = try await repo.insertImported(book); try await repo.trashBook(id: book.id)
        try await repo.permanentlyDelete(id: book.id, vault: vault, indexes: FileTextIndexStore(root: store.root))
        XCTAssertFalse(vault.contains(id: book.id))
        let previous = try JSONDecoder().decode(LibrarySnapshot.self, from: Data(contentsOf: store.previousURL))
        XCTAssertTrue(previous.books.isEmpty)
    }
}
