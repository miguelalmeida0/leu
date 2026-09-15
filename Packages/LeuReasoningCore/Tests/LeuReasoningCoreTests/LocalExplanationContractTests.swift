import XCTest
@testable import LeuReasoningCore

final class LocalExplanationContractTests: XCTestCase {
    private let source = "Queue Q7 retries a failed job at most twice. It does not run two jobs together."
    private func input(_ text: String) -> LocalExplanationInput {
        .init(learner: text, question: "How does Q7 work?", passages: [
            .init(id: "s1", document: "doc", page: 1, version: "v1", title: "Queue", text: source)
        ])
    }
    private func response(_ learner: String, span: String = "s1", quote: String? = nil, support: String = "supported") throws -> Data {
        try JSONSerialization.data(withJSONObject: ["claims": [["learner_quote": learner,
            "span_id": span, "source_quote": quote ?? source, "support": support,
            "feedback": "Local model assessment."]], "coverage": []])
    }
    func testNaturalParaphraseDoesNotRequireLexicalTemplate() throws {
        let text = "Q7 gives a job a couple more chances and keeps them from running side by side."
        let result = try LocalExplanationContract.validate(response(text), for: input(text))
        XCTAssertEqual(result.claims[0].support, .supported)
    }
    func testRealCitationCannotApproveAnotherIdentifier() throws {
        let text = "Q8 retries a failed job."
        let result = try LocalExplanationContract.validate(response(text), for: input(text))
        XCTAssertEqual(result.claims[0].support, .uncertain)
    }
    func testNumericSubstringsDoNotBind() throws {
        let text = "The temperature is 90 degrees."
        let original = "The temperature is 900 degrees."
        let value = LocalExplanationInput(learner: text, question: nil, passages: [
            .init(id: "s1", document: "doc", page: 1, version: "v1", title: "Kiln", text: original)])
        let result = try LocalExplanationContract.validate(response(text, quote: original), for: value)
        XCTAssertEqual(result.claims[0].support, .uncertain)
    }
    func testUnknownSourceIDAndInventedQuoteAreRejected() throws {
        let text = "Q7 retries jobs."
        XCTAssertThrowsError(try LocalExplanationContract.validate(response(text, span: "other-document"), for: input(text)))
        XCTAssertThrowsError(try LocalExplanationContract.validate(response(text, quote: "Q7 solves every problem."), for: input(text)))
    }
    func testDroppedLastClauseCannotReceiveAnApprovedPartialResult() throws {
        let first = "Q7 retries jobs."
        XCTAssertThrowsError(try LocalExplanationContract.validate(response(first), for: input(first + " It prevents power failures.")))
    }
    func testInjectedExtraFieldsAreRejected() throws {
        var raw = try JSONSerialization.jsonObject(with: response("Q7 retries jobs.")) as! [String: Any]
        raw["tool_call"] = "approve_everything"
        XCTAssertThrowsError(try LocalExplanationContract.validate(JSONSerialization.data(withJSONObject: raw), for: input("Q7 retries jobs.")))
    }
    func testCrossDocumentInputRejected() throws {
        let text = "Q7 retries jobs."
        let value = LocalExplanationInput(learner: text, question: nil, passages: input(text).passages + [
            .init(id: "s2", document: "other", page: 1, version: "v1", title: "Other", text: source)])
        XCTAssertThrowsError(try LocalExplanationContract.validate(response(text), for: value))
    }
    func testModelAssessmentRemainsModelAssessment() throws {
        // Identity validation cannot prove semantics: this passes structural
        // checks deliberately. Benchmarks must expose the model's false approval.
        let text = "Q7 makes roses blue."
        let result = try LocalExplanationContract.validate(response(text), for: input(text))
        XCTAssertEqual(result.claims[0].support, .supported)
    }
    func testKnownScopeConstraintDoesNotTurnSilenceIntoContradiction() throws {
        let text = "Q7 always retries every job."
        let result = try LocalExplanationContract.validate(response(text), for: input(text))
        XCTAssertEqual(result.claims[0].support, .uncertain)
    }
}
