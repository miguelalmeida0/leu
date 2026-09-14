import Foundation

public struct RankedKnowledgeConnection: Equatable, Sendable {
    public var passage: KnowledgePassage
    public var score: Double
    public var reason: KnowledgeConnectionReason
    public init(passage: KnowledgePassage, score: Double, reason: KnowledgeConnectionReason) {
        self.passage = passage; self.score = score; self.reason = reason
    }
}

public struct ConnectionRanker: Sendable {
    private let tokenizer = TechnicalTokenizer()
    public init() {}

    public func related(to source: KnowledgePassage, snapshot: KnowledgeSnapshot,
                        limit: Int = 7, minimumScore: Double = 2.4) -> [RankedKnowledgeConnection] {
        guard let sourceRecord = snapshot.indexRecords.first(where: { $0.passageID == source.id }) else { return [] }
        let bm25 = BM25Index(records: snapshot.indexRecords)
        let sourceTerms = sourceRecord.termCounts.keys.filter { !TechnicalTokenizer.genericTerms.contains($0) }
        let phrases = sourceRecord.phraseCounts.keys.filter { sourceRecord.phraseCounts[$0, default: 0] > 0 }
        let hits = bm25.search(terms: Array(sourceTerms), phrases: Array(phrases), excluding: source.id, limit: max(50, limit * 10))
        let passageMap = Dictionary(uniqueKeysWithValues: snapshot.passages.map { ($0.id, $0) })
        let recordMap = Dictionary(uniqueKeysWithValues: snapshot.indexRecords.map { ($0.passageID, $0) })
        let conceptMap = Dictionary(uniqueKeysWithValues: snapshot.concepts.map { ($0.id, $0.name) })
        var ranked: [RankedKnowledgeConnection] = []

        for hit in hits {
            guard let candidate = passageMap[hit.passageID], candidate.isAvailable,
                  let record = recordMap[candidate.id] else { continue }
            let sharedConceptIDs = sourceRecord.conceptIDs.intersection(record.conceptIDs)
            let sharedConcepts = sharedConceptIDs.compactMap { conceptMap[$0] }.sorted()
            let sharedPhrases = sourceRecord.phraseCounts.keys.filter { record.phraseCounts[$0] != nil }
                .sorted { lhs, rhs in bm25.idf(lhs) > bm25.idf(rhs) }.prefix(3).map { $0 }
            let sharedTerms = sourceRecord.termCounts.keys.filter { record.termCounts[$0] != nil && !TechnicalTokenizer.genericTerms.contains($0) }
            let rareTerm = sharedTerms.map { bm25.idf($0) }.max() ?? 0
            let headingOverlap = !sourceRecord.headingTerms.intersection(record.headingTerms).isEmpty ? 0.55 : 0
            let conceptBoost = min(2.4, Double(sharedConcepts.count) * 0.9)
            let phraseBoost = min(2.2, Double(sharedPhrases.count) * 0.8)
            let crossBookBoost = candidate.documentID == source.documentID ? 0.0 : 0.35
            let genericOnlyPenalty = sharedTerms.isEmpty && sharedConcepts.isEmpty && sharedPhrases.isEmpty ? 1.4 : 0
            let duplicatePenalty = nearDuplicate(source.normalizedText, candidate.normalizedText) ? 1.25 : 0
            let score = hit.score * 0.42 + conceptBoost + phraseBoost + min(1.1, rareTerm * 0.22) + headingOverlap + crossBookBoost - genericOnlyPenalty - duplicatePenalty
            guard score >= minimumScore else { continue }
            let explanation = explanation(sharedConcepts: sharedConcepts, sharedPhrases: sharedPhrases, sharedTerms: sharedTerms)
            ranked.append(RankedKnowledgeConnection(passage: candidate, score: score,
                reason: KnowledgeConnectionReason(sharedConcepts: sharedConcepts, sharedPhrases: sharedPhrases,
                    sourceHeading: source.sectionTitle, destinationHeading: candidate.sectionTitle,
                    explanation: explanation)))
        }
        return collapseNearDuplicates(ranked).sorted { lhs, rhs in
            lhs.score == rhs.score ? lhs.passage.id.uuidString < rhs.passage.id.uuidString : lhs.score > rhs.score
        }.prefix(max(0, limit)).map { $0 }
    }

    private func explanation(sharedConcepts: [String], sharedPhrases: [String], sharedTerms: [String]) -> String {
        if let concept = sharedConcepts.first { return "Same concept · \(concept)" }
        if !sharedPhrases.isEmpty { return "Related through · " + sharedPhrases.prefix(3).joined(separator: " · ") }
        return "Related through · " + sharedTerms.prefix(3).joined(separator: " · ")
    }

    private func collapseNearDuplicates(_ input: [RankedKnowledgeConnection]) -> [RankedKnowledgeConnection] {
        var kept: [RankedKnowledgeConnection] = []
        for item in input.sorted(by: { $0.score > $1.score }) {
            if kept.contains(where: { nearDuplicate($0.passage.normalizedText, item.passage.normalizedText) }) { continue }
            kept.append(item)
        }
        return kept
    }

    private func nearDuplicate(_ lhs: String, _ rhs: String) -> Bool {
        let a = Set(tokenizer.tokens(in: lhs)), b = Set(tokenizer.tokens(in: rhs))
        guard !a.isEmpty, !b.isEmpty else { return false }
        let ratio = Double(a.intersection(b).count) / Double(a.union(b).count)
        return ratio >= 0.82
    }
}
