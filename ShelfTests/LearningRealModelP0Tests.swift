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
        var generated = 0
        var represented = 0
        var meaningful = 0
        var inferenceAttempts = 0
        var inferenceErrors: [String] = []
        var rejectionCodes: [String] = []
        var operations: [String] = []
        func attachMetrics() {
            let metrics: [String: Any] = ["generated": generated, "inferenceAttempts": inferenceAttempts,
                "meaningfulClaims": meaningful, "inferenceErrors": inferenceErrors,
                "representableClaims": represented, "accepted": accepted, "rejected": rejectionCodes.count,
                "repairCount": 0, "cognitiveOperations": operations, "rejectionCodes": rejectionCodes,
                "backend": provider.backend]
            guard let data = try? JSONSerialization.data(withJSONObject: metrics, options: [.prettyPrinted, .sortedKeys]) else {
                XCTFail("Could not encode real-model metrics"); return
            }
            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
            attachment.name = "real-model-v2-metrics"; attachment.lifetime = .keepAlways; add(attachment)
            print("[leu-real-model-v2] \(metrics)")
        }
        defer { attachMetrics() }
        for page in bundle.analysis.pages.filter({ $0.pageIndex == 2 }) {
            let packet = try XCTUnwrap(LearningSourcePacket(analysis: bundle.analysis, page: page))
            let preflight = GroundedQuestionCompiler().compile(packet)
            represented += preflight.selectableClaims.count
            meaningful += preflight.meaningfulClaims.count
            XCTAssertEqual(preflight.status, .representable)
            XCTAssertGreaterThan(preflight.selectableClaims.count, 0)
            let preflightAttachment = XCTAttachment(data: try JSONEncoder().encode(preflight), uniformTypeIdentifier: "public.json")
            preflightAttachment.name = "real-model-preflight-page-3"; preflightAttachment.lifetime = .keepAlways; add(preflightAttachment)
            let packetAttachment = XCTAttachment(data: try JSONEncoder().encode(packet), uniformTypeIdentifier: "public.json")
            packetAttachment.name = "real-model-source-packet-page-3"; packetAttachment.lifetime = .keepAlways; add(packetAttachment)
            inferenceAttempts += 1
            let candidate: LearningModelCandidate
            do { candidate = try await provider.generateQuestion(from: packet) }
            catch { inferenceErrors.append(String(describing: error)); throw error }
            generated += 1
            XCTAssertNotNil(candidate.selection)
            operations.append(candidate.skill)
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
            case .failure(let reason):
                rejectionCodes.append(reason.rawValue)
                print("[leu-real-model] rejected=\(reason.rawValue)")
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
