import XCTest
@testable import ShelfCore

final class BugfixSafetyTests: XCTestCase {
    func testMemoryLabelProtectsEveryClauseAndReaderGuideHasNoIntelligence() {
        let text = "MEMORY HTML is the recipe; the DOM is the live cake sitting on the table."
        let evidence = SemanticEvidenceSpan(documentID: UUID(), pageIndex: 0, sectionTitle: "WHY", sourceText: text)
        XCTAssertTrue(GeneralClaimExtractor().extract(text, evidence: evidence).isEmpty)
        let page = AnalyzedPage(pageIndex: 1, normalizedText: "How to use this manual\nRead the PLAIN and MEMORY lines first.", segments: [])
        XCTAssertFalse(page.isIntelligenceEligible)
        XCTAssertFalse(InstructionalText.isReaderGuidePage("How to use this API\nYour browser may cache responses."))
    }
    func testTechnicalSecondPersonIsNotAnInstruction() {
        for text in ["When you call setState, React schedules an update.", "Your browser may reuse a cached response.",
                     "If you mutate the object, the reference stays the same."] {
            XCTAssertFalse(InstructionalText.isReaderInstruction(text), text)
        }
    }
    func testActualStudyInstructionsAreRejected() {
        for text in ["Do not memorize this word-for-word.", "Read this section first.", "Try answering before revealing.",
                     "Swipe to continue.", "Use this page to study.", "Keep the following structure."] {
            XCTAssertTrue(InstructionalText.isReaderInstruction(text), text)
        }
    }
    func testDegradedPageRetainsCanonicalSearchTextButNoClaimsQuestionsOrPackets() throws {
        let source = "A cache is a reusable store for recent responses. A queue is an ordered buffer of pending requests."
        var bad = SourcePageInput(pageIndex: 0, text: source); bad.spatialIntegrityPassed = false
        var good = SourcePageInput(pageIndex: 1, text: source); good.spatialIntegrityPassed = true
        var analysis = DocumentAnalyzer().analyze(documentID: UUID(), fingerprint: "same-pdf", pages: [bad, good])
        analysis.extractionVersion = SourceExtractionVersion.current
        XCTAssertEqual(analysis.pages[0].normalizedText, source)
        XCTAssertEqual(analysis.pages[0].canonicalText, source)
        XCTAssertTrue(analysis.pages[0].segments.isEmpty)
        XCTAssertFalse(analysis.pages[1].segments.isEmpty)
        XCTAssertNil(LearningSourcePacket(analysis: analysis, page: analysis.pages[0]))
        let semantic = SemanticCompiler().compile(analysis)
        XCTAssertFalse(semantic.propositions.contains { $0.evidence.pageIndex == 0 })
        XCTAssertTrue(semantic.propositions.contains { $0.evidence.pageIndex == 1 })
        XCTAssertFalse(DeterministicQuestionEngine().generate(from: analysis).contains { $0.source.pageIndex == 0 })
        let decoded = try JSONDecoder().decode(SourcePageInput.self, from: JSONEncoder().encode(bad))
        XCTAssertEqual(decoded.spatialIntegrityPassed, false, "Extraction checkpoints must retain degraded status")
        let reopened = try JSONDecoder().decode(DocumentAnalysis.self, from: JSONEncoder().encode(analysis))
        XCTAssertFalse(reopened.pages[0].isIntelligenceEligible)
    }
    func testForgedSegmentsOnDegradedPageCannotReachSemanticCompiler() {
        var page = AnalyzedPage(pageIndex: 0, normalizedText: "A cache is a reusable store for responses.", segments: [
            SourceSegment(pageIndex: 0, kind: .definition, text: "A cache is a reusable store for responses.")])
        page.spatialIntegrityPassed = false
        let analysis = DocumentAnalysis(documentID: UUID(), fingerprint: "pdf", algorithmVersion: 2, pages: [page])
        XCTAssertTrue(SemanticCompiler().compile(analysis).propositions.isEmpty)
    }
    func testMigrationPreservesHistoryAndAuthoredObjects() throws {
        let id = UUID(), questionID = UUID()
        let source = LearningSource(documentID: id, pageIndex: 0, sourceText: "Old derived material")
        let old = LearningObject(type: .passage, source: source, title: "Old", origin: .documentAnalysis)
        let authored = LearningObject(type: .recall, source: source, title: "My note", origin: .userAuthored)
        var analysis = DocumentAnalysis(documentID: id, fingerprint: "unchanged", algorithmVersion: 2, pages: [])
        analysis.extractionVersion = SourceExtractionVersion.current - 1
        var snapshot = LearningSnapshot(analyses: [id: analysis], learningObjects: [old, authored])
        snapshot.reviewStates[old.id] = ReviewState(learningObjectID: old.id)
        snapshot.attempts = [LearningAttempt(learningObjectID: old.id, questionID: questionID, rating: .difficult, wasCorrect: false, confidence: .certain)]
        snapshot.confidenceRecords = [ConfidenceRecord(questionID: questionID, propositionID: nil, confidence: .certain, wasCorrect: false)]
        snapshot.relationships = [LearningRelationship(sourceObjectID: old.id, targetObjectID: authored.id, kind: .custom, customLabel: "My link")]
        snapshot.trails = [LearningTrail(title: "My trail", nodes: [TrailNode(kind: .learningObject, referenceID: old.id, title: "My step")])]
        snapshot.sessions = [StudySession(requestedMinutes: 5, activities: [StudyActivity(kind: .recall, learningObjectID: old.id, title: "Prior recall", estimatedSeconds: 60)], completedAt: Date())]
        let before = snapshot
        XCTAssertTrue(DerivedExtractionMigration.apply(to: &snapshot))
        XCTAssertEqual(snapshot.learningObjects.first { $0.id == old.id }?.sourceIsStale, true)
        XCTAssertEqual(snapshot.learningObjects.first { $0.id == authored.id }, authored)
        XCTAssertEqual(snapshot.attempts, before.attempts)
        XCTAssertEqual(snapshot.reviewStates, before.reviewStates)
        XCTAssertEqual(snapshot.confidenceRecords, before.confidenceRecords)
        XCTAssertEqual(snapshot.sessions, before.sessions)
        XCTAssertEqual(snapshot.relationships, before.relationships)
        XCTAssertEqual(snapshot.trails, before.trails)
        XCTAssertEqual(snapshot.analyses, before.analyses, "Keep canonical reading/search pending reindex")
        XCTAssertFalse(DerivedExtractionMigration.apply(to: &snapshot), "Migration is idempotent")
    }
    func testFinalGateRejectsGiantAndSectionLabelOptions() {
        let options = [QuestionOption(text: "the same person"), QuestionOption(text: "a different object"),
            QuestionOption(text: Array(repeating: "long distractor", count: 30).joined(separator: " "))]
        let q = LearningQuestion(stableKey: "old", kind: .definition, prompt: "Which definition describes the source concept?",
            options: options, correctOptionID: options[0].id,
            source: LearningSource(documentID: UUID(), pageIndex: 0, sourceText: "A source defines the same person."), qualityScore: 0.8)
        XCTAssertNotNil(FinalMCQAdmission.rejectionReason(q))
        var label = q; label.options[2].text = "other person R E A L E X A M P L E"
        XCTAssertEqual(FinalMCQAdmission.rejectionReason(label), "section_label_option")
    }
}
