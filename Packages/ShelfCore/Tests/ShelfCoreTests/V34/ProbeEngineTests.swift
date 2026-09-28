import XCTest
@testable import ShelfCore

final class ProbeEngineTests: XCTestCase {
    private var kb: ConceptKnowledgeBase { LearningCorpus.mastery }
    private var analysis: DocumentAnalysis { LearningCorpus.analysis("Mobile Mastery") }
    private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private func day(_ n: Double) -> Date { start.addingTimeInterval(n * 86_400) }
    private func id(_ name: String) -> LearnerConceptID { LearnerConceptID(documentID: analysis.documentID, concept: ConceptKey(name)) }
    private func probes(_ name: String) -> [LearningProbe] { ProbeGenerator(knowledge: kb).probes(for: ConceptKey(name), documentID: analysis.documentID) }

    func testEveryProbeOnTheManualIsGroundedAnswerableAndLeakFree() {
        let generator = ProbeGenerator(knowledge: kb)
        var total = 0, rich = 0
        for card in kb.cards {
            let probes = generator.probes(for: card.key, documentID: card.documentID)
            total += probes.count
            if probes.count >= 3 && Set(probes.map(\.operation)).count >= 2 { rich += 1 }
            for probe in probes {
                XCTAssertNil(ProbeValidator.failure(probe, in: kb, analysis: analysis), probe.prompt)
                XCTAssertTrue(probe.evidence.allSatisfy { $0.isCurrent(in: analysis) }, "every probe cites exact current source text")
                if case .choice(let options, let answer) = probe.format {
                    XCTAssertEqual(ConceptKey(options[answer]), card.key)
                    let quoted = probe.prompt.components(separatedBy: "“").dropFirst().joined()
                    for (index, option) in options.enumerated() where index != answer {
                        XCTAssertFalse(ProbeGenerator.names(option, in: quoted), "a distractor named in the quote would look right: \(probe.prompt)")
                    }
                    // Independently of the gate: no word of the answer that no distractor shares
                    // appears in the quoted source text.
                    let distractorWords = Set(options.enumerated().filter { $0.offset != answer }.flatMap { Self.words($0.element) })
                    for word in card.names.flatMap(Self.words) where !distractorWords.contains(word) {
                        XCTAssertFalse(Self.words(quoted).contains(word), "“\(word)” gives away \(card.name): \(probe.prompt)")
                    }
                }
            }
        }
        // 84% before quoted examples and definitions were checked for the answer's own words;
        // the questions that gave their answer away ("JOIN" in a SQL JOIN example) are gone.
        XCTAssertGreaterThanOrEqual(Double(rich) / Double(kb.cards.count), 0.75, "at least 75% of cards get three probes of two kinds")
        XCTAssertGreaterThan(total, 900)
    }

    func testPromptsReadNaturallyForNamesOfEveryShape() {
        let define = { (name: String) in self.probes(name).first { $0.operation == .define }?.prompt }
        XCTAssertEqual(define("AbortController"), "In one sentence, what is AbortController?")
        XCTAssertEqual(define("HTTP status codes"), "In one sentence, what are HTTP status codes?")
        XCTAssertEqual(define("Transaction"), "In one sentence, what is a transaction?")
        XCTAssertEqual(define("Hashing"), "In one sentence, what is hashing?")
        XCTAssertEqual(define("Foreign key"), "In one sentence, what is a foreign key?")
        XCTAssertNil(define("AI support assistant with private docs"), "a scenario title is not a concept to define")
        XCTAssertEqual(define("HTTP"), "In one sentence, what is HTTP?", "“https” in the source is not HTTP in the plural")
        XCTAssertEqual(define("never"), "In one sentence, what is “never”?", "a code keyword is quoted, not given an article")
        XCTAssertEqual(PromptRealizer.inline("Single Responsibility Principle"), "the Single Responsibility Principle")
        XCTAssertNil(PromptRealizer.objectQuestion(LearningClaim(concept: ConceptKey("AbortController"), conceptName: "AbortController",
            kind: .mechanism, subject: "A browser API used to cancel", predicate: "fetch", object: "requests or other async work",
            qualifier: nil, negated: false, evidence: SourceSpan(documentID: analysis.documentID, pageIndex: 0,
            range: SourceTextRange(location: 0, length: 3), text: "A browser API used to cancel fetch requests or other async work."),
            grounding: .literal, role: .core)), "a subject with a clause inside cannot be asked as “What does … <verb>?”")
        let all = kb.cards.flatMap { probes($0.name) }.map(\.prompt)
        for bad in ["a never", "an HTTP ", "a single Responsibility", "used to cancel fetch?", "What does the stack data structure?"] {
            XCTAssertFalse(all.contains { $0.contains(bad) }, bad)
        }
        XCTAssertEqual(PromptRealizer.article(for: "union type"), "a")
        XCTAssertEqual(PromptRealizer.article(for: "API"), "an")
        XCTAssertEqual(PromptRealizer.article(for: "REST API"), "a")
    }

