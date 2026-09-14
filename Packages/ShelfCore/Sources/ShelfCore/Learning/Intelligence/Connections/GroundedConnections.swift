import Foundation

public struct GroundedConnection: Codable, Equatable, Sendable, Identifiable {
    public let current: IntelligenceSource
    public let connected: IntelligenceSource
    public let currentClaim: GroundedQuestionClaim
    public let connectedClaim: GroundedQuestionClaim
    public var id: String { current.id + "|" + connected.id }
    public var label: String { "Same mechanism" }
    public var explanation: String {
        "Both passages explicitly describe “\(currentClaim.predicate) \(currentClaim.object)”. Compare their subjects and scope in the excerpts."
    }
}

public enum ConnectionValidator {
    public static func admits(_ a: GroundedQuestionClaim, _ b: GroundedQuestionClaim,
                              current: IntelligenceSource, connected: IntelligenceSource) -> Bool {
        guard a.documentID != b.documentID, current.claims.contains(a), connected.claims.contains(b),
              normalize(a.evidence.text) != normalize(b.evidence.text),
              !nearDuplicate(current.passage.sourceText, connected.passage.sourceText),
              a.negated == b.negated, normalize(a.qualifier ?? "") == normalize(b.qualifier ?? ""),
              normalize(a.predicate) == normalize(b.predicate), normalize(a.object) == normalize(b.object),
              a.object.split(whereSeparator: \.isWhitespace).count >= 2,
              (a.object + " " + (a.qualifier ?? "")).split(whereSeparator: \.isWhitespace).count >= 4 else { return false }
        return true
    }
    private static func normalize(_ value: String) -> String { CanonicalWhitespaceResolver.normalize(value).lowercased() }
    static func nearDuplicate(_ a: String, _ b: String) -> Bool {
        let left = Set(normalize(a).split(separator: " ")), right = Set(normalize(b).split(separator: " "))
        return Double(left.intersection(right).count) / Double(max(1, left.union(right).count)) > 0.92
    }
}

/// Hybrid local signals retrieve candidates; matching an explicit relation in both
/// canonical passages independently admits the connection. Keywords alone fail.
public struct GroundedConnectionIndex: Sendable {
    private let index: HybridLocalIndex
    public var semanticBackend: LocalSemanticSignal.Backend { index.semanticBackend }
    public init(analyses: [UUID: DocumentAnalysis]) {
        var sources: [UUID: IntelligenceSource] = [:]
        for analysis in analyses.values {
            for page in analysis.pages where page.isIntelligenceEligible {
                guard let text = page.canonicalText,
                      let source = IntelligenceSource(source: LearningSource(documentID: analysis.documentID,
                        pageIndex: page.pageIndex, sourceText: text), analysis: analysis), !source.claims.isEmpty else { continue }
                let id = StableIdentity.uuid(source.id)
                sources[id] = source
            }
        }
        index = HybridLocalIndex(sources: Array(sources.values))
    }
    public func connections(from source: IntelligenceSource, limit: Int = 5) -> [GroundedConnection] {
        var output: [GroundedConnection] = [], seen = Set<String>()
        for hit in index.search(source.claims.map(\.evidence.text).joined(separator: " "), concepts: source.claims.map(\.concept), limit: 32) {
            let other = hit.source
            guard other.packet.documentID != source.packet.documentID else { continue }
            let canonical = CanonicalWhitespaceResolver.normalize(other.passage.sourceText).lowercased()
            guard !seen.contains(where: { ConnectionValidator.nearDuplicate($0, canonical) }) else { continue }
            if let pair = source.claims.lazy.flatMap({ a in other.claims.map { (a, $0) } }).first(where: {
                ConnectionValidator.admits($0.0, $0.1, current: source, connected: other)
            }) {
                output.append(.init(current: source, connected: other, currentClaim: pair.0, connectedClaim: pair.1))
                seen.insert(canonical)
                if output.count >= limit { break }
            }
        }
        return output
    }
}
