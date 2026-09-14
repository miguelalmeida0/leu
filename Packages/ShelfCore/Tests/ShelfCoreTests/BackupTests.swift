import XCTest
@testable import ShelfCore

final class BackupTests: XCTestCase {
    func testRoundTripPreservesOriginalsAndMetadata() throws {
        let dir = try TestDirectory(); let vault = FileDocumentVault(root: dir.url.appendingPathComponent("source"))
        let book = try diskBook(directory: dir, vault: vault)
        let mark = StudyAnnotation(bookID: book.id, pageIndex: 1, kind: .review, note: "Remember this")
        let state = LibrarySnapshot(books: [book], annotations: [mark], didSeedSamples: true)
        let archive = dir.url.appendingPathComponent("backup.shelfbackup")
        try BackupWriter().write(snapshot: state, vault: vault, to: archive)
        let staged = try BackupReader().stage(archive, in: dir.url); defer { staged.discard() }
        XCTAssertEqual(staged.snapshot, state)
        XCTAssertEqual(try Data(contentsOf: staged.vault.originalURL(for: book.id)), try Data(contentsOf: vault.originalURL(for: book.id)))
    }
    func testEmptyLibraryBackupRoundTrip() throws {
        let dir = try TestDirectory(); let archive = dir.url.appendingPathComponent("empty.shelfbackup")
        try BackupWriter().write(snapshot: LibrarySnapshot(), vault: FileDocumentVault(root: dir.url), to: archive)
        let staged = try BackupReader().stage(archive, in: dir.url); defer { staged.discard() }
        XCTAssertTrue(staged.snapshot.books.isEmpty)
    }
    func testBadMagicRejected() throws {
        let dir = try TestDirectory(); let file = try dir.file("bad", content: Data(repeating: 0, count: 100))
        XCTAssertThrowsError(try BackupReader().stage(file, in: dir.url))
    }
    func testTruncatedHeaderRejected() throws {
        let dir = try TestDirectory(); let file = try dir.file("bad", content: BackupFormat.magic.prefix(4))
        XCTAssertThrowsError(try BackupReader().stage(file, in: dir.url))
    }
    func testManifestLengthBombRejected() throws {
        let dir = try TestDirectory()
        let file = try dir.file("bad", content: BackupFormat.magic + BackupFormat.encodeLength(UInt64.max))
        XCTAssertThrowsError(try BackupReader().stage(file, in: dir.url))
    }
    func testChecksumTamperingRejectedAndStagingRemoved() throws {
        let dir = try TestDirectory(); let vault = FileDocumentVault(root: dir.url.appendingPathComponent("source"))
        let book = try diskBook(directory: dir, vault: vault); let archive = dir.url.appendingPathComponent("bad.shelfbackup")
        try BackupWriter().write(snapshot: LibrarySnapshot(books: [book]), vault: vault, to: archive)
        var data = try Data(contentsOf: archive); data[data.count-1] ^= 0xff; try data.write(to: archive)
        XCTAssertThrowsError(try BackupReader().stage(archive, in: dir.url))
        let names = try FileManager.default.contentsOfDirectory(atPath: dir.url.path)
        XCTAssertFalse(names.contains { $0.hasPrefix("restore-") })
    }
    func testTrailingBytesRejected() throws {
        let dir = try TestDirectory(); let archive = dir.url.appendingPathComponent("bad.shelfbackup")
        try BackupWriter().write(snapshot: LibrarySnapshot(), vault: FileDocumentVault(root: dir.url), to: archive)
        var data = try Data(contentsOf: archive); data.append(4); try data.write(to: archive)
        XCTAssertThrowsError(try BackupReader().stage(archive, in: dir.url))
    }
    func testTruncatedPDFRejected() throws {
        let dir = try TestDirectory(); let vault = FileDocumentVault(root: dir.url.appendingPathComponent("source"))
        let book = try diskBook(directory: dir, vault: vault); let archive = dir.url.appendingPathComponent("bad.shelfbackup")
        try BackupWriter().write(snapshot: LibrarySnapshot(books: [book]), vault: vault, to: archive)
        var data = try Data(contentsOf: archive); data.removeLast(3); try data.write(to: archive)
        XCTAssertThrowsError(try BackupReader().stage(archive, in: dir.url))
    }
    func testModifiedOriginalCannotProduceFalseVerifiedBackup() throws {
        let dir = try TestDirectory(); let vault = FileDocumentVault(root: dir.url.appendingPathComponent("source"))
        let book = try diskBook(directory: dir, vault: vault)
        try Data("tampered".utf8).write(to: vault.originalURL(for: book.id))
        let archive = dir.url.appendingPathComponent("fail.shelfbackup")
        XCTAssertThrowsError(try BackupWriter().write(snapshot: LibrarySnapshot(books: [book]), vault: vault, to: archive))
        XCTAssertFalse(FileManager.default.fileExists(atPath: archive.path))
    }
    func testExistingBackupIsNotOverwritten() throws {
        let dir = try TestDirectory(); let archive = try dir.file("keep", content: Data("original-backup".utf8))
        XCTAssertThrowsError(try BackupWriter().write(snapshot: LibrarySnapshot(), vault: FileDocumentVault(root: dir.url), to: archive))
        XCTAssertEqual(try Data(contentsOf: archive), Data("original-backup".utf8))
    }
    func testMissingOriginalFailsExport() throws {
        let dir = try TestDirectory()
        XCTAssertThrowsError(try BackupWriter().write(snapshot: LibrarySnapshot(books: [fixtureBook()]),
            vault: FileDocumentVault(root: dir.url), to: dir.url.appendingPathComponent("missing")))
    }
    func testTrashIsIncludedInBackup() throws {
        let dir = try TestDirectory(); let vault = FileDocumentVault(root: dir.url.appendingPathComponent("source"))
        var book = try diskBook(directory: dir, vault: vault); book.trashedAt = Date()
        let archive = dir.url.appendingPathComponent("trash.shelfbackup")
        try BackupWriter().write(snapshot: LibrarySnapshot(books: [book]), vault: vault, to: archive)
        let staged = try BackupReader().stage(archive, in: dir.url); defer { staged.discard() }
        XCTAssertTrue(staged.snapshot.books[0].isTrashed); XCTAssertTrue(staged.vault.contains(id: book.id))
    }
    func testRestoreCommitsOriginalAndMetadata() async throws {
        let dir = try TestDirectory(); let sourceVault = FileDocumentVault(root: dir.url.appendingPathComponent("source"))
        let book = try diskBook(directory: dir, vault: sourceVault)
        let incoming = StagedBackup(snapshot: LibrarySnapshot(books: [book]), root: sourceVault.root)
        let targetVault = FileDocumentVault(root: dir.url.appendingPathComponent("target"))
        let repo = LibraryRepository(persistence: JSONSnapshotStore(root: targetVault.root))
        let result = try await repo.mergeBackup(incoming, into: targetVault)
        XCTAssertEqual(result.addedBooks, 1); XCTAssertTrue(targetVault.contains(id: book.id))
        let state = try await repo.snapshot(); XCTAssertEqual(state.books[0].indexStatus, .pending)
    }
    func testFailedRestoreRollsBackNewOriginals() async throws {
        let dir = try TestDirectory(); let sourceVault = FileDocumentVault(root: dir.url.appendingPathComponent("source"))
        let book = try diskBook(directory: dir, vault: sourceVault)
        let incoming = StagedBackup(snapshot: LibrarySnapshot(books: [book]), root: sourceVault.root)
        let targetVault = FileDocumentVault(root: dir.url.appendingPathComponent("target"))
        let store = MemoryStore(); store.failWrites(); let repo = LibraryRepository(persistence: store)
        do { _ = try await repo.mergeBackup(incoming, into: targetVault); XCTFail("Must fail") } catch {}
        XCTAssertFalse(targetVault.contains(id: book.id))
        let state = try await repo.snapshot(); XCTAssertTrue(state.books.isEmpty)
    }
}
