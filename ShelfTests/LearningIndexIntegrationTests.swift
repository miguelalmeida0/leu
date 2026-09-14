import XCTest
import PDFKit
import UIKit
import ShelfCore
@testable import Shelf

/// Apple-only integration coverage for the local PDF -> Learning OS pipeline.
final class LearningIndexIntegrationTests: XCTestCase {
    private func sample(_ name: String) throws -> URL {
        try XCTUnwrap(Bundle.main.url(forResource: name, withExtension: "pdf"))
    }

    func testPDFLearningIndexerProducesSourceBoundLocalMaterialAndClearsCheckpointAfterCommit() async throws {
        let root = temporaryDirectory()
        let checkpoints = FilePDFTextExtractionCheckpointStore(root: root)
        let indexer = PDFLearningIndexer(extractor: PDFKitTextExtractor(checkpoints: checkpoints))
        let url = try sample("React Notes")
        let hash = try FileDigest.sha256(url: url)
        let book = Book(id: UUID(), title: "React Notes", originalFilename: "React Notes.pdf",
                        fingerprint: hash, pageCount: 4, byteCount: Int64((try? Data(contentsOf: url).count) ?? 0))

        let bundle = try await indexer.index(book: book, url: url)
        XCTAssertEqual(bundle.analysis.documentID, book.id)
        XCTAssertEqual(bundle.analysis.fingerprint, hash)
        XCTAssertEqual(bundle.analysis.pages.count, 4)
        XCTAssertTrue(bundle.hasUsableText)
        XCTAssertFalse(bundle.topics.isEmpty)
        let progress = await indexer.progressValue()
        XCTAssertEqual(progress, 1, accuracy: 0.001)
        let pendingCheckpoint = await checkpoints.load(documentID: book.id)
        XCTAssertNotNil(pendingCheckpoint, "Extraction should remain resumable until repository commit succeeds.")

        await indexer.commitCompleted(documentID: book.id)
        let clearedCheckpoint = await checkpoints.load(documentID: book.id)
        XCTAssertNil(clearedCheckpoint)
        for question in bundle.questions {
            XCTAssertEqual(question.source.documentID, book.id)
            XCTAssertTrue(bundle.analysis.pages.indices.contains(question.source.pageIndex))
        }
    }

    func testCheckpointStoreRoundTripsPartialExtraction() async {
        let root = temporaryDirectory()
        let store = FilePDFTextExtractionCheckpointStore(root: root)
        let id = UUID()
        let checkpoint = PDFTextExtractionCheckpoint(fingerprint: "abc", extractionVersion: 1,
            pageCount: 4, pages: [SourcePageInput(pageIndex: 0, text: "first"), SourcePageInput(pageIndex: 1, text: "second")])
        await store.save(checkpoint, documentID: id)
        let restored = await store.load(documentID: id)
        XCTAssertEqual(restored?.fingerprint, "abc")
        XCTAssertEqual(restored?.pages.map(\.pageIndex), [0, 1])
        await store.remove(documentID: id)
        let removed = await store.load(documentID: id)
        XCTAssertNil(removed)
    }

    func testImageLikeLowTextPDFRemainsIndexableWithoutFakeStudyQuestions() async throws {
        let root = temporaryDirectory()
        let url = root.appendingPathComponent("low-text.pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
        let data = renderer.pdfData { context in
            context.beginPage()
            ("Hi" as NSString).draw(at: CGPoint(x: 20, y: 20), withAttributes: [.font: UIFont.systemFont(ofSize: 14)])
        }
        try data.write(to: url)
        let hash = try FileDigest.sha256(url: url)
        let book = Book(id: UUID(), title: "Scan", originalFilename: "scan.pdf", fingerprint: hash,
                        pageCount: 1, byteCount: Int64(data.count))
        let bundle = try await PDFLearningIndexer().index(book: book, url: url)
        XCTAssertFalse(bundle.hasUsableText)
        XCTAssertTrue(bundle.questions.isEmpty)
        XCTAssertEqual(bundle.analysis.pages.count, 1)
    }

    private func temporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
}
