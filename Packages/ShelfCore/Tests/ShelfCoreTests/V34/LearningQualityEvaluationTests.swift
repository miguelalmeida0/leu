import XCTest
@testable import ShelfCore

/// Quality gates on the labeled diagnosis fixture (written before V34; dev tuned, held-out
/// reported) and on grounding coverage of the real 345-page manual. Thresholds sit just under
/// measured V34 performance so a regression fails loudly; the V27 baseline stays runnable.
final class LearningQualityEvaluationTests: XCTestCase {
    func testDevExplanationsAreDiagnosedActionably() {
        let report = DiagnosisEvaluation.evaluate(split: "dev", DiagnosisEvaluation.v34)
        print("QUALITY|dev|v34|\(report)")
        XCTAssertGreaterThanOrEqual(report.actionableRate, 0.90)
        XCTAssertGreaterThanOrEqual(report.lenientRate, 0.90)
        XCTAssertGreaterThanOrEqual(report.issueRecall, 0.95)
        XCTAssertLessThanOrEqual(report.issueFalse, 2)
        XCTAssertLessThanOrEqual(report.claimFalseAlarms, 2)
    }

    func testHeldOutExplanationsClearTheTargetAndFarExceedTheBaseline() {
        let v34 = DiagnosisEvaluation.evaluate(split: "holdout", DiagnosisEvaluation.v34)
        let v27 = DiagnosisEvaluation.evaluate(split: "holdout", DiagnosisEvaluation.v27)
        print("QUALITY|holdout|v34|\(v34)")
        print("QUALITY|holdout|v27|\(v27)")
        XCTAssertGreaterThanOrEqual(v34.actionableRate, 0.70, "plan target was 45%; first blind run 56%")
        XCTAssertGreaterThanOrEqual(v34.lenientRate, 0.85)
        XCTAssertGreaterThanOrEqual(v34.issueRecall, 0.75)
        XCTAssertLessThanOrEqual(v34.issueFalse, 3)
        XCTAssertGreaterThanOrEqual(v34.actionableRate - v27.actionableRate, 0.5)
        XCTAssertLessThan(v34.issueFalse, v27.issueFalse)
    }

    func testNearlyEveryConceptCardHasComparableGroundedClaims() {
        let kb = LearningCorpus.mastery
        let comparable = kb.cards.filter { DiagnosisTarget.concept($0.key, in: kb) != nil }.count
        let defined = kb.cards.filter { kb.definition(of: $0.key) != nil }.count
        print("QUALITY|cards=\(kb.cards.count)|comparable=\(comparable)|defined=\(defined)|claims=\(kb.claims.count)|edges=\(kb.edges.count)")
        XCTAssertGreaterThanOrEqual(Double(comparable) / Double(kb.cards.count), 0.90)
        XCTAssertGreaterThanOrEqual(Double(defined) / Double(kb.cards.count), 0.90)
        let analysis = LearningCorpus.analysis("Mobile Mastery")
        XCTAssertTrue(kb.claims.allSatisfy { $0.evidence.isCurrent(in: analysis) }, "every claim cites exact current source text")
    }
}
