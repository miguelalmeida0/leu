import XCTest
@testable import ShelfCore

/// The judgement's decision boundary: when an answer is credited, recorded as a misconception,
/// or held back behind one discriminating question — and what that question is about.
final class UnderstandingJudgeTests: XCTestCase {
    private var kb: ConceptKnowledgeBase { LearningCorpus.mastery }
    private var documentID: UUID { LearningCorpus.analysis("Mobile Mastery").documentID }
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func target(_ name: String) throws -> DiagnosisTarget { try XCTUnwrap(DiagnosisTarget.concept(ConceptKey(name), in: kb)) }
    private func assess(_ text: String, _ name: String, prior: LearnerPrior = LearnerPrior()) throws -> UnderstandingAssessment {
        UnderstandingDiagnoser().assess(text, target: try target(name), prior: prior)
    }
    private func evidence(_ assessment: UnderstandingAssessment) -> [LearningEvidence] {
        LearnerEvidenceMapper(knowledge: kb).evidence(from: assessment, documentID: documentID, identity: "attempt", at: now)
    }
    private func definition(_ name: String) throws -> LearningClaim { try XCTUnwrap(kb.definition(of: ConceptKey(name))) }

    func testAClearParaphraseIsCreditedWithoutAQuestion() throws {
        // "not on every event" negates the universal: it is not an overgeneralization.
        let assessed = try assess("Throttling runs the handler at most once per time window, not on every event.", "Throttling")
        XCTAssertNil(assessed.judgement.question)
        XCTAssertTrue(assessed.judgement.state.credits)
        XCTAssertFalse(assessed.diagnosis.has(.overgeneralization))
        XCTAssertTrue(evidence(assessed).contains { $0.outcome == .correct })
    }

    func testAUniversalIsAnOvergeneralizationOnlyWhereTheSourceIsQualified() throws {
        // The hedge is on the lifetime ("usually … short"), not on being presented with each request.
        let presented = try assess("An access token is presented on every API request to authorize it, and it only lives a short time.", "Access token")
        XCTAssertFalse(presented.diagnosis.has(.overgeneralization))
        // "every failed call" universalises exactly what the source limits ("when the failure may be temporary").
        let always = try assess("You should always retry every failed call, whatever went wrong.", "Retry")
        XCTAssertTrue(always.diagnosis.has(.overgeneralization))
        XCTAssertEqual(always.judgement.state, .misconception)
    }

    func testTheAlternativeALearnerRejectsIsNotReadAsTheirClaim() throws {
        let assessed = try assess("Encryption can be undone with the right key, unlike a hash, which is one-way.", "Encryption")
        XCTAssertFalse(assessed.diagnosis.has(.contradiction), "\"unlike a hash\" names the contrast, it does not claim encryption is one-way")
        XCTAssertNotEqual(assessed.judgement.state, .misconception)
    }

    func testANegatedClaimIsNeverCreditedWithoutItsNegationAndTheOmissionIsAsked() throws {
        let negated = try XCTUnwrap(kb.claims(teaching: ConceptKey("Authorization")).first { $0.statement.contains("Identity alone is not permission") })
        let assessed = try assess("Knowing who a user is gives them permission to do everything.", "Authorization")
        XCTAssertFalse([ClaimCoverage.covered, .partial].contains(assessed.diagnosis.assessment(negated.id)?.coverage ?? .missing))
        let question = try XCTUnwrap(assessed.judgement.question)
        XCTAssertEqual(question.claimIDs, [negated.id], "the question is about the claim the answer may be misreading")
        XCTAssertTrue(question.between.contains(.misconception))
        XCTAssertNotEqual(question.operation, .misconceptionCheck, "nothing is on record: a right answer counts at the claim's own level")
        XCTAssertTrue(evidence(assessed).isEmpty, "nothing is learned until it is answered")
        XCTAssertFalse(assessed.diagnosis.intervention.revealsSource)
        // The correct definition, which shares those words, is credited — not suspected.
        let right = try assess("Deciding what an authenticated identity is allowed to do, checked per action or resource.", "Authorization")
        XCTAssertNil(right.judgement.question)
        XCTAssertFalse(right.diagnosis.hasMisconception)
    }

    func testADoubtedContradictionIsShownBesideTheSourceButNotRecordedUntilSettled() throws {
        // One shared word ("encrypted") carries the contradiction: too little to record a misconception on.
        let assessed = try assess("A JWT is a compact token with signed claims. It is encrypted, so no one can see inside.", "JWT")
        XCTAssertTrue(assessed.diagnosis.has(.contradiction))
        let question = try XCTUnwrap(assessed.judgement.question)
        XCTAssertTrue(question.between.contains(.misconception))
        XCTAssertTrue(evidence(assessed).isEmpty, "nothing is recorded until the question is answered")
        // What the comparison states is still shown beside the source, never contradicted by a "can't tell yet".
        XCTAssertEqual(assessed.diagnosis.intervention.kind, .correctContradiction)
        XCTAssertNotNil(assessed.diagnosis.intervention.followUp)
    }

