import XCTest
@testable import ShelfCore

final class LearnerEvidenceTests: XCTestCase {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private var kb: ConceptKnowledgeBase { LearningCorpus.mastery }
    private var mapper: LearnerEvidenceMapper { LearnerEvidenceMapper(knowledge: kb) }

    private func question(about concept: String, prompt: String, correct: String, distractors: [String],
                          kind: QuestionKind = .termMatching) -> LearningQuestion {
        let definition = kb.definition(of: ConceptKey(concept))!
        let options = ([correct] + distractors).map { QuestionOption(id: StableIdentity.uuid(prompt + $0), text: $0) }
        return LearningQuestion(stableKey: "test|" + prompt, kind: kind, prompt: prompt, options: options,
                                correctOptionID: options[0].id, source: definition.evidence.learningSource, qualityScore: 0.8)
    }

    private func option(_ question: LearningQuestion, _ text: String) -> UUID { question.options.first { $0.text == text }!.id }

    func testAQuestionResolvesToTheConceptItTests() {
        let q = question(about: "Debouncing", prompt: "Which concept is described as delaying an action until a burst of events has been quiet?",
                         correct: "Debouncing", distractors: ["Throttling", "Custom hook"])
        XCTAssertEqual(mapper.concept(for: q)?.id.concept, ConceptKey("Debouncing"))
        XCTAssertEqual(LearnerEvidenceMapper.operation(for: q), .recognizeDefinition)
        let correct = mapper.evidence(answering: q, selected: q.correctOptionID, confidence: .certain, at: now)
        XCTAssertEqual(correct.map(\.outcome), [.correct])
        XCTAssertNil(correct.first?.misconception)
    }

    func testChoosingASiblingConceptIsRecordedAsConfusionWithIt() {
        let q = question(about: "Debouncing", prompt: "Which concept is described as delaying an action until a burst of events has been quiet?",
                         correct: "Debouncing", distractors: ["Throttling", "Custom hook"])
        let evidence = mapper.evidence(answering: q, selected: option(q, "Throttling"), confidence: .fairlySure, at: now)
        XCTAssertEqual(evidence.first?.outcome, .incorrect)
        XCTAssertEqual(evidence.first?.misconception?.kind, .confusion)
        XCTAssertEqual(evidence.first?.misconception?.relatedConcept, ConceptKey("Throttling"))
        let analysis = DistractorAnalysis.analyze(question: q, selected: q.options.first { $0.text == "Throttling" }!,
                                                  tested: mapper.concept(for: q), in: kb)
        XCTAssertTrue(analysis.explanation?.contains("at most once per time window") == true,
                      "the feedback shows what the chosen concept actually is, in the source's words")
    }

    func testChoosingTheReverseOfASourceClaimIsAContradictionOfThatClaim() {
        let q = question(about: "Authorization", prompt: "Which statement matches your source about authorization?",
                         correct: "Authorization still happens per action/resource.", distractors: ["Identity alone is permission.", "Sessions are stateless."],
                         kind: .sourceStatement)
        let wrong = q.options.first { $0.text == "Identity alone is permission." }!
        let analysis = DistractorAnalysis.analyze(question: q, selected: wrong, tested: mapper.concept(for: q), in: kb)
        XCTAssertEqual(analysis.kind, .contradiction)
        XCTAssertEqual(analysis.claimID, kb.claims(teaching: ConceptKey("Authorization")).first { $0.statement == "Identity alone is not permission." }?.id)
        XCTAssertTrue(analysis.explanation?.contains("Identity alone is not permission") == true)
    }

    func testAnUntraceableDistractorClaimsNothing() {
        let q = question(about: "Foreign key", prompt: "What does a foreign key protect?",
                         correct: "Referential integrity between related records", distractors: ["The colour of a sandwich", "Something vague"],
                         kind: .semanticRelationship)
        let analysis = DistractorAnalysis.analyze(question: q, selected: q.options[1], tested: mapper.concept(for: q), in: kb)
        XCTAssertEqual(analysis, .untraced)
        let evidence = mapper.evidence(answering: q, selected: q.options[1].id, confidence: nil, at: now)
        XCTAssertEqual(evidence.first?.outcome, .incorrect)
        XCTAssertNil(evidence.first?.misconception)
    }

