import XCTest
@testable import ShelfCore

/// Teach It Back as learner evidence, end to end: what an explanation teaches the learner model,
/// what it leaves for the study session to follow up, and how the model moves as answers arrive.
final class TeachItBackLoopTests: XCTestCase {
    private var analysis: DocumentAnalysis { LearningCorpus.analysis("Mobile Mastery") }
    private var kb: ConceptKnowledgeBase { LearningCorpus.mastery }
    private var analyses: [UUID: DocumentAnalysis] { [analysis.documentID: analysis] }
    private static let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private func day(_ n: Double) -> Date { Self.start.addingTimeInterval(n * 86_400 + 3_600) }
    private func concept(_ name: String) -> LearnerConceptID { LearnerConceptID(documentID: analysis.documentID, concept: ConceptKey(name)) }

    private func cardSource(_ name: String) throws -> IntelligenceSource {
        let definition = try XCTUnwrap(kb.definition(of: ConceptKey(name)))
        let page = try XCTUnwrap(analysis.pages.first { $0.pageIndex == definition.evidence.pageIndex })
        let paragraph = try XCTUnwrap(page.segments.first { CanonicalWhitespaceResolver.normalize($0.text).contains(CanonicalWhitespaceResolver.normalize(definition.evidence.text)) })
        return try XCTUnwrap(IntelligenceSource(source: LearningSource(documentID: analysis.documentID, pageIndex: page.pageIndex,
                                                                        sourceText: paragraph.text), analysis: analysis))
    }

    /// One comparison as the reader runs it: the result is kept with the attempt, and whatever
    /// evidence the judgement lets through is committed with it — possibly none.
    private func teach(_ text: String, _ name: String, into model: inout LearnerModelState, at date: Date) throws -> UnderstandingAttempt {
        let source = try cardSource(name)
        let assessed = try XCTUnwrap(TeachBack.assessment(text, source: source, knowledge: kb, model: model, at: date))
        var attempt = UnderstandingAttempt(source: source, learnerExplanation: text, createdAt: date)
        attempt.result = assessed.result
        let evidence = LearnerEvidenceMapper(knowledge: kb).evidence(from: assessed.assessment, documentID: analysis.documentID,
                                                                     identity: attempt.id.uuidString, at: date)
        if !evidence.isEmpty { LearnerModelReducer().apply(evidence, to: &model); attempt.evidenceRecordedAt = date }
        return attempt
    }

    func testAnUndecidedExplanationTeachesNothingAndIsFollowedUpWithItsOwnQuestion() throws {
        var model = LearnerModelState()
        let attempt = try teach("An idempotent operation is one you may only perform a single time.", "Idempotency", into: &model, at: day(0))
        XCTAssertNil(attempt.evidenceRecordedAt)
        XCTAssertTrue(model.isEmpty, "a reading that could be a misconception is not recorded as partial understanding")
        let asked = try XCTUnwrap(attempt.result?.diagnosis?.intervention.followUp)

        let pending = TeachBackFollowThrough.pending(attempts: [attempt], model: model, analyses: analyses, now: day(1))
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending.first?.kind, .discriminate)
        XCTAssertEqual(pending.first?.concept, concept("Idempotency"))
        XCTAssertTrue(TeachBackFollowThrough.pending(attempts: [attempt], model: model, analyses: [:], now: day(1)).isEmpty,
                      "a question worded from a page that is no longer current is never asked")
        let decision = try XCTUnwrap(AdaptiveProbeSelector(knowledge: kb).next(for: concept("Idempotency"), state: model, preferring: .open,
                                                                              now: day(1), verification: pending.first))
        XCTAssertEqual(decision.reason, .verification)
        XCTAssertEqual(decision.probe.prompt, asked.prompt, "the session asks the question the comparison ended with")
        XCTAssertEqual(decision.probe.rubricClaimIDs, asked.rubricClaimIDs)
        XCTAssertNil(ProbeValidator.failure(decision.probe, in: kb, analysis: analysis))

