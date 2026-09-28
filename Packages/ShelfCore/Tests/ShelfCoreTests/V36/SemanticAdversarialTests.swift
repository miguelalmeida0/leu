import XCTest
@testable import ShelfCore

/// The V36 adversarial suite: the fifteen kinds of language of the V36 brief that defeat word
/// matching, each read with words only (exactly V35) and with meaning too (V36). Everywhere:
/// meaning never buys a write the words do not earn, a wrong answer is never credited without its
/// misconception, and a right one is never recorded as a misconception. Cases V36 still gets wrong
/// are listed by name, not left out.
final class SemanticAdversarialTests: XCTestCase {
    enum Truth { case right, wrong, partial, nothing }
    struct Case { let category: String; let concept: String; let text: String; let truth: Truth }

    /// Written for this suite, not taken from any evaluation split.
    static let cases: [Case] = [
        Case(category: "sameMeaningDifferentWords", concept: "Closure", text: "A closure remembers its surrounding bindings.", truth: .right),
        Case(category: "sameMeaningDifferentWords", concept: "Closure", text: "The inner function can still access variables from the function that created it.", truth: .right),
        Case(category: "sameMeaningDifferentWords", concept: "Refresh token", text: "A refresh token is a longer-lasting credential that gets you new access tokens without logging in again.", truth: .right),
        Case(category: "sameWordsOppositeMeaning", concept: "Idempotency", text: "Idempotency makes retries dangerous.", truth: .wrong),
        Case(category: "sameWordsOppositeMeaning", concept: "JWT", text: "Nobody holding a JWT can read the claims in its payload.", truth: .wrong),
        Case(category: "sameWordsOppositeMeaning", concept: "Throttling", text: "Throttling waits until the events stop coming and only then runs the handler once.", truth: .wrong),
        Case(category: "negation", concept: "Authentication", text: "Authentication does not establish identity.", truth: .wrong),
        Case(category: "negation", concept: "Idempotency", text: "Repeating an idempotent operation does not have the same effect as doing it once.", truth: .wrong),
        Case(category: "qualifiedVsAbsolute", concept: "Retry", text: "Retrying a failed call always makes it succeed eventually, whatever the error.", truth: .wrong),
        Case(category: "qualifiedVsAbsolute", concept: "Retry", text: "You try a failed call again when the failure might only be temporary.", truth: .right),
        Case(category: "causeVsCorrelation", concept: "Database index", text: "Big tables are usually the slow ones, so a table's size is what an index shrinks to make lookups fast.", truth: .wrong),
        Case(category: "causeVsCorrelation", concept: "Retry", text: "Calls that fail at night tend to succeed in the morning, so the time of day is what makes a retry work.", truth: .wrong),
        Case(category: "subjectObjectReversal", concept: "Refresh token", text: "An access token is a longer-lived credential used to obtain new refresh tokens.", truth: .wrong),
        Case(category: "subjectObjectReversal", concept: "Authorization", text: "Authorization is what an allowed identity uses to decide who it is.", truth: .wrong),
        Case(category: "rightConclusionWrongReasoning", concept: "Database index", text: "An index speeds up lookups on a column, because the database keeps the results of earlier queries and hands them back.", truth: .wrong),
        Case(category: "rightConclusionWrongReasoning", concept: "Refresh token", text: "A refresh token gets you a new access token without logging in again, because your password is stored inside it.", truth: .wrong),
        Case(category: "multipleConcepts", concept: "Authentication", text: "Authentication checks who you are; authorization then decides what you may do.", truth: .right),
        Case(category: "multipleConcepts", concept: "Debouncing", text: "Debouncing waits for a pause in the events, while throttling runs at most once per window.", truth: .right),
        Case(category: "partialUnderstanding", concept: "Idempotency", text: "Idempotency is about retries.", truth: .partial),
        Case(category: "irrelevantButTopical", concept: "JWT", text: "JWTs are really popular and lots of web frameworks support them.", truth: .nothing),
        Case(category: "misconceptionParaphrase", concept: "JWT", text: "JWTs are signed so nobody can read them.", truth: .wrong),
        Case(category: "misconceptionParaphrase", concept: "HttpOnly cookie", text: "Marking a cookie HttpOnly makes XSS attacks harmless.", truth: .wrong),
        Case(category: "exampleInsteadOfDefinition", concept: "Idempotency", text: "Pressing an elevator call button five times still brings just one elevator.", truth: .right),
        Case(category: "veryShort", concept: "Database index", text: "It's fast.", truth: .nothing),
        Case(category: "verboseWithOneWrongClause", concept: "JWT", text: "A JWT is a compact token with a header, a payload and a signature. The signature lets the API check who issued it without looking anything up in a database. Because it is encrypted, nobody can read the claims inside.", truth: .wrong),
        Case(category: "verboseWithOneWrongClause", concept: "Stateless server", text: "A stateless server handles each request without relying on anything kept in its own memory, so any replica can take the next request, which makes horizontal scaling easier; that is also why stateless servers never need a database.", truth: .wrong),
        Case(category: "pronounAmbiguity", concept: "useCallback", text: "It keeps it so that it doesn't have to make it again.", truth: .nothing),
        Case(category: "pronounAmbiguity", concept: "Closure", text: "It keeps them around after it finishes so that it can use them.", truth: .nothing),
    ]
    /// Still wrong in V36 exactly as in V35 (the words-only reader decides them and meaning adds no
    /// doubt): a reversal credited in full, a correlation credited in part, and a two-concept
    /// contrast recorded as a confusion.
    static let knownFailures: Set<String> = [
        "Authorization is what an allowed identity uses to decide who it is.",
        "Calls that fail at night tend to succeed in the morning, so the time of day is what makes a retry work.",
        "Debouncing waits for a pause in the events, while throttling runs at most once per window.",
    ]

