import XCTest
import PDFKit
import ShelfCore
@testable import Shelf

/// Real PDF, actual Apple model, production validation and durable repository.
/// A skipped unavailable target or a rejected output is never inference success.
final class LearningRealModelP0Tests: XCTestCase {
    func testRealReactInferenceValidationPersistenceAndPlanning() async throws {
        let provider = AppleLearningIntelligenceProvider()
        let state = await provider.availability()
        guard state == .available else {
            throw XCTSkip("MODEL IMPLEMENTED; REAL INFERENCE NOT VERIFIED ON THIS TARGET: \(state)")
        }
        let url = try XCTUnwrap(Bundle.main.url(forResource: "React Notes", withExtension: "pdf"))
        let bytes = try Data(contentsOf: url)
        let pdf = try XCTUnwrap(PDFDocument(url: url))
        let book = Book(id: UUID(), title: "React Notes", originalFilename: url.lastPathComponent,
            fingerprint: try FileDigest.sha256(url: url), pageCount: 4, byteCount: Int64(bytes.count))
        let bundle = try await PDFLearningIndexer().index(book: book, url: url)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = FileLearningSnapshotStore(root: root)
        let repository = LearningRepository(persistence: store)
        try await repository.upsertAnalysis(bundle.analysis, topics: bundle.topics,
            questions: bundle.questions, semanticIndex: bundle.semanticIndex)
        var accepted = 0
        for page in bundle.analysis.pages.filter({ $0.pageIndex == 2 }) {
            let packet = try XCTUnwrap(LearningSourcePacket(analysis: bundle.analysis, page: page))
            let candidate = try await provider.generateQuestion(from: packet)
            let data = try JSONEncoder().encode(candidate)
            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
            attachment.name = "real-model-react-page-\(page.pageIndex + 1)"
            attachment.lifetime = .keepAlways; add(attachment)
            let result = LearningCandidateValidator().validate(candidate, packet: packet,
                analysis: bundle.analysis, existing: try await repository.snapshot().questions)
            switch result {
            case .success(let question):
                let range = try XCTUnwrap(question.source.range)
                let page = try XCTUnwrap(pdf.page(at: question.source.pageIndex))
                XCTAssertEqual(page.selection(for: NSRange(location: range.location, length: range.length))?.string,
                    question.source.sourceText, "The accepted quote must resolve through real PDFKit selection.")
                try await repository.storeModelQuestion(question)
                accepted += 1
            case .failure(let reason): print("[leu-real-model] rejected=\(reason.rawValue)")
            }
        }
        XCTAssertGreaterThan(accepted, 0, "Real responses alone do not satisfy the accepted learning question gate.")
        let reopened = try store.load()
        XCTAssertEqual(reopened.questions.filter { $0.modelProvenance != nil }.count, accepted)
        let plan = ShelfStudySessionPlanner().plan(snapshot: reopened, topicID: nil, minutes: 10, now: Date())
        XCTAssertTrue(plan.activities.contains { activity in
            reopened.questions.contains { $0.id == activity.questionID && $0.modelProvenance != nil }
        })
        XCTAssertEqual(try Data(contentsOf: url), bytes)
    }
}
