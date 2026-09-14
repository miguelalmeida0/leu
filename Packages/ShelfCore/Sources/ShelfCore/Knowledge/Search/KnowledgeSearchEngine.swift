import Foundation

public struct KnowledgeSearchResult: Equatable, Sendable {
    public var concepts: [KnowledgeConcept]
    public var passages: [KnowledgePassage]
    public var chains: [TopicChain]
    public var documentIDs: [UUID]

    public init(concepts: [KnowledgeConcept] = [], passages: [KnowledgePassage] = [],
                chains: [TopicChain] = [], documentIDs: [UUID] = []) {
        self.concepts = concepts; self.passages = passages; self.chains = chains; self.documentIDs = documentIDs
    }
}

public struct KnowledgeSearchEngine: Sendable {
    private let tokenizer = TechnicalTokenizer()
    public init() {}

    public func search(_ query: String, in snapshot: KnowledgeSnapshot, limit: Int = 50) -> KnowledgeSearchResult {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count >= 2 else { return KnowledgeSearchResult() }
        let queryTokens = tokenizer.tokens(in: clean)
        let queryPhrases = tokenizer.phraseCounts(in: clean).keys.map { $0 }
        let bm25 = BM25Index(records: snapshot.indexRecords)
        let hits = bm25.search(terms: queryTokens, phrases: queryPhrases, limit: limit)
        let passageMap = Dictionary(uniqueKeysWithValues: snapshot.passages.map { ($0.id, $0) })
        let passages = hits.compactMap { passageMap[$0.passageID] }.filter(\.isAvailable)

        let aliasMap = snapshot.aliases.reduce(into: [UUID: [String]]()) { $0[$1.conceptID, default: []].append($1.value) }
        let folded = clean.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let concepts = snapshot.concepts.compactMap { concept -> (KnowledgeConcept, Int)? in
            let names = [concept.name] + aliasMap[concept.id, default: []]
            let exact = names.contains { $0.compare(clean, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
            let partial = names.contains { $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).contains(folded) }
            return exact ? (concept, 2) : (partial ? (concept, 1) : nil)
        }.sorted { lhs, rhs in lhs.1 == rhs.1 ? lhs.0.name < rhs.0.name : lhs.1 > rhs.1 }.map(\.0)

        let chains = snapshot.topicChains.filter { chain in
            chain.title.localizedCaseInsensitiveContains(clean) || chain.items.contains { ($0.annotation ?? "").localizedCaseInsensitiveContains(clean) }
        }.sorted { $0.updatedAt > $1.updatedAt }

        var docScores: [UUID: Int] = [:]
        for passage in passages { docScores[passage.documentID, default: 0] += 1 }
        let documentIDs = docScores.sorted { lhs, rhs in lhs.value == rhs.value ? lhs.key.uuidString < rhs.key.uuidString : lhs.value > rhs.value }.map(\.key)
        return KnowledgeSearchResult(concepts: Array(concepts.prefix(12)), passages: Array(passages.prefix(limit)),
                                     chains: Array(chains.prefix(20)), documentIDs: documentIDs)
    }
}
