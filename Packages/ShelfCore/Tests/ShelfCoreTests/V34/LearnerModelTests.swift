import XCTest
@testable import ShelfCore

final class LearnerModelTests: XCTestCase {
    let document = UUID(uuidString: "00000000-0000-0000-0000-00000000A001")!
    let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
    var cache: LearnerConceptID { LearnerConceptID(documentID: document, concept: ConceptKey("Cache")) }
    var index: LearnerConceptID { LearnerConceptID(documentID: document, concept: ConceptKey("Database index")) }

    func day(_ n: Double) -> Date { start.addingTimeInterval(n * 86_400) }

    func evidence(_ concept: LearnerConceptID, _ operation: ProbeOperation, _ outcome: EvidenceOutcome,
                          at date: Date, channel: EvidenceChannel = .choice, confidence: ConfidenceLevel? = nil,
                          claims: [String] = [], misconception: MisconceptionObservation? = nil, rivals: [ConceptKey] = []) -> LearningEvidence {
        LearningEvidence(concept: concept, conceptName: concept.concept.value, operation: operation, outcome: outcome,
                         channel: channel, confidence: confidence, claimIDs: claims, misconception: misconception, occurredAt: date, rivals: rivals)
    }

    func evidence(_ operation: ProbeOperation, _ outcome: EvidenceOutcome, at date: Date, channel: EvidenceChannel = .choice,
                          confidence: ConfidenceLevel? = nil, claims: [String] = [], misconception: MisconceptionObservation? = nil,
                          rivals: [ConceptKey] = []) -> LearningEvidence {
        evidence(cache, operation, outcome, at: date, channel: channel, confidence: confidence, claims: claims, misconception: misconception, rivals: rivals)
    }

    func evidence(_ outcome: EvidenceOutcome, at date: Date, channel: EvidenceChannel = .choice,
                          confidence: ConfidenceLevel? = nil, claims: [String] = [], misconception: MisconceptionObservation? = nil) -> LearningEvidence {
        evidence(cache, .define, outcome, at: date, channel: channel, confidence: confidence, claims: claims, misconception: misconception)
    }

    func model(_ items: [LearningEvidence]) -> LearnerModelState {
        var state = LearnerModelState()
        LearnerModelReducer().apply(items, to: &state)
        return state
    }

    func testOneCorrectAnswerIsNotMasteryButSpacedSuccessesAre() {
        let once = model([evidence(.correct, at: day(0))])
        XCTAssertLessThan(once.mastery(cache)!.strength(.define, at: day(0))!, 0.7, "one answer may be a lucky guess")
        XCTAssertEqual(once.mastery(cache)!.level(at: day(0)), 0)

        let spaced = model([evidence(.correct, at: day(0)), evidence(.correct, at: day(1)), evidence(.correct, at: day(3))])
        XCTAssertGreaterThanOrEqual(spaced.mastery(cache)!.strength(.define, at: day(3))!, 0.7)
        XCTAssertEqual(spaced.mastery(cache)!.level(at: day(3)), 1)
    }

    func testSpacingBuildsRetentionThatCrammingDoesNot() {
        let crammed = model((0..<3).map { evidence(.correct, at: day(0).addingTimeInterval(Double($0) * 600)) })
        let spaced = model((0..<3).map { evidence(.correct, at: day(Double($0) * 2)) })
        let crammedLater = crammed.mastery(cache)!.operation(.define)!.retention(at: day(10))
        let spacedLater = spaced.mastery(cache)!.operation(.define)!.retention(at: day(14))
        XCTAssertGreaterThan(spacedLater, crammedLater, "ten days after the last success, spaced practice is retained better")
        let fresh = spaced.mastery(cache)!.strength(.define, at: day(4))!
        XCTAssertLessThan(spaced.mastery(cache)!.strength(.define, at: day(30))!, fresh, "strength fades without practice")
    }

    func testOldEvidenceCountsLessThanNewEvidence() {
        let recovered = model([evidence(.incorrect, at: day(0)), evidence(.incorrect, at: day(1)),
                               evidence(.correct, at: day(200)), evidence(.correct, at: day(201))])
        let recent = model([evidence(.correct, at: day(0)), evidence(.correct, at: day(1)),
                            evidence(.incorrect, at: day(200)), evidence(.incorrect, at: day(201))])
        XCTAssertGreaterThan(recovered.mastery(cache)!.operation(.define)!.estimate, 0.6)
        XCTAssertLessThan(recent.mastery(cache)!.operation(.define)!.estimate, 0.4)
    }

