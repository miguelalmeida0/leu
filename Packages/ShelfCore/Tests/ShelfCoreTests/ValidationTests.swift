import XCTest
@testable import ShelfCore

final class ValidationTests: XCTestCase {
    func testUnsupportedSchemaRejected() {
        var state = LibrarySnapshot(); state.schemaVersion = 10
        XCTAssertThrowsError(try state.validated())
    }
    func testDuplicateDocumentIDsRejected() {
        let book = fixtureBook(); XCTAssertThrowsError(try LibrarySnapshot(books: [book, book]).validated())
    }
    func testDanglingCollectionReferenceRejected() {
        var book = fixtureBook(); book.collectionIDs = [UUID()]
        XCTAssertThrowsError(try LibrarySnapshot(books: [book]).validated())
    }
    func testInvalidFingerprintRejected() {
        var book = fixtureBook(); book.fingerprint = "not-a-checksum"
        XCTAssertThrowsError(try LibrarySnapshot(books: [book]).validated())
    }
    func testOversizeDocumentMetadataRejected() {
        var book = fixtureBook(); book.byteCount = DocumentLimits.maxBytes + 1
        XCTAssertThrowsError(try LibrarySnapshot(books: [book]).validated())
    }
    func testNegativeAnnotationSizeRejected() {
        let book = fixtureBook()
        let mark = StudyAnnotation(bookID: book.id, pageIndex: 0, kind: .note,
                                   rects: [PDFRect(x: 0, y: 0, width: -1, height: 4)])
        XCTAssertThrowsError(try LibrarySnapshot(books: [book], annotations: [mark]).validated())
    }
    func testOrphanBookmarkRejected() {
        let mark = PageBookmark(bookID: UUID(), pageIndex: 0, title: "No document")
        XCTAssertThrowsError(try LibrarySnapshot(bookmarks: [mark]).validated())
    }
    func testOriginalNameDoesNotAffectIdentity() {
        var book = fixtureBook(); book.originalFilename = "../../does-not-control-path.pdf"
        XCTAssertNoThrow(try LibrarySnapshot(books: [book]).validated())
    }
}
