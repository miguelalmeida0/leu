import XCTest
@testable import LeuReasoningCore

final class LearnerAlignmentTests: XCTestCase {

    /// The worked example from the brief: a claim that drops the source's
    /// condition is partial, not simply wrong.
    func testDroppedConditionIsPartialNotWrong() throws {
        let graph = try CorpusFixture.graph()
        let report = ExplanationAligner().align(explanation: "Retries fix failed requests.",
                                                concept: "retrying",
                                                in: graph)
        XCTAssertEqual(report.verdict, .partiallySupported)
        XCTAssertTrue(report.findings.contains { $0.type == .missingCondition })
        let feedback = try XCTUnwrap(report.alignments.first?.feedback)
        XCTAssertTrue(feedback.text.contains("missing the condition"))
        XCTAssertTrue(feedback.provenance.isComplete)
    }

    /// The same idea stated universally is an overgeneralisation.
    func testUniversalClaimOverASourceConditionIsRejected() throws {
        let graph = try CorpusFixture.graph()
        let report = ExplanationAligner().align(explanation: "You should retry every failed request.",
                                                concept: "retrying",
                                                in: graph)
        XCTAssertEqual(report.verdict, .contradicted)
        XCTAssertTrue(report.findings.contains { $0.type == .scopeTooBroad })
    }

    func testParaphraseWithDifferentVocabularyIsAccepted() throws {
        let graph = try CorpusFixture.graph()
        let report = ExplanationAligner().align(explanation: "Caching means reusing data you fetched before.",
                                                concept: "caching",
                                                in: graph)
        XCTAssertEqual(report.verdict, .supported)
        XCTAssertTrue(report.findings.isEmpty)
    }

    func testReversedCausalityIsDetected() throws {
        let graph = try CorpusFixture.graph()
        let report = ExplanationAligner().align(explanation: "A cascading failure causes thread pool exhaustion.",
                                                concept: "thread pool exhaustion",
                                                in: graph)
        XCTAssertEqual(report.verdict, .contradicted)
        XCTAssertTrue(report.findings.contains { $0.type == .reversedCauseEffect })
    }

    func testUnrelatedClaimIsNotAddressedRatherThanWrong() throws {
        let graph = try CorpusFixture.graph()
        let report = ExplanationAligner().align(explanation: "Kubernetes pods schedule onto nodes by affinity.",
                                                concept: "caching",
                                                in: graph)
        XCTAssertEqual(report.verdict, .notAddressed)
    }

    func testLearnerPropositionsNeverEnterTheGraph() throws {
        let graph = try CorpusFixture.graph()
        let propositions = PropositionSplitter().split("Retries fix every failed request.")
        XCTAssertFalse(propositions.isEmpty)
        for proposition in propositions {
            XCTAssertNil(graph.atom(proposition.id))
        }
    }

    /// Certification gates over the whole learner corpus.
    func testCorpusAlignmentGates() async throws {
        let corpus = try CorpusFixture.load()
        let report = await EvaluationHarness(corpus: corpus).run()
        let alignment = report.learnerAlignment

        XCTAssertGreaterThanOrEqual(alignment.paraphraseCases, 20)
        XCTAssertGreaterThanOrEqual(alignment.contradictionCases, 20)
        XCTAssertGreaterThanOrEqual(alignment.overgeneralisationCases, 20)

        let paraphraseRate = Double(alignment.paraphraseAccepted) / Double(max(alignment.paraphraseCases, 1))
        let contradictionRate = Double(alignment.contradictionRejected) / Double(max(alignment.contradictionCases, 1))
        let overgeneralisationRate = Double(alignment.overgeneralisationDetected) / Double(max(alignment.overgeneralisationCases, 1))

        XCTAssertGreaterThanOrEqual(paraphraseRate, 0.80, "paraphrase acceptance: \(paraphraseRate)")
        XCTAssertGreaterThanOrEqual(contradictionRate, 0.80, "contradiction rejection: \(contradictionRate)")
        XCTAssertGreaterThanOrEqual(overgeneralisationRate, 0.80, "overgeneralisation detection: \(overgeneralisationRate)")
    }

    func testExplanationDeltaReportsWhatTheLearnerFixed() throws {
        let graph = try CorpusFixture.graph()
        let delta = UnderstandingStateProjector().explanationDelta(
            previous: "Retries fix failed requests.",
            updated: "If the failure is transient, retrying enables the operation to succeed.",
            concept: "retrying",
            in: graph)
        XCTAssertTrue(delta.resolved.contains(.missingCondition))
        XCTAssertTrue(delta.introduced.isEmpty)
        XCTAssertTrue(delta.improved)
    }
}