    func testFailingBasicsCapTheLevelEvenWhenHarderQuestionsSucceed() {
        let state = model([evidence(.contrast, .correct, at: day(0)), evidence(.contrast, .correct, at: day(1)),
                           evidence(.define, .incorrect, at: day(1)), evidence(.define, .incorrect, at: day(2))])
        XCTAssertEqual(state.mastery(cache)!.level(at: day(2)), 0)
    }

    func testMisconceptionNeedsCorrectAnswersOnTwoDistinctDaysToRetire() {
        let wrong = MisconceptionObservation(kind: .contradiction, claimID: "claim-stale", relatedConcept: nil,
                                             learnerWording: "Caches never become stale.")
        var state = model([evidence(.incorrect, at: day(0), channel: .explanation, claims: ["claim-stale"], misconception: wrong)])
        let record = state.misconceptions.first!
        XCTAssertEqual(record.status, .active)
        XCTAssertEqual(record.learnerWording, "Caches never become stale.")
        XCTAssertEqual(state.strongestMisconception(for: cache, at: day(0))?.id, record.id)

        let reducer = LearnerModelReducer()
        reducer.apply(evidence(.misconceptionCheck, .correct, at: day(0).addingTimeInterval(3600), claims: ["claim-stale"]), to: &state)
        reducer.apply(evidence(.misconceptionCheck, .correct, at: day(0).addingTimeInterval(7200), claims: ["claim-stale"]), to: &state)
        XCTAssertEqual(state.misconceptions.first!.status, .resolving, "two answers in one sitting count once")
        reducer.apply(evidence(.purpose, .correct, at: day(2), claims: ["claim-stale"]), to: &state)
        XCTAssertEqual(state.misconceptions.first!.status, .resolved)
        XCTAssertEqual(state.misconceptions.first!.salience(at: day(2)), 0)

        reducer.apply(evidence(.incorrect, at: day(9), channel: .explanation, claims: ["claim-stale"], misconception: wrong), to: &state)
        XCTAssertEqual(state.misconceptions.count, 1, "a relapse reopens the same record")
        XCTAssertEqual(state.misconceptions.first!.status, .active)
        XCTAssertEqual(state.misconceptions.first!.occurrences, 2)
    }

    func testUnrelatedCorrectAnswersDoNotRetireAMisconception() {
        let wrong = MisconceptionObservation(kind: .contradiction, claimID: "claim-stale", relatedConcept: nil, learnerWording: "never stale")
        let state = model([evidence(.incorrect, at: day(0), claims: ["claim-stale"], misconception: wrong),
                           evidence(.define, .correct, at: day(1), claims: ["claim-definition"]),
                           evidence(.define, .correct, at: day(3), claims: ["claim-definition"])])
        XCTAssertEqual(state.misconceptions.first!.status, .active)
    }

    func testConfusionRetiresOnlyThroughDiscrimination() {
        let confused = MisconceptionObservation(kind: .confusion, claimID: nil, relatedConcept: ConceptKey("Throttling"),
                                                learnerWording: "Debouncing runs at most once per interval")
        var state = model([evidence(.incorrect, at: day(0), misconception: confused),
                           evidence(.mechanism, .correct, at: day(1)), evidence(.mechanism, .correct, at: day(2))])
        XCTAssertEqual(state.misconceptions.first!.status, .active, "explaining the concept alone does not show the two are told apart")
        LearnerModelReducer().apply([evidence(.contrast, .correct, at: day(3), rivals: [ConceptKey("Database index")]),
                                     evidence(.recognizeDefinition, .correct, at: day(4), rivals: [ConceptKey("Cache stampede")])], to: &state)
        XCTAssertEqual(state.misconceptions.first!.status, .active, "telling it apart from other concepts says nothing about throttling")
        LearnerModelReducer().apply([evidence(.contrast, .correct, at: day(5), rivals: [ConceptKey("Throttling")]),
                                     evidence(.recognizeDefinition, .correct, at: day(7), rivals: [ConceptKey("Throttling"), ConceptKey("Polling")])], to: &state)
        XCTAssertEqual(state.misconceptions.first!.status, .resolved)
    }

