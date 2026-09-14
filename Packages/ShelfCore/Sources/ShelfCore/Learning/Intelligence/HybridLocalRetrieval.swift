import Foundation
#if canImport(NaturalLanguage)
import NaturalLanguage
#endif

/// Retrieval signal only. These vectors are never proof of a claim or answer.
public final class LocalSemanticSignal: @unchecked Sendable {
    public enum Backend: String, Codable, Sendable { case appleSentence, appleWordMean, unavailable }
    public let backend: Backend
    private let lock = NSLock()
    #if canImport(NaturalLanguage)
    private let embedding: NLEmbedding?
    #endif
    public init(enabled: Bool = true) {
        #if canImport(NaturalLanguage)
        if enabled, let sentence = NLEmbedding.sentenceEmbedding(for: .english) {
            embedding = sentence; backend = .appleSentence
        } else if enabled, let word = NLEmbedding.wordEmbedding(for: .english) {
            embedding = word; backend = .appleWordMean
        } else { embedding = nil; backend = .unavailable }
        #else
        backend = .unavailable
        #endif
    }
    public func vector(_ text: String) -> [Double]? {
        #if canImport(NaturalLanguage)
        lock.lock(); defer { lock.unlock() }
        guard let embedding else { return nil }
        if backend == .appleSentence { return embedding.vector(for: text).flatMap(Self.normalized) }
        let words = HybridLocalIndex.tokens(text).filter { !Self.stopwords.contains($0) }
        let vectors = words.compactMap { embedding.vector(for: $0) }
        guard vectors.count >= 2 else { return nil }
        var sum = [Double](repeating: 0, count: embedding.dimension)
        for vector in vectors where vector.count == sum.count {
            for i in sum.indices { sum[i] += vector[i] }
        }
        return Self.normalized(sum)
        #else
        return nil
        #endif
    }
    private static let stopwords: Set<String> = ["the", "and", "that", "this", "with", "from", "for", "into", "which", "when", "what", "how", "are", "was", "has", "have", "its", "can", "will", "you", "your"]
    private static func normalized(_ values: [Double]) -> [Double]? {
        let length = sqrt(values.reduce(0) { $0 + $1 * $1 })
        guard length.isFinite, length > 0 else { return nil }
        return values.map { $0 / length }
    }
    public static func cosine(_ lhs: [Double]?, _ rhs: [Double]?) -> Double? {
        guard let lhs, let rhs, lhs.count == rhs.count, !lhs.isEmpty else { return nil }
        return max(-1, min(1, zip(lhs, rhs).reduce(0) { $0 + $1.0 * $1.1 }))
    }
}

