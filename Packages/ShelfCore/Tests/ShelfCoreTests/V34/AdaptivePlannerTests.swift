import XCTest
@testable import ShelfCore

final class AdaptivePlannerTests: XCTestCase {
    private final class MemoryStore: LearningSnapshotPersistence, @unchecked Sendable {
        var stored = LearningSnapshot()
        func load() throws -> LearningSnapshot { stored }
        func save(_ snapshot: LearningSnapshot) throws { stored = snapshot }
    }

    private static let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private static let manualSnapshot: LearningSnapshot = {
        let store = MemoryStore()
        let repository = LearningRepository(persistence: store)
        let analysis = LearningCorpus.analysis("Mobile Mastery")
        let done = expectationBox()
        Task { try await repository.upsertAnalysis(analysis, topics: [], questions: []); done.value = true }
        while !done.value { RunLoop.current.run(until: Date().addingTimeInterval(0.01)) }
        return store.stored
    }()

    private final class expectationBox: @unchecked Sendable { var value = false }

    private func shape(_ session: StudySession) -> [String] {
        session.activities.map { "\($0.kind.rawValue)|\($0.learningObjectID?.uuidString ?? "-")|\($0.questionID?.uuidString ?? "-")" }
    }

    func testWithoutKnowledgeThePlanIsExactlyTheOldPlan() {
        let snapshot = Self.manualSnapshot
        let planner = ShelfStudySessionPlanner()
        let old = planner.plan(snapshot: snapshot, topicID: nil, minutes: 10, mode: .learn, now: Self.now)
        let explicit = planner.plan(snapshot: snapshot, knowledge: .empty, topicID: nil, minutes: 10, mode: .learn, now: Self.now)
        XCTAssertEqual(shape(old), shape(explicit))
        XCTAssertTrue(explicit.activities.allSatisfy { $0.probe == nil })
    }

    func testALiveMisconceptionBringsItsConceptToTheFrontWithAQuestionAboutIt() throws {
        var snapshot = Self.manualSnapshot
        let kb = LearningCorpus.mastery
        let planner = ShelfStudySessionPlanner()
        let later = Self.now.addingTimeInterval(600)
        let before = planner.plan(snapshot: snapshot, knowledge: kb, topicID: nil, minutes: 10, mode: .learn, now: later)
        // A concept the plan reaches, but not first.
        let concept = try XCTUnwrap(before.activities.dropFirst(3).compactMap(\.probe?.concept).first { $0 != before.activities.first?.probe?.concept })
        let claim = try XCTUnwrap(kb.claims(teaching: concept.concept).first { $0.role == .core })
        LearnerModelReducer().apply(LearningEvidence(concept: concept, conceptName: concept.concept.value, operation: .define, outcome: .incorrect,
            channel: .explanation, claimIDs: [claim.id], misconception: MisconceptionObservation(kind: .contradiction, claimID: claim.id,
            relatedConcept: nil, learnerWording: "a confident but wrong restatement of this idea"), occurredAt: Self.now), to: &snapshot.learnerModel)
        let after = planner.plan(snapshot: snapshot, knowledge: kb, topicID: nil, minutes: 10, mode: .learn, now: later)
        let first = try XCTUnwrap(after.activities.first)
        XCTAssertEqual(first.probe?.concept, concept, "the misconceived concept is practised first")
        XCTAssertTrue(after.activities.prefix(2).contains { $0.probe?.operation == .misconceptionCheck },
                      "and the wrong idea itself is re-tested in the learner's own words")
    }