    func testRecognitionUsesTheSourceDefinitionWithoutTheName() throws {
        let recognize = try XCTUnwrap(probes("Debouncing").first { $0.operation == .recognizeDefinition })
        XCTAssertTrue(recognize.prompt.contains("delaying an action until a burst of events has been quiet"))
        XCTAssertFalse(recognize.prompt.lowercased().contains("debounc"))
        guard case .choice(let options, let answer) = recognize.format else { return XCTFail("choice expected") }
        XCTAssertEqual(options[answer], "Debouncing")
        XCTAssertTrue(options.contains("Throttling"), "the easiest concept to confuse it with is among the options")
        let question = try XCTUnwrap(recognize.question)
        XCTAssertEqual(question.correctOption?.text, "Debouncing")
        XCTAssertEqual(question.id, recognize.question?.id, "rebuilding the question gives the same identity")
    }

    func testUngroundedStaleOrLeakingProbesAreRejected() throws {
        let probe = try XCTUnwrap(probes("Foreign key").first { $0.operation == .purpose })
        XCTAssertNil(ProbeValidator.failure(probe, in: kb, analysis: analysis))
        var changed = analysis
        let page = try XCTUnwrap(changed.pages.firstIndex { $0.pageIndex == probe.evidence[0].pageIndex })
        changed.pages[page].canonicalText = "Rewritten page."
        XCTAssertEqual(ProbeValidator.failure(probe, in: kb, analysis: changed), "evidence not current")
        let claim = try XCTUnwrap(kb.claims.first { $0.id == probe.rubricClaimIDs[0] })
        let leaking = LearningProbe(concept: probe.concept, conceptName: probe.conceptName, operation: .purpose,
                                    prompt: "Why does a foreign key protect \(claim.object)?", format: .open, rubric: [claim])
        XCTAssertEqual(ProbeValidator.failure(leaking, in: kb), "prompt leaks answer")
        let invented = LearningProbe(concept: probe.concept, conceptName: probe.conceptName, operation: .define,
                                     prompt: "In one sentence, what is a foreign key?", format: .open, rubric: [claim, LearningClaim(
            concept: claim.concept, conceptName: claim.conceptName, kind: .property, subject: "Foreign key", predicate: "is", object: "a kind of cache",
            qualifier: nil, negated: false, evidence: SourceSpan(documentID: claim.evidence.documentID, pageIndex: 0,
            range: SourceTextRange(location: 0, length: 3), text: "abc"), grounding: .literal, role: .core)])
        XCTAssertEqual(ProbeValidator.failure(invented, in: kb), "rubric claim missing", "a question answered by an invented claim is refused")
    }

    private static func words(_ text: String) -> [String] {
        text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
    }

    func testQuotedExamplesThatContainTheAnswerAreNeverAsked() {
        // Each of these examples names its concept ("SELECT … JOIN orders", "Set-Cookie: …; HttpOnly").
        for name in ["never", "any", "try / catch", "HttpOnly cookie", "SQL JOIN", "Lazy loading", "React.memo", "satisfies operator",
                     "Offset pagination", "Database index", "Discriminated union", "Stale-while-revalidate"] {
            for probe in probes(name) where probe.format.isChoice {
                let quoted = probe.prompt.components(separatedBy: "“").dropFirst().joined()
                XCTAssertFalse(Self.words(quoted).contains { word in Self.words(name).contains(word) && !["and", "or"].contains(word) },
                               "\(name): \(probe.prompt)")
            }
        }
        XCTAssertTrue(ProbeGenerator.singlesOut(["LRU cache"], among: ["Distributed cache", "Cache-aside"], in: "evicts the least recently used entry"),
                      "a spelled-out acronym gives the answer away")
        XCTAssertFalse(ProbeGenerator.singlesOut(["Foreign key"], among: ["Primary key", "Unique constraint"], in: "a key in another table"),
                       "a word a distractor shares leaves the choice open")
    }

    func testAcronymExpansionsNeverGiveAwayTheAnswer() {
        XCTAssertTrue(ProbeGenerator.spellsAcronym("TTL", in: "Time To Live: how long a cached value remains valid"))
        XCTAssertFalse(ProbeGenerator.spellsAcronym("TTL", in: "how long a cached value remains valid before expiring"))
        XCTAssertNil(probes("TTL").first { $0.operation == .recognizeDefinition && $0.prompt.lowercased().contains("time to live") })
    }

