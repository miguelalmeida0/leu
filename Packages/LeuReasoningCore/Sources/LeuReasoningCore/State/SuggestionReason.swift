import Foundation

/// Why Leu is showing something. Every suggestion the engine produces carries
/// one: there is no ranking signal in this package that cannot be explained in
/// a sentence, and nothing is optimised for engagement.
public struct SuggestionReason: Codable, Equatable, Sendable {
    public enum Cause: String, Codable, CaseIterable, Sendable {
        /// The learner explicitly asked about this.
        case youAsked
        /// The learner's own explanation left this out or got it wrong.
        case yourExplanation
        /// The passage the learner is reading depends on this.
        case currentPassageDependsOnIt
        /// Another document in the library explains it more directly.
        case anotherSourceExplainsIt
        /// The learner marked something unresolved and this is the next step.
        case unresolvedQuestion
        /// The source states a condition or failure mode the learner has not seen.
        case sourceStatesACondition
        /// The learner opened a prerequisite and this follows from it.
        case followsPrerequisiteYouOpened
    }

    public var cause: Cause
    /// The sentence shown to the learner, already complete.
    public var text: String
    /// Artifacts that justify the suggestion.
    public var evidence: [StableID]
    public var provenance: Provenance?

    public init(cause: Cause, text: String, evidence: [StableID], provenance: Provenance? = nil) {
        self.cause = cause
        self.text = text
        self.evidence = evidence
        self.provenance = provenance
    }
}