    private var kb: ConceptKnowledgeBase { LearningCorpus.mastery }
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func read(_ text: String, _ concept: String, semantics: Bool) throws -> (UnderstandingAssessment, [LearningEvidence]) {
        let target = try XCTUnwrap(DiagnosisTarget.concept(ConceptKey(concept), in: kb), concept)
        let assessment = (semantics ? UnderstandingDiagnoser() : UnderstandingDiagnoser(semantics: nil)).assess(text, target: target)
        let evidence = LearnerEvidenceMapper(knowledge: kb).evidence(from: assessment, documentID: LearningCorpus.analysis("Mobile Mastery").documentID,
                                                                     identity: "adversarial", at: now)
        return (assessment, evidence)
    }

    private func key(_ item: LearningEvidence) -> String {
        "\(item.concept.concept.value)|\(item.operation.rawValue)|\(item.outcome.rawValue)|\(item.misconception?.kind.rawValue ?? "-")"
    }

    func testTheSuiteCoversEveryCategoryOfTheBrief() {
        XCTAssertEqual(Set(Self.cases.map(\.category)).count, 15)
        XCTAssertTrue(Self.knownFailures.isSubset(of: Set(Self.cases.map(\.text))))
    }

    func testMeaningNeverBuysAWriteTheWordsDoNotEarn() throws {
        for item in Self.cases {
            let (_, words) = try read(item.text, item.concept, semantics: false)
            let (_, meaning) = try read(item.text, item.concept, semantics: true)
            XCTAssertTrue(Set(meaning.map(key)).isSubset(of: Set(words.map(key))), item.text)
        }
    }

    func testAWrongAnswerIsNeverCreditedWithoutItsMisconception() throws {
        for item in Self.cases where item.truth == .wrong && !Self.knownFailures.contains(item.text) {
            let (_, evidence) = try read(item.text, item.concept, semantics: true)
            XCTAssertFalse(evidence.contains { $0.outcome == .correct }, "mastery for: \(item.text)")
            let credited = evidence.contains { $0.outcome != .incorrect && $0.misconception == nil }
            XCTAssertFalse(credited && !evidence.contains { $0.misconception != nil }, "credit without the misconception: \(item.text)")
        }
    }

