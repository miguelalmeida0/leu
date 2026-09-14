import XCTest
@testable import ShelfCore

final class GeneralExtractionV25Tests: XCTestCase {
    private let documentID = UUID(uuidString: "25252525-2525-2525-2525-252525252525")!
    private func evidence(_ source: String, page: Int = 0) -> SemanticEvidenceSpan {
        SemanticEvidenceSpan(documentID: documentID, pageIndex: page, sectionTitle: nil, sourceText: source)
    }
    private func analysis() -> DocumentAnalysis {
        DocumentAnalysis(documentID: documentID, fingerprint: "v25-quality", algorithmVersion: 2,
            pages: QuestionQualityCorpus.fixtures.enumerated().map { index, fixture in
                AnalyzedPage(pageIndex: index, normalizedText: fixture.source,
                    segments: [SourceSegment(pageIndex: index, kind: .paragraph, text: fixture.source)])
            })
    }

    func testEachQualityFixtureHasTeachingConceptIntentAndNaturalQuestion() throws {
        XCTAssertGreaterThanOrEqual(QuestionQualityCorpus.fixtures.count, 100)
        XCTAssertEqual(Set(QuestionQualityCorpus.fixtures.map(\.domain)).count, 16)
        for fixture in QuestionQualityCorpus.fixtures {
            let claims = GeneralClaimExtractor().extract(fixture.source, evidence: evidence(fixture.source))
            let claim = try XCTUnwrap(claims.first, fixture.source)
            XCTAssertEqual(claim.subject.lowercased(), fixture.meaningful.lowercased(), fixture.source)
            XCTAssertTrue(fixture.allowedIntents.contains(claim.intent), fixture.source)
            for incidental in fixture.incidental { XCTAssertFalse(claims.contains { $0.subject.lowercased() == incidental.lowercased() }, fixture.source) }
            let question = try XCTUnwrap(QuestionRealizer().realize(claim), fixture.source)
            XCTAssertNil(QuestionSelfContainment.rejectionReason(prompt: question.prompt, answer: question.answer, concept: claim.subject), fixture.source)
            XCTAssertEqual(question.evidence.documentID, documentID)
            XCTAssertEqual(question.evidence.sourceText, fixture.source)
        }
    }

    func testFinalMultipleChoiceBankContainsReasoningAndNoAnswerLeakage() throws {
        let source = analysis(), index = SemanticCompiler().compile(source)
        let questions = SemanticQuestionCompiler().compile(index: index, analysis: source)
        XCTAssertGreaterThan(questions.count, 30)
        XCTAssertTrue(questions.contains { $0.semanticOperator == "application" })
        XCTAssertTrue(questions.contains { $0.semanticOperator == "debugging" })
        for q in questions {
            XCTAssertTrue(DeterministicQuestionEngine().validate(q), q.prompt)
            let p = try XCTUnwrap(index.propositions.first { $0.id == q.propositionID })
            XCTAssertEqual(q.source, p.evidence.learningSource)
            XCTAssertNil(QuestionSelfContainment.rejectionReason(prompt: q.prompt, answer: try XCTUnwrap(q.correctOption).text, concept: try XCTUnwrap(p.claim).subject))
        }
        XCTAssertEqual(questions.map(\.id), SemanticQuestionCompiler().compile(index: index, analysis: source).map(\.id))
    }

    func testTwentyRejectedRenderedCandidatesHaveReasons() {
        let rejected = [
            "What does A microtask happen after?", "What does An index prevent or require?",
            "What does this source contrast with authentication?", "What follows from A deadlock?",
            "What does it mean?", "Why does this work?", "What happens here?", "What do they require?",
            "What does that cause?", "What does a cache prevents?", "According to this source, what is caching?",
            "How does {subject} work?", "What completes ___ in a cache?", "What is <concept> used for?",
            "Which definition", "Why?", "What is stored data?", "What does the above prevent?",
            "How do those relate?", "What do these require?"
        ]
        XCTAssertEqual(rejected.count, 20)
        for prompt in rejected {
            XCTAssertNotNil(QuestionSelfContainment.rejectionReason(prompt: prompt, answer: "stored data", concept: "cache"), prompt)
        }
    }

    func testIncidentalAndUnsupportedSourcesFailClosed() {
        for text in ["A cache is a cache.", "Caching is a technique."] {
            let claims = GeneralClaimExtractor().extract(text, evidence: evidence(text))
            XCTAssertTrue(claims.compactMap { QuestionRealizer().realize($0) }.isEmpty, text)
        }
        for text in ["It probably does something useful.", "JSON is shown above.", "The response body is encoded as JSON in the example.", "An example is a large arbitrary object.", "Unlike caching, transactions exist."] {
            XCTAssertTrue(GeneralClaimExtractor().extract(text, evidence: evidence(text)).isEmpty, text)
        }
    }

