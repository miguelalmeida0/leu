import XCTest
@testable import ShelfCore

final class DocumentAnalysisTests: XCTestCase {
    private let analyzer = DocumentAnalyzer()
    private let documentID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

    func testRepeatedHeaderAndFooterAreRemoved() {
        let pages = (0..<4).map { index in
            SourcePageInput(pageIndex: index, text: "INTERVIEW GUIDE\n\nEVENT LOOP\nThe event loop is a scheduling mechanism.\n\nPage \(index + 1)")
        }
        let result = analyzer.analyze(documentID: documentID, fingerprint: "abc", pages: pages)
        XCTAssertFalse(result.pages[0].normalizedText.localizedCaseInsensitiveContains("INTERVIEW GUIDE"))
        XCTAssertFalse(result.pages[0].normalizedText.localizedCaseInsensitiveContains("Page 1"))
        XCTAssertTrue(result.repeatedHeaders.contains("interview guide"))
    }

    func testHyphenatedLineWrapRepairsWhenNextLineStartsLowercase() {
        let normalized = analyzer.normalize("micro-\ntask queue")
        XCTAssertEqual(normalized, "microtask queue")
    }

    func testHeadingAndDefinitionAreSeparated() {
        let page = SourcePageInput(pageIndex: 0, text: "JAVASCRIPT RUNTIME\n\nA closure is a function plus its lexical environment.")
        let result = analyzer.analyze(documentID: documentID, fingerprint: "x", pages: [page])
        XCTAssertEqual(result.pages[0].segments.first?.kind, .heading)
        XCTAssertTrue(result.pages[0].segments.contains(where: { $0.kind == .definition }))
    }

    func testEmptyPageIsSafe() {
        let result = analyzer.analyze(documentID: documentID, fingerprint: "x", pages: [SourcePageInput(pageIndex: 0, text: "")])
        XCTAssertEqual(result.pages.count, 1)
        XCTAssertTrue(result.pages[0].segments.isEmpty)
    }


    func testLargeDocumentAnalysisPreservesPageIdentity() {
        let pages = (0..<320).map { index in
            SourcePageInput(pageIndex: index, text: "SYSTEM DESIGN NOTES\n\nCache entry \(index) is a stored representation with a validator.\n\nPage \(index + 1)")
        }
        let result = analyzer.analyze(documentID: documentID, fingerprint: "large", pages: pages)
        XCTAssertEqual(result.pages.count, 320)
        XCTAssertEqual(result.pages.first?.pageIndex, 0)
        XCTAssertEqual(result.pages.last?.pageIndex, 319)
        XCTAssertTrue(result.pages.allSatisfy { !$0.normalizedText.isEmpty })
    }

    func testListLineIsDetected() {
        let page = SourcePageInput(pageIndex: 0, text: "- GET requests retrieve a resource\n- POST requests submit data")
        let result = analyzer.analyze(documentID: documentID, fingerprint: "x", pages: [page])
        XCTAssertTrue(result.pages[0].segments.allSatisfy { $0.kind == .listItem })
    }
}