    func testCreditRestingOnSharedWordsIsAskedAboutBeforeItCounts() throws {
        let assessed = try assess("An idempotent operation is one you may only perform a single time.", "Idempotency")
        let question = try XCTUnwrap(assessed.judgement.question)
        XCTAssertEqual(question.claimIDs, [try definition("Idempotency").id])
        XCTAssertEqual(question.between, [.fragile, .misconception])
        XCTAssertTrue(evidence(assessed).isEmpty)
        XCTAssertEqual(assessed.diagnosis.intervention.kind, .cueMissingIdea)
        XCTAssertNotNil(assessed.diagnosis.intervention.followUp)
    }

    func testALearnerWhoSaysTheyAreUnsureIsAskedBeforeBeingCredited() throws {
        let assessed = try assess("I think throttling maybe limits an action so it runs at most once per time window while events continue?", "Throttling")
        XCTAssertTrue(assessed.diagnosis.level == .mostly || assessed.diagnosis.level == .solid, "the wording itself is right")
        let question = try XCTUnwrap(assessed.judgement.question)
        XCTAssertTrue(question.between.contains(.fragile))
        XCTAssertTrue(evidence(assessed).isEmpty)
        XCTAssertEqual(assessed.judgement.hypotheses.first?.cue, .selfDoubt)
        // "A kind of" names a category; it is not a hedge.
        let category = try assess("Throttling is a kind of limit: the handler runs at most once per time window, not on every event.", "Throttling")
        XCTAssertFalse(category.judgement.hypotheses.contains { $0.cue == .selfDoubt })
    }

    func testWordsOfAnotherConceptAskForTheContrastWithThatConcept() throws {
        let assessed = try assess("Authentication works out which actions and resources a user is allowed to use.", "Authentication")
        let question = try XCTUnwrap(assessed.judgement.question)
        XCTAssertEqual(question.operation, .contrast)
        XCTAssertEqual(question.relatedConcept, ConceptKey("Authorization"))
        XCTAssertEqual(assessed.diagnosis.intervention.kind, .distinguishConcepts)
        XCTAssertFalse(assessed.diagnosis.intervention.revealsSource, "a doubt is asked about, not corrected")
        XCTAssertTrue(assessed.diagnosis.intervention.followUp?.prompt.contains("differ") ?? false)
        XCTAssertTrue(evidence(assessed).isEmpty)
        // With nothing else in the answer to credit, the question is still the contrast, not the definition.
        let alone = try assess("Authentication decides what you're allowed to do once you're in.", "Authentication")
        XCTAssertEqual(alone.judgement.question?.between, [.misconception, .insufficientEvidence])
        XCTAssertEqual(alone.diagnosis.intervention.kind, .distinguishConcepts)
        // The message states the doubt without promising a question: a recall card shows it alone.
        XCTAssertEqual(alone.diagnosis.intervention.message, "Your explanation could also describe Authorization.")
        XCTAssertEqual(alone.diagnosis.intervention.followUp?.operation, .contrast)
        XCTAssertTrue(evidence(alone).isEmpty)
    }

    func testAnswersTheTargetExplainsWellAreNotSuspectedOfConfusion() throws {
        // Keys, tables and columns belong to several database concepts; this answer is about its own.
        let assessed = try assess("A foreign key is a column whose value has to point at a key in a different table.", "Foreign key")
        XCTAssertNotEqual(assessed.judgement.question?.operation, .contrast)
    }

    func testACopiedSourceSentenceAsksForOwnWordsAndCountsForNothingYet() throws {
        let assessed = try assess("Debouncing is delaying an action until a burst of events has been quiet for a chosen interval.", "Debouncing")
        XCTAssertEqual(assessed.diagnosis.level, .surface)
        XCTAssertNotNil(assessed.judgement.question)
        XCTAssertEqual(assessed.diagnosis.intervention.kind, .explainInOwnWords)
        XCTAssertTrue(evidence(assessed).isEmpty)
    }

    func testARightConclusionWithAnUnsettledReasonEarnsPartialCreditOnly() throws {
        let assessed = try assess("Throttling runs the handler at most once per time window; that's because JavaScript is single-threaded.", "Throttling")
        XCTAssertEqual(assessed.judgement.state, .weakReasoning)
        XCTAssertNil(assessed.judgement.question)
        let items = evidence(assessed)
        XCTAssertFalse(items.isEmpty)
        XCTAssertFalse(items.contains { $0.outcome == .correct }, "the reason given is not the source's")
    }

    func testNothingComparableLearnsNothingAndAsksForTheIdeaItself() throws {
        let assessed = try assess("It is about operations.", "Idempotency")
        XCTAssertEqual(assessed.judgement.state, .insufficientEvidence)
        XCTAssertEqual(assessed.judgement.question?.operation, .define)
        XCTAssertTrue(evidence(assessed).isEmpty)
    }