    func testOnlyCheckedAnswersAboutTheSameIdeaRetireAMisconception() {
        let wrong = MisconceptionObservation(kind: .contradiction, claimID: "claim-a", relatedConcept: nil, learnerWording: "It never expires")
        let rated = model([evidence(.incorrect, at: day(0), claims: ["claim-a"], misconception: wrong),
                           evidence(.misconceptionCheck, .correct, at: day(1), channel: .selfRating, claims: ["claim-a"]),
                           evidence(.misconceptionCheck, .correct, at: day(3), channel: .selfRating, claims: ["claim-a"])])
        XCTAssertEqual(rated.misconceptions.first!.status, .active, "“Knew it” is the learner's own read, not a correction")
        let elsewhere = model([evidence(.incorrect, at: day(0), claims: ["claim-a"], misconception: wrong),
                               evidence(.misconceptionCheck, .correct, at: day(1), claims: ["claim-b"]),
                               evidence(.misconceptionCheck, .correct, at: day(3), claims: ["claim-b"])])
        XCTAssertEqual(elsewhere.misconceptions.first!.status, .active, "correcting another idea does not correct this one")
        let checked = model([evidence(.incorrect, at: day(0), claims: ["claim-a"], misconception: wrong),
                             evidence(.misconceptionCheck, .correct, at: day(1), channel: .explanation, claims: ["claim-a"]),
                             evidence(.misconceptionCheck, .correct, at: day(3), claims: ["claim-a"])])
        XCTAssertEqual(checked.misconceptions.first!.status, .resolved)
    }

    func testMisconceptionSalienceFadesWithTimeButNeverRetiresByItself() {
        let wrong = MisconceptionObservation(kind: .overgeneralization, claimID: "c1", relatedConcept: nil, learnerWording: "always")
        let state = model([evidence(.partial, at: day(0), misconception: wrong)])
        let record = state.misconceptions.first!
        XCTAssertEqual(record.salience(at: day(21)), record.salience(at: day(0)) / 2, accuracy: 0.001)
        XCTAssertEqual(record.status, .active)
        let recurring = model([evidence(.partial, at: day(0), misconception: wrong), evidence(.partial, at: day(1), misconception: wrong)])
        XCTAssertGreaterThan(recurring.misconceptions.first!.salience(at: day(1)), record.salience(at: day(0)))
    }

    func testConfidentErrorsRaisePriorityAboveHesitantOnes() {
        let confident = model([evidence(.incorrect, at: day(0), confidence: .certain)])
        let hesitant = model([evidence(.incorrect, at: day(0), confidence: .guessing)])
        let priority = RetrievalPriority()
        XCTAssertGreaterThan(priority.score(for: cache, in: confident, at: day(1)), priority.score(for: cache, in: hesitant, at: day(1)))
        XCTAssertEqual(priority.score(for: index, in: confident, at: day(1)), 0, "no evidence, no opinion")
    }

    func testFailureRaisesRetrievalPriorityAndSpacedSuccessLowersIt() {
        let priority = RetrievalPriority()
        let failed = model([evidence(.incorrect, at: day(0)), evidence(.incorrect, at: day(1))])
        let learned = model([evidence(.correct, at: day(0)), evidence(.correct, at: day(1)), evidence(.correct, at: day(3))])
        XCTAssertGreaterThan(priority.score(for: cache, in: failed, at: day(3.5)), priority.score(for: cache, in: learned, at: day(3.5)),
                             "a concept just failed needs practice more than one just recalled well")
        XCTAssertGreaterThan(priority.score(for: cache, in: learned, at: day(60)), priority.score(for: cache, in: learned, at: day(3.5)),
                             "and a well-recalled concept comes back as it fades")
    }

    func testMisconceptionOutranksPlainWeakness() {
        let wrong = MisconceptionObservation(kind: .contradiction, claimID: "c", relatedConcept: nil, learnerWording: "x")
        let state = model([evidence(cache, .define, .incorrect, at: day(0), misconception: wrong),
                           evidence(index, .define, .incorrect, at: day(0))])
        let priority = RetrievalPriority()
        XCTAssertGreaterThan(priority.score(for: cache, in: state, at: day(1)), priority.score(for: index, in: state, at: day(1)))
    }

    func testCalibrationDetectsOverconfidenceFromChoiceAnswersOnly() {
        var overconfident = (0..<6).map { evidence(.incorrect, at: day(Double($0)), confidence: .certain) }
        overconfident += (0..<6).map { evidence(.incorrect, at: day(Double($0) + 0.5), channel: .explanation, confidence: .guessing) }
        let state = model(overconfident)
        XCTAssertEqual(state.calibration.answered, 6, "explanations are not objectively scored")
        XCTAssertTrue(state.calibration.isOverconfident)

        let calibrated = model((0..<8).map { evidence($0 % 2 == 0 ? .correct : .incorrect, at: day(Double($0)), confidence: .unsure) })
        XCTAssertFalse(calibrated.calibration.isOverconfident)
    }

