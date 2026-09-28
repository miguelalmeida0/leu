import Foundation
@testable import ShelfCore

/// Real-text evaluation corpus built from PDFs already in the repository
/// (Tests/Fixtures/tools/build_corpus.py approximates the app's PDFKit block reconstruction).
/// Pages are analysed exactly as the app does: reconstructed blocks feed DocumentAnalyzer,
/// the raw page string becomes the canonical text, and spatial integrity is verified.
enum LearningCorpus {
    struct Page: Decodable { let text: String; let canonical: String }
    struct Document: Decodable { let title: String; let pages: [Page] }

    static var fixtures: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Fixtures")
    }

    static let documents: [Document] = {
        let data = try! Data(contentsOf: fixtures.appendingPathComponent("leu-real-corpus.json"))
        return try! JSONDecoder().decode([Document].self, from: data)
    }()

    static let analyses: [String: DocumentAnalysis] = {
        var result: [String: DocumentAnalysis] = [:]
        for document in documents { result[document.title] = analyse(document) }
        return result
    }()

    static func analyse(_ document: Document) -> DocumentAnalysis {
        let inputs = document.pages.enumerated().map { index, page -> SourcePageInput in
            var input = SourcePageInput(pageIndex: index, text: page.text)
            input.spatialIntegrityPassed = true
            return input
        }
        var analysis = DocumentAnalyzer().analyze(documentID: StableIdentity.uuid("corpus|" + document.title),
            fingerprint: String(StableIdentity.hash64(document.title + "|v34")), pages: inputs)
        analysis.extractionVersion = SourceExtractionVersion.current
        for index in analysis.pages.indices { analysis.pages[index].canonicalText = document.pages[index].canonical }
        return analysis
    }

    static func analysis(_ title: String) -> DocumentAnalysis { analyses[title]! }

    static let knowledge: [String: ConceptKnowledgeBase] = {
        var result: [String: ConceptKnowledgeBase] = [:]
        for (title, analysis) in analyses { result[title] = ConceptKnowledgeCompiler().compile(analysis) }
        return result
    }()

    static var mastery: ConceptKnowledgeBase { knowledge["Mobile Mastery"]! }
}
