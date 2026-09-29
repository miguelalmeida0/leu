import XCTest
@testable import ShelfCore

// THROWAWAY — V37 capability spike only (branch `test`, never merged into dev before a pass).

/// Weak reasoning scored apart from the state, and V10 (the model's own low confidence).
final class ZZSpikeReasoningTests: XCTestCase {
    private typealias S = SpikeSynthetic

    private func item(_ state: String, _ categories: [String], text: String = "JWTs are signed, so nobody can read them.",
                      concept: String = "JWT") throws -> GeneralizationEvaluation.Case {
        let json = """
        {"id": "r-\(abs(text.hashValue))-\(state)", "document": "Mobile Mastery", "concept": "\(concept)", "page": null,
         "text": \(String(reflecting: text)), "state": "\(state)", "misconceptions": [], "credits": [],
         "categories": \(String(reflecting: categories)),
         "paraphraseGroup": null}
        """
        return try JSONDecoder().decode(GeneralizationEvaluation.Case.self, from: Data(json.utf8))
    }

    /// A misconception can also carry a reasoning fault: the state's precedence never hides it.
    func testGoldReasoningIssuesIgnoreStatePrecedence() throws {
        XCTAssertTrue(SpikeReasoning.gold(try item("weakReasoning", []), explicit: nil))
        XCTAssertTrue(SpikeReasoning.gold(try item("misconception", ["wrongConclusionPlausibleReason"]), explicit: nil))
        XCTAssertTrue(SpikeReasoning.gold(try item("misconception", ["causeVsCorrelation"]), explicit: nil))
        XCTAssertFalse(SpikeReasoning.gold(try item("misconception", ["negation"]), explicit: nil))
        XCTAssertFalse(SpikeReasoning.gold(try item("weakReasoning", []), explicit: false), "an explicit label wins")
    }

    /// "JWTs are signed, so nobody can read them": a plausible reason linked to a wrong conclusion is a
    /// reasoning issue even though the state is misconception.
    func testReadingFlagsAWrongConclusionDrawnFromAPlausibleReason() throws {
        let jwt = try item("misconception", ["wrongConclusionPlausibleReason"])
        let labels = [S.label(1, "claim-ff95fc8d2fc5f02e", "partiallyEntails", role: "reason"),
                      S.label(2, S.jwtNotEncrypted, "contradicts", misconception: "m1")]
        for config in SpikeConfig.allCases {
            let located = S.check("mistaken", locate: (2, S.jwtNotEncrypted, "wrongIdea"))
            let record = S.record(jwt.id, labels, links: [SpikeLink(reason: 1, conclusion: 2)], opinion: located)
            let (linked, spike) = try S.judge(jwt, record: record, config: config)
            XCTAssertEqual(spike.segments.count, 2, "V35's clause splitter separates \", so\"")
            XCTAssertEqual(linked.judged.state, "misconception", config.rawValue)
            XCTAssertTrue(SpikeReasoning.predicted(linked.judged, checked: linked.checked), config.rawValue)
            // B reads the model's own links only; C and D take the link from the answer's "so" (V37).
            let (unlinked, _) = try S.judge(jwt, record: S.record(jwt.id, labels, opinion: located), config: config)
            XCTAssertEqual(SpikeReasoning.predicted(unlinked.judged, checked: unlinked.checked), config != .b, config.rawValue)
        }
    }

    /// V10: a label the model itself calls low-confidence is asked about, never written firmly (C, D);
    /// B trusts the reading as it is. D (dev13): the row's self-reported confidence does not veto a label both
    /// independent readers confirm (it was among the least stable outputs across runs); it still binds otherwise.
    func testV10LowConfidenceIsNeverWrittenFirmly() throws {
        let text = "It checks that the person is really who they claim to be."
        let item = S.adHoc(text, concept: "Authentication")
        let unsure = S.record(item.id, [S.label(1, S.authDefinition, "entails", confidence: "low")], opinion: S.check("correct"))
        XCTAssertFalse(try S.judge(item, record: unsure, config: .b).0.judged.asksProbe)
        let checked = try S.judge(item, record: unsure, config: .c).0
        XCTAssertTrue(checked.checked!.fired.contains("V10"))
        XCTAssertTrue(checked.judged.asksProbe)
        XCTAssertFalse(checked.judged.recordsMastery)
        let agreed = try S.judge(item, record: unsure, config: .d).0
        XCTAssertTrue(agreed.checked!.fired.contains("D-agree"))
        XCTAssertFalse(agreed.judged.asksProbe)
        let disputed = S.record(item.id, [S.label(1, S.authDefinition, "entails", confidence: "low")], opinion: S.check("vague"))
        XCTAssertTrue(try S.judge(item, record: disputed, config: .d).0.judged.asksProbe, "without agreement V10 binds")
        let denial = S.adHoc("Authentication does not verify identity.", concept: "Authentication")
        let unsureDenial = S.record(denial.id, [S.label(1, S.authDefinition, "contradicts", polarity: "negated", confidence: "low")],
                                    opinion: S.check("mistaken", locate: (1, S.authDefinition, "wrongIdea")))
        XCTAssertEqual(try S.judge(denial, record: unsureDenial, config: .d).0.judged.state, "misconception", "check and locator agree")
        let elsewhere = S.record(denial.id, [S.label(1, S.authDefinition, "contradicts", polarity: "negated", confidence: "low")],
                                 opinion: S.check("mistaken", locate: (0, nil, "none")))
        let doubted = try S.judge(denial, record: elsewhere, config: .d).0
        XCTAssertTrue(doubted.judged.asksProbe)
        XCTAssertFalse(doubted.judged.recordsMisconception)
        let invalid = S.record(item.id, [S.label(1, S.authDefinition, "entails", confidence: "certain")])
        XCTAssertEqual(try S.judge(item, record: invalid, config: .b).0.fallback, .invalidReading, "V1 checks the value")
    }
}
