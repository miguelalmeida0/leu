import Foundation

/// How strongly a verdict is supported. Neither tier is semantic entailment.
public enum EvidenceTier: String, Codable, Sendable {
    /// Same wording as the source after whitespace/case/punctuation normalisation.
    case exact
    /// Stems, curated paraphrase families and opposite-meaning dimensions agree.
    case lexical
}

public enum ClaimCoverage: String, Codable, Sendable { case covered, partial, contradicted, missing }

/// What part of a claim was not expressed.
public enum MissingElement: String, Codable, Sendable { case condition, relation, detail }

public enum UnderstandingIssueKind: String, Codable, CaseIterable, Sendable {
    /// States the opposite of a source claim (negation or opposite-meaning wording).
    case contradiction
    /// Right pieces, reversed direction: the cause and the effect (or subject and object) are swapped.
    case causalReversal
    /// Universal wording ("always", "every") where the source is qualified.
    case overgeneralization
    /// Attributes another concept's property to this one.
    case confusedConcept
    /// Content the source does not settle.
    case unsupported
    /// Explains the concept with its own name.
    case circular
    /// Reproduces the source wording: memory of the text, not yet shown understanding.
    case verbatim
    /// An important claim is absent.
    case missingKeyIdea
    /// The core is right but the condition that limits it is missing.
    case droppedCondition
    /// Nothing comparable was written.
    case nonsense
}

public enum StatementVerdict: String, Codable, Sendable {
    case supports, partiallySupports, contradicts, reverses, confuses, overgeneralizes, unsupported, circular, restates, noise
}

public struct StatementDiagnosis: Codable, Equatable, Sendable {
    public let learnerText: String
    public let verdict: StatementVerdict
    public let claimID: String?
    public let tier: EvidenceTier?
    /// Source words the learner expressed, and source words that were absent.
    public let matchedTerms: [String]
    public let missingTerms: [String]
}

public struct ClaimAssessment: Codable, Equatable, Sendable {
    public let claimID: String
    public let coverage: ClaimCoverage
    public let missing: MissingElement?
    public let learnerText: String?
}

public struct UnderstandingIssue: Codable, Equatable, Hashable, Sendable {
    public let kind: UnderstandingIssueKind
    public let claimID: String?
    public let relatedConcept: ConceptKey?
    public let learnerText: String?
    public init(kind: UnderstandingIssueKind, claimID: String? = nil, relatedConcept: ConceptKey? = nil, learnerText: String? = nil) {
        self.kind = kind; self.claimID = claimID; self.relatedConcept = relatedConcept; self.learnerText = learnerText
    }
}

public enum UnderstandingLevel: String, Codable, Sendable {
    /// Every key idea, nothing wrong.
    case solid
    /// Most key ideas; something is missing or over-broad.
    case mostly
    /// Some key ideas.
    case partial
    /// Source wording reproduced; understanding not yet shown.
    case surface
    /// The concept explained by its own name.
    case circular
    /// A contradiction, reversal or confusion is present.
    case misconceived
    /// Only statements the source does not settle.
    case unrelated
    /// Empty, too short or not comparable.
    case insufficient
}

/// The complete, source-bound reading of one explanation.
public struct UnderstandingDiagnosis: Codable, Equatable, Sendable {
    public static let version = 1
    public let version: Int
    public let concept: ConceptKey?
    public let conceptName: String?
    public let statements: [StatementDiagnosis]
    public let claims: [ClaimAssessment]
    public let issues: [UnderstandingIssue]
    public let level: UnderstandingLevel
    /// Weighted share of key claims expressed (partial counts half). Not a grade; never shown as a number.
    public let coverage: Double
    public let intervention: LearningIntervention
    /// Every claim the diagnosis refers to, with its exact source span.
    public let referencedClaims: [LearningClaim]

    public func claim(_ id: String?) -> LearningClaim? { id.flatMap { id in referencedClaims.first { $0.id == id } } }
    public func assessment(_ id: String) -> ClaimAssessment? { claims.first { $0.claimID == id } }
    public var covered: [LearningClaim] { claims.filter { $0.coverage == .covered }.compactMap { claim($0.claimID) } }
    public var partial: [LearningClaim] { claims.filter { $0.coverage == .partial }.compactMap { claim($0.claimID) } }
    public var missing: [LearningClaim] { claims.filter { $0.coverage == .missing }.compactMap { claim($0.claimID) } }
    public func has(_ kind: UnderstandingIssueKind) -> Bool { issues.contains { $0.kind == kind } }
    public var hasMisconception: Bool { issues.contains { [.contradiction, .causalReversal, .confusedConcept].contains($0.kind) } }
}