    func testTheSameEvidenceNeverCountsTwice() {
        let item = evidence(.incorrect, at: day(0), confidence: .certain)
        var state = LearnerModelState()
        XCTAssertTrue(LearnerModelReducer().apply(item, to: &state))
        let once = state
        XCTAssertFalse(LearnerModelReducer().apply(item, to: &state))
        XCTAssertEqual(state, once)
    }

    func testRemediationDetourReturnsToItsObjective() {
        var state = LearnerModelState(objective: RemediationObjective(objective: cache, prerequisite: index, startedAt: day(0)))
        let reducer = LearnerModelReducer()
        reducer.apply(evidence(cache, .define, .incorrect, at: day(0.1)), to: &state)
        XCTAssertNotNil(state.objective, "evidence on the objective itself does not end the detour")
        reducer.apply(evidence(index, .define, .incorrect, at: day(0.2)), to: &state)
        XCTAssertEqual(state.objective?.detourAttempts, 1)
        reducer.apply(evidence(index, .define, .correct, at: day(0.3)), to: &state)
        XCTAssertNil(state.objective, "the prerequisite is repaired: back to the objective")

        var stuck = LearnerModelState(objective: RemediationObjective(objective: cache, prerequisite: index, startedAt: day(0)))
        reducer.apply((1...3).map { evidence(index, .define, .incorrect, at: day(Double($0) * 0.1)) }, to: &stuck)
        XCTAssertNil(stuck.objective, "three failed detour attempts return to the objective anyway")

        var stale = LearnerModelState(objective: RemediationObjective(objective: cache, prerequisite: index, startedAt: day(0)))
        reducer.apply(evidence(cache, .define, .correct, at: day(8)), to: &stale)
        XCTAssertNil(stale.objective)
    }

    func testCollectionsStayBounded() {
        var state = LearnerModelState()
        let reducer = LearnerModelReducer()
        for n in 0..<360 {
            let wrong = MisconceptionObservation(kind: .contradiction, claimID: "claim-\(n)", relatedConcept: nil, learnerWording: "w")
            reducer.apply(evidence(.incorrect, at: day(Double(n) * 0.01), claims: ["claim-\(n)"], misconception: wrong), to: &state)
        }
        XCTAssertEqual(state.misconceptions.count, LearnerModelState.misconceptionLimit)
        XCTAssertTrue(state.misconceptions.contains { $0.claimID == "claim-359" }, "the newest record is kept")
        XCTAssertLessThanOrEqual(state.appliedEvidenceIDs.count, LearnerModelState.evidenceIDLimit)
    }

    func testOldEvidenceNeverCountsAgainAfterItLeavesTheIDRecord() {
        let reducer = LearnerModelReducer()
        let old = evidence(.correct, at: day(0))
        var state = model([old])
        for n in 1...450 { reducer.apply(evidence(index, .define, .incorrect, at: day(1).addingTimeInterval(Double(n))), to: &state) }
        XCTAssertFalse(state.appliedEvidenceIDs.contains(old.id), "the id record stays bounded")
        XCTAssertLessThanOrEqual(state.appliedEvidence.count, LearnerModelState.evidenceIDLimit)
        let before = state
        XCTAssertFalse(reducer.apply(old, to: &state), "replayed after 450 later answers, the old answer is not counted again")
        XCTAssertEqual(state, before)
        XCTAssertTrue(reducer.apply(evidence(.correct, at: day(2)), to: &state), "a new answer still counts")
        let reloaded = try? JSONDecoder().decode(LearnerModelState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(reloaded, state, "the guarantee survives a save")
    }

    func testTheModelRoundTripsThroughJSON() throws {
        let wrong = MisconceptionObservation(kind: .confusion, claimID: nil, relatedConcept: ConceptKey("TTL"), learnerWording: "w")
        var state = model([evidence(.correct, at: day(0), confidence: .certain), evidence(.contrast, .incorrect, at: day(1), misconception: wrong)])
        state.objective = RemediationObjective(objective: cache, prerequisite: index, startedAt: day(1))
        let decoded = try JSONDecoder().decode(LearnerModelState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(decoded, state)
    }
}