    func testAnExplanationBecomesOneObservationPerOperationWithMisconceptionsKeptApart() {
        let target = DiagnosisTarget.concept(ConceptKey("Debouncing"), in: kb)!
        let documentID = kb.concept(ConceptKey("Debouncing"))!.documentID
        let good = UnderstandingDiagnoser().diagnose("Debouncing delays an action until a burst of events has been quiet for a chosen interval, so expensive work does not fire on every keystroke.", target: target)
        let solid = mapper.evidence(from: good, documentID: documentID, at: now)
        XCTAssertFalse(solid.isEmpty)
        XCTAssertTrue(solid.allSatisfy { $0.misconception == nil && $0.outcome == .correct && $0.channel == .explanation })
        XCTAssertEqual(Set(solid.map(\.operation)).count, solid.count, "one observation per operation")

        let confused = UnderstandingDiagnoser().diagnose("Debouncing runs an action at most once per time window while events continue.", target: target)
        let wrong = mapper.evidence(from: confused, documentID: documentID, at: now)
        XCTAssertTrue(wrong.contains { $0.misconception?.kind == .confusion && $0.misconception?.relatedConcept == ConceptKey("Throttling") })

        let nonsense = UnderstandingDiagnoser().diagnose("asdf qwer", target: target)
        XCTAssertTrue(mapper.evidence(from: nonsense, documentID: documentID, at: now).isEmpty, "no attempt is not a failed attempt")
    }

    func testOneRecallIsOneObservation() throws {
        let definition = try XCTUnwrap(kb.definition(of: ConceptKey("Debouncing")))
        let probe = try XCTUnwrap(ProbeGenerator(knowledge: kb).probes(for: ConceptKey("Debouncing"), documentID: definition.evidence.documentID)
            .first { $0.operation == .define })
        let typed = UnderstandingDiagnoser().diagnose("Debouncing waits until a burst of events has been quiet for a chosen interval before acting.",
                                                      target: try XCTUnwrap(DiagnosisTarget.probe(probe, in: kb)))
        let evidence = mapper.evidence(recall: definition.evidence.learningSource, rating: .knewIt, probe: probe, diagnosis: typed, at: now)
        XCTAssertFalse(evidence.isEmpty)
        XCTAssertFalse(evidence.contains { $0.channel == .selfRating }, "what was typed speaks for the answer; the rating does not count it again")
        XCTAssertEqual(Set(evidence.map { "\($0.concept)|\($0.operation)" }).count, evidence.count)
        let untyped = mapper.evidence(recall: definition.evidence.learningSource, rating: .knewIt, probe: probe, diagnosis: nil, at: now)
        XCTAssertEqual(untyped.map(\.channel), [.selfRating])
    }

    func testComparingTheSameAttemptAgainAddsNothing() throws {
        let target = try XCTUnwrap(DiagnosisTarget.concept(ConceptKey("Debouncing"), in: kb))
        let documentID = try XCTUnwrap(kb.concept(ConceptKey("Debouncing"))).documentID
        let first = UnderstandingDiagnoser().diagnose("Debouncing waits until events stop.", target: target)
        let edited = UnderstandingDiagnoser().diagnose("Debouncing delays an action until a burst of events has been quiet for a chosen interval, so expensive work does not fire on every keystroke.", target: target)
        var state = LearnerModelState()
        LearnerModelReducer().apply(mapper.evidence(from: first, documentID: documentID, identity: "attempt-1", at: now), to: &state)
        let once = state
        LearnerModelReducer().apply(mapper.evidence(from: edited, documentID: documentID, identity: "attempt-1", at: now.addingTimeInterval(60)), to: &state)
        XCTAssertEqual(state.concepts, once.concepts, "an attempt improved after seeing the source is not new evidence")
        LearnerModelReducer().apply(mapper.evidence(from: edited, documentID: documentID, identity: "attempt-2", at: now.addingTimeInterval(86_400)), to: &state)
        XCTAssertNotEqual(state.concepts, once.concepts, "a new attempt is")
    }

    func testSelfRatedRecallIsTheLearnersOwnReadAtHalfWeight() {
        let definition = kb.definition(of: ConceptKey("Idempotency"))!
        let evidence = mapper.evidence(recalling: definition.evidence.learningSource, rating: .difficult, at: now)
        XCTAssertEqual(evidence.map(\.concept.concept), [ConceptKey("Idempotency")])
        XCTAssertEqual(evidence.first?.channel, .selfRating)
        XCTAssertEqual(evidence.first?.outcome, .partial)
    }
}

