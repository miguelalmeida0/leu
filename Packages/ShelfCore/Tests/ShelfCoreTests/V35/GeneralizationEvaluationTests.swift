import XCTest
@testable import ShelfCore

/// Generalization of understanding judgements to explanations written by annotators working only
/// from a labeling guide and the source's sentences (dev: reported and used for development;
/// sealed: aggregates only, once per release).
final class GeneralizationEvaluationTests: XCTestCase {
    func testDevSplitReport() throws {
        let fixture = try XCTUnwrap(GeneralizationEvaluation.fixture("dev"), "dev generalization fixture")
        let v34 = GeneralizationEvaluation.evaluate(fixture, GeneralizationEvaluation.v34)
        let v35 = GeneralizationEvaluation.evaluate(fixture, GeneralizationEvaluation.v35)
        print("GENERALIZATION|dev|v34-policy|\(v34)")
        print("GENERALIZATION|dev|v35|\(v35)")
        print("GENERALIZATION|dev|v35|\(v35.breakdown)")
        print("TRAJECTORY|dev|v34-policy|\(LearnerTrajectoryEvaluation.evaluate(fixture, GeneralizationEvaluation.v34))")
        print("TRAJECTORY|dev|v35|\(LearnerTrajectoryEvaluation.evaluate(fixture, GeneralizationEvaluation.v35))")
        XCTAssertEqual(v35.unavailable, 0, "every dev case has a comparable target")
        XCTAssertGreaterThanOrEqual(v35.cases, 100)
        assertJudgementIsSaferAndBetterCalibrated(v35, than: v34)
        assertStillCreditsUnderstanding(v35, v34)
    }

    /// Asking about everything would pass every safety check: the judgement must still credit at
    /// least half the understanding the V34 policy credits.
    private func assertStillCreditsUnderstanding(_ v35: GeneralizationEvaluation.Report, _ v34: GeneralizationEvaluation.Report,
                                                 file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertGreaterThanOrEqual(v35.masteryCredited * 2, v34.masteryCredited, file: file, line: line)
        XCTAssertLessThan(v35.probes, v35.cases, file: file, line: line)
    }

    /// The same reader, two policies: the judgement never adds mastery or credits a misconception
    /// the V34 policy would not, commits fewer harmful verdicts, and states calibrated confidence.
    private func assertJudgementIsSaferAndBetterCalibrated(_ v35: GeneralizationEvaluation.Report, than v34: GeneralizationEvaluation.Report,
                                                           file: StaticString = #filePath, line: UInt = #line) {
        let harmful = { (r: GeneralizationEvaluation.Report) in r.overCredit + r.falseAlarm + r.missedMisconception }
        XCTAssertLessThanOrEqual(v35.falseMastery, v34.falseMastery, file: file, line: line)
        XCTAssertLessThanOrEqual(v35.misconceptionCredited, v34.misconceptionCredited, file: file, line: line)
        XCTAssertLessThanOrEqual(v35.falseMisconception, v34.falseMisconception, file: file, line: line)
        XCTAssertLessThan(harmful(v35), harmful(v34), file: file, line: line)
        XCTAssertLessThan(v35.brierScore, v34.brierScore, file: file, line: line)
    }

    /// The V34 fixture read as coarse judgements, labels untouched. Its held-out split was audited
    /// for V35, so this is a regression view, not evidence of generalization.
    func testLegacyFixtureAsJudgements() {
        for split in ["dev", "holdout"] {
            let fixture = GeneralizationEvaluation.legacy(split)
            let v34 = GeneralizationEvaluation.evaluate(fixture, GeneralizationEvaluation.v34, metamorphic: false)
            let v35 = GeneralizationEvaluation.evaluate(fixture, GeneralizationEvaluation.v35, metamorphic: false)
            print("GENERALIZATION|legacy-\(split)|v34-policy|\(v34)")
            print("GENERALIZATION|legacy-\(split)|v35|\(v35)")
            XCTAssertLessThanOrEqual(v35.falseMastery, v34.falseMastery, "the judgement never adds mastery the V34 policy would not")
            XCTAssertLessThanOrEqual(v35.misconceptionCredited, v34.misconceptionCredited)
            XCTAssertLessThanOrEqual(v35.wrongCommits, v34.wrongCommits)
            assertStillCreditsUnderstanding(v35, v34)
        }
    }

