import Foundation
import XCTest
@testable import ShelfCore

final class TestDirectory {
    let url: URL
    init() throws {
        url = FileManager.default.temporaryDirectory.appendingPathComponent("ShelfTests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
    deinit { try? FileManager.default.removeItem(at: url) }
    func file(_ name: String, content: Data = Data("%PDF-test-fixture".utf8)) throws -> URL {
        let path = url.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: path); return path
    }
}

final class MemoryStore: SnapshotPersistence, @unchecked Sendable {
    private let lock = NSLock()
    private var value: LibrarySnapshot
    private var fail = false
    init(_ value: LibrarySnapshot = LibrarySnapshot()) { self.value = value }
    func load() throws -> SnapshotLoad { lock.lock(); defer { lock.unlock() }; return SnapshotLoad(snapshot: value) }
    func save(_ snapshot: LibrarySnapshot) throws {
        lock.lock(); defer { lock.unlock() }
        if fail { throw CocoaError(.fileWriteOutOfSpace) }
        value = snapshot
    }
    func failWrites(_ fail: Bool = true) { lock.lock(); defer { lock.unlock() }; self.fail = fail }
}

actor StubInspector: DocumentInspecting {
    let rejected: Bool
    init(rejected: Bool = false) { self.rejected = rejected }
    func inspect(_ url: URL) async throws -> PDFInspection {
        if rejected { throw ShelfError.invalidPDF("Fixture rejection.") }
        return PDFInspection(pageCount: 3,
            index: BookTextIndex(pages: [IndexedPage(pageIndex: 0, text: "Closures remember lexical scope.")]), status: .ready)
    }
}

func fixtureBook(title: String = "React Notes", id: UUID = UUID(), pages: Int = 12) -> Book {
    Book(id: id, title: title, originalFilename: title + ".pdf", fingerprint: String(repeating: "a", count: 64),
         pageCount: pages, byteCount: 40, importedAt: Date(timeIntervalSince1970: 100))
}

func diskBook(directory: TestDirectory, vault: FileDocumentVault, title: String = "Original", content: String = "%PDF-fixture-alpha") throws -> Book {
    let source = try directory.file(UUID().uuidString + ".pdf", content: Data(content.utf8))
    let id = UUID()
    let saved = try vault.stageCopy(from: source, id: id)
    return Book(id: id, title: title, originalFilename: title + ".pdf", fingerprint: try FileDigest.sha256(url: saved),
                pageCount: 3, byteCount: Int64(content.utf8.count))
}
