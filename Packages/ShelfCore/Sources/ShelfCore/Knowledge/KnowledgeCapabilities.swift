import Foundation

public protocol PassageIndexing: Sendable {
    func index(analysis: DocumentAnalysis, concepts: [KnowledgeConcept], aliases: [ConceptAlias]) -> KnowledgeDocumentBundle
}

public protocol ConnectionRanking: Sendable {
    func related(to source: KnowledgePassage, snapshot: KnowledgeSnapshot,
                 limit: Int, minimumScore: Double) -> [RankedKnowledgeConnection]
}

public protocol KnowledgeSearching: Sendable {
    func search(_ query: String, in snapshot: KnowledgeSnapshot, limit: Int) -> KnowledgeSearchResult
}

extension KnowledgePipeline: PassageIndexing {}
extension ConnectionRanker: ConnectionRanking {}
extension KnowledgeSearchEngine: KnowledgeSearching {}