    func testEveryPlannedQuestionIsGroundedAndNoQuestionRepeatsInASession() {
        let kb = LearningCorpus.mastery
        let analysis = LearningCorpus.analysis("Mobile Mastery")
        let start = Date()
        let session = ShelfStudySessionPlanner().plan(snapshot: Self.manualSnapshot, knowledge: kb, topicID: nil, minutes: 30, mode: .learn, now: Self.now)
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 10, "planning a 30-minute session over 345 pages stays interactive")
        let probed = session.activities.compactMap(\.probe)
        XCTAssertFalse(probed.isEmpty)
        XCTAssertEqual(Set(probed.map(\.id)).count, probed.count)
        for activity in session.activities {
            guard let probe = activity.probe else { continue }
            XCTAssertNil(ProbeValidator.failure(probe, in: kb, analysis: analysis))
            if activity.kind == .question { XCTAssertEqual(activity.questionID, probe.question?.id) }
            if activity.kind == .recall { XCTAssertFalse(probe.format.isChoice) }
        }
        print("PLANNER|seconds=\(elapsed)|activities=\(session.activities.count)|probed=\(probed.count)")
    }

    func testEveryQuestionIsAboutThePassageItIsShownWith() throws {
        var snapshot = Self.manualSnapshot
        let kb = LearningCorpus.mastery
        let mapper = LearnerEvidenceMapper(knowledge: kb)
        // A learner failing the basics of every concept with prerequisites invites detours.
        let failing = kb.cards.filter { !kb.prerequisites(of: $0.key).isEmpty }.prefix(40)
        for card in failing {
            let id = LearnerConceptID(documentID: card.documentID, concept: card.key)
            for n in 0..<2 {
                LearnerModelReducer().apply(LearningEvidence(concept: id, conceptName: card.name, operation: .define, outcome: .incorrect,
                    channel: .explanation, occurredAt: Self.now.addingTimeInterval(Double(n))), to: &snapshot.learnerModel)
            }
        }
        let session = ShelfStudySessionPlanner().plan(snapshot: snapshot, knowledge: kb, topicID: nil, minutes: 30, mode: .learn, now: Self.now.addingTimeInterval(60))
        var detours = 0
        for activity in session.activities {
            guard let probe = activity.probe, let object = snapshot.learningObjects.first(where: { $0.id == activity.learningObjectID }) else { continue }
            XCTAssertTrue(mapper.concepts(in: object.source).contains { $0.id == probe.concept },
                          "“\(probe.prompt)” must be shown with a passage about \(probe.concept.concept)")
            // What the learner is shown after answering holds the sentences that answer it.
            for claimID in probe.rubricClaimIDs {
                let claim = try XCTUnwrap(kb.claims.first { $0.id == claimID })
                XCTAssertTrue(probe.answerText.contains(CanonicalWhitespaceResolver.normalize(claim.evidence.text)), probe.prompt)
                XCTAssertEqual(probe.answerSource?.documentID, claim.evidence.documentID)
            }
            if activity.remediation != nil { detours += 1 }
        }
        XCTAssertFalse(session.activities.isEmpty)
        print("PLANNER|detours=\(detours)|activities=\(session.activities.count)")
    }

    func testAnotherBookWithTheSameConceptNamesChangesNothing() throws {
        let kb = LearningCorpus.mastery
        var copy = LearningCorpus.analysis("Mobile Mastery")
        copy.documentID = UUID(uuidString: "22222222-0000-0000-0000-000000000001")!
        let library = ConceptKnowledgeBase.merged([kb, ConceptKnowledgeCompiler().compile(copy)])
        let alone = ShelfStudySessionPlanner().plan(snapshot: Self.manualSnapshot, knowledge: kb, topicID: nil, minutes: 30, mode: .learn, now: Self.now)
        let beside = ShelfStudySessionPlanner().plan(snapshot: Self.manualSnapshot, knowledge: library, topicID: nil, minutes: 30, mode: .learn, now: Self.now)
        XCTAssertEqual(beside.activities.map(\.probe), alone.activities.map(\.probe), "questions come from the passage's own book")
        XCTAssertEqual(beside.activities.map(\.learningObjectID), alone.activities.map(\.learningObjectID))
        let original = kb.concept(ConceptKey("Foreign key"))!.documentID
        for name in ["Foreign key", "Debouncing", "Hashing"] {
            let own = ProbeGenerator(knowledge: kb).probes(for: ConceptKey(name), documentID: original)
            let other = ProbeGenerator(knowledge: library.restricted(to: copy.documentID)).probes(for: ConceptKey(name), documentID: copy.documentID)
            XCTAssertEqual(other.count, own.count, "\(name): the second book's questions are as rich as the first's")
            XCTAssertTrue(other.allSatisfy { $0.evidence.allSatisfy { $0.documentID == copy.documentID } })
        }
    }

    func testSessionsWithProbesSurviveTheCheckpointRoundTrip() throws {
        let kb = LearningCorpus.mastery
        let session = ShelfStudySessionPlanner().plan(snapshot: Self.manualSnapshot, knowledge: kb, topicID: nil, minutes: 10, mode: .learn, now: Self.now)
        let decoded = try JSONDecoder().decode(StudySession.self, from: JSONEncoder().encode(session))
        XCTAssertEqual(decoded, session)
        var legacy = try JSONSerialization.jsonObject(with: JSONEncoder().encode(session)) as! [String: Any]
        legacy["activities"] = (legacy["activities"] as! [[String: Any]]).map { activity in
            var copy = activity; copy.removeValue(forKey: "probe"); copy.removeValue(forKey: "remediation"); return copy
        }
        let old = try JSONDecoder().decode(StudySession.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertTrue(old.activities.allSatisfy { $0.probe == nil }, "checkpoints written before V34 still resume")
    }

    func testAFinishedSessionIsStoredWithoutItsQuestions() throws {
        var session = ShelfStudySessionPlanner().plan(snapshot: Self.manualSnapshot, knowledge: LearningCorpus.mastery, topicID: nil,
                                                      minutes: 30, mode: .learn, now: Self.now)
        XCTAssertTrue(session.activities.contains { $0.probe != nil })
        var snapshot = LearningSnapshot()
        StudyCheckpointMutation.storeSession(session, in: &snapshot)
        XCTAssertEqual(snapshot.sessions.first?.activities.map(\.probe), session.activities.map(\.probe), "an unfinished session resumes with its questions")
        let unfinished = try JSONEncoder().encode(snapshot.sessions).count
        session.completedAt = Self.now
        StudyCheckpointMutation.storeSession(session, in: &snapshot)
        XCTAssertTrue(snapshot.sessions.first!.activities.allSatisfy { $0.probe == nil })
        XCTAssertEqual(snapshot.sessions.first?.activities.map(\.id), session.activities.map(\.id), "the history of what was studied stays")
        XCTAssertLessThan(try JSONEncoder().encode(snapshot.sessions).count, unfinished / 2)
    }
}
