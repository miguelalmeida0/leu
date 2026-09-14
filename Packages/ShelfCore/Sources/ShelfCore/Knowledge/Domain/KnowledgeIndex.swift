import Foundation

public struct KnowledgeIndexVersion: Codable, Equatable, Sendable {
    public var schema: Int
    public var passageSegmentation: Int
    public var conceptDictionary: Int
    public var ranking: Int

    public init(schema: Int = 1, passageSegmentation: Int = 1,
                conceptDictionary: Int = 1, ranking: Int = 1) {
        self.schema = schema; self.passageSegmentation = passageSegmentation
        self.conceptDictionary = conceptDictionary; self.ranking = ranking
    }

    public static let current = KnowledgeIndexVersion(passageSegmentation: 2)
}

public struct KnowledgeIndexRecord: Codable, Equatable, Sendable {
    public var passageID: UUID
    public var documentID: UUID
    public var termCounts: [String: Int]
    public var phraseCounts: [String: Int]
    public var headingTerms: Set<String>
    public var conceptIDs: Set<UUID>
    public var tokenCount: Int

    public init(passageID: UUID, documentID: UUID, termCounts: [String: Int],
                phraseCounts: [String: Int] = [:], headingTerms: Set<String> = [],
                conceptIDs: Set<UUID> = [], tokenCount: Int) {
        self.passageID = passageID; self.documentID = documentID; self.termCounts = termCounts
        self.phraseCounts = phraseCounts; self.headingTerms = headingTerms
        self.conceptIDs = conceptIDs; self.tokenCount = max(1, tokenCount)
    }
}

public struct ImportAnalysisState: Codable, Equatable, Sendable {
    public var documentID: UUID
    public var fingerprint: String
    public var versions: KnowledgeIndexVersion
    public var indexedAt: Date
    public var passageCount: Int

    public init(documentID: UUID, fingerprint: String, versions: KnowledgeIndexVersion,
                indexedAt: Date = Date(), passageCount: Int) {
        self.documentID = documentID; self.fingerprint = fingerprint; self.versions = versions
        self.indexedAt = indexedAt; self.passageCount = passageCount
    }
}
