import Foundation

public struct KnowledgeSnapshot: Codable, Equatable, Sendable {
    public var schemaVersion: Int

    // Source-derived content. It may be rebuilt, except unavailable tombstones that protect user links.
    public var passages: [KnowledgePassage]
    public var sections: [KnowledgeSection]
    public var chapters: [KnowledgeChapter]

    // Derived index. Safe to rebuild.
    public var indexRecords: [KnowledgeIndexRecord]
    public var importStates: [UUID: ImportAnalysisState]
    public var detectedBindings: [PassageConceptBinding]

    // Curated/user knowledge. Never discard during index cleanup.
    public var concepts: [KnowledgeConcept]
    public var aliases: [ConceptAlias]
    public var userBindings: [PassageConceptBinding]
    public var confirmedConnections: [KnowledgeConnection]
    public var topicChains: [TopicChain]

    public init(schemaVersion: Int = 1, passages: [KnowledgePassage] = [],
                sections: [KnowledgeSection] = [], chapters: [KnowledgeChapter] = [],
                indexRecords: [KnowledgeIndexRecord] = [], importStates: [UUID: ImportAnalysisState] = [:],
                detectedBindings: [PassageConceptBinding] = [], concepts: [KnowledgeConcept] = [],
                aliases: [ConceptAlias] = [], userBindings: [PassageConceptBinding] = [],
                confirmedConnections: [KnowledgeConnection] = [], topicChains: [TopicChain] = []) {
        self.schemaVersion = schemaVersion; self.passages = passages; self.sections = sections
        self.chapters = chapters; self.indexRecords = indexRecords; self.importStates = importStates
        self.detectedBindings = detectedBindings; self.concepts = concepts; self.aliases = aliases
        self.userBindings = userBindings; self.confirmedConnections = confirmedConnections
        self.topicChains = topicChains
    }
}