        // Once the learner has answered about the concept, nothing is pending any more.
        LearnerModelReducer().apply(LearningEvidence(concept: concept("Idempotency"), conceptName: "Idempotency", operation: decision.probe.operation,
                                                     outcome: .correct, channel: .explanation, claimIDs: decision.probe.rubricClaimIDs,
                                                     probeID: decision.probe.id, occurredAt: day(2)), to: &model)
        XCTAssertTrue(TeachBackFollowThrough.pending(attempts: [attempt], model: model, analyses: analyses, now: day(2)).isEmpty)
    }

    func testAnUnderstoodExplanationIsCheckedForTransferBeforeTheConceptCountsAsMastered() throws {
        var model = LearnerModelState()
        let attempt = try teach("Throttling runs the handler at most once per time window, not on every event.", "Throttling", into: &model, at: day(0))
        XCTAssertNotNil(attempt.evidenceRecordedAt)
        let pending = TeachBackFollowThrough.pending(attempts: [attempt], model: model, analyses: analyses, now: day(1))
        XCTAssertEqual(pending.map(\.kind), [.transfer])
        let decision = try XCTUnwrap(AdaptiveProbeSelector(knowledge: kb).next(for: concept("Throttling"), state: model, now: day(1),
                                                                              verification: pending.first))
        XCTAssertEqual(decision.reason, .verification)
        XCTAssertGreaterThanOrEqual(decision.probe.level, 3, "a contrast or an example, not the definition again")
        // Answered since: checked. The check is one question, not a promotion that lasts.
        var answered = model
        LearnerModelReducer().apply(LearningEvidence(concept: concept("Throttling"), conceptName: "Throttling", operation: decision.probe.operation,
                                                     outcome: .correct, channel: .choice, claimIDs: decision.probe.rubricClaimIDs,
                                                     probeID: decision.probe.id, occurredAt: day(2)), to: &answered)
        XCTAssertTrue(TeachBackFollowThrough.pending(attempts: [attempt], model: answered, analyses: analyses, now: day(2)).isEmpty)
        XCTAssertNotEqual(LearnerConceptState.of(concept("Throttling"), in: answered, at: day(2)), .mastered, "one right answer is not mastery")
        // Where no contrast or example question exists, whatever is asked next settles it too.
        LearnerModelReducer().apply(LearningEvidence(concept: concept("Throttling"), conceptName: "Throttling", operation: .define,
                                                     outcome: .correct, channel: .choice, occurredAt: day(2)), to: &model)
        XCTAssertTrue(TeachBackFollowThrough.pending(attempts: [attempt], model: model, analyses: analyses, now: day(3)).isEmpty)
    }

    func testAMisconceptionIsRetiredOnlyByClearCorrectionsOnTwoDaysAndAnAmbiguousAnswerChangesNothing() throws {
        var model = LearnerModelState()
        let retry = concept("Retry")
        _ = try teach("You should always retry every failed call, whatever went wrong.", "Retry", into: &model, at: day(0))
        XCTAssertEqual(LearnerConceptState.of(retry, in: model, at: day(0)), .misconception)

        let correction = "You try a failed request again when the problem might only be temporary, like a network blip."
        _ = try teach(correction, "Retry", into: &model, at: day(1))
        XCTAssertEqual(model.misconceptions(for: retry).first?.status, .resolving)
        XCTAssertEqual(LearnerConceptState.of(retry, in: model, at: day(1)), .fragile)

        // Too vague to compare with the source: it teaches the model nothing, and cannot advance the retirement.
        let before = model
        let ambiguous = try teach("Retrying is something clients do.", "Retry", into: &model, at: day(2))
        XCTAssertNil(ambiguous.evidenceRecordedAt)
        XCTAssertEqual(model, before)

        _ = try teach(correction, "Retry", into: &model, at: day(3))
        XCTAssertEqual(model.misconceptions(for: retry, includeResolved: true).first?.status, .resolved)
        XCTAssertNotEqual(LearnerConceptState.of(retry, in: model, at: day(3)), .misconception)
    }

    func testNewContradictingEvidenceOutweighsEarlierUnderstanding() throws {
        var model = LearnerModelState()
        let retry = concept("Retry")
        _ = try teach("You try a failed request again when the problem might only be temporary, like a network blip.", "Retry", into: &model, at: day(0))
        XCTAssertNotEqual(LearnerConceptState.of(retry, in: model, at: day(0)), .misconception)
        _ = try teach("You should always retry every failed call, whatever went wrong.", "Retry", into: &model, at: day(1))
        XCTAssertEqual(LearnerConceptState.of(retry, in: model, at: day(1)), .misconception)
    }

    private final class MemoryStore: LearningSnapshotPersistence, @unchecked Sendable {
        var stored = LearningSnapshot()
        func load() throws -> LearningSnapshot { stored }
        func save(_ snapshot: LearningSnapshot) throws { stored = snapshot }
    }
    private final class Flag: @unchecked Sendable { var value = false }

    func testTheNextStudySessionAsksThePendingQuestionFirst() throws {
        let store = MemoryStore(), done = Flag()
        let repository = LearningRepository(persistence: store), manual = analysis
        Task { try await repository.upsertAnalysis(manual, topics: [], questions: []); done.value = true }
        while !done.value { RunLoop.current.run(until: Date().addingTimeInterval(0.01)) }
        var snapshot = store.stored
        var model = snapshot.learnerModel
        // A concept the manual's study plan covers, explained by a learner who says they are unsure.
        let attempt = try teach("I think rate limiting maybe restricts how frequently a client may perform an operation?", "Rate limiting",
                                into: &model, at: day(0))
        XCTAssertNil(attempt.evidenceRecordedAt)
        let asked = try XCTUnwrap(attempt.result?.diagnosis?.intervention.followUp)
        let planner = ShelfStudySessionPlanner()
        let without = planner.plan(snapshot: snapshot, knowledge: kb, topicID: nil, minutes: 10, mode: .learn, now: day(1))
        XCTAssertFalse(without.activities.contains { $0.probe?.prompt == asked.prompt })
        snapshot.understandingAttempts.append(attempt)
        let with = planner.plan(snapshot: snapshot, knowledge: kb, topicID: nil, minutes: 10, mode: .learn, now: day(1))
        let position = try XCTUnwrap(with.activities.firstIndex { $0.probe?.prompt == asked.prompt }, "the pending question is planned")
        XCTAssertLessThan(position, 2, "and it comes first")
        XCTAssertEqual(with.activities[position].kind, .recall, "answered in the learner's own words")
    }

    /// Nothing new is stored: an attempt whose comparison ended with a discriminating question is
    /// the V34 shape, passes the V34 admission check, and survives the store round trip.
    func testADeferredAttemptIsStoredAndReadmittedWithTheV34Shape() throws {
        let store = MemoryStore(), stored = Flag()
        let repository = LearningRepository(persistence: store), manual = analysis
        var model = LearnerModelState()
        let attempt = try teach("An idempotent operation is one you may only perform a single time.", "Idempotency", into: &model, at: day(0))
        Task {
            try await repository.upsertAnalysis(manual, topics: [], questions: [])
            try await repository.recordEvidence([], for: attempt)
            stored.value = true
        }
        while !stored.value { RunLoop.current.run(until: Date().addingTimeInterval(0.01)) }
        let saved = try XCTUnwrap(store.stored.understandingAttempts.first { $0.id == attempt.id })
        XCTAssertNil(saved.evidenceRecordedAt, "nothing was counted, so a later answer still can be")
        XCTAssertEqual(saved.result, attempt.result)
        let result = try XCTUnwrap(saved.result)
        XCTAssertTrue(TeachLeuValidator.isValid(result, explanation: saved.learnerExplanation, analyses: store.stored.analyses))
        let encoded = try JSONEncoder().encode(store.stored)
        let decoded = try JSONDecoder().decode(LearningSnapshot.self, from: encoded)
        XCTAssertEqual(decoded.understandingAttempts.first { $0.id == attempt.id }?.result, result)
    }

    func testExplanationsThatMeanTheSameThingDoNotMakeTheStateFlip() throws {
        var model = LearnerModelState()
        let throttling = concept("Throttling")
        let paraphrases = ["Throttling runs the handler at most once per time window, not on every event.",
                           "Throttling makes sure the handler runs at most once per time window while the events keep coming.",
                           "With throttling, however fast events arrive, the action runs at most once in each time window."]
        var states: [LearnerConceptState] = []
        for (n, text) in paraphrases.enumerated() {
            _ = try teach(text, "Throttling", into: &model, at: day(Double(n)))
            states.append(LearnerConceptState.of(throttling, in: model, at: day(Double(n))))
        }
        XCTAssertFalse(states.contains(.misconception))
        XCTAssertEqual(states[1], states[2], "once there is enough evidence, a paraphrase leaves the reading where it was")
        XCTAssertEqual(model.mastery(throttling)?.operations.map(\.estimate).max().map { $0 > 0.7 }, true)
    }
}
