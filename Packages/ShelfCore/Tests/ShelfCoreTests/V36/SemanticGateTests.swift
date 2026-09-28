import XCTest
@testable import ShelfCore

/// The gate between "these words are close" and "this clause says that claim": similarity never
/// overrides a contradiction, an opposite, an omitted negation or an absolute where the source
/// hedges; credit in other words must rest on the other words; and a reversal is read only where
/// the negated words are the claim's own.
final class SemanticGateTests: XCTestCase {
    private var kb: ConceptKnowledgeBase { LearningCorpus.mastery }

    private func gate(_ text: String, _ concept: String, claim needle: String) throws -> (SemanticGate, SemanticEvidence) {
        let space = try XCTUnwrap(SemanticSpace.shared)
        let target = try XCTUnwrap(DiagnosisTarget.concept(ConceptKey(concept), in: kb))
        let claim = try XCTUnwrap(target.allClaims.first { $0.statement.contains(needle) }, needle)
        let context = AlignmentContext(target: target)
        let clause = LearnerClause(text)
        let alignment = Alignment(clause: clause, rubric: ClaimRubric(claim), context: context)
        let evidence = SemanticMatcher.evidence(claim: alignment.rubric.complement, learner: SemanticReader(space: space, context: context).learnerTerms(clause),
                                                lexical: { clause.profile.match($0) }, space: space)
        return (SemanticGate(alignment, evidence: evidence, space: space, context: context), evidence)
    }

    func testSimilarityNeverOverridesContradictionNegationOrScope() throws {
        let vetoed: [(String, String, String, SemanticGate.Block)] = [
            ("Authentication is the process of not verifying who a user or service is.", "Authentication", "verifying who", .contradiction),
            ("Indexes trade extra storage and write cost for slower reads.", "Database index", "trade additional storage", .opposite),
            ("Identity by itself is permission.", "Authorization", "Identity alone is not permission", .omittedNegation),
            ("Retrying means you always attempt a failed operation again, every single time.", "Retry", "failure may be temporary", .universal),
        ]
        for (text, concept, needle, block) in vetoed {
            let (gate, evidence) = try gate(text, concept, claim: needle)
            XCTAssertGreaterThanOrEqual(evidence.recall, SemanticThresholds.expressed, "close enough to credit on similarity alone: \(text)")
            XCTAssertTrue(gate.blocks.contains(block), "\(text): \(gate.blocks)")
            XCTAssertNil(gate.coverage, text)
        }
    }

    func testCreditInOtherWordsRestsOnTheOtherWords() throws {
        // "longer-lasting" for "longer-lived", "gets" for "obtain": the stand-ins carry the claim.
        let (paraphrase, evidence) = try gate("A refresh token is a longer-lasting credential that gets you new access tokens without logging in again.",
                                              "Refresh token", claim: "obtain new access tokens")
        XCTAssertEqual(paraphrase.coverage, .covered)
        XCTAssertEqual(Set(evidence.substitutions.map(\.claim)), ["longer-lived", "obtain"])
        XCTAssertFalse(paraphrase.reversesSense, "\"without logging in again\" keeps the claim's own negation")
        // Its own words already reach the claim: that was the lexical reader's to settle.
        let (own, _) = try gate("Indexes trade additional storage and write cost for quicker reads.", "Database index", claim: "trade additional storage")
        XCTAssertNil(own.coverage)
        XCTAssertEqual(own.blocks, [.ownWords])
    }

    func testAnOppositeWordTheWordsOnlyReaderMissesIsReadAsAReversedSense() throws {
        let (gate, evidence) = try gate("Idempotency makes retries dangerous.", "Idempotency", claim: "makes retries safe")
        XCTAssertEqual(evidence.opposites.map(\.learner), ["dangerous"])
        XCTAssertNil(gate.coverage)
        XCTAssertTrue(gate.reversesSense)
    }

    func testAReversalIsReadOnlyOnTheClaimsOwnWords() throws {
        // "no more than once" reaches "at most once" only through "repeatedly", the very thing the
        // negation undoes: neither credit nor a reversal.
        let (bounded, _) = try gate("Throttling caps an action so it fires no more than once in each interval while events keep arriving.",
                                    "Throttling", claim: "at most once per time window")
        XCTAssertNil(bounded.coverage)
        XCTAssertFalse(bounded.reversesSense)
        // "Not every event" denies a universal the claim never states.
        XCTAssertNotEqual(SemanticGate.polarity(LearnerClause("The handler runs once per interval, not on every event."),
                                                ClaimRubric(try XCTUnwrap(DiagnosisTarget.concept(ConceptKey("Throttling"), in: kb)?.rubric.first)),
                                                space: try XCTUnwrap(SemanticSpace.shared)), .reversed)
    }

    func testClearParaphrasesTheStaticSpaceCannotCarryStayUncredited() throws {
        // Known limit, reported rather than tuned away: a word-level space misses phrase-level
        // paraphrase. The answer is asked about, never marked wrong.
        let (lifespan, _) = try gate("A brief lifespan limits the harm when somebody steals the token.", "Access token", claim: "Short lifetimes reduce damage")
        XCTAssertEqual(lifespan.blocks, [.thin])
        XCTAssertFalse(lifespan.reversesSense)
    }
}
