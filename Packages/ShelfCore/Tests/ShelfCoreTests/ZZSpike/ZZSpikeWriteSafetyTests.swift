import XCTest
@testable import ShelfCore

// THROWAWAY — V37 capability spike only (branch `test`, never merged into dev before a pass).

/// dev13: selective protection of decisive writes, and claim / reasoning / misconception kept apart.
final class ZZSpikeWriteSafetyTests: XCTestCase {
    private typealias S = SpikeSynthetic
    private let jwtText = "A JWT is a compact signed token with a header, a payload and a signature. Because it is encrypted, nobody can read the claims."

    private func judge(_ text: String, concept: String, _ labels: [SpikeSegmentLabel], opinion: SpikeSecondOpinionOutput? = nil,
                       _ config: SpikeConfig = .d) throws -> SpikeAdapter.Outcome {
        let item = S.adHoc(text, concept: concept)
        return try S.judge(item, record: S.record(item.id, labels, opinion: opinion), config: config).0
    }

    /// A label both readers agree on is not held back by a lexical heuristic (V7 here); V11 still binds.
    func testAgreementOutranksHeuristicsButNotPartialCredit() throws {
        let short = [S.label(1, S.authDefinition, "entails", specificity: "vague")]
        let text = "It is about checking identity."
        XCTAssertTrue(try judge(text, concept: "Authentication", short, .c).judged.asksProbe, "C: V7 alone makes it tentative")
        let agreed = try judge(text, concept: "Authentication", short, opinion: S.check("correct"))
        XCTAssertTrue(agreed.checked!.fired.contains("D-agree"))
        XCTAssertFalse(agreed.judged.asksProbe)
        let partial = [S.label(1, S.authDefinition, "partiallyEntails")]
        XCTAssertTrue(try judge(text, concept: "Authentication", partial, opinion: S.check("correct")).judged.asksProbe)
    }

    /// Both readers accept "Because it is encrypted" as the "not automatically encrypted" claim: an affirmative
    /// segment credited with a negated claim restates what the source denies (V3a). No credit, no mastery, and
    /// agreement does not override it. As a reason clause it is probed as reasoning; as a statement, the judge's
    /// own omitted-negation rule asks a misconception check.
    func testAnOmittedNegationIsNeverCreditOrMastery() throws {
        let labels = [S.label(1, S.jwtDefinition, "entails"), S.label(2, S.jwtNotEncrypted, "entails", role: "reason"), S.label(3)]
        let outcome = try judge(jwtText, concept: "JWT", labels, opinion: S.check("correct"))
        XCTAssertTrue(outcome.checked!.fired.contains("V3a"))
        XCTAssertFalse(outcome.judged.recordsMastery)
        XCTAssertTrue(outcome.judged.asksProbe)
        XCTAssertEqual(outcome.judged.state, "weakReasoning", "a reason clause: the reasoning is what is asked about")
        // The same wrong idea as a plain statement: the judge's omitted-negation rule asks a misconception check.
        let statement = "A JWT is a compact signed token with a header, a payload and a signature. JWTs are automatically encrypted."
        let plain = try judge(statement, concept: "JWT", [S.label(1, S.jwtDefinition, "entails"), S.label(2, S.jwtNotEncrypted, "entails")],
                              opinion: S.check("correct"))
        XCTAssertTrue(plain.checked!.fired.contains("V3a"))
        XCTAssertFalse(plain.judged.recordsMastery)
        XCTAssertTrue(plain.assessment?.judgement.question?.between.contains(.misconception) ?? false)
        let negated = try judge("A JWT is a compact signed token. It is not automatically encrypted.", concept: "JWT",
                                [S.label(1, S.jwtDefinition, "entails"), S.label(2, S.jwtNotEncrypted, "entails", polarity: "negated")],
                                opinion: S.check("correct"))
        XCTAssertFalse(negated.checked!.fired.contains("V3a"), "the negation expressed: credit stands")
    }

    /// An unmatched "Because …" clause is an unsettled reason: never committed as weak reasoning with credit.
    func testAnUnmatchedReasonClauseIsNeverCommitted() throws {
        let labels = [S.label(1, S.jwtDefinition, "entails"), S.label(2), S.label(3)]
        for config in SpikeConfig.allCases {
            let outcome = try judge(jwtText, concept: "JWT", labels, opinion: S.check("vague"), config)
            XCTAssertFalse(outcome.judged.state == "weakReasoning" && !outcome.judged.asksProbe, config.rawValue)
        }
    }

    /// A credited claim, a faulty reason and a separate misconception, in one answer, kept apart.
    func testClaimReasoningAndMisconceptionFacetsCoexist() throws {
        let text = "The inner function can still access the outer variable because JavaScript copies all outer variables into it. Closures are only used for private state."
        let segments = SpikeSegmenter.segments(text)
        XCTAssertEqual(segments.count, 3, "\(segments)")
        let purpose = "claim-ea1f1e097d9c8eab"
        let labels = [S.label(1, S.closureDefinition, "entails"), S.label(2, S.closureRetain, "contradicts", role: "reason"),
                      S.label(3, purpose, "contradicts")]
        let outcome = try judge(text, concept: "Closure", labels, opinion: S.check("mistaken", locate: (3, purpose, "wrongIdea")), .c)
        let facets = try XCTUnwrap(outcome.facets)
        XCTAssertEqual(facets.claims[S.closureDefinition], "covered")
        XCTAssertEqual(facets.reasoning, .faulty)
        XCTAssertEqual(facets.misconceptions, [purpose])
    }
}
