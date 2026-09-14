import XCTest
import PDFKit
import ShelfCore
@testable import Shelf

final class QuestionContractV2IntegrationTests: XCTestCase {
    func testRealReactPageThreeHasMeaningfulRealizableClaimsAndExactPDFSpans() async throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "React Notes", withExtension: "pdf"))
        let pdf = try XCTUnwrap(PDFDocument(url: url))
        let book = Book(title: "React Notes", originalFilename: url.lastPathComponent,
            fingerprint: try FileDigest.sha256(url: url), pageCount: pdf.pageCount,
            byteCount: Int64(try Data(contentsOf: url).count))
        let bundle = try await PDFLearningIndexer().index(book: book, url: url)
        let page = try XCTUnwrap(bundle.analysis.pages.first { $0.pageIndex == 2 })
        let packet = try XCTUnwrap(LearningSourcePacket(analysis: bundle.analysis, page: page))
        let preflight = GroundedQuestionCompiler().compile(packet)
        XCTAssertEqual(preflight.status, .representable)
        XCTAssertGreaterThan(preflight.selectableClaims.count, 0)
        XCTAssertTrue(preflight.selectableClaims.contains { ["mechanism", "constraint", "consequence"].contains($0.cognitiveOperation) })
        XCTAssertFalse(preflight.questions.contains { $0.prompt == "What do Keys describe?" || $0.choices[$0.correctChoice] == "identity" })
        for candidate in preflight.questions {
            let question = try LearningCandidateValidator().validate(candidate, packet: packet, analysis: bundle.analysis, existing: bundle.questions).get()
            let range = try XCTUnwrap(question.source.range)
            XCTAssertEqual(pdf.page(at: 2)?.selection(for: NSRange(location: range.location, length: range.length))?.string, question.source.sourceText)
        }
        let attachment = XCTAttachment(data: try JSONEncoder().encode(preflight), uniformTypeIdentifier: "public.json")
        attachment.name = "react-page3-representability-v2"; attachment.lifetime = .keepAlways; add(attachment)
    }

    func testProviderRejectsZeroRepresentabilityBeforeAvailabilityOrInference() async throws {
        let text = "Keys describe identity. A heading is a short title for a section of a source document."
        var page = AnalyzedPage(pageIndex: 0, normalizedText: text,
            segments: [SourceSegment(pageIndex: 0, kind: .paragraph, text: text)])
        page.canonicalText = text
        var analysis = DocumentAnalysis(documentID: UUID(), fingerprint: "preflight-test", algorithmVersion: 2, pages: [page])
        analysis.extractionVersion = SourceExtractionVersion.current
        let packet = try XCTUnwrap(LearningSourcePacket(analysis: analysis, page: page))
        do {
            _ = try await AppleLearningIntelligenceProvider().generateQuestion(from: packet)
            XCTFail("A zero-representability packet cannot invoke or return a model selection")
        } catch GroundedQuestionGenerationError.noRepresentableQuestion {} catch {
            XCTFail("Preflight must win even when the model is unavailable: \(error)")
        }
    }
}