    func testARightAnswerIsNeverRecordedAsAMisconception() throws {
        for item in Self.cases where item.truth == .right && !Self.knownFailures.contains(item.text) {
            let (assessment, evidence) = try read(item.text, item.concept, semantics: true)
            XCTAssertFalse(evidence.contains { $0.misconception != nil }, item.text)
            XCTAssertNotEqual(assessment.judgement.state, .misconception, item.text)
        }
    }

    func testWhatMeaningAddsOverWordsOnly() throws {
        // A long, fluent answer with one wrong reason: V35 records mastery, V36 asks for the reason.
        let verbose = try XCTUnwrap(Self.cases.first { $0.category == "verboseWithOneWrongClause" && $0.concept == "JWT" })
        let (_, v35) = try read(verbose.text, verbose.concept, semantics: false)
        XCTAssertTrue(v35.contains { $0.outcome == .correct })
        let (assessment, v36) = try read(verbose.text, verbose.concept, semantics: true)
        XCTAssertTrue(v36.isEmpty)
        XCTAssertEqual(assessment.judgement.question?.between.first, .weakReasoning)
        // "Dangerous" where the source says "safe": words only, it is asked the same definition
        // question as the right answer; V36 asks whether it reverses the claim it echoes.
        let safe = try XCTUnwrap(DiagnosisTarget.concept(ConceptKey("Idempotency"), in: kb)?.allClaims.first { $0.statement.contains("makes retries safe") })
        let (words, _) = try read("Idempotency makes retries dangerous.", "Idempotency", semantics: false)
        let (right, _) = try read("Idempotency makes retries safe.", "Idempotency", semantics: true)
        XCTAssertEqual(words.judgement.question?.operation, right.judgement.question?.operation)
        let (meaning, meaningEvidence) = try read("Idempotency makes retries dangerous.", "Idempotency", semantics: true)
        XCTAssertEqual(meaning.judgement.question?.operation, .misconceptionCheck)
        XCTAssertEqual(meaning.judgement.question?.claimIDs, [safe.id])
        XCTAssertEqual(meaning.judgement.hypotheses.first?.cue, .opposite)
        XCTAssertNotEqual(right.judgement.question?.operation, .misconceptionCheck)
        XCTAssertTrue(meaningEvidence.isEmpty)
    }

    func testTheBriefsOwnExamples() throws {
        // Shares "signed" and "read" with the source, says the opposite of it: never credited.
        let (signed, signedEvidence) = try read("JWTs are signed so nobody can read them.", "JWT", semantics: true)
        XCTAssertTrue(signedEvidence.isEmpty)
        XCTAssertFalse(signed.judgement.state.credits)
        // A negation decides the meaning: no credit however close the words.
        let (denied, deniedEvidence) = try read("Authentication does not establish identity.", "Authentication", semantics: true)
        XCTAssertTrue(deniedEvidence.isEmpty)
        XCTAssertFalse(denied.judgement.state.credits)
        // "Remembers its surrounding bindings" and "can still access variables from the function
        // that created it" say the same thing; the static space does not relate "bindings" to
        // "variables" (cosine 0.09), so V36 does not align them. The first is asked about, never
        // marked wrong; the second is credited on its words.
        let (bindings, bindingsEvidence) = try read("A closure remembers its surrounding bindings.", "Closure", semantics: true)
        XCTAssertTrue(bindingsEvidence.isEmpty)
        XCTAssertNotNil(bindings.judgement.question)
        XCTAssertNotEqual(bindings.judgement.state, .misconception)
        let (_, variables) = try read("The inner function can still access variables from the function that created it.", "Closure", semantics: true)
        XCTAssertTrue(variables.contains { $0.outcome == .correct })
    }
}
