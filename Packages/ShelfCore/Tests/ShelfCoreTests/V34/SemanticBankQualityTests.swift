import XCTest
@testable import ShelfCore

final class SemanticBankQualityTests: XCTestCase {
    private func question(_ prompt: String, _ options: [String], key: String = "semantic|test|v4") -> LearningQuestion {
        let choices = options.map { QuestionOption(text: $0) }
        return LearningQuestion(stableKey: key + "|" + prompt, kind: .semanticRelationship, prompt: prompt, options: choices,
                                correctOptionID: choices[0].id, source: LearningSource(documentID: UUID(), pageIndex: 0, sourceText: "x"),
                                qualityScore: 0.7)
    }
    private let concepts = ["Hashing", "Encryption", "Access token", "Refresh token"]
    private let answers = ["referential integrity between records", "the order of rows in a table", "the size of an index file"]

    func testMalformedStemsFromTheBaselineBankAreRejected() {
        for prompt in ["What does Two request?", "What does Many request?", "What does an HTTP request?",
                       "What does an array method that return?", "What does then select?", "What does failed request?",
                       "What does a React component is a function that return?", "What does How browser request?"] {
            XCTAssertNotNil(SemanticStemGate.rejectionReason(question(prompt, answers)), prompt)
        }
    }

    func testWellFormedStemsAreKept() {
        for prompt in ["What does a foreign key protect?", "What does API return?", "What does createCounter() return?",
                       "What do Embeddings enable?", "What does a model select?", "What does jitter prevent?"] {
            XCTAssertNil(SemanticStemGate.rejectionReason(question(prompt, answers)), prompt)
        }
    }

    func testConceptRecognitionNeedsADescriptionAndRealConceptOptions() {
        XCTAssertNotNil(SemanticStemGate.rejectionReason(question("Which concept is described as retrieved?", concepts)))
        XCTAssertNotNil(SemanticStemGate.rejectionReason(question("Which concept is described as PRIMARY KEY?", concepts)))
        XCTAssertNotNil(SemanticStemGate.rejectionReason(question("Which concept is described as just thin copies of an ORM with no value?",
            ["Do not add repositories that", "const declared inside a block", "Authorization answers \"what", "Hashing"])))
        XCTAssertNil(SemanticStemGate.rejectionReason(question("Which concept is described as an impossible value?", ["never", "unknown", "any", "Array"])))
        XCTAssertNil(SemanticStemGate.rejectionReason(question("Which concept is described as intended to be one-way?", concepts)))
    }

    func testOnlyTheLegacySemanticBankIsGated() {
        XCTAssertNil(SemanticStemGate.rejectionReason(question("What does Two request?", answers, key: "probe")))
    }

    func testOnePromptWithTwoAnswersIsAmbiguous() {
        let a = question("What is meant by HTTP?", ["a stateless request-response protocol", "a", "b"])
        let b = question("What is meant by http?", ["stateless, so sessions provide continuity", "a", "b"])
        let c = question("What does a foreign key protect?", answers)
        XCTAssertEqual(SemanticStemGate.ambiguousPrompts([a, b, c]), ["what is meant by http?"])
    }

    func testStoredBanksLoseTheirAmbiguousPromptsToo() {
        let document = UUID()
        func stored(_ prompt: String, _ answer: String, key: String) -> LearningQuestion {
            let choices = [answer, "the order of rows in a table", "the size of an index file"].map { QuestionOption(text: $0) }
            return LearningQuestion(stableKey: key, kind: .semanticRelationship, prompt: prompt, options: choices, correctOptionID: choices[0].id,
                                    source: LearningSource(documentID: document, pageIndex: 0, sourceText: "x"), qualityScore: 0.7)
        }
        var snapshot = LearningSnapshot()
        snapshot.questions = [stored("What does a foreign key protect?", "referential integrity between records", key: "semantic|a"),
                              stored("What does a foreign key protect?", "the link between two related tables", key: "semantic|b"),
                              stored("What does a unique constraint protect?", "one row per email address", key: "semantic|c"),
                              stored("What does a foreign key protect?", "referential integrity between records", key: "v3|d"),
                              stored("What does a foreign key protect?", "the link between two related tables", key: "v3|e")]
        DerivedExtractionMigration.apply(to: &snapshot)
        XCTAssertEqual(snapshot.questions.map(\.stableKey), ["semantic|c", "v3|d", "v3|e"],
                       "the two semantic questions sharing a prompt go; V3 questions are never touched")
    }

    func testTheManualsBankIsFastDeterministicAndClean() {
        let analysis = LearningCorpus.analysis("Mobile Mastery")
        let index = SemanticCompiler().compile(analysis)
        let start = Date()
        let bank = SemanticQuestionCompiler().compile(index: index, analysis: analysis)
        let seconds = Date().timeIntervalSince(start)
        XCTAssertLessThan(seconds, 30, "was 87 s before V34 (debug build)")
        XCTAssertEqual(bank.map(\.id), SemanticQuestionCompiler().compile(index: index, analysis: analysis).map(\.id))
        XCTAssertGreaterThan(bank.count, 300)
        XCTAssertTrue(SemanticStemGate.ambiguousPrompts(bank).isEmpty)
        XCTAssertTrue(bank.allSatisfy { FinalMCQAdmission.rejectionReason($0, analysis: analysis) == nil })
        print("SEMANTIC|seconds=\(seconds)|questions=\(bank.count)")
    }
}
