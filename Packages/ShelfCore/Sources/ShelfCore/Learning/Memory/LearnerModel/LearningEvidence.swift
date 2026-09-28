import Foundation

/// A concept as the learner meets it. The same name in two documents is two concepts,
/// because each document's own claims define it.
public struct LearnerConceptID: Codable, Hashable, Comparable, Sendable, CustomStringConvertible {
    public let documentID: UUID
    public let concept: ConceptKey
    public init(documentID: UUID, concept: ConceptKey) { self.documentID = documentID; self.concept = concept }
    public var description: String { documentID.uuidString + "|" + concept.value }
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.description < rhs.description }
}

public enum EvidenceOutcome: String, Codable, Sendable {
    case correct, partial, incorrect
    var value: Double {
        switch self {
        case .correct: return 1
        case .partial: return 0.5
        case .incorrect: return 0
        }
    }
}

/// Where evidence came from. A self-rating is the learner's own read and weighs half.
public enum EvidenceChannel: String, Codable, Sendable {
    /// An answered multiple-choice question or choice probe: objectively scored.
    case choice
    /// An explanation compared with grounded claims (Teach It Back, typed recall).
    case explanation
    /// "Forgot / Difficult / Knew it" after revealing the source.
    case selfRating

    var weight: Double { self == .selfRating ? 0.5 : 1 }
}

public enum MisconceptionKind: String, Codable, CaseIterable, Sendable {
    /// The learner stated the opposite of a claim.
    case contradiction
    /// Right pieces, reversed direction.
    case reversal
    /// Another concept's property attributed to this one (or its distractor chosen).
    case confusion
    /// Universal wording where the source is qualified.
    case overgeneralization
}

/// A specific wrong idea seen in one answer, with the learner's own words.
public struct MisconceptionObservation: Codable, Equatable, Sendable {
    public let kind: MisconceptionKind
    public let claimID: String?
    public let relatedConcept: ConceptKey?
    public let learnerWording: String
    public init(kind: MisconceptionKind, claimID: String?, relatedConcept: ConceptKey?, learnerWording: String) {
        self.kind = kind; self.claimID = claimID; self.relatedConcept = relatedConcept
        self.learnerWording = String(CanonicalWhitespaceResolver.normalize(learnerWording).prefix(240))
    }
}

/// One observation of what the learner can do with a concept.
public struct LearningEvidence: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let concept: LearnerConceptID
    public let conceptName: String
    public let operation: ProbeOperation
    public let outcome: EvidenceOutcome
    public let channel: EvidenceChannel
    public let confidence: ConfidenceLevel?
    /// The grounded claims this evidence is about.
    public let claimIDs: [String]
    public let misconception: MisconceptionObservation?
    public let probeID: String?
    public let occurredAt: Date
    /// A prerequisite detour the answered question started.
    public internal(set) var startsObjective: RemediationObjective?
    /// Concepts the answer had to be told apart from: a contrast partner, or the other options of
    /// a choice question. Only telling the same two concepts apart retires a confusion between them.
    public let rivals: [ConceptKey]

    /// `identity` names the answer this evidence comes from (a Teach It Back attempt): comparing
    /// the same attempt again after editing it yields the same ids, so it is counted once.
    public init(concept: LearnerConceptID, conceptName: String, operation: ProbeOperation, outcome: EvidenceOutcome,
                channel: EvidenceChannel, confidence: ConfidenceLevel? = nil, claimIDs: [String] = [],
                misconception: MisconceptionObservation? = nil, probeID: String? = nil, occurredAt: Date,
                startsObjective: RemediationObjective? = nil, rivals: [ConceptKey] = [], identity: String? = nil) {
        self.concept = concept; self.conceptName = String(conceptName.prefix(120)); self.operation = operation
        self.outcome = outcome; self.channel = channel; self.confidence = confidence
        self.claimIDs = Array(claimIDs.prefix(12)); self.misconception = misconception
        self.probeID = probeID; self.occurredAt = occurredAt; self.startsObjective = startsObjective
        self.rivals = Array(rivals.prefix(6))
        let parts = identity.map { identity in
            [identity, concept.description, operation.rawValue, channel.rawValue, misconception.map { "\($0.kind.rawValue)|\($0.claimID ?? "")|\($0.relatedConcept?.value ?? "")" } ?? ""]
        } ?? [concept.description, operation.rawValue, channel.rawValue, outcome.rawValue,
              String(occurredAt.timeIntervalSinceReferenceDate), probeID ?? "", claimIDs.joined(separator: ",")]
        id = "evidence-" + String(StableIdentity.hash64(parts.joined(separator: "|")), radix: 16)
    }
}
