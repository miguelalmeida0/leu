import Foundation

public enum ConceptOrigin: String, Codable, Sendable {
    /// A confirmed concept card: a heading whose definition or pronoun sentences resolved to it.
    case heading
    /// The grammatical subject of a literal source sentence.
    case subject
}

public struct ConceptEntry: Codable, Hashable, Sendable, Identifiable {
    public var id: String { key.value + "|" + documentID.uuidString }
    public let key: ConceptKey
    public var name: String
    public var origin: ConceptOrigin
    public let documentID: UUID
    public let pageIndex: Int
    public var heading: SourceSpan?
    /// Section title shared by sibling cards ("DATABASES & DATA INTEGRITY").
    public var section: String?
    /// Source examples bound to this card (e.g. a REAL EXAMPLE region).
    public var examples: [SourceSpan]
    /// The claim that defines the card: a resolved definition, or the first sentence of its
    /// explanatory region when the source defines it with a full sentence.
    public var definingClaimID: String? = nil
    /// Other names the source uses for the card ("LLM" for "Large Language Model (LLM)").
    public var aliases: [String] = []
    public var names: [String] { [name] + aliases }
}

public enum ConceptRelation: String, Codable, Sendable {
    /// The concept's own explanation uses the other concept: a prerequisite candidate.
    case uses
    /// The source explicitly contrasts the two concepts in one passage.
    case contrastsWith
}

public struct ConceptEdge: Codable, Hashable, Sendable {
    public let from: ConceptKey
    public let to: ConceptKey
    public let relation: ConceptRelation
    public let evidence: SourceSpan
}

/// Grounded knowledge for one or more documents. Derived data: safe to rebuild, never persisted
/// as truth. Every claim and edge cites an exact canonical span.
public struct ConceptKnowledgeBase: Codable, Equatable, Sendable {
    public static let compilerVersion = 1
    public private(set) var concepts: [ConceptEntry]
    public private(set) var claims: [LearningClaim]
    public private(set) var edges: [ConceptEdge]

    public init(concepts: [ConceptEntry] = [], claims: [LearningClaim] = [], edges: [ConceptEdge] = []) {
        self.concepts = concepts.sorted { ($0.key, $0.documentID.uuidString, $0.pageIndex) < ($1.key, $1.documentID.uuidString, $1.pageIndex) }
        self.claims = claims
        self.edges = edges
    }

    public static let empty = ConceptKnowledgeBase()
    public var isEmpty: Bool { claims.isEmpty }

    /// The preferred entry for a concept: a confirmed card before a mere sentence subject.
    public func concept(_ key: ConceptKey) -> ConceptEntry? {
        concepts.filter { $0.key == key }.min { lhs, rhs in
            (lhs.origin == .heading ? 0 : 1, lhs.pageIndex) < (rhs.origin == .heading ? 0 : 1, rhs.pageIndex)
        }
    }
    public var cards: [ConceptEntry] { concepts.filter { $0.origin == .heading } }

    public func claims(teaching key: ConceptKey, roles: Set<ClaimRole> = [.core]) -> [LearningClaim] {
        claims.filter { $0.teaches(key) && roles.contains($0.role) }
    }

    public func claims(onPage documentID: UUID, pageIndex: Int) -> [LearningClaim] {
        claims.filter { $0.evidence.documentID == documentID && $0.evidence.pageIndex == pageIndex }
    }

    /// Claims whose evidence lies inside a selected passage (exact range when known).
    public func claims(within source: LearningSource, roles: Set<ClaimRole> = [.core, .supporting]) -> [LearningClaim] {
        let page = claims(onPage: source.documentID, pageIndex: source.pageIndex).filter { roles.contains($0.role) }
        if let range = source.range, range.length > 0 {
            return page.filter {
                $0.evidence.range.location >= range.location &&
                    $0.evidence.range.location + $0.evidence.range.length <= range.location + range.length
            }
        }
        let passage = CanonicalWhitespaceResolver.normalize(source.sourceText)
        return page.filter { passage.contains(CanonicalWhitespaceResolver.normalize($0.evidence.text)) }
    }

    /// Cards of the same document and section, nearest pages first.
    public func siblings(of key: ConceptKey, limit: Int = 6) -> [ConceptEntry] {
        guard let home = concept(key), home.origin == .heading else { return [] }
        return cards.filter { $0.key != key && $0.documentID == home.documentID && $0.section == home.section }
            .sorted { (abs($0.pageIndex - home.pageIndex), $0.key) < (abs($1.pageIndex - home.pageIndex), $1.key) }
            .prefix(limit).map { $0 }
    }

    public func edges(from key: ConceptKey, _ relation: ConceptRelation) -> [ConceptEdge] {
        edges.filter { $0.from == key && $0.relation == relation }
    }

    /// Concepts whose own explanation this concept's explanation depends on, earliest first.
    public func prerequisites(of key: ConceptKey) -> [ConceptKey] {
        var seen = Set<ConceptKey>()
        return edges(from: key, .uses).compactMap { edge -> (ConceptKey, Int)? in
            guard seen.insert(edge.to).inserted, !claims(teaching: edge.to).isEmpty,
                  let entry = concept(edge.to) else { return nil }
            return (edge.to, entry.pageIndex)
        }.sorted { ($0.1, $0.0) < ($1.1, $1.0) }.map(\.0)
    }

    public func definition(of key: ConceptKey) -> LearningClaim? {
        guard let entry = concept(key) else { return nil }
        if let id = entry.definingClaimID, let claim = claims.first(where: { $0.id == id }) { return claim }
        return claims(teaching: key).first { $0.kind == .definition }
    }

    public func contrasts(of key: ConceptKey) -> [ConceptKey] {
        Array(Set(edges.filter { $0.relation == .contrastsWith && ($0.from == key || $0.to == key) }
            .map { $0.from == key ? $0.to : $0.from })).sorted()
    }

    /// One document's part. Lookups here are by concept name, and names repeat across documents
    /// ("Cache" in two books), so anything that asks about a concept works on one document.
    public func restricted(to documentID: UUID) -> ConceptKnowledgeBase {
        ConceptKnowledgeBase(concepts: concepts.filter { $0.documentID == documentID },
                             claims: claims.filter { $0.evidence.documentID == documentID },
                             edges: edges.filter { $0.evidence.documentID == documentID })
    }

    /// Several documents side by side. Restrict to one document before asking about a concept.
    public static func merged(_ parts: [ConceptKnowledgeBase]) -> ConceptKnowledgeBase {
        ConceptKnowledgeBase(concepts: parts.flatMap(\.concepts), claims: parts.flatMap(\.claims),
                             edges: parts.flatMap(\.edges))
    }
}