    func testAnOpenProbeIsGradedAgainstItsOwnRubric() throws {
        let contrast = try XCTUnwrap(probes("Encryption").first { $0.operation == .contrast })
        XCTAssertEqual(contrast.relatedConcept, ConceptKey("Hashing"))
        let target = try XCTUnwrap(DiagnosisTarget.probe(contrast, in: kb))
        XCTAssertEqual(Set(target.rubric.map(\.id)), Set(contrast.rubricClaimIDs))
        let answer = "Encryption is a reversible transformation that protects data with keys, while hashing is a one-way transformation that maps input to a digest."
        let diagnosis = UnderstandingDiagnoser().diagnose(answer, target: target)
        XCTAssertFalse(diagnosis.hasMisconception)
        XCTAssertTrue(diagnosis.claims.allSatisfy { $0.coverage != .missing }, "both definitions were expressed")
    }

    // MARK: - Adaptive selection (scripted learners)

    private func answer(_ state: inout LearnerModelState, _ decision: ProbeDecision, _ outcome: EvidenceOutcome, at date: Date,
                        confidence: ConfidenceLevel? = nil, misconception: MisconceptionObservation? = nil) {
        if let objective = decision.startsObjective { state.objective = objective }
        // As the evidence mapper does: the concepts the question set beside this one.
        var rivals = decision.probe.relatedConcept.map { [$0] } ?? []
        if case .choice(let options, let answer) = decision.probe.format {
            rivals += options.indices.filter { $0 != answer }.map { ConceptKey(options[$0]) }
        }
        LearnerModelReducer().apply(LearningEvidence(concept: decision.probe.concept, conceptName: decision.probe.conceptName,
            operation: decision.probe.operation, outcome: outcome, channel: decision.probe.format.isChoice ? .choice : .explanation,
            confidence: confidence, claimIDs: decision.probe.rubricClaimIDs, misconception: misconception, probeID: decision.probe.id,
            occurredAt: date, rivals: rivals), to: &state)
    }

    func testANewConceptStartsWithRecognitionOrDefinitionThenClimbs() throws {
        let selector = AdaptiveProbeSelector(knowledge: kb)
        var state = LearnerModelState()
        let first = try XCTUnwrap(selector.next(for: id("Debouncing"), state: state, now: day(0)))
        XCTAssertEqual(first.probe.level, 1)
        XCTAssertEqual(first.reason, .climb)
        var date = day(0)
        for _ in 0..<4 {
            let decision = try XCTUnwrap(selector.next(for: id("Debouncing"), state: state, now: date))
            guard decision.probe.level == 1 else { break }
            answer(&state, decision, .correct, at: date)
            date = date.addingTimeInterval(86_400 * 1.5)
        }
        let later = try XCTUnwrap(selector.next(for: id("Debouncing"), state: state, now: date))
        XCTAssertGreaterThanOrEqual(later.probe.level, 2, "after spaced successes at recognition, the questions ask for explanation")
    }

    func testALiveMisconceptionIsRetestedUntilSpacedCorrectionsRetireIt() throws {
        let selector = AdaptiveProbeSelector(knowledge: kb)
        let claim = try XCTUnwrap(kb.claims(teaching: ConceptKey("Authorization")).first { $0.statement == "Identity alone is not permission." })
        var state = LearnerModelState()
        LearnerModelReducer().apply(LearningEvidence(concept: id("Authorization"), conceptName: "Authorization", operation: .define,
            outcome: .incorrect, channel: .explanation, claimIDs: [claim.id],
            misconception: MisconceptionObservation(kind: .contradiction, claimID: claim.id, relatedConcept: nil,
                learnerWording: "Once you know who the user is, they have permission to do everything"), occurredAt: day(0)), to: &state)
        let check = try XCTUnwrap(selector.next(for: id("Authorization"), state: state, now: day(0.1)))
        XCTAssertEqual(check.reason, .misconception)
        XCTAssertEqual(check.probe.operation, .misconceptionCheck)
        XCTAssertEqual(check.probe.rubricClaimIDs, [claim.id])
        XCTAssertTrue(check.probe.prompt.contains("they have permission to do everything"), "the learner meets their own words again")
        answer(&state, check, .correct, at: day(0.2))
        answer(&state, check, .correct, at: day(2))
        XCTAssertEqual(state.misconceptions.first?.status, .resolved)
        let next = try XCTUnwrap(selector.next(for: id("Authorization"), state: state, now: day(2.1)))
        XCTAssertNotEqual(next.reason, .misconception)
    }

