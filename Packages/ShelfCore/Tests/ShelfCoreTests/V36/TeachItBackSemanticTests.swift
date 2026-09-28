import XCTest
@testable import ShelfCore

/// Teach It Back reads meaning with no feature of its own: it compares an explanation with the
/// card's passage through the same reader and judge, so V36 reaches it unchanged. A right
/// explanation in other words is read for what it says and asked about; a fluent explanation with
/// a reason the source does not give is asked about instead of credited.
final class TeachItBackSemanticTests: XCTestCase {
    private var analysis: DocumentAnalysis { LearningCorpus.analysis("Mobile Mastery") }
    private var kb: ConceptKnowledgeBase { LearningCorpus.mastery }
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func cardSource(_ name: String) throws -> IntelligenceSource {
        let definition = try XCTUnwrap(kb.definition(of: ConceptKey(name)))
        let page = try XCTUnwrap(analysis.pages.first { $0.pageIndex == definition.evidence.pageIndex })
        let paragraph = try XCTUnwrap(page.segments.first { CanonicalWhitespaceResolver.normalize($0.text).contains(CanonicalWhitespaceResolver.normalize(definition.evidence.text)) })
        return try XCTUnwrap(IntelligenceSource(source: LearningSource(documentID: analysis.documentID, pageIndex: page.pageIndex, sourceText: paragraph.text),
                                                analysis: analysis))
    }

    /// The comparison Teach It Back runs, and the same comparison read with words only (V35).
    private func teach(_ text: String, _ name: String) throws -> (teachBack: UnderstandingAssessment, wordsOnly: UnderstandingAssessment, evidence: [LearningEvidence]) {
        let source = try cardSource(name)
        let assessed = try XCTUnwrap(TeachBack.assessment(text, source: source, knowledge: kb, at: now))
        let target = try XCTUnwrap(DiagnosisTarget.passage(source.passage, in: kb))
        let words = UnderstandingDiagnoser(semantics: nil).assess(text, target: target)
        let evidence = LearnerEvidenceMapper(knowledge: kb).evidence(from: assessed.assessment, documentID: analysis.documentID, identity: "teach", at: now)
        return (assessed.assessment, words, evidence)
    }

    func testARightExplanationInOtherWordsIsReadForWhatItSaysAndAskedAbout() throws {
        // "Logged-in" for "authenticated", "permitted" for "allowed": words only, nothing comparable.
        let text = "Authorization is deciding what a logged-in person is permitted to do, like letting everyone read reports but only admins delete accounts."
        let read = try teach(text, "Authorization")
        XCTAssertEqual(read.wordsOnly.judgement.state, .insufficientEvidence)
        XCTAssertEqual(read.teachBack.judgement.state, .mostlyUnderstood)
        XCTAssertTrue(read.teachBack.judgement.hypotheses.contains { $0.cue == .semanticCoverage })
        XCTAssertTrue(read.teachBack.judgement.needsEvidence, "meaning is asked about before anything is recorded")
        XCTAssertTrue(read.evidence.isEmpty)
        XCTAssertNotEqual(read.teachBack.judgement.state, .misconception)
    }

    func testAFluentExplanationWithAReasonTheSourceDoesNotGiveIsAskedAboutNotCredited() throws {
        let text = "An index makes lookups on a column quicker, because the database remembers the answers of earlier queries and returns them at once."
        let read = try teach(text, "Database index")
        XCTAssertNil(read.wordsOnly.judgement.question, "words only, the conclusion is credited as it stands")
        XCTAssertEqual(read.teachBack.judgement.state, .weakReasoning)
        let question = try XCTUnwrap(read.teachBack.judgement.question)
        XCTAssertEqual(question.between.first, .weakReasoning)
        XCTAssertEqual(question.operation, .mechanism, "the question asks for the reason")
        XCTAssertTrue(read.evidence.isEmpty)
        XCTAssertEqual(read.teachBack.diagnosis.intervention.message, "Your conclusion matches your source, but Leu can't find the reason you give in it.")
        // The study session follows it up with that question.
        var attempt = UnderstandingAttempt(source: try cardSource("Database index"), learnerExplanation: text, createdAt: now)
        attempt.result = try XCTUnwrap(TeachBack.assessment(text, source: try cardSource("Database index"), knowledge: kb, at: now)).result
        let pending = TeachBackFollowThrough.pending(attempts: [attempt], model: LearnerModelState(), analyses: [analysis.documentID: analysis],
                                                     now: now.addingTimeInterval(86_400))
        XCTAssertEqual(pending.map(\.kind), [.discriminate])
    }
}
