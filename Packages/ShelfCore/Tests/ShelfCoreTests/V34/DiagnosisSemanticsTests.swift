import XCTest
@testable import ShelfCore

/// The polarity, scope and evidence rules behind diagnosis, stated as behaviour.
final class DiagnosisSemanticsTests: XCTestCase {
    private func compare(_ claim: String, _ learner: String) -> [PropositionComparison] {
        Proposition.split(claim).flatMap { c in Proposition.split(learner).compactMap { PropositionComparison(claim: c, learner: $0) } }
    }

    func testEveryAssertionInASentenceKeepsItsOwnPolarity() {
        let parts = Proposition.split("CORS is not authentication and it does not stop non-browser clients.")
        XCTAssertEqual(parts.count, 2)
        XCTAssertTrue(parts.allSatisfy(\.negative), "two negations never cancel into agreement")
        let joined = Proposition.split("Using a cache means you never repeat work and nothing can go wrong.")
        XCTAssertEqual(joined.count, 2)
        XCTAssertTrue(joined.allSatisfy(\.negative))
    }

    func testNegativeVerbsAndContrastsCarryNegation() {
        XCTAssertTrue(Proposition.split("A transaction prevents partial updates.")[0].negative)
        let contrast = Proposition.split("JWTs are signed claim containers, not automatically encrypted.")
        XCTAssertEqual(contrast.map(\.negative), [false, true])
        let leading = Proposition.split("Without invalidation, fast responses can be confidently wrong.")
        XCTAssertEqual(leading.map(\.negative), [true, false], "“without X” governs X, not the whole sentence")
    }

    func testOppositeClaimsAboutTheSameContentContradict() {
        XCTAssertTrue(compare("Setting state does not change the state variable inside the running event handler.",
                              "Calling setState immediately changes the variable in the running handler.").contains(where: \.contradicts),
                      "identifiers keep their parts: setState is set + state")
        XCTAssertTrue(compare("A transaction prevents partial updates.", "A transaction allows partial updates.").contains(where: \.contradicts))
        XCTAssertTrue(compare("Encryption is a reversible transformation.", "Encryption is a one-way transformation.").contains(where: \.contradicts),
                      "opposite-meaning words contradict without any negation")
    }

    func testNegatedDetailsTheLearnerNeverMentionedAreNotContradicted() {
        XCTAssertFalse(compare("Debouncing avoids firing expensive work for every keystroke.",
                               "Debouncing waits until events stop, then runs the action.").contains(where: \.contradicts),
                       "“not for every keystroke” is only contradicted by “for every keystroke”")
        XCTAssertFalse(compare("A Promise lets asynchronous operations be composed without deep nesting of callbacks.",
                               "A promise represents the eventual result of an async operation.").contains(where: \.contradicts))
    }

    func testExpressingANegativeVerbByNegationIsAgreement() {
        let kb = LearningCorpus.mastery
        let target = DiagnosisTarget.concept(ConceptKey("Debouncing"), in: kb)!
        let diagnosis = UnderstandingDiagnoser().diagnose("Debouncing waits until a burst of events has been quiet for a chosen interval, so expensive work does not fire on every keystroke.", target: target)
        XCTAssertFalse(diagnosis.hasMisconception)
        let purpose = kb.claims(teaching: ConceptKey("Debouncing")).first { $0.statement.contains("avoids firing") }!
        XCTAssertEqual(diagnosis.assessment(purpose.id)?.coverage, .covered, "“does not fire” says “avoids firing”")
    }

    func testAConfusionNeedsSubstantiveEvidenceAndCircularityNeedsTheHeadWord() {
        let kb = LearningCorpus.mastery
        let deadlock = UnderstandingDiagnoser().diagnose("A deadlock is when a transaction is slow.", target: DiagnosisTarget.concept(ConceptKey("Deadlock"), in: kb)!)
        XCTAssertFalse(deadlock.has(.confusedConcept), "two shared words do not name what was confused")
        let invalidation = UnderstandingDiagnoser().diagnose("Cache invalidation is when the cache stops working.",
                                                             target: DiagnosisTarget.concept(ConceptKey("Cache invalidation"), in: kb)!)
        XCTAssertFalse(invalidation.has(.circular), "explaining with a different concept (cache) is not circular")
        XCTAssertTrue(invalidation.has(.unsupported))
        let throttling = UnderstandingDiagnoser().diagnose("Debouncing runs an action at most once per time window while events continue.",
                                                           target: DiagnosisTarget.concept(ConceptKey("Debouncing"), in: kb)!)
        XCTAssertTrue(throttling.issues.contains { $0.kind == .confusedConcept && $0.relatedConcept == ConceptKey("Throttling") })
    }
    func testADeeperQuestionContrastsOnlyWithAConceptWorthTellingApart() throws {
        let kb = LearningCorpus.mastery
        for (name, partner) in [("Authentication", "authorization"), ("Hashing", "encryption"), ("useMemo", "usecallback")] {
            let target = try XCTUnwrap(DiagnosisTarget.concept(ConceptKey(name), in: kb))
            let followUp = FollowUps.deeper(target, after: UnderstandingDiagnoser().diagnose("x y z", target: target))
            XCTAssertEqual(followUp?.operation, .contrast)
            XCTAssertTrue(followUp?.prompt.lowercased().contains(partner) == true, followUp?.prompt ?? "")
        }
        for name in ["Foreign key", "Cache", "Transaction", "SSR"] {
            let target = try XCTUnwrap(DiagnosisTarget.concept(ConceptKey(name), in: kb))
            let followUp = FollowUps.deeper(target, after: UnderstandingDiagnoser().diagnose("x y z", target: target))
            XCTAssertNotEqual(followUp?.operation, .contrast, "\(name): a prerequisite or mere neighbour is not a concept to contrast with")
        }
    }
}
