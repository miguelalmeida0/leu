import Foundation

/// What kind of assertion an atom makes. The type drives which reasoning
/// operations are legal over it, so it is part of the representation rather
/// than a label.
public enum ClaimType: String, Codable, CaseIterable, Sendable {
    case definition
    case mechanism
    case cause
    case consequence
    case constraint
    case tradeoff
    case sequence
    case distinction
    case example
    case failureMode
    case prerequisite
}

/// A modifier that narrows a claim. Dropping a qualifier is the single most
/// common way an explanation silently becomes wrong, so qualifiers are
/// first-class and are compared explicitly during learner alignment.
public struct Qualifier: Codable, Equatable, Hashable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable {
        case scope        // "for transient failures"
        case frequency    // "usually", "often"
        case degree       // "significantly"
        case temporal     // "during a reorder"
        case modality     // "may", "must", "should"
        case purpose      // "in order to keep state"
    }

    public var kind: Kind
    public var text: String

    public init(kind: Kind, text: String) {
        self.kind = kind
        self.text = text
    }
}

/// A number carried by a claim, kept structured so that "at least 3" and "3"
/// never compare equal.
public struct NumericFact: Codable, Equatable, Hashable, Sendable {
    public enum Comparator: String, Codable, CaseIterable, Sendable {
        case exactly, atLeast, atMost, approximately, range
    }

    public var comparator: Comparator
    public var value: Double
    public var upperValue: Double?
    public var unit: String?
    public var rawText: String

    public init(comparator: Comparator,
                value: Double,
                upperValue: Double? = nil,
                unit: String? = nil,
                rawText: String) {
        self.comparator = comparator
        self.value = value
        self.upperValue = upperValue
        self.unit = unit
        self.rawText = rawText
    }
}

/// A symbol that must survive extraction verbatim: `useMemo`, `409`,
/// `Cache-Control`, `index`. Identifier drift is a correctness bug, not a
/// stylistic one.
public struct SourceIdentifier: Codable, Equatable, Hashable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable {
        case apiSymbol, httpStatus, header, keyword, filePath, other
    }

    public var kind: Kind
    public var text: String

    public init(kind: Kind, text: String) {
        self.kind = kind
        self.text = text
    }
}

/// A precondition attached to a claim ("if the failure is transient").
public struct ClaimCondition: Codable, Equatable, Hashable, Sendable {
    public var text: String
    /// `false` when the condition is stated negatively ("unless the key is stable").
    public var isPositive: Bool
    /// Concept slugs the condition mentions, for matching without vocabulary
    /// equality.
    public var concepts: [String]

    public init(text: String, isPositive: Bool = true, concepts: [String] = []) {
        self.text = text
        self.isPositive = isPositive
        self.concepts = concepts
    }
}

/// How faithfully the atom's text maps onto the document.
public enum SourceIntegrity: String, Codable, CaseIterable, Sendable {
    /// Subject/relation/object are substrings of the canonical span.
    case verbatim
    /// Whitespace/case/lemma normalisation only.
    case normalized
    /// The span was reassembled across a line or page break.
    case reconstructed
}

/// The unit of grounded knowledge.
///
/// An atom is a single assertion, tied to one span of one document, expressed
/// as subject–relation–object plus everything that narrows it.
public struct KnowledgeAtom: Codable, Equatable, Hashable, Sendable, Identifiable {
    public var id: StableID
    public var claimType: ClaimType

    public var subject: String
    public var relation: String
    public var object: String

    /// Concept slugs this atom is about (normalised, not display strings).
    public var concepts: [String]

    public var qualifiers: [Qualifier]
    /// `true` when the claim itself is negated ("does not preserve state").
    public var isNegated: Bool
    public var numbers: [NumericFact]
    public var identifiers: [SourceIdentifier]
    public var conditions: [ClaimCondition]
    /// Other atoms this claim presupposes, when the source states the
    /// dependency explicitly.
    public var dependencies: [StableID]

    public var sourceIntegrity: SourceIntegrity
    public var provenance: Provenance

    public init(id: StableID,
                claimType: ClaimType,
                subject: String,
                relation: String,
                object: String,
                concepts: [String] = [],
                qualifiers: [Qualifier] = [],
                isNegated: Bool = false,
                numbers: [NumericFact] = [],
                identifiers: [SourceIdentifier] = [],
                conditions: [ClaimCondition] = [],
                dependencies: [StableID] = [],
                sourceIntegrity: SourceIntegrity = .normalized,
                provenance: Provenance) {
        self.id = id
        self.claimType = claimType
        self.subject = subject
        self.relation = relation
        self.object = object
        self.concepts = concepts
        self.qualifiers = qualifiers
        self.isNegated = isNegated
        self.numbers = numbers
        self.identifiers = identifiers
        self.conditions = conditions
        self.dependencies = dependencies
        self.sourceIntegrity = sourceIntegrity
        self.provenance = provenance
    }

    /// Convenience constructor that derives the id from the atom's content so
    /// that re-extracting the same document is idempotent.
    public init(claimType: ClaimType,
                subject: String,
                relation: String,
                object: String,
                concepts: [String] = [],
                qualifiers: [Qualifier] = [],
                isNegated: Bool = false,
                numbers: [NumericFact] = [],
                identifiers: [SourceIdentifier] = [],
                conditions: [ClaimCondition] = [],
                dependencies: [StableID] = [],
                sourceIntegrity: SourceIntegrity = .normalized,
                provenance: Provenance) {
        let span = provenance.spans.first
        let components = [
            span?.documentID ?? "unknown",
            String(span?.page ?? -1),
            claimType.rawValue,
            subject.lowercased(),
            relation.lowercased(),
            object.lowercased(),
            isNegated ? "neg" : "pos",
            conditions.map(\.text).joined(separator: "|")
        ]
        self.init(id: StableID(namespace: "atom", components: components),
                  claimType: claimType,
                  subject: subject,
                  relation: relation,
                  object: object,
                  concepts: concepts,
                  qualifiers: qualifiers,
                  isNegated: isNegated,
                  numbers: numbers,
                  identifiers: identifiers,
                  conditions: conditions,
                  dependencies: dependencies,
                  sourceIntegrity: sourceIntegrity,
                  provenance: provenance)
    }

    // Field mirrors required by consumers that think in document terms.
    public var sourceDocumentID: String? { provenance.spans.first?.documentID }
    public var page: Int? { provenance.spans.first?.page }
    public var canonicalSpan: String? { provenance.spans.first?.canonicalSpan }
    public var sourceRole: SourceRole { provenance.spans.first?.sourceRole ?? .unknown }
    public var confidenceInParsing: Double { provenance.confidenceInParsing }

    /// A plain reading of the claim, used when Leu renders grounded text.
    public var statement: String {
        var parts: [String] = []
        if let scope = qualifiers.first(where: { $0.kind == .scope }) {
            parts.append(scope.text.hasPrefix("for ") || scope.text.hasPrefix("in ") ? scope.text : "for \(scope.text)")
        }
        if let condition = conditions.first {
            parts.append(condition.isPositive ? "if \(condition.text)" : "unless \(condition.text)")
        }
        let core = "\(subject) \(isNegated ? "does not " : "")\(relation) \(object)"
        parts.append(core)
        return parts.joined(separator: ", ")
    }

    /// True when the atom is eligible to feed mechanism/causal reasoning.
    public var carriesMechanism: Bool {
        sourceRole.yieldsFactualClaims && [.mechanism, .cause, .consequence, .prerequisite, .constraint, .failureMode].contains(claimType)
    }
}
