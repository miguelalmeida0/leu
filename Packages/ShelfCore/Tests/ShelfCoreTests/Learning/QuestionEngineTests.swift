import XCTest
@testable import ShelfCore

final class QuestionEngineTests: XCTestCase {
    private let engine = DeterministicQuestionEngine()
    private let documentID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

    func testDefinitionsGenerateSourceBoundQuestions() {
        let analysis = makeAnalysis([
            "A closure is a function together with its lexical environment.",
            "A promise is an object representing an eventual result.",
            "A microtask is work scheduled before the next task.",
            "A component is a reusable unit of interface behavior."
        ])
        let questions = engine.generate(from: analysis)
        XCTAssertFalse(questions.isEmpty)
        for question in questions {
            XCTAssertEqual(question.source.documentID, documentID)
            XCTAssertNotNil(question.correctOption)
            XCTAssertEqual(Set(question.options.map { $0.text.lowercased() }).count, question.options.count)
            XCTAssertTrue(engine.validate(question))
        }
    }


    func testAdditionalTemplatesStaySourceBound() {
        let analysis = makeAnalysis([
            "A closure is a function together with its lexical environment.",
            "A promise is an object representing an eventual result.",
            "A microtask is work scheduled before the next task.",
            "A component is a reusable unit of interface behavior."
        ])
        let questions = engine.generate(from: analysis)
        XCTAssertTrue(questions.contains { $0.kind == .termMatching })
        XCTAssertTrue(questions.contains { $0.kind == .definition })
        XCTAssertTrue(questions.allSatisfy { $0.semanticFingerprint != nil && $0.propositionID != nil })
        XCTAssertFalse(questions.contains { $0.kind == .sourceStatement || $0.kind == .listMembership || $0.kind == .cloze })
        for question in questions {
            XCTAssertEqual(question.source.documentID, documentID)
            XCTAssertTrue(engine.validate(question))
        }
    }

    func testOutputIsDeterministic() {
        let analysis = makeAnalysis([
            "A closure is a function together with its lexical environment.",
            "A promise is an object representing an eventual result.",
            "A microtask is work scheduled before the next task."
        ])
        let first = engine.generate(from: analysis)
        let second = engine.generate(from: analysis)
        XCTAssertEqual(first.map(\.id), second.map(\.id))
        XCTAssertEqual(first.map { $0.options.map(\.id) }, second.map { $0.options.map(\.id) })
    }

    func testQualityEvaluatorRejectsDuplicateAndMalformedOptions() {
        let source = LearningSource(documentID: UUID(), pageIndex: 0, sourceText: "A closure preserves lexical context.")
        let correct = QuestionOption(text: "Lexical context")
        let duplicate = QuestionOption(text: "Lexical context")
        let other = QuestionOption(text: "Network cache")
        let question = LearningQuestion(
            stableKey: "bad", kind: .sourceStatement, prompt: "Which statement?",
            options: [correct, duplicate, other], correctOptionID: correct.id, source: source, qualityScore: 1
        )
        XCTAssertFalse(QuestionQualityEvaluator().accepts(question))
    }

    func testInsufficientDataCreatesNoFabricatedQuestions() {
        let analysis = makeAnalysis(["Hello world."])
        XCTAssertTrue(engine.generate(from: analysis).isEmpty)
    }

    func testCorrectDefinitionAppearsExactlyOnce() {
        let analysis = makeAnalysis([
            "Cache control is a set of directives for HTTP caching behavior.",
            "A transaction is a unit of database work that commits atomically.",
            "Authorization is a decision about what an identity may access."
        ])
        for question in engine.generate(from: analysis) where question.kind == .definition {
            let correct = question.correctOption!.text.lowercased()
            XCTAssertEqual(question.options.filter { $0.text.lowercased() == correct }.count, 1)
        }
    }


    func testProgressiveHintsDoNotRevealCorrectAnswerBeforeReveal() {
        let source = LearningSource(documentID: documentID, pageIndex: 4,
                                    sourceText: "A microtask is work scheduled before the next task.",
                                    sectionTitle: "Event Loop")
        let correct = QuestionOption(text: "microtask")
        let b = QuestionOption(text: "timer")
        let c = QuestionOption(text: "render")
        let question = LearningQuestion(stableKey: "hint", kind: .cloze, prompt: "Which term?",
                                        options: [correct, b, c], correctOptionID: correct.id, source: source, qualityScore: 0.9)
        let hints = ProgressiveHintBuilder().hints(for: question, topicName: "JavaScript")
        XCTAssertFalse(hints.isEmpty)
        for hint in hints where hint.level >= 2 {
            XCTAssertFalse(hint.text.localizedCaseInsensitiveContains("microtask"))
        }
    }

    private func makeAnalysis(_ paragraphs: [String]) -> DocumentAnalysis {
        let segments = paragraphs.enumerated().map { index, text in
            SourceSegment(pageIndex: index, kind: .definition, text: text, sectionTitle: "Concepts", importance: 0.9)
        }
        return DocumentAnalysis(documentID: documentID, fingerprint: "f", algorithmVersion: 1,
            pages: segments.map { AnalyzedPage(pageIndex: $0.pageIndex, normalizedText: $0.text, segments: [$0]) })
    }
}
