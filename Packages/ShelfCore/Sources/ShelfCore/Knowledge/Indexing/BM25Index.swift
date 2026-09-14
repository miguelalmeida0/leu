import Foundation

public struct BM25Hit: Equatable, Sendable {
    public var passageID: UUID
    public var score: Double
    public init(passageID: UUID, score: Double) { self.passageID = passageID; self.score = score }
}

public struct BM25Index: Sendable {
    private let records: [UUID: KnowledgeIndexRecord]
    private let inverted: [String: Set<UUID>]
    private let documentFrequency: [String: Int]
    private let averageLength: Double
    private let count: Int

    public init(records source: [KnowledgeIndexRecord]) {
        records = Dictionary(uniqueKeysWithValues: source.map { ($0.passageID, $0) })
        count = max(1, source.count)
        averageLength = source.isEmpty ? 1 : Double(source.map(\.tokenCount).reduce(0, +)) / Double(source.count)
        var postings: [String: Set<UUID>] = [:]
        for record in source {
            for term in record.termCounts.keys { postings[term, default: []].insert(record.passageID) }
            for phrase in record.phraseCounts.keys { postings[phrase, default: []].insert(record.passageID) }
        }
        inverted = postings
        documentFrequency = postings.mapValues(\.count)
    }

    public func search(terms: [String], phrases: [String] = [], excluding passageID: UUID? = nil,
                       limit: Int = 40) -> [BM25Hit] {
        let queryTerms = Array(Set(terms + phrases.filter { documentFrequency[$0] != nil }))
        var candidateIDs = Set<UUID>()
        for term in queryTerms { candidateIDs.formUnion(inverted[term] ?? []) }
        if let passageID { candidateIDs.remove(passageID) }
        let scored = candidateIDs.compactMap { id -> BM25Hit? in
            guard let record = records[id] else { return nil }
            var score = 0.0
            for term in queryTerms {
                let tf = record.termCounts[term] ?? record.phraseCounts[term] ?? 0
                guard tf > 0 else { continue }
                let df = documentFrequency[term] ?? 0
                let idf = log(1 + (Double(count - df) + 0.5) / (Double(df) + 0.5))
                let length = Double(record.tokenCount)
                let k1 = 1.4, b = 0.72
                let numerator = Double(tf) * (k1 + 1)
                let denominator = Double(tf) + k1 * (1 - b + b * length / max(averageLength, 1))
                let phraseBoost = term.contains(" ") ? 1.85 : 1.0
                score += idf * numerator / max(denominator, 0.0001) * phraseBoost
            }
            return score > 0 ? BM25Hit(passageID: id, score: score) : nil
        }
        return scored.sorted { lhs, rhs in
            lhs.score == rhs.score ? lhs.passageID.uuidString < rhs.passageID.uuidString : lhs.score > rhs.score
        }.prefix(max(0, limit)).map { $0 }
    }

    public func idf(_ term: String) -> Double {
        let df = documentFrequency[term] ?? 0
        return log(1 + (Double(count - df) + 0.5) / (Double(df) + 0.5))
    }
}
