import XCTest
@testable import ShelfCore

final class QueryAndSearchTests: XCTestCase {
    func testTitleSearchFoldsAccentsAndCase() {
        let state = LibrarySnapshot(books: [fixtureBook(title: "Café React")])
        XCTAssertEqual(LibraryQuery(text: "CAFE").apply(to: state).count, 1)
    }
    func testTrashNeverAppearsInActiveQuery() {
        var book = fixtureBook(); book.trashedAt = Date()
        XCTAssertTrue(LibraryQuery().apply(to: LibrarySnapshot(books: [book])).isEmpty)
    }
    func testFavoriteScope() {
        var a = fixtureBook(); a.isFavorite = true
        var b = fixtureBook(title: "B"); b.fingerprint = String(repeating: "b", count: 64)
        XCTAssertEqual(LibraryQuery(section: .favorites).apply(to: LibrarySnapshot(books: [a,b])).map(\.id), [a.id])
    }
    func testRecentsExcludeUnopenedBooks() {
        let state = LibrarySnapshot(books: [fixtureBook()]); XCTAssertTrue(LibraryQuery(section: .recents).apply(to: state).isEmpty)
    }
    func testCollectionAndTagFiltersCompose() {
        let c = BookCollection(name: "Frontend"); var a = fixtureBook(); a.collectionIDs = [c.id]; a.tags = ["react"]
        let state = LibrarySnapshot(books: [a], collections: [c])
        XCTAssertEqual(LibraryQuery(collectionID: c.id, tag: "react").apply(to: state).count, 1)
        XCTAssertEqual(LibraryQuery(collectionID: c.id, tag: "backend").apply(to: state).count, 0)
    }
    func testStudyScopeRequiresActualStudyMarker() {
        let book = fixtureBook(); let mark = StudyAnnotation(bookID: book.id, pageIndex: 1, kind: .highlight)
        var state = LibrarySnapshot(books: [book], annotations: [mark])
        XCTAssertTrue(LibraryQuery(section: .review).apply(to: state).isEmpty)
        state.annotations[0].kind = .review; XCTAssertEqual(LibraryQuery(section: .review).apply(to: state).count, 1)
    }
    func testSearchReturnsSourceCoordinates() async throws {
        let dir = try TestDirectory(); let indexes = FileTextIndexStore(root: dir.url); let book = fixtureBook()
        try indexes.write(BookTextIndex(pages: [IndexedPage(pageIndex: 2, text: "A closure remembers scope.")]), id: book.id)
        let result = try await LibraryTextSearch(indexes: indexes).search("closure", books: [book])
        XCTAssertEqual(result.count, 1); XCTAssertEqual(result[0].pageIndex, 2); XCTAssertEqual(result[0].location, 2)
        XCTAssertEqual(result[0].length, 7)
    }
    func testSearchUsesUTF16Coordinates() async throws {
        let dir = try TestDirectory(); let indexes = FileTextIndexStore(root: dir.url); let book = fixtureBook()
        try indexes.write(BookTextIndex(pages: [IndexedPage(pageIndex: 0, text: "🙂 closure")]), id: book.id)
        let result = try await LibraryTextSearch(indexes: indexes).search("closure", books: [book])
        XCTAssertEqual(result[0].location, 3)
    }
    func testSearchResultLimit() async throws {
        let dir = try TestDirectory(); let indexes = FileTextIndexStore(root: dir.url); let book = fixtureBook()
        try indexes.write(BookTextIndex(pages: (0..<10).map { IndexedPage(pageIndex: $0, text: "closure") }), id: book.id)
        let result = try await LibraryTextSearch(indexes: indexes).search("closure", books: [book], limit: 2)
        XCTAssertEqual(result.count, 2)
    }
    func testEmptyAndShortSearchAreCheapNoOps() async throws {
        let dir = try TestDirectory(); let service = LibraryTextSearch(indexes: FileTextIndexStore(root: dir.url))
        let a = try await service.search(" ", books: [fixtureBook()]); XCTAssertTrue(a.isEmpty)
        let b = try await service.search("a", books: [fixtureBook()]); XCTAssertTrue(b.isEmpty)
    }
    func testMissingIndexDoesNotFailSearch() async throws {
        let dir = try TestDirectory(); let service = LibraryTextSearch(indexes: FileTextIndexStore(root: dir.url))
        let result = try await service.search("closure", books: [fixtureBook()]); XCTAssertTrue(result.isEmpty)
    }
    func testSearchDoesNotCrossScope() async throws {
        let dir = try TestDirectory(); let indexes = FileTextIndexStore(root: dir.url); let book = fixtureBook()
        try indexes.write(BookTextIndex(pages: [IndexedPage(pageIndex: 0, text: "closure")]), id: book.id)
        let result = try await LibraryTextSearch(indexes: indexes).search("closure", books: [])
        XCTAssertTrue(result.isEmpty)
    }
    func testNoteAndQuoteSearchFindTheirOwningBook() {
        let book = fixtureBook(title: "Untitled")
        let annotation = StudyAnnotation(bookID: book.id, pageIndex: 1, kind: .note,
            quote: "A closure remembers scope", note: "Réview this carefully")
        let state = LibrarySnapshot(books: [book], annotations: [annotation])
        XCTAssertEqual(LibraryQuery(text: "REVIEW").apply(to: state).map(\.id), [book.id])
        XCTAssertEqual(LibraryQuery(text: "closure").apply(to: state).map(\.id), [book.id])
    }
    func testNoteMatchesDoNotBypassFavoritesOrTrash() {
        var book = fixtureBook(title: "Untitled")
        let note = StudyAnnotation(bookID: book.id, pageIndex: 0, kind: .note, note: "Important edge case")
        var state = LibrarySnapshot(books: [book], annotations: [note])
        XCTAssertTrue(LibraryQuery(section: .favorites, text: "edge").apply(to: state).isEmpty)
        book.trashedAt = Date(); state.books = [book]
        XCTAssertTrue(LibraryQuery(text: "edge").apply(to: state).isEmpty)
    }
}
