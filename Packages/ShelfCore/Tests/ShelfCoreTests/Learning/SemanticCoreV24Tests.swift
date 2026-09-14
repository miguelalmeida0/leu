import XCTest
@testable import ShelfCore

final class SemanticCoreV24Tests: XCTestCase {
    private let documentID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!

    func testCompilerProducesProvenanceAndTypedFact() {
        let analysis = makeAnalysis(["useCallback memoizes a function definition between renders."])
        let index = SemanticCompiler().compile(analysis)
        let fact = index.propositions.first { $0.subjectID == "react.useCallback" }
        XCTAssertEqual(fact?.relation, .memoizes)
        XCTAssertEqual(fact?.confidenceClass, .verified)
        XCTAssertEqual(fact?.evidence.documentID, documentID)
        XCTAssertFalse(fact?.evidence.sourceHash.isEmpty ?? true)
    }

    func testAssociationsNeverBecomeQuizTruth() {
        let paragraphs = [
            "useEffect and useMemo appear together in this discussion.",
            "useEffect and useMemo appear together in another discussion."
        ]
        let index = SemanticCompiler().compile(makeAnalysis(paragraphs))
        XCTAssertFalse(index.associations.isEmpty)
        XCTAssertTrue(index.propositions.allSatisfy { $0.truthClass != .associationCandidate })
    }

    func testSemanticQuestionsHaveFingerprintsAndNoPagePresenceFamily() {
        let analysis = makeAnalysis([
            "A closure is a function together with its lexical environment.",
            "A promise is an object representing an eventual result.",
            "A microtask is work scheduled before the next task.",
            "A component is a reusable unit of interface behavior."
        ])
        let questions = DeterministicQuestionEngine().generate(from: analysis)
        XCTAssertFalse(questions.isEmpty)
        XCTAssertTrue(questions.allSatisfy { $0.semanticFingerprint != nil && $0.propositionID != nil })
        XCTAssertFalse(questions.contains { $0.prompt.localizedCaseInsensitiveContains("appeared on page") })
        XCTAssertEqual(Set(questions.compactMap(\.semanticFingerprint)).count, questions.count)
    }

    func testIdenticalCompilationIsDeterministic() {
        let analysis = makeAnalysis([
            "useMemo memoizes a calculated value.",
            "useCallback memoizes a function definition between renders.",
            "Effects run after React commits updates to the DOM."
        ])
        let first = SemanticCompiler().compile(analysis)
        let second = SemanticCompiler().compile(analysis)
        XCTAssertEqual(first.concepts, second.concepts)
        XCTAssertEqual(first.propositions, second.propositions)
    }

    func testAmbiguousOrUnsupportedTextFailsClosed() {
        let index = SemanticCompiler().compile(makeAnalysis(["It probably does something useful with state."]))
        XCTAssertTrue(index.propositions.isEmpty)
        XCTAssertTrue(SemanticQuestionCompiler().compile(index: index).isEmpty)
    }

    func testCodeParserProducesStructuralFacts() {
        let evidence = SemanticEvidenceSpan(documentID: documentID, pageIndex: 0, sectionTitle: "Code",
                                            sourceText: "const values = await Promise.all(tasks)")
        let parsed = CodeSemanticParser().facts(in: evidence.sourceText, evidence: evidence)
        XCTAssertTrue(parsed.propositions.contains { $0.subjectID == "js.promise.all" && $0.relation == .awaits })
        XCTAssertTrue(parsed.propositions.allSatisfy { $0.truthClass == .structural })
    }


    func testSemanticIndexAndQuestionBankPersistTogether() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let analysis = makeAnalysis([
            "A closure is a function together with its lexical environment.",
            "A promise is an object representing an eventual result.",
            "A microtask is work scheduled before the next task."
        ])
        let index = SemanticCompiler().compile(analysis)
        let questions = SemanticQuestionCompiler().compile(index: index)
        XCTAssertEqual(analysis.extractionVersion, SourceExtractionVersion.current)
        XCTAssertEqual(questions.count, 6)
        let store = FileLearningSnapshotStore(root: root)
        let repo = LearningRepository(persistence: store)
        _ = try await repo.open()
        try await repo.upsertAnalysis(analysis, topics: [], questions: questions, semanticIndex: index)
        let reopened = LearningRepository(persistence: FileLearningSnapshotStore(root: root))
        let snapshot = try await reopened.open()
        XCTAssertEqual(snapshot.semanticIndexes[documentID], index)
        XCTAssertEqual(snapshot.questions.count, 6)
        XCTAssertEqual(Set(snapshot.questions.compactMap(\.semanticFingerprint)), Set(questions.compactMap(\.semanticFingerprint)))

        // The same populated bank must be invalidated when its extraction is old
        // (including unversioned legacy data), without touching durable history.
        for version: Int? in [SourceExtractionVersion.current - 1, nil] {
            var outdated = snapshot
            outdated.analyses[documentID]?.extractionVersion = version
            outdated.attempts = [LearningAttempt(learningObjectID: UUID(), questionID: questions[0].id,
                rating: .difficult, wasCorrect: false, confidence: .certain)]
            try store.save(outdated)
            let durableBefore = try store.load()
            let migrated = try await LearningRepository(persistence: store).open()
            XCTAssertNil(migrated.semanticIndexes[documentID], "Old extraction \(String(describing: version))")
            XCTAssertTrue(migrated.questions.isEmpty)
            XCTAssertEqual(migrated.attempts, durableBefore.attempts)
            let durableAfter = try store.load()
            XCTAssertNil(durableAfter.semanticIndexes[documentID])
            XCTAssertTrue(durableAfter.questions.isEmpty)
            XCTAssertEqual(durableAfter.attempts, durableBefore.attempts)
        }
    }

    private func makeAnalysis(_ paragraphs: [String]) -> DocumentAnalysis {
        let segments = paragraphs.enumerated().map { i, text in
            SourceSegment(pageIndex: i, kind: text.contains("Promise.all") ? .code : .definition,
                          text: text, sectionTitle: "Concepts", importance: 0.9)
        }
        var analysis = DocumentAnalysis(documentID: documentID, fingerprint: "semantic-fixture", algorithmVersion: 1,
                                pages: segments.map { AnalyzedPage(pageIndex: $0.pageIndex, normalizedText: $0.text, segments: [$0]) })
        analysis.extractionVersion = SourceExtractionVersion.current
        return analysis
    }
}
