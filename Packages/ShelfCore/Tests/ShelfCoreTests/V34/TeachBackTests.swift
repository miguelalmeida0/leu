import XCTest
@testable import ShelfCore

final class TeachBackTests: XCTestCase {
    private var analysis: DocumentAnalysis { LearningCorpus.analysis("Mobile Mastery") }
    private var kb: ConceptKnowledgeBase { LearningCorpus.mastery }

    private func cardSource(_ name: String) throws -> IntelligenceSource {
        let definition = try XCTUnwrap(kb.definition(of: ConceptKey(name)))
        let page = try XCTUnwrap(analysis.pages.first { $0.pageIndex == definition.evidence.pageIndex })
        let paragraph = try XCTUnwrap(page.segments.first { CanonicalWhitespaceResolver.normalize($0.text).contains(CanonicalWhitespaceResolver.normalize(definition.evidence.text)) })
        return try XCTUnwrap(IntelligenceSource(source: LearningSource(documentID: analysis.documentID, pageIndex: page.pageIndex,
                                                                        sourceText: paragraph.text), analysis: analysis))
    }

    func testConceptCardsCanBeTaughtBackWhereTheOldComparisonCouldNotRun() throws {
        let source = try cardSource("Debouncing")
        let old = TeachLeuValidator.evaluate("Debouncing waits until typing stops before searching.", source: source)
        let result = try XCTUnwrap(TeachBack.assess("Debouncing waits until a burst of events has been quiet for a chosen interval before running the action.",
                                                    source: source, knowledge: kb))
        XCTAssertTrue(old.supported.isEmpty, "V27 recognised only exact sentences")
        XCTAssertFalse(result.supported.isEmpty)
        XCTAssertTrue(result.supported.contains { $0.description.contains("delaying an action until a burst of events") })
        XCTAssertEqual(result.backend, TeachBack.backend)
        XCTAssertNotNil(result.diagnosis?.intervention.followUp, "there is always a next step")
    }

    func testAPartialExplanationIsToldWhichIdeaIsMissingWithoutBeingGivenIt() throws {
        let source = try cardSource("Foreign key")
        let result = try XCTUnwrap(TeachBack.assess("A foreign key is a column whose value has to point at a key in a different table.",
                                                    source: source, knowledge: kb))
        let diagnosis = try XCTUnwrap(result.diagnosis)
        let purpose = try XCTUnwrap(kb.claims(teaching: ConceptKey("Foreign key")).first { $0.statement.contains("referential integrity") })
        XCTAssertTrue(result.omitted.contains { $0.id == purpose.id }, "worth adding: the purpose")
        XCTAssertEqual(diagnosis.intervention.kind, .cueMissingIdea)
        let question = try XCTUnwrap(diagnosis.intervention.followUp?.prompt)
        XCTAssertFalse(question.lowercased().contains("referential integrity"), "the cue asks for the idea, it does not reveal it")
    }

    func testOnlyAnExplanationCoveringEveryIdeaIsToldSo() throws {
        let source = try cardSource("Foreign key")
        let mapper = LearnerEvidenceMapper(knowledge: kb), at = Date(timeIntervalSinceReferenceDate: 0)
        let words = try XCTUnwrap(TeachBack.assess("constraint linking value one table key another table referential integrity records",
                                                   source: source, knowledge: kb))
        let listed = try XCTUnwrap(words.diagnosis)
        XCTAssertEqual(listed.level, .insufficient, "keywords say nothing about how the ideas relate")
        XCTAssertTrue(words.supported.isEmpty)
        XCTAssertTrue(mapper.evidence(from: listed, documentID: analysis.documentID, at: at).isEmpty)

        let partly = try XCTUnwrap(TeachBack.assess("A foreign key is a column whose value has to point at a key in a different table. It relates records.",
                                                    source: source, knowledge: kb))
        let diagnosis = try XCTUnwrap(partly.diagnosis)
        let purpose = try XCTUnwrap(kb.claims(teaching: ConceptKey("Foreign key")).first { $0.evidence.text.contains("referential integrity") })
        XCTAssertEqual(diagnosis.claims.first { $0.claimID == purpose.id }?.coverage, .partial)
        XCTAssertNotEqual(diagnosis.intervention.kind, .deepen, "a half-stated idea is cued, never called complete")
        XCTAssertFalse(partly.supported.contains { $0.claimID == purpose.id }, "a touched idea is not listed as captured")
        XCTAssertTrue(partly.omitted.contains { $0.id == purpose.id }, "it is worth adding, in the source's words")
        XCTAssertFalse(mapper.evidence(from: diagnosis, documentID: analysis.documentID, at: at)
                        .contains { $0.outcome == .correct && $0.claimIDs.contains(purpose.id) })
    }