/// Differences remain explicit even when an embedding rates two strings alike.
public struct ProtectedSemanticTokens: Equatable, Sendable {
    public let negations: Set<String>
    public let numbers: Set<String>
    public let identifiers: Set<String>
    public let operators: Set<String>
    public let quantifiers: Set<String>
    public init(_ text: String) {
        negations = Set(Self.matches(#"\b(?:not|never|except|without|cannot|neither|nor)\b"#, text.lowercased()))
        numbers = Set(Self.matches(#"(?<![\w])\d+(?:\.\d+)?%?\b"#, text))
        identifiers = Set(Self.matches(#"`[^`]+`|\b[A-Z]{2,}(?:\.[A-Za-z_$][\w$]*)*\b|\b[a-z_$]+[A-Z][\w$]*\b|\b[A-Za-z_$][\w$]*(?:\.[A-Za-z_$][\w$]*)+\b"#, text))
        operators = Set(Self.matches(#"===|!==|==|!=|<=|>=|=>|->|&&|\|\||(?<![<>=!])[<>](?![=>])"#, text))
        quantifiers = Set(Self.matches(#"\b(?:all|every|always|only|some|may|must|should|transient|permanent)\b"#, text.lowercased()))
    }
    public func differences(from other: Self) -> [String] {
        var result: [String] = []
        if negations != other.negations { result.append("negation_scope") }
        if numbers != other.numbers { result.append("numeric_value") }
        if identifiers != other.identifiers { result.append("code_identifier") }
        if operators != other.operators { result.append("operator") }
        if quantifiers != other.quantifiers { result.append("quantifier_scope") }
        return result
    }
    private static func matches(_ pattern: String, _ text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range) }
    }
}

public struct HybridLocalHit: Sendable {
    public let source: IntelligenceSource
    public let lexicalScore: Double
    public let semanticScore: Double?
    public let conceptOverlap: Double
    public let protectedDifferences: [String]
    public let score: Double
}

public struct HybridLocalIndex: Sendable {
    private let sources: [UUID: IntelligenceSource]
    private let vectors: [UUID: [Double]]
    private let concepts: [UUID: Set<String>]
    private let protected: [UUID: ProtectedSemanticTokens]
    private let bm25: BM25Index
    private let signal: LocalSemanticSignal
    public var semanticBackend: LocalSemanticSignal.Backend { signal.backend }
    public init(sources input: [IntelligenceSource], signal: LocalSemanticSignal = LocalSemanticSignal()) {
        self.signal = signal
        var sources: [UUID: IntelligenceSource] = [:], vectors: [UUID: [Double]] = [:]
        var concepts: [UUID: Set<String>] = [:], protected: [UUID: ProtectedSemanticTokens] = [:]
        var records: [KnowledgeIndexRecord] = []
        for source in input {
            guard source.packet.sourceIntegrityPassed == true, source.extractionVersion == SourceExtractionVersion.current else { continue }
            let id = StableIdentity.uuid(source.id)
            guard sources[id] == nil else { continue }
            // Only factual source claims contribute to this candidate index.
            let text = source.claims.map(\.evidence.text).joined(separator: " ")
            guard !text.isEmpty else { continue }
            sources[id] = source; vectors[id] = signal.vector(text)
            concepts[id] = Set(Self.tokens(source.claims.map(\.concept).joined(separator: " ")))
            protected[id] = ProtectedSemanticTokens(text)
            let words = Self.tokens(text)
            records.append(.init(passageID: id, documentID: source.packet.documentID,
                termCounts: Dictionary(words.map { ($0, 1) }, uniquingKeysWith: +), tokenCount: words.count))
        }
        self.sources = sources; self.vectors = vectors; self.concepts = concepts; self.protected = protected
        bm25 = BM25Index(records: records)
    }
    public func search(_ query: String, concepts queryConcepts: [String] = [], limit: Int = 32) -> [HybridLocalHit] {
        guard limit > 0, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        let lexical = Dictionary(uniqueKeysWithValues: bm25.search(terms: Self.tokens(query), limit: sources.count).map { ($0.passageID, $0.score) })
        let maximum = max(1, lexical.values.max() ?? 0), vector = signal.vector(query)
        let queryTerms = Set(Self.tokens(queryConcepts.joined(separator: " "))), protection = ProtectedSemanticTokens(query)
        return sources.compactMap { id, source -> HybridLocalHit? in
            let lex = lexical[id] ?? 0, semantic = LocalSemanticSignal.cosine(vector, vectors[id])
            let overlap = Double(queryTerms.intersection(concepts[id] ?? []).count) / Double(max(1, queryTerms.count))
            guard lex > 0 || overlap > 0 || (semantic ?? 0) >= 0.55 else { return nil }
            let differences = protection.differences(from: protected[id]!)
            // Similarity cannot erase a protected-token mismatch or assert equivalence.
            let semanticWeight = differences.isEmpty ? 0.3 : 0.1
            let score = 0.55 * lex / maximum + semanticWeight * max(0, semantic ?? 0) + 0.15 * overlap
            return .init(source: source, lexicalScore: lex, semanticScore: semantic,
                conceptOverlap: overlap, protectedDifferences: differences, score: score)
        }.sorted { $0.score == $1.score ? $0.source.id < $1.source.id : $0.score > $1.score }.prefix(limit).map { $0 }
    }
    static func tokens(_ text: String) -> [String] {
        text.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count > 2 }
    }
}
