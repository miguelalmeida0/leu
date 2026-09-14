import XCTest
@testable import ShelfCore

final class ImportTests: XCTestCase {
    func testImportCopiesIndexesAndCommits() async throws {
        let dir = try TestDirectory(); let root = dir.url.appendingPathComponent("library")
        let repo = LibraryRepository(persistence: JSONSnapshotStore(root: root)); let vault = FileDocumentVault(root: root)
        let indexes = FileTextIndexStore(root: root)
        let service = DocumentImportService(repository: repo, vault: vault, inspector: StubInspector(), indexes: indexes)
        let source = try dir.file("React_Notes.pdf")
        let result = try await service.importDocument(at: source)
        XCTAssertEqual(result.book.title, "React Notes"); XCTAssertTrue(vault.contains(id: result.book.id))
        XCTAssertNotNil(try indexes.read(id: result.book.id)); XCTAssertFalse(result.wasDuplicate)
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
    }
    func testDuplicateImportDoesNotCreateExtraOriginal() async throws {
        let dir = try TestDirectory(); let root = dir.url.appendingPathComponent("library")
        let repo = LibraryRepository(persistence: JSONSnapshotStore(root: root)); let vault = FileDocumentVault(root: root)
        let service = DocumentImportService(repository: repo, vault: vault, inspector: StubInspector(), indexes: FileTextIndexStore(root: root))
        let source = try dir.file("a.pdf"); _ = try await service.importDocument(at: source)
        let duplicate = try await service.importDocument(at: source); XCTAssertTrue(duplicate.wasDuplicate)
        let files = try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("Originals").path)
        XCTAssertEqual(files.count, 1)
    }
    func testRejectedPDFRemovesStagedOriginal() async throws {
        let dir = try TestDirectory(); let root = dir.url.appendingPathComponent("library")
        let repo = LibraryRepository(persistence: MemoryStore()); let vault = FileDocumentVault(root: root)
        let service = DocumentImportService(repository: repo, vault: vault, inspector: StubInspector(rejected: true), indexes: FileTextIndexStore(root: root))
        let source = try dir.file("bad.pdf")
        do { _ = try await service.importDocument(at: source); XCTFail("Must reject") } catch {}
        let state = try await repo.snapshot(); XCTAssertTrue(state.books.isEmpty)
        let files = try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("Originals").path)
        XCTAssertTrue(files.isEmpty)
    }
    func testWriteFailureRollsBackOriginal() async throws {
        let dir = try TestDirectory(); let store = MemoryStore(); store.failWrites()
        let repo = LibraryRepository(persistence: store); let vault = FileDocumentVault(root: dir.url)
        let service = DocumentImportService(repository: repo, vault: vault, inspector: StubInspector(), indexes: FileTextIndexStore(root: dir.url))
        let source = try dir.file("source.pdf")
        do { _ = try await service.importDocument(at: source); XCTFail("Must reject") } catch {}
        let state = try await repo.snapshot(); XCTAssertTrue(state.books.isEmpty)
        let originals = try FileManager.default.contentsOfDirectory(atPath: dir.url.appendingPathComponent("Originals").path)
        XCTAssertTrue(originals.isEmpty)
    }
    func testEmptyFileRejected() async throws {
        let dir = try TestDirectory(); let repo = LibraryRepository(persistence: MemoryStore())
        let service = DocumentImportService(repository: repo, vault: FileDocumentVault(root: dir.url), inspector: StubInspector(), indexes: FileTextIndexStore(root: dir.url))
        let source = try dir.file("empty.pdf", content: Data())
        do { _ = try await service.importDocument(at: source); XCTFail("Must reject") } catch {}
    }
    func testDirectoryRejected() async throws {
        let dir = try TestDirectory(); let repo = LibraryRepository(persistence: MemoryStore())
        let service = DocumentImportService(repository: repo, vault: FileDocumentVault(root: dir.url), inspector: StubInspector(), indexes: FileTextIndexStore(root: dir.url))
        do { _ = try await service.importDocument(at: dir.url); XCTFail("Must reject") } catch {}
    }
    func testOriginalFilenameCannotEscapeVault() async throws {
        let dir = try TestDirectory(); let repo = LibraryRepository(persistence: MemoryStore()); let vault = FileDocumentVault(root: dir.url)
        let service = DocumentImportService(repository: repo, vault: vault, inspector: StubInspector(), indexes: FileTextIndexStore(root: dir.url))
        let source = try dir.file("real.pdf")
        let result = try await service.importDocument(at: source, originalFilename: "../../escape.pdf")
        XCTAssertEqual(result.book.originalFilename, "escape.pdf")
        XCTAssertTrue(vault.contains(id: result.book.id))
    }
}