final class LearnerRepositoryTests: XCTestCase {
    private final class MemoryStore: LearningSnapshotPersistence, @unchecked Sendable {
        var stored = LearningSnapshot()
        var failSaves = false
        func load() throws -> LearningSnapshot { stored }
        func save(_ snapshot: LearningSnapshot) throws {
            if failSaves { throw ShelfError.corruptLibrary("disk full") }
            stored = snapshot
        }
    }

    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func prepared() async throws -> (LearningRepository, MemoryStore, LearningObject, LearningEvidence) {
        let store = MemoryStore()
        let repository = LearningRepository(persistence: store)
        let analysis = LearningCorpus.analysis("React Notes")
        try await repository.upsertAnalysis(analysis, topics: [], questions: [])
        let object = try await repository.snapshot().studyObjects.first!
        let kb = LearningCorpus.knowledge["React Notes"]!
        let claim = kb.claims.first { $0.role == .core }!
        let evidence = LearningEvidence(concept: LearnerConceptID(documentID: analysis.documentID, concept: claim.topic ?? claim.concept),
                                        conceptName: claim.conceptName, operation: .recognizeDefinition, outcome: .incorrect,
                                        channel: .choice, confidence: .certain, claimIDs: [claim.id], occurredAt: now)
        return (repository, store, object, evidence)
    }

    func testAReviewAndWhatItShowsAreCommittedTogether() async throws {
        let (repository, store, object, evidence) = try await prepared()
        let before = await repository.revision
        try await repository.review(objectID: object.id, rating: .forgot, correct: false, confidence: .certain, at: now, evidence: [evidence])
        XCTAssertEqual(store.stored.attempts.count, 1)
        XCTAssertEqual(store.stored.learnerModel.mastery(evidence.concept)?.confidentErrors, 1)
        let after = await repository.revision
        XCTAssertEqual(after, before + 1)
    }

    func testAFailedSaveKeepsNeitherTheAttemptNorTheEvidence() async throws {
        let (repository, store, object, evidence) = try await prepared()
        store.failSaves = true
        do {
            try await repository.review(objectID: object.id, rating: .forgot, at: now, evidence: [evidence])
            XCTFail("the save must fail")
        } catch {}
        let snapshot = try await repository.snapshot()
        XCTAssertTrue(snapshot.attempts.isEmpty)
        XCTAssertTrue(snapshot.learnerModel.isEmpty)
    }

    func testRetriedEvidenceIsCountedOnceAndForeignDocumentsAreIgnored() async throws {
        let (repository, _, _, evidence) = try await prepared()
        try await repository.recordEvidence([evidence])
        try await repository.recordEvidence([evidence])
        let foreign = LearningEvidence(concept: LearnerConceptID(documentID: UUID(), concept: ConceptKey("ghost")), conceptName: "ghost",
                                       operation: .define, outcome: .correct, channel: .choice, occurredAt: now)
        try await repository.recordEvidence([foreign])
        let model = try await repository.snapshot().learnerModel
        XCTAssertEqual(model.mastery(evidence.concept)?.operation(.recognizeDefinition)?.attempts, 1)
        XCTAssertNil(model.mastery(foreign.concept))
    }

    func testAnOlderSnapshotCanNeverReplaceANewerOne() async throws {
        let (repository, _, object, _) = try await prepared()
        let older = try await repository.revisionedSnapshot()
        try await repository.review(objectID: object.id, rating: .knewIt, at: now)
        let newer = try await repository.revisionedSnapshot()
        var gate = SnapshotRevisionGate()
        XCTAssertTrue(gate.admit(newer.revision))
        XCTAssertFalse(gate.admit(older.revision), "a refresh that finished late must not undo the newer state")
        XCTAssertTrue(gate.admit(newer.revision), "re-reading the same revision is harmless")
    }

    func testADetourIsRememberedWithTheAnswerThatStartedItAndOnlyForKnownDocuments() async throws {
        let (repository, _, _, evidence) = try await prepared()
        let prerequisite = LearnerConceptID(documentID: evidence.concept.documentID, concept: ConceptKey("state"))
        let detour = RemediationObjective(objective: evidence.concept, prerequisite: prerequisite, startedAt: now)
        let answer = LearningEvidence(concept: prerequisite, conceptName: "state", operation: .define, outcome: .incorrect,
                                      channel: .choice, occurredAt: now.addingTimeInterval(1), startsObjective: detour)
        try await repository.recordEvidence([answer])
        let stored = try await repository.snapshot().learnerModel.objective
        XCTAssertEqual(stored?.prerequisite, prerequisite)
        XCTAssertEqual(stored?.detourAttempts, 1, "the answer that started the detour already counts toward it")
        let ghost = LearnerConceptID(documentID: UUID(), concept: ConceptKey("ghost"))
        let foreign = LearningEvidence(concept: ghost, conceptName: "ghost", operation: .define, outcome: .incorrect, channel: .choice,
                                       occurredAt: now.addingTimeInterval(2),
                                       startsObjective: RemediationObjective(objective: ghost, prerequisite: ghost, startedAt: now))
        try await repository.recordEvidence([foreign])
        let unchanged = try await repository.snapshot().learnerModel.objective
        XCTAssertEqual(unchanged?.objective, evidence.concept, "evidence about a removed document changes nothing")
    }
}
