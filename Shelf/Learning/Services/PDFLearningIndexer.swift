import Foundation
import ShelfCore

struct LearningIndexBundle: Sendable {
    let analysis: DocumentAnalysis
    let topics: [TopicClassification]
    let questions: [LearningQuestion]
    let semanticIndex: SemanticIndex
    let hasUsableText: Bool
    let degradedPages: [Int]
}

actor PDFLearningIndexer {
    private let extractor: any PDFTextExtracting
    private let analyzer: any DocumentAnalyzing
    private let classifier: any TopicClassifying
    private let questionEngine: any QuestionGenerating
    private var currentProgress: Double = 0

    init(extractor: any PDFTextExtracting = PDFKitTextExtractor(),
         analyzer: any DocumentAnalyzing = DocumentAnalyzer(),
         classifier: any TopicClassifying = TopicClassifier(),
         questionEngine: any QuestionGenerating = DeterministicQuestionEngine()) {
        self.extractor = extractor
        self.analyzer = analyzer
        self.classifier = classifier
        self.questionEngine = questionEngine
    }

    func progressValue() -> Double { currentProgress }

    func index(book: Book, url: URL) async throws -> LearningIndexBundle {
        currentProgress = 0
        let extraction = try await extractor.extract(documentID: book.id, fingerprint: book.fingerprint, url: url) { [weak self] fraction in
            await self?.setProgress(fraction * 0.72)
        }
        try Task.checkCancellation()
        currentProgress = 0.76
        let inputs = extraction.pages.map { page -> SourcePageInput in
            var page = page
            if extraction.degradedPages.contains(page.pageIndex) {
                page.spatialIntegrityPassed = false
                page.text = extraction.canonicalPages[page.pageIndex] ?? page.text
            }
            return page
        }
        var analysis = analyzer.analyze(documentID: book.id, fingerprint: book.fingerprint,
                                        pages: inputs)
        analysis.extractionVersion = PDFKitTextExtractor.extractionVersion
        for index in analysis.pages.indices {
            analysis.pages[index].canonicalText = extraction.canonicalPages[analysis.pages[index].pageIndex]
        }
        try Task.checkCancellation()
        currentProgress = 0.86
        let pageTexts = analysis.pages.filter(\.isIntelligenceEligible).map(\.normalizedText)
        let topics = classifier.classify(title: book.title, filename: book.originalFilename,
                                         outline: extraction.outlineTitles, texts: pageTexts)
        try Task.checkCancellation()
        currentProgress = 0.92
        let topicIDs = Set(topics.filter { $0.score >= 0.18 }.map(\.topic.id))
        let semanticIndex = SemanticCompiler().compile(analysis)
        let questions = SemanticQuestionCompiler().compile(index: semanticIndex, topicIDs: topicIDs, analysis: analysis)
        StudyInteractionTrace.record("index.compile document=\(book.id) claims=\(semanticIndex.propositions.filter { $0.claim != nil }.count) quizTruth=\(semanticIndex.propositions.filter(\.isQuizTruth).count) accepted=\(questions.count)")
        try Task.checkCancellation()
        currentProgress = 1
        return LearningIndexBundle(analysis: analysis, topics: topics, questions: questions, semanticIndex: semanticIndex,
                                   hasUsableText: extraction.nonEmptyCharacters >= 80,
                                   degradedPages: extraction.degradedPages)
    }

    func commitCompleted(documentID: UUID) async {
        await extractor.clearCheckpoint(documentID: documentID)
    }

    private func setProgress(_ value: Double) {
        currentProgress = min(max(value, 0), 1)
    }
}
