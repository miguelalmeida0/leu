import XCTest
@testable import ShelfCore

final class BackupMergerTests: XCTestCase {
    func testIdenticalPDFDeduplicates() throws {
        let book = fixtureBook()
        let plan = try BackupMerger.plan(current: LibrarySnapshot(books: [book]), incoming: LibrarySnapshot(books: [fixtureBook()]))
        XCTAssertEqual(plan.result.matchedBooks, 1); XCTAssertTrue(plan.copies.isEmpty)
    }
    func testExistingReadingPositionAndTitleWin() throws {
        var book = fixtureBook(); book.title = "My current title"; book.position.pageIndex = 4
        let plan = try BackupMerger.plan(current: LibrarySnapshot(books: [book]), incoming: LibrarySnapshot(books: [fixtureBook(title: "Old title")]))
        XCTAssertEqual(plan.snapshot.books[0].title, "My current title")
        XCTAssertEqual(plan.snapshot.books[0].position.pageIndex, 4)
    }
    func testCollectionNameMatchingRemapsMembership() throws {
        let currentCollection = BookCollection(name: "Study"), backupCollection = BookCollection(name: "study")
        var book = fixtureBook(); book.collectionIDs = [backupCollection.id]
        let plan = try BackupMerger.plan(current: LibrarySnapshot(collections: [currentCollection]),
                                        incoming: LibrarySnapshot(books: [book], collections: [backupCollection]))
        XCTAssertEqual(plan.snapshot.collections.count, 1)
        XCTAssertEqual(plan.snapshot.books[0].collectionIDs, [currentCollection.id])
    }
    func testConflictingBookIDGetsNewIdentity() throws {
        let current = fixtureBook(); var incoming = current
        incoming.fingerprint = String(repeating: "b", count: 64)
        let plan = try BackupMerger.plan(current: LibrarySnapshot(books: [current]), incoming: LibrarySnapshot(books: [incoming]))
        XCTAssertEqual(plan.snapshot.books.count, 2)
        XCTAssertNotEqual(plan.snapshot.books[1].id, current.id)
        XCTAssertEqual(plan.copies[0].source, current.id)
    }
    func testRestoringTwiceDoesNotDuplicateNotes() throws {
        let book = fixtureBook(); let note = StudyAnnotation(bookID: book.id, pageIndex: 2, kind: .note, note: "Keep")
        let state = LibrarySnapshot(books: [book], annotations: [note])
        let first = try BackupMerger.plan(current: LibrarySnapshot(), incoming: state)
        let second = try BackupMerger.plan(current: first.snapshot, incoming: state)
        XCTAssertEqual(second.snapshot.annotations.count, 1)
        XCTAssertEqual(second.result.addedAnnotations, 0); XCTAssertTrue(second.copies.isEmpty)
    }
    func testExistingNoteEditsWinOverBackup() throws {
        let book = fixtureBook(); let note = StudyAnnotation(bookID: book.id, pageIndex: 0, kind: .note, note: "Current")
        var older = note; older.note = "Old"
        let plan = try BackupMerger.plan(current: LibrarySnapshot(books: [book], annotations: [note]),
                                        incoming: LibrarySnapshot(books: [book], annotations: [older]))
        XCTAssertEqual(plan.snapshot.annotations[0].note, "Current")
    }
    func testAnnotationIDCollisionAcrossDifferentBooksPreservesBoth() throws {
        let a = fixtureBook(); var b = fixtureBook(title: "Other"); b.fingerprint = String(repeating: "b", count: 64)
        let note = StudyAnnotation(bookID: a.id, pageIndex: 0, kind: .note)
        var other = note; other.bookID = b.id
        let plan = try BackupMerger.plan(current: LibrarySnapshot(books: [a], annotations: [note]),
                                        incoming: LibrarySnapshot(books: [b], annotations: [other]))
        XCTAssertEqual(plan.snapshot.annotations.count, 2)
        XCTAssertEqual(Set(plan.snapshot.annotations.map(\.id)).count, 2)
    }
    func testBookmarkDeduplicationUsesPageAndBook() throws {
        let book = fixtureBook()
        let a = PageBookmark(bookID: book.id, pageIndex: 1, title: "Current")
        let b = PageBookmark(bookID: book.id, pageIndex: 1, title: "Backup")
        let plan = try BackupMerger.plan(current: LibrarySnapshot(books: [book], bookmarks: [a]),
                                        incoming: LibrarySnapshot(books: [book], bookmarks: [b]))
        XCTAssertEqual(plan.snapshot.bookmarks.count, 1); XCTAssertEqual(plan.snapshot.bookmarks[0].title, "Current")
    }
}
