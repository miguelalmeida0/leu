import ShelfCore
import XCTest
@testable import Shelf

/// The pure parts of Notes and Trails in the Felt redesign: what the notebook keeps and how
/// it splits, and where the trail walk places its stops.
final class FeltScreensTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    private func book(_ title: String) -> Book {
        Book(title: title, originalFilename: "\(title).pdf", fingerprint: title, pageCount: 40, byteCount: 1_000)
    }

    func testNotebookKeepsWordsNewestFirstAndSplitsByWeek() {
        let react = book("React Notes"), design = book("System Design")
        let marks = [
            StudyAnnotation(bookID: react.id, pageIndex: 1, kind: .note, note: "Handlers see a snapshot.", createdAt: now.addingTimeInterval(-86_400)),
            StudyAnnotation(bookID: design.id, pageIndex: 2, kind: .highlight, quote: "Keep storage separate.", createdAt: now.addingTimeInterval(-20 * 86_400)),
            StudyAnnotation(bookID: design.id, pageIndex: 3, kind: .highlight, createdAt: now),
            StudyAnnotation(bookID: UUID(), pageIndex: 0, kind: .note, note: "A removed book.", createdAt: now)
        ]
        let entries = NotebookModel.entries(annotations: marks, books: [react, design])
        XCTAssertEqual(entries.map(\.text), ["Handlers see a snapshot.", "“Keep storage separate.”"])
        XCTAssertEqual(entries.first?.place, "React Notes, page 2")
        XCTAssertTrue(entries[1].isQuote)
        let pages = NotebookModel.split(entries, now: now)
        XCTAssertEqual(pages.thisWeek.count, 1)
        XCTAssertEqual(pages.earlier.count, 1)
        XCTAssertEqual(NotebookModel.entries(annotations: marks, books: [react, design], bookID: design.id).count, 1)
        XCTAssertEqual(NotebookModel.books(in: entries, from: [design, react]).map(\.title), ["React Notes", "System Design"])
    }

    func testNotebookHeadlineCountsInWords() {
        XCTAssertEqual(NotebookModel.headline(count: 0), "Nothing kept yet.")
        XCTAssertEqual(NotebookModel.headline(count: 1), "One thing worth keeping.")
        XCTAssertEqual(NotebookModel.headline(count: 5), "Five things worth keeping.")
        XCTAssertEqual(NotebookModel.headline(count: 14), "14 things worth keeping.")
    }

    func testTrailWalkSnakesWithoutOverlapAndFitsItsHeight() {
        for width in [340.0, 700.0, 1_100.0] {
            let geometry = TrailWalkGeometry(count: 7, width: width)
            let size = geometry.cardSize
            var frames: [CGRect] = []
            for index in 0..<7 {
                let centre = geometry.centre(of: index)
                let frame = CGRect(x: centre.x - size.width / 2, y: centre.y - size.height / 2, width: size.width, height: size.height)
                XCTAssertGreaterThanOrEqual(frame.minX, -0.5, "width \(width)")
                XCTAssertLessThanOrEqual(frame.maxX, width + 0.5, "width \(width)")
                XCTAssertLessThanOrEqual(frame.maxY, geometry.height, "width \(width)")
                XCTAssertFalse(frames.contains { $0.insetBy(dx: 2, dy: 2).intersects(frame) }, "stop \(index) overlaps at width \(width)")
                frames.append(frame)
            }
        }
    }
}