    func testAConfusionIsAddressedByContrastingTheTwoConcepts() throws {
        var state = LearnerModelState()
        LearnerModelReducer().apply(LearningEvidence(concept: id("Debouncing"), conceptName: "Debouncing", operation: .define,
            outcome: .incorrect, channel: .explanation,
            misconception: MisconceptionObservation(kind: .confusion, claimID: nil, relatedConcept: ConceptKey("Throttling"),
                learnerWording: "Debouncing runs at most once per interval"), occurredAt: day(0)), to: &state)
        let decision = try XCTUnwrap(AdaptiveProbeSelector(knowledge: kb).next(for: id("Debouncing"), state: state, now: day(0.1)))
        XCTAssertEqual(decision.reason, .misconception)
        XCTAssertTrue(decision.probe.relatedConcept == ConceptKey("Throttling") || decision.probe.format.isChoice)
        // Told apart on two separate days, through the questions the selector itself chose.
        var date = day(0.1)
        for _ in 0..<2 {
            let next = try XCTUnwrap(AdaptiveProbeSelector(knowledge: kb).next(for: id("Debouncing"), state: state, now: date))
            answer(&state, next, .correct, at: date)
            date = date.addingTimeInterval(86_400 * 1.5)
        }
        XCTAssertEqual(state.misconceptions.first?.status, .resolved)
    }

    func testAFailingConceptDetoursOnceToAWeakPrerequisiteAndReturns() throws {
        let selector = AdaptiveProbeSelector(knowledge: kb)
        let cache = id("Cache")
        XCTAssertFalse(kb.prerequisites(of: cache.concept).isEmpty)
        var state = LearnerModelState()
        for n in 0..<2 {
            LearnerModelReducer().apply(LearningEvidence(concept: cache, conceptName: "Cache", operation: .define, outcome: .incorrect,
                                                         channel: .explanation, occurredAt: day(Double(n) * 0.1)), to: &state)
        }
        let detour = try XCTUnwrap(selector.next(for: cache, state: state, now: day(0.3)))
        XCTAssertEqual(detour.reason, .prerequisite)
        XCTAssertNotEqual(detour.probe.concept, cache)
        XCTAssertEqual(detour.startsObjective?.objective, cache)
        answer(&state, detour, .correct, at: day(0.4))
        XCTAssertNil(state.objective, "the prerequisite is repaired")
        let back = try XCTUnwrap(selector.next(for: cache, state: state, now: day(0.5)))
        XCTAssertEqual(back.probe.concept, cache, "and the learner returns to the concept they came for")
    }

    func testAnAbandonedDetourExpiresEvenWithoutNewAnswers() throws {
        let cache = id("Cache"), prerequisite = try XCTUnwrap(kb.prerequisites(of: cache.concept).first)
        var state = LearnerModelState()
        state.objective = RemediationObjective(objective: cache, prerequisite: LearnerConceptID(documentID: cache.documentID, concept: prerequisite),
                                               startedAt: day(0))
        let selector = AdaptiveProbeSelector(knowledge: kb)
        XCTAssertEqual(selector.next(for: cache, state: state, now: day(1))?.reason, .prerequisite)
        XCTAssertNotEqual(selector.next(for: cache, state: state, now: day(8))?.reason, .prerequisite, "a week later the detour is over")
    }

    func testOverconfidentLearnersAreAskedToExplainRatherThanRecognise() throws {
        var state = LearnerModelState()
        LearnerModelReducer().apply(LearningEvidence(concept: id("Idempotency"), conceptName: "Idempotency", operation: .recognizeDefinition,
            outcome: .incorrect, channel: .choice, confidence: .certain, occurredAt: day(0)), to: &state)
        let decision = try XCTUnwrap(AdaptiveProbeSelector(knowledge: kb).next(for: id("Idempotency"), state: state, now: day(0.5)))
        XCTAssertFalse(decision.probe.format.isChoice)
        XCTAssertEqual(decision.reason, .overconfidence)
    }

    func testPracticeStaysVariedAndDeterministic() throws {
        let selector = AdaptiveProbeSelector(knowledge: kb)
        var state = LearnerModelState()
        var asked: [LearningProbe] = []
        var date = day(0)
        for _ in 0..<8 {
            let decision = try XCTUnwrap(selector.next(for: id("Foreign key"), state: state, now: date))
            XCTAssertEqual(selector.next(for: id("Foreign key"), state: state, now: date), decision, "same state, same choice")
            asked.append(decision.probe)
            answer(&state, decision, .partial, at: date)
            date = date.addingTimeInterval(3600)
        }
        for window in 0..<(asked.count - 2) {
            let ops = asked[window..<(window + 3)].map(\.operation)
            XCTAssertFalse(ops.allSatisfy { $0 == ops[0] }, "never the same kind of question three times running")
        }
        let available = Set(asked.map(\.id)).count
        XCTAssertGreaterThanOrEqual(available, 3)
        for (index, probe) in asked.enumerated() {
            // With n distinct questions available, a prompt returns only after the n - 1 others.
            let previous = asked[max(0, index - (available - 1))..<index].map(\.id)
            XCTAssertFalse(previous.contains(probe.id), "a prompt is not repeated before the others were asked")
        }
    }
}