    func testMechanismAndConditionDoNotReverseDirection() throws {
        let mechanism = "Prepared statements prevent SQL injection through parameterization."
        let claim = try XCTUnwrap(GeneralClaimExtractor().extract(mechanism, evidence: evidence(mechanism)).first)
        let q = try XCTUnwrap(QuestionRealizer().realize(claim))
        let dns = "DNS works by resolving host names through a hierarchy of servers."
        let dnsClaim = try XCTUnwrap(GeneralClaimExtractor().extract(dns, evidence: evidence(dns)).first)
        XCTAssertEqual(QuestionRealizer().realize(dnsClaim)?.prompt, "How does DNS work?")
        XCTAssertEqual(QuestionRealizer().realize(dnsClaim)?.answer, "resolving host names through a hierarchy of servers")
        XCTAssertEqual(q.intent, .mechanism); XCTAssertEqual(q.answer, "parameterization")
        XCTAssertTrue(q.prompt.contains("prevent SQL injection"))
        let condition = "Encryption guarantees confidentiality when the key remains secret."
        let c = try XCTUnwrap(GeneralClaimExtractor().extract(condition, evidence: evidence(condition)).first)
        XCTAssertEqual(QuestionRealizer().realize(c)?.answer, "the key remains secret")
        XCTAssertTrue(QuestionRealizer().realize(c)?.prompt.hasPrefix("Under what condition") == true)
    }

    func testSentenceProvenanceUsesUTF16AndDoesNotAbsorbNeighboringClaims() throws {
        let text = "A queue is a first-in-first-out collection. A stack is a last-in-first-out collection."
        let claims = GeneralClaimExtractor().extract(text, evidence: evidence(text, page: 18))
        XCTAssertEqual(claims.count, 2)
        XCTAssertEqual(claims.last?.evidence.pageIndex, 18)
        let last = try XCTUnwrap(claims.last)
        XCTAssertEqual((text as NSString).substring(with: NSRange(location: last.evidence.charStart, length: last.evidence.charLength)), last.evidence.sourceText)
    }

    func testImportanceActuallyChangesSelection() throws {
        let source = analysis(), index = SemanticCompiler().compile(source)
        let questions = SemanticQuestionCompiler().compile(index: index, analysis: source)
        let target = try XCTUnwrap(questions.last)
        var snapshot = LearningSnapshot(analyses: [documentID: source], semanticIndexes: [documentID: index], questions: questions)
        let object = LearningObject(type: .passage, source: target.source, title: "Priority", origin: .userSelection)
        snapshot.learningObjects = [object]
        snapshot.attempts = (0..<3).map { _ in LearningAttempt(learningObjectID: object.id, questionID: target.id, rating: .forgot, wasCorrect: false, confidence: .certain) }
        snapshot.confidenceRecords = (0..<2).map { _ in ConfidenceRecord(questionID: target.id, propositionID: target.propositionID, confidence: .certain, wasCorrect: false) }
        snapshot.trails = [LearningTrail(title: "Important", nodes: [TrailNode(kind: .question, referenceID: target.id, title: "Priority")])]
        snapshot.lensUsage["\(documentID)|\(target.source.pageIndex)"] = 5
        let marks = [StudyAnnotation(bookID: documentID, pageIndex: target.source.pageIndex, kind: .confusing)]
        XCTAssertEqual(ConceptImportanceModel().ranked(questions, snapshot: snapshot, annotations: marks).first?.id, target.id)
    }

