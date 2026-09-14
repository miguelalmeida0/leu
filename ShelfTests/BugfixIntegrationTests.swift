import XCTest
import PDFKit
import ShelfCore
@testable import Shelf

final class BugfixIntegrationTests: XCTestCase {
    func testDegradedPageSurvivesIndexerWithoutEnteringIntelligence() async throws {
        let text = "A cache is a reusable store for recent responses. A queue is an ordered buffer for pending requests. A stack is a last-in-first-out buffer for saved values."
        let extractor = DegradedFixtureExtractor(text: text)
        let book = Book(title: "Mixed integrity", originalFilename: "mixed.pdf", fingerprint: "same-bytes", pageCount: 2, byteCount: 1)
        let result = try await PDFLearningIndexer(extractor: extractor).index(book: book, url: URL(fileURLWithPath: "/unused-fixture.pdf"))
        XCTAssertEqual(result.degradedPages, [0])
        XCTAssertEqual(result.analysis.pages[0].canonicalText, text)
        XCTAssertEqual(result.analysis.pages[0].normalizedText, text)
        XCTAssertFalse(result.analysis.pages[0].isIntelligenceEligible)
        XCTAssertFalse(result.semanticIndex.propositions.contains { $0.evidence.pageIndex == 0 })
        XCTAssertTrue(result.semanticIndex.propositions.contains { $0.evidence.pageIndex == 1 })
        XCTAssertFalse(result.questions.contains { $0.source.pageIndex == 0 })
        XCTAssertNil(LearningSourcePacket(analysis: result.analysis, page: result.analysis.pages[0]))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = LearningRepository(persistence: FileLearningSnapshotStore(root: root))
        try await repository.upsertAnalysis(result.analysis, topics: result.topics, questions: result.questions, semanticIndex: result.semanticIndex)
        let snapshot = try await repository.snapshot()
        XCTAssertFalse(snapshot.learningObjects.contains { $0.source.pageIndex == 0 })
        XCTAssertTrue(snapshot.learningObjects.contains { $0.source.pageIndex == 1 })
    }

    func testTrackedLabelsUseMeasuredWordGapsAndPreserveWords() {
        for text in ["IN ONE BREATH", "MAKE IT STICK", "REAL EXAMPLE"] {
            var glyphs: [PDFGlyph] = []; var x: CGFloat = 0; var index = 0
            for character in text {
                if character == " " { x += 3; continue }
                glyphs.append(PDFGlyph(text: String(character), bounds: CGRect(x: x, y: 10, width: 5, height: 10), sourceIndex: index, fontSize: 10, monospaced: false))
                glyphs.append(PDFGlyph(text: " ", bounds: CGRect(x: x+5, y: 10, width: 2, height: 10), sourceIndex: index+1, fontSize: 10, monospaced: false))
                index += 2; x += 7
            }
            XCTAssertEqual(PDFLineGrouper().lines(from: glyphs, pageWidth: 600).first?.text, text)
        }
    }

    @MainActor func testFitWidthPagesAndWiderZoomKeepsPan() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "React Notes", withExtension: "pdf"))
        let pdf = try XCTUnwrap(PDFDocument(url: url))
        let view = PDFView(frame: CGRect(x: 0, y: 0, width: 360, height: 600))
        view.document = pdf
        let zoom = PDFZoomState(view: view)
        // Width comparison is independent of persisted fit-page magnification.
        let page = try XCTUnwrap(view.currentPage)
        let width = page.bounds(for: view.displayBox).width
        view.scaleFactor = view.bounds.width / width
        XCTAssertTrue(zoom.horizontallyContained)
        view.scaleFactor = view.bounds.width / width * 1.5
        XCTAssertFalse(zoom.horizontallyContained)
    }
}

private struct DegradedFixtureExtractor: PDFTextExtracting {
    let text: String
    func extract(documentID: UUID, fingerprint: String, url: URL, progress: @Sendable (Double) async -> Void) async throws -> PDFTextExtraction {
        await progress(1)
        return PDFTextExtraction(pages: [SourcePageInput(pageIndex: 0, text: text), SourcePageInput(pageIndex: 1, text: text)],
            outlineTitles: [], nonEmptyCharacters: text.count*2, canonicalPages: [0: text, 1: text], degradedPages: [0])
    }
    func clearCheckpoint(documentID: UUID) async {}
}
