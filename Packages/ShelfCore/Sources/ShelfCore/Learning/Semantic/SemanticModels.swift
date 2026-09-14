import Foundation

public enum SemanticRelation: String, Codable, CaseIterable, Sendable {
    case definedAs
    case isA
    case purpose
    case usedFor
    case requires
    case dependsOn
    case enables
    case prevents
    case causes
    case resultsIn
    case before
    case after
    case contrastsWith
    case tradeoff
    case exampleOf
    case partOf
    case contains
    case memoizes
    case reads
    case writes
    case calls
    case returns
    case mutates
    case subscribesTo
    case cleansUp
    case awaits

    public var questionVerb: String {
        switch self {
        case .definedAs: return "means"
        case .isA: return "is"
        case .purpose, .usedFor: return "is used for"
        case .requires, .dependsOn: return "depends on"
        case .enables: return "enables"
        case .prevents: return "prevents"
        case .causes: return "can cause"
        case .resultsIn: return "results in"
        case .before: return "happens before"
        case .after: return "happens after"
        case .tradeoff: return "trades off"
        case .contrastsWith: return "contrasts with"
        case .exampleOf: return "is an example of"
        case .partOf: return "is part of"
        case .contains: return "contains"
        case .memoizes: return "memoizes"
        case .reads: return "reads"
        case .writes: return "writes"
        case .calls: return "calls"
        case .returns: return "returns"
        case .mutates: return "mutates"
        case .subscribesTo: return "subscribes to"
        case .cleansUp: return "cleans up"
        case .awaits: return "awaits"
        }
    }
}

public enum SemanticTruthClass: String, Codable, Sendable {
    case verifiedSource
    case curatedOntology
    case structural
    case associationCandidate
    case learnerConfirmed
}

public enum SemanticConfidenceClass: String, Codable, Sendable {
    case verified
    case strong
    case associationOnly
}

public struct SemanticEvidenceSpan: Codable, Equatable, Hashable, Sendable {
    public var documentID: UUID
    public var pageIndex: Int
    public var sectionTitle: String?
    public var sourceText: String
    public var charStart: Int
    public var charLength: Int
    public var sourceHash: String

    public init(documentID: UUID, pageIndex: Int, sectionTitle: String?, sourceText: String,
                charStart: Int = 0, charLength: Int? = nil) {
        self.documentID = documentID
        self.pageIndex = pageIndex
        self.sectionTitle = sectionTitle
        self.sourceText = sourceText
        self.charStart = max(0, charStart)
        self.charLength = max(0, charLength ?? sourceText.count)
        self.sourceHash = String(StableIdentity.hash64("\(documentID)|\(pageIndex)|\(sourceText)"), radix: 16)
    }

    public var learningSource: LearningSource {
        LearningSource(documentID: documentID, pageIndex: pageIndex, sourceText: sourceText,
                       sectionTitle: sectionTitle)
    }
}

public struct SemanticConcept: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: String
    public var canonicalName: String
    public var aliases: [String]
    public var domain: String
    public var isCurated: Bool

    public init(id: String, canonicalName: String, aliases: [String] = [],
                domain: String = "document", isCurated: Bool = false) {
        self.id = id
        self.canonicalName = canonicalName
        self.aliases = aliases
        self.domain = domain
        self.isCurated = isCurated
    }
}

public struct SemanticProposition: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: String
    public var subjectID: String
    public var relation: SemanticRelation
    public var objectText: String
    public var objectConceptID: String?
    public var truthClass: SemanticTruthClass
    public var confidenceClass: SemanticConfidenceClass
    public var evidence: SemanticEvidenceSpan
    public var extractionRuleID: String
    public var claim: ExtractedClaim?

    public init(subjectID: String, relation: SemanticRelation, objectText: String,
                objectConceptID: String? = nil, truthClass: SemanticTruthClass,
                confidenceClass: SemanticConfidenceClass, evidence: SemanticEvidenceSpan,
                extractionRuleID: String, claim: ExtractedClaim? = nil) {
        self.subjectID = subjectID
        self.relation = relation
        self.objectText = objectText
        self.objectConceptID = objectConceptID
        self.truthClass = truthClass
        self.confidenceClass = confidenceClass
        self.evidence = evidence
        self.extractionRuleID = extractionRuleID
        self.claim = claim
        let key = "\(subjectID)|\(relation.rawValue)|\(objectConceptID ?? objectText.lowercased())|\(evidence.sourceHash)|2"
        self.id = String(StableIdentity.hash64(key), radix: 16)
    }

    public var isQuizTruth: Bool {
        confidenceClass == .verified && truthClass != .associationCandidate
    }
}

public struct SemanticAssociation: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: String
    public var conceptIDs: [String]
    public var score: Double
    public var reason: String

    public init(conceptIDs: [String], score: Double, reason: String) {
        self.conceptIDs = conceptIDs.sorted()
        self.score = min(max(score, 0), 1)
        self.reason = reason
        self.id = String(StableIdentity.hash64(self.conceptIDs.joined(separator: "|") + "|" + reason), radix: 16)
    }
}

public struct SemanticIndex: Codable, Equatable, Sendable {
    public var documentID: UUID
    public var documentFingerprint: String
    public var semanticVersion: Int
    public var ontologyVersion: Int
    public var concepts: [SemanticConcept]
    public var propositions: [SemanticProposition]
    public var associations: [SemanticAssociation]
    public var rejectionCounts: [String: Int]

    public init(documentID: UUID, documentFingerprint: String, semanticVersion: Int = 2,
                ontologyVersion: Int = 1, concepts: [SemanticConcept] = [],
                propositions: [SemanticProposition] = [], associations: [SemanticAssociation] = [],
                rejectionCounts: [String: Int] = [:]) {
        self.documentID = documentID
        self.documentFingerprint = documentFingerprint
        self.semanticVersion = semanticVersion
        self.ontologyVersion = ontologyVersion
        self.concepts = concepts
        self.propositions = propositions
        self.associations = associations
        self.rejectionCounts = rejectionCounts
    }
}

public enum SemanticQuestionOperator: String, Codable, CaseIterable, Sendable {
    case definition
    case relationship
    case reverseRelationship
    case timing
    case prerequisite
    case purpose
    case comparison
    case codeInterpretation
}