    func testLegacySemanticIndexDecodesWithoutNewClaimField() throws {
        var data = try JSONSerialization.jsonObject(with: JSONEncoder().encode(SemanticCompiler().compile(analysis()))) as! [String: Any]
        data["propositions"] = (data["propositions"] as! [[String: Any]]).map { value in var p = value; p.removeValue(forKey: "claim"); return p }
        let decoded = try JSONDecoder().decode(SemanticIndex.self, from: JSONSerialization.data(withJSONObject: data))
        XCTAssertTrue(decoded.propositions.allSatisfy { $0.claim == nil })
    }
    func testTradeoffPatternsPreserveBothSidesWithoutDomainSpecialCases() throws {
        let cases: [(String, String, String)] = [
            ("Compression improves transfer speed but increases CPU work.", "transfer speed", "CPU work"),
            ("Indexes accelerate reads but add maintenance work during writes.", "reads", "maintenance work during writes"),
            ("Compression reduces network traffic while increasing CPU work.", "network traffic", "CPU work"),
            ("Batching helps throughput at the cost of latency.", "throughput", "latency"),
            ("Compression trades CPU work for smaller payloads.", "smaller payloads", "CPU work"),
            ("A vector scan is faster for small libraries but slower for large libraries.", "small libraries", "large libraries"),
            ("Caching improves response time while requiring extra memory.", "response time", "extra memory"),
            ("Although caching improves response time, it increases memory usage.", "response time", "memory usage"),
            ("Replication benefits availability, but writes become more expensive.", "availability", "more expensive")
        ]
        for (text, benefit, cost) in cases {
            let claim = try XCTUnwrap(GeneralClaimExtractor().extract(text, evidence: evidence(text)).first, text)
            let sides = try XCTUnwrap(claim.tradeoff, text)
            XCTAssertEqual(claim.relation, .tradeoff)
            XCTAssertEqual(sides.benefit.object, benefit)
            XCTAssertEqual(sides.cost.object, cost)
            XCTAssertEqual(claim.evidence.sourceText, text)
            let question = try XCTUnwrap(QuestionRealizer().realize(claim), text)
            XCTAssertTrue(question.answer.contains(benefit)); XCTAssertTrue(question.answer.contains(cost))
            XCTAssertFalse(question.prompt.lowercased().contains(benefit.lowercased()), text)
        }
    }

    func testPreventionScopeIsNotMistakenForMechanism() throws {
        let text = "A readonly property prevents reassignment through a typed reference."
        let claim = try XCTUnwrap(GeneralClaimExtractor().extract(text, evidence: evidence(text)).first)
        XCTAssertEqual(claim.intent, .constraint); XCTAssertEqual(claim.relation, .prevents)
        XCTAssertEqual(claim.object, "reassignment through a typed reference")
        XCTAssertNil(claim.qualifier)
        let question = try XCTUnwrap(QuestionRealizer().realize(claim))
        XCTAssertEqual(question.prompt, "What does a readonly property prevent through a typed reference?")
        XCTAssertEqual(question.answer, "reassignment")
        let mechanism = "Prepared statements prevent SQL injection through parameterization."
        let other = try XCTUnwrap(GeneralClaimExtractor().extract(mechanism, evidence: evidence(mechanism)).first)
        XCTAssertEqual(other.intent, .mechanism); XCTAssertEqual(other.qualifier, "parameterization")
    }

    func testOptionCuesAreRejectedWithoutInventingReplacementDistractors() {
        XCTAssertNotNil(QuestionOptionQuality.rejectionReason(prompt: "What does cache invalidation prevent?",
            answer: "cache invalidation prevents stale reads", alternatives: ["repeated network work under heavy load", "an unbounded queue of pending requests"]))
        XCTAssertNotNil(QuestionOptionQuality.rejectionReason(prompt: "What does an index prevent?",
            answer: "a full table scan on the filtered column", alternatives: ["latency", "memory"]))
        XCTAssertNil(QuestionOptionQuality.rejectionReason(prompt: "What trade-off should you consider when using indexes?",
            answer: "accelerating reads; adding maintenance work during writes",
            alternatives: ["accelerating reads; consuming memory for saved entries", "improving availability; adding coordination work during updates"]))
    }

    func testTradeoffChoiceDoesNotNameOnlyTheCorrectSubject() throws {
        let source = analysis(), index = SemanticCompiler().compile(source)
        let bank = SemanticQuestionCompiler().compile(index: index, analysis: source)
        let questions = bank.filter { $0.semanticOperator == "application" || $0.semanticOperator == "debugging" }
        XCTAssertGreaterThanOrEqual(questions.count, 6)
        for q in questions {
            let claim = try XCTUnwrap(index.propositions.first { $0.id == q.propositionID }?.claim)
            XCTAssertTrue(q.options.allSatisfy { !$0.text.lowercased().contains(claim.subject.lowercased()) }, q.prompt)
            let answer = try XCTUnwrap(q.correctOption).text
            XCTAssertNil(QuestionOptionQuality.rejectionReason(prompt: q.prompt, answer: answer,
                alternatives: q.options.filter { $0.id != q.correctOptionID }.map(\.text)))
            print("[leu-question-bank] \(q.semanticOperator ?? "") | \(q.prompt) | \(q.options.map(\.text)) | answer=\(answer)")
        }
    }

}
