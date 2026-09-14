import Foundation

/// The ways a learner's claim can diverge from what a source actually says.
///
/// These are claim-comparison outcomes, not psychology. Each one is decided by
/// a specific structural difference between a proposition and an atom.
public enum MisconceptionType: String, Codable, CaseIterable, Sendable {
    /// The source restricts the claim to a condition the learner omitted.
    case missingCondition
    /// The learner asserts the claim more widely than the source does.
    case scopeTooBroad
    /// The learner restricts the claim more than the source does.
    case scopeTooNarrow
    /// The learner has cause and effect the wrong way round.
    case reversedCauseEffect
    /// The learner claims A depends on B where the source says the reverse, or
    /// names a different dependency altogether.
    case wrongDependency
    /// Steps stated in an order the source contradicts.
    case wrongSequence
    /// The learner negates (or fails to negate) where the source does not.
    case incorrectNegation
    /// Numbers disagree with the source.
    case numericalMismatch
    /// An API, header or status code that does not match the source.
    case identifierMismatch
    /// Content with no basis in any source: not wrong, but not supported.
    case unsupportedAddition
    /// Two distinct concepts treated as one.
    case conflatedConcepts

    /// Whether this divergence makes the claim wrong, as opposed to incomplete.
    public var isContradiction: Bool {
        switch self {
        case .reversedCauseEffect, .wrongDependency, .wrongSequence,
             .incorrectNegation, .numericalMismatch, .identifierMismatch, .scopeTooBroad:
            return true
        case .missingCondition, .scopeTooNarrow, .unsupportedAddition, .conflatedConcepts:
            return false
        }
    }
}

/// A specific divergence, with the source evidence that establishes it and the
/// exact sentence Leu may say about it.
public struct MisconceptionFinding: Codable, Equatable, Sendable {
    public var type: MisconceptionType
    public var propositionID: StableID
    public var atomID: StableID?
    /// The precise thing that differs: the omitted condition, the wrong number.
    public var detail: String
    /// Templated, grounded feedback. Never free-form generation.
    public var feedback: String
    public var provenance: Provenance

    public init(type: MisconceptionType,
                propositionID: StableID,
                atomID: StableID?,
                detail: String,
                feedback: String,
                provenance: Provenance) {
        self.type = type
        self.propositionID = propositionID
        self.atomID = atomID
        self.detail = detail
        self.feedback = feedback
        self.provenance = provenance
    }
}