    /// Never prints a case. Aggregates are printed only when LEU_SEALED_REPORT=1.
    func testSealedSplitIsEvaluableAndReportsAggregatesOnlyOnRequest() throws {
        let fixture = try XCTUnwrap(GeneralizationEvaluation.fixture("sealed"), "sealed generalization fixture")
        let v34 = GeneralizationEvaluation.evaluate(fixture, GeneralizationEvaluation.v34)
        let v35 = GeneralizationEvaluation.evaluate(fixture, GeneralizationEvaluation.v35)
        XCTAssertEqual(v35.unavailable, 0, "every sealed case has a comparable target")
        XCTAssertGreaterThanOrEqual(v35.cases, 100)
        assertJudgementIsSaferAndBetterCalibrated(v35, than: v34)
        guard ProcessInfo.processInfo.environment["LEU_SEALED_REPORT"] == "1" else { return }
        print("GENERALIZATION|sealed|v34-policy|\(v34)")
        print("GENERALIZATION|sealed|v35|\(v35)")
        print("TRAJECTORY|sealed|v34-policy|\(LearnerTrajectoryEvaluation.evaluate(fixture, GeneralizationEvaluation.v34))")
        print("TRAJECTORY|sealed|v35|\(LearnerTrajectoryEvaluation.evaluate(fixture, GeneralizationEvaluation.v35))")
    }

    /// The metrics themselves: a predictor that credits everything is charged with every false
    /// mastery and every credited misconception; one that probes everything credits nothing.
    func testMetricsChargeFalseMasteryAndCountProbes() throws {
        func item(_ id: String, _ state: String, _ misconceptions: [GeneralizationEvaluation.Misconception] = [],
                  group: String? = nil) -> GeneralizationEvaluation.Case {
            .init(id: id, document: "Mobile Mastery", text: "Idempotency means the same request can be repeated safely.", state: state,
                  concept: "Idempotency", page: nil, misconceptions: misconceptions, credits: [], categories: ["paraphrase"],
                  paraphraseGroup: group)
        }
        let wrong = GeneralizationEvaluation.Misconception(kind: "contradiction", claim: nil, confusedWith: nil)
        let fixture = GeneralizationEvaluation.Fixture(split: "test", cases: [
            item("a", "understood", group: "g"), item("b", "understood", group: "g"), item("c", "misconception", [wrong]),
            item("d", "fragile"), item("e", "insufficient")
        ])
        let input = try XCTUnwrap(GeneralizationEvaluation.input(for: fixture.cases[0]))
        let concept = LearnerConceptID(documentID: input.documentID, concept: try XCTUnwrap(input.target.concept))
        let credit = LearningEvidence(concept: concept, conceptName: "Idempotency", operation: .define, outcome: .correct,
                                      channel: .explanation, occurredAt: GeneralizationEvaluation.epoch)
        let generous = GeneralizationEvaluation.evaluate(fixture, { _, _ in .init(state: "understood", confidence: 1, asksProbe: false, evidence: [credit]) },
                                                         metamorphic: false)
        XCTAssertEqual(generous.falseMastery, 3)
        XCTAssertEqual(generous.goldNotPositive, 3)
        XCTAssertEqual(generous.misconceptionCredited, 1)
        XCTAssertEqual(generous.masteryCredited, 2)
        XCTAssertEqual(generous.coarseRight, 2)
        XCTAssertEqual(generous.stableGroups, 1)
        XCTAssertEqual(generous.brierScore, 0.6, accuracy: 1e-9, "three confident errors in five")
        let cautious = GeneralizationEvaluation.evaluate(fixture, { _, _ in .init(state: "fragile", confidence: 0.5, asksProbe: true, evidence: []) },
                                                         metamorphic: false)
        XCTAssertEqual(cautious.falseMastery, 0)
        XCTAssertEqual(cautious.masteryCredited, 0, "probing everything never credits real understanding either")
        XCTAssertEqual(cautious.probes, 5)
        XCTAssertEqual(cautious.misconceptionProbed, 1)
        XCTAssertEqual(cautious.brierScore, 0.25, accuracy: 1e-9)
    }
}
