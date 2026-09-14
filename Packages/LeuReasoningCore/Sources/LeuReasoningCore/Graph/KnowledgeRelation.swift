import Foundation

/// The relationship vocabulary. Each kind has a fixed reading direction and a
/// fixed set of reasoning operations it licenses.
public enum RelationKind: String, Codable, CaseIterable, Sendable {
    case supports
    case explains
    case causes
    case prevents
    case enables
    case requires
    case contrastsWith
    case exampleOf
    case failureOf
    case consequenceOf
    case prerequisiteOf
    case implementationOf
    case samePrincipleAs
    case refines
    case scopes
    case qualifies

    /// Relations that move forward along a mechanism ("what does this enable?").
    public var isForwardMechanism: Bool {
        switch self {
        case .enables, .causes, .consequenceOf, .explains, .prevents: return true
        default: return false
        }
    }

    /// Relations that move backward ("what does this depend on?").
    public var isBackwardDependency: Bool {
        switch self {
        case .requires, .prerequisiteOf: return true
        default: return false
        }
    }

    /// Symmetric relations are stored once but traversed in both directions.
    public var isSymmetric: Bool {
        switch self {
        case .contrastsWith, .samePrincipleAs: return true
        default: return false
        }
    }

    /// Whether two relations of these kinds may be composed transitively.
    /// Composition is the only way the engine is allowed to produce a claim the
    /// source never spelled out, and it is deliberately narrow.
    public func composes(with next: RelationKind) -> InferenceRule? {
        switch (self, next) {
        case (.enables, .enables): return .transitiveEnablement
        case (.causes, .causes): return .causalComposition
        case (.enables, .causes), (.causes, .enables): return .causalComposition
        case (.requires, .requires): return .transitiveRequirement
        case (.prerequisiteOf, .prerequisiteOf): return .transitiveRequirement
        default: return nil
        }
    }
}

/// Either end of a relation: a phrase-level node in the mechanism graph, or a
/// whole claim (used for cross-source relations like `refines`).
public enum GraphEndpoint: Codable, Equatable, Hashable, Sendable {
    case node(StableID)
    case atom(StableID)

    public var id: StableID {
        switch self {
        case .node(let id), .atom(let id): return id
        }
    }

    public var isNode: Bool {
        if case .node = self { return true }
        return false
    }
}

/// A directed, provenance-carrying edge.
public struct KnowledgeRelation: Codable, Equatable, Hashable, Sendable, Identifiable {
    public var id: StableID
    public var kind: RelationKind
    public var subject: GraphEndpoint
    public var object: GraphEndpoint
    /// Conditions under which the edge holds ("if the failure is transient").
    public var conditions: [ClaimCondition]
    public var qualifiers: [Qualifier]
    /// The atoms that assert this edge. Never empty for source-supported edges.
    public var supportingAtoms: [StableID]
    public var provenance: Provenance

    public init(id: StableID,
                kind: RelationKind,
                subject: GraphEndpoint,
                object: GraphEndpoint,
                conditions: [ClaimCondition] = [],
                qualifiers: [Qualifier] = [],
                supportingAtoms: [StableID] = [],
                provenance: Provenance) {
        self.id = id
        self.kind = kind
        self.subject = subject
        self.object = object
        self.conditions = conditions
        self.qualifiers = qualifiers
        self.supportingAtoms = supportingAtoms
        self.provenance = provenance
    }

    public init(kind: RelationKind,
                subject: GraphEndpoint,
                object: GraphEndpoint,
                conditions: [ClaimCondition] = [],
                qualifiers: [Qualifier] = [],
                supportingAtoms: [StableID] = [],
                provenance: Provenance) {
        let components = [kind.rawValue, subject.id.rawValue, object.id.rawValue,
                          conditions.map(\.text).joined(separator: "|"),
                          provenance.admissibility.rawValue]
        self.init(id: StableID(namespace: "rel", components: components),
                  kind: kind,
                  subject: subject,
                  object: object,
                  conditions: conditions,
                  qualifiers: qualifiers,
                  supportingAtoms: supportingAtoms,
                  provenance: provenance)
    }

    public var isSourceSupported: Bool { provenance.admissibility == .sourceSupported }
}

/// A phrase-level node: the thing a mechanism step is about.
public struct KnowledgeNode: Codable, Equatable, Hashable, Sendable, Identifiable {
    public var id: StableID
    /// Display label, taken from the first source phrasing seen.
    public var label: String
    /// Normalised key used for merging ("a stable key" and "stable keys" merge).
    public var key: String
    public var concepts: [String]
    public var atomIDs: [StableID]

    public init(label: String, concepts: [String] = [], atomIDs: [StableID] = []) {
        let key = KnowledgeNode.key(for: label)
        self.id = StableID(namespace: "node", components: [key])
        self.label = label
        self.key = key
        self.concepts = concepts
        self.atomIDs = atomIDs
    }

    /// Merging key: stemmed content tokens, order preserved. This is what makes
    /// "a stable key" and "stable keys" the same node without a synonym table.
    public static func key(for label: String) -> String {
        let tokens = TextScanning.contentTokens(label)
        return tokens.isEmpty ? TextScanning.normalizedTokens(label).joined(separator: "-") : tokens.joined(separator: "-")
    }
}