    func testAClearlyStatedWrongIdeaIsRecordedAtOnce() throws {
        let assessed = try assess("You should always retry every failed call, whatever went wrong.", "Retry")
        XCTAssertNil(assessed.judgement.question)
        XCTAssertTrue(evidence(assessed).contains { $0.misconception?.kind == .overgeneralization })
    }

    func testALiveEarlierMisconceptionIsAskedAboutUntilAnAnswerClearlyCorrectsIt() throws {
        let claim = try definition("Throttling")
        let concept = LearnerConceptID(documentID: documentID, concept: ConceptKey("Throttling"))
        let record = MisconceptionRecord(id: "m1", concept: concept, kind: .contradiction, claimID: claim.id, relatedConcept: nil,
                                         learnerWording: "waits until the events stop", occurrences: 1, firstSeenAt: now, lastSeenAt: now,
                                         status: .active, correctionDays: 0, lastCorrectAt: nil)
        let prior = LearnerPrior(misconceptions: [record], at: now.addingTimeInterval(86_400))
        // About the concept, but silent on the misread claim: ask about that claim first.
        let silent = try assess("Throttling protects expensive handlers during scrolling.", "Throttling", prior: prior)
        XCTAssertEqual(silent.judgement.question?.claimIDs, [claim.id])
        XCTAssertEqual(silent.judgement.question?.operation, .misconceptionCheck)
        XCTAssertTrue(evidence(silent).isEmpty)
        // The same answer with no earlier misconception is simply partial.
        XCTAssertNil(try assess("Throttling protects expensive handlers during scrolling.", "Throttling").judgement.question)
        // A clear restatement of the corrected claim is counted: it is what retires the misconception.
        let corrected = try assess("Throttling runs the handler at most once per time window, not on every event.", "Throttling", prior: prior)
        XCTAssertNil(corrected.judgement.question)
        XCTAssertTrue(evidence(corrected).contains { $0.claimIDs.contains(claim.id) && $0.outcome == .correct })
        // A misconception unrevisited for two months no longer colours a new answer.
        var model = LearnerModelState()
        model.misconceptions = [record]
        XCTAssertTrue(LearnerPrior(model, concepts: [concept], at: now.addingTimeInterval(60 * 86_400)).misconceptions.isEmpty)
        // One about a supporting claim, which no answer's evidence ever touches, cannot be papered
        // over, so it holds nothing back (it would otherwise block every answer until it fades).
        let jwt = try target("JWT")
        let summary = try XCTUnwrap(jwt.supporting.first { claim in jwt.allClaims.contains { $0.id == claim.id } })
        let aside = MisconceptionRecord(id: "m2", concept: LearnerConceptID(documentID: documentID, concept: ConceptKey("JWT")),
                                        kind: .overgeneralization, claimID: summary.id, relatedConcept: nil, learnerWording: "always",
                                        occurrences: 1, firstSeenAt: now, lastSeenAt: now, status: .active, correctionDays: 0, lastCorrectAt: nil)
        let unaffected = try assess("A JWT is a compact token that carries signed claims about a user.", "JWT",
                                    prior: LearnerPrior(misconceptions: [aside], at: now.addingTimeInterval(86_400)))
        XCTAssertNil(unaffected.diagnosis.assessment(summary.id), "a supporting claim is never assessed as part of an answer")
        XCTAssertFalse(unaffected.judgement.hypotheses.contains { $0.cue == .priorMisconception })
    }

    func testTypedRecallTheJudgementCannotConfirmLeavesOnlyTheLearnersOwnReadAsDifficult() throws {
        let mapper = LearnerEvidenceMapper(knowledge: kb)
        let source = try definition("Idempotency").evidence.learningSource
        let unsure = try assess("An idempotent operation is one you may only perform a single time.", "Idempotency")
        let held = mapper.evidence(recall: source, rating: .knewIt, probe: nil, assessment: unsure, at: now)
        XCTAssertFalse(held.isEmpty)
        XCTAssertTrue(held.allSatisfy { $0.channel == .selfRating && $0.outcome == .partial }, "\"Knew it\" cannot outrun an answer Leu could not confirm")
        let clear = try assess("Repeating an idempotent operation has the same intended effect as performing it once.", "Idempotency")
        XCTAssertTrue(mapper.evidence(recall: source, rating: .forgot, probe: nil, assessment: clear, at: now).allSatisfy { $0.channel == .explanation },
                      "a confirmed typed answer speaks for itself")
        XCTAssertEqual(mapper.evidence(recall: source, rating: .knewIt, probe: nil, assessment: nil, at: now).map(\.outcome), [.correct],
                       "nothing typed: the learner's own read, as before")
    }

    func testTheSameAnswerIsAlwaysJudgedTheSameWay() throws {
        let text = "An idempotent operation is one you may only perform a single time."
        let first = try assess(text, "Idempotency"), second = try assess(text, "Idempotency")
        XCTAssertEqual(first.judgement, second.judgement)
        XCTAssertEqual(first.diagnosis, second.diagnosis)
    }
}