    func testCopyingTheSourceIsAskedForOwnWordsAndEarnsOnlyPartialCredit() throws {
        let source = try cardSource("Foreign key")
        let result = try XCTUnwrap(TeachBack.assess("A foreign key is a constraint linking a value in one table to a key in another table.",
                                                    source: source, knowledge: kb))
        let diagnosis = try XCTUnwrap(result.diagnosis)
        XCTAssertTrue(diagnosis.issues.contains { $0.kind == .verbatim })
        XCTAssertEqual(diagnosis.intervention.kind, .explainInOwnWords)
        let evidence = LearnerEvidenceMapper(knowledge: kb).evidence(from: diagnosis, documentID: analysis.documentID, at: Date(timeIntervalSinceReferenceDate: 0))
        XCTAssertFalse(evidence.isEmpty)
        XCTAssertFalse(evidence.contains { $0.outcome == .correct }, "remembering the words is not yet understanding them")
    }

    func testFeedbackQuotesOnlyTheSourcesOwnWords() throws {
        let source = try cardSource("Foreign key")
        let result = try XCTUnwrap(TeachBack.assess("A foreign key does not protect referential integrity between related records.",
                                                    source: source, knowledge: kb))
        let challenge = try XCTUnwrap(result.challenged.first)
        XCTAssertTrue(challenge.explanation.contains("Under “Foreign key”, your source says: “It protects referential integrity between related records”"),
                      challenge.explanation)
        XCTAssertFalse(challenge.explanation.contains("“Foreign key protects"), "Leu's reading of “It” is never presented as the source's words")
    }

    func testAWrongExplanationIsShownBesideTheSourceSentence() throws {
        let source = try cardSource("Encryption")
        let result = try XCTUnwrap(TeachBack.assess("Encryption is a one-way transformation that cannot be reversed.", source: source, knowledge: kb))
        let challenge = try XCTUnwrap(result.challenged.first)
        XCTAssertEqual(challenge.learnerText, "Encryption is a one-way transformation that cannot be reversed.")
        XCTAssertTrue(challenge.explanation.contains("“A reversible transformation that protects data using cryptographic keys”"), challenge.explanation)
        XCTAssertEqual(result.diagnosis?.intervention.kind, .correctContradiction)
    }

    func testStoredResultsAreAdmittedOnlyWhileTheirSourceIsUnchanged() throws {
        let source = try cardSource("Idempotency")
        let explanation = "Idempotency means repeating an operation has the same effect as doing it once."
        let result = try XCTUnwrap(TeachBack.assess(explanation, source: source, knowledge: kb))
        let current = [analysis.documentID: analysis]
        XCTAssertTrue(TeachLeuValidator.isValid(result, explanation: explanation, analyses: current))
        XCTAssertFalse(TeachLeuValidator.isValid(result, explanation: "", analyses: current), "a result belongs to the explanation it was made from")
        XCTAssertFalse(TeachLeuValidator.isValid(result, explanation: "Idempotency is a kind of cache.", analyses: current))
        var changed = analysis
        let index = try XCTUnwrap(changed.pages.firstIndex { $0.pageIndex == source.passage.pageIndex })
        changed.pages[index].canonicalText = (changed.pages[index].canonicalText ?? "") + " Edited."
        XCTAssertFalse(TeachLeuValidator.isValid(result, explanation: explanation, analyses: [analysis.documentID: changed]))
        var forged = result
        forged.diagnosis = nil
        XCTAssertFalse(TeachLeuValidator.isValid(forged, explanation: explanation, analyses: current))
    }

    func testAPassageWithoutGroundedClaimsFallsBackToTheOldComparison() throws {
        let source = try cardSource("Debouncing")
        XCTAssertNil(TeachBack.assess("anything", source: source, knowledge: .empty))
    }

    func testAPageAloneIsEnoughToKnowWhetherTeachingIsPossible() throws {
        let source = try cardSource("Foreign key")
        let start = Date()
        let local = ConceptKnowledgeCompiler().compile(analysis, pageIndices: [source.passage.pageIndex])
        XCTAssertLessThan(Date().timeIntervalSince(start), 1)
        XCTAssertNotNil(DiagnosisTarget.passage(source.passage, in: local))
    }
}
