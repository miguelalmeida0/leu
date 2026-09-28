import XCTest
@testable import ShelfCore

/// The per-concept state is read from the persisted evidence and the date, never stored.
final class LearnerConceptStateTests: XCTestCase {
    let concept = LearnerConceptID(documentID: UUID(uuidString: "00000000-0000-0000-0000-00000000B001")!, concept: ConceptKey("Idempotency"))
    let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
    func day(_ n: Double) -> Date { start.addingTimeInterval(n * 86_400) }

    func evidence(_ operation: ProbeOperation, _ outcome: EvidenceOutcome, day n: Double, channel: EvidenceChannel = .explanation,
                  claims: [String] = ["c1"], misconception: MisconceptionObservation? = nil) -> LearningEvidence {
        LearningEvidence(concept: concept, conceptName: "Idempotency", operation: operation, outcome: outcome, channel: channel,
                         claimIDs: claims, misconception: misconception, occurredAt: day(n))
    }

    func state(_ items: [LearningEvidence], at n: Double) -> LearnerConceptState {
        var model = LearnerModelState()
        LearnerModelReducer().apply(items, to: &model)
        return LearnerConceptState.of(concept, in: model, at: day(n))
    }

    func testNothingKnownIsUnknownAndOneAnswerIsNotEnough() {
        XCTAssertEqual(state([], at: 0), .unknown)
        XCTAssertEqual(state([evidence(.mechanism, .correct, day: 0)], at: 0), .insufficientEvidence, "one good explanation may be luck")
        XCTAssertEqual(state([evidence(.mechanism, .correct, day: 0, channel: .selfRating), evidence(.mechanism, .correct, day: 1, channel: .selfRating)], at: 1),
                       .insufficientEvidence, "two self-ratings weigh as one answer")
    }

    func testReliableExplanationsAreMostlyUnderstoodUntilConnectedOrTransferred() {
        let explained = [evidence(.mechanism, .correct, day: 0), evidence(.mechanism, .correct, day: 1)]
        XCTAssertEqual(state(explained, at: 1), .mostlyUnderstood)
        let transferred = explained + [evidence(.contrast, .correct, day: 2), evidence(.contrast, .correct, day: 3)]
        XCTAssertEqual(state(transferred, at: 3), .mastered)
    }

    func testMasteryFadesWithForgettingWithoutAnyStoredLabelChanging() {
        let transferred = [evidence(.mechanism, .correct, day: 0), evidence(.mechanism, .correct, day: 1),
                           evidence(.contrast, .correct, day: 2), evidence(.contrast, .correct, day: 3)]
        XCTAssertEqual(state(transferred, at: 3), .mastered)
        XCTAssertNotEqual(state(transferred, at: 60), .mastered, "two months without practice: no longer shown")
    }

    func testLiveMisconceptionWinsAndResolvingIsFragile() {
        let wrong = MisconceptionObservation(kind: .contradiction, claimID: "c1", relatedConcept: nil, learnerWording: "only once")
        let mistaken = [evidence(.mechanism, .correct, day: 0), evidence(.mechanism, .correct, day: 1),
                        evidence(.define, .incorrect, day: 2, misconception: wrong)]
        XCTAssertEqual(state(mistaken, at: 2), .misconception)
        let corrected = mistaken + [evidence(.define, .correct, day: 3)]
        XCTAssertEqual(state(corrected, at: 3), .fragile, "one correction on one day leaves it resolving")
        XCTAssertEqual(state(corrected + [evidence(.define, .correct, day: 4)], at: 4), .mostlyUnderstood, "resolved after two days")
    }

    func testRightAnswersWithoutWorkingExplanationsAreWeakReasoning() {
        let items = [evidence(.recognizeDefinition, .correct, day: 0, channel: .choice), evidence(.recognizeDefinition, .correct, day: 1, channel: .choice),
                     evidence(.mechanism, .incorrect, day: 1), evidence(.mechanism, .partial, day: 2)]
        XCTAssertEqual(state(items, at: 2), .weakReasoning)
    }
}
