import Foundation

/// An explicit thing the learner did. Nothing here is inferred, sensed, or
/// guessed: no dwell time, no scroll depth, no affect, no ability estimate.
public enum LearningEvent: Codable, Equatable, Sendable {
    case requestedExplanation(concept: String, at: Date)
    case askedQuestion(text: String, concept: String?, at: Date)
    case savedQuestion(questionID: String, concept: String?, at: Date)
    case attemptedExplanation(concept: String, text: String, verdict: AlignmentVerdict, at: Date)
    case openedPrerequisite(concept: String, at: Date)
    case openedRelatedSource(documentID: String, concept: String?, at: Date)
    case changedExplanation(concept: String, previous: String, updated: String, at: Date)
    case markedResolved(concept: String, at: Date)

    public var timestamp: Date {
        switch self {
        case .requestedExplanation(_, let at), .askedQuestion(_, _, let at), .savedQuestion(_, _, let at),
             .attemptedExplanation(_, _, _, let at), .openedPrerequisite(_, let at),
             .openedRelatedSource(_, _, let at), .changedExplanation(_, _, _, let at),
             .markedResolved(_, let at):
            return at
        }
    }

    public var concept: String? {
        switch self {
        case .requestedExplanation(let concept, _), .attemptedExplanation(let concept, _, _, _),
             .openedPrerequisite(let concept, _), .changedExplanation(let concept, _, _, _),
             .markedResolved(let concept, _):
            return concept
        case .askedQuestion(_, let concept, _), .savedQuestion(_, let concept, _),
             .openedRelatedSource(_, let concept, _):
            return concept
        }
    }
}

/// A question the learner raised that no explicit action has closed.
public struct UnresolvedQuestion: Codable, Equatable, Sendable {
    public var text: String
    public var concept: String?
    public var raisedAt: Date

    public init(text: String, concept: String?, raisedAt: Date) {
        self.text = text
        self.concept = concept
        self.raisedAt = raisedAt
    }
}

public struct ExplanationAttempt: Codable, Equatable, Sendable {
    public var concept: String
    public var text: String
    public var verdict: AlignmentVerdict
    public var at: Date
    /// Set when the learner later edited this explanation.
    public var revisedTo: String?

    public init(concept: String, text: String, verdict: AlignmentVerdict, at: Date, revisedTo: String? = nil) {
        self.concept = concept
        self.text = text
        self.verdict = verdict
        self.at = at
        self.revisedTo = revisedTo
    }
}

/// What Leu knows about what the learner is currently working on.
///
/// Persisted structures are versioned and bound to the extraction version that
/// produced the knowledge they refer to, so a re-extraction can invalidate
/// stale references instead of silently pointing at the wrong atom.
public struct UnderstandingState: Codable, Equatable, Sendable {
    public static let schemaVersion = 1

    public var version: Int
    public var extractionVersion: String
    /// Concepts touched by explicit actions, most recent first.
    public var activeConcepts: [String]
    public var unresolvedQuestions: [UnresolvedQuestion]
    public var attemptedExplanations: [ExplanationAttempt]
    public var visitedDependencies: [String]
    public var relatedSourcesSeen: [String]
    public var resolvedByUser: [String]
    public var lastEventAt: Date?

    public init(version: Int = UnderstandingState.schemaVersion,
                extractionVersion: String = SourceSpan.currentExtractionVersion,
                activeConcepts: [String] = [],
                unresolvedQuestions: [UnresolvedQuestion] = [],
                attemptedExplanations: [ExplanationAttempt] = [],
                visitedDependencies: [String] = [],
                relatedSourcesSeen: [String] = [],
                resolvedByUser: [String] = [],
                lastEventAt: Date? = nil) {
        self.version = version
        self.extractionVersion = extractionVersion
        self.activeConcepts = activeConcepts
        self.unresolvedQuestions = unresolvedQuestions
        self.attemptedExplanations = attemptedExplanations
        self.visitedDependencies = visitedDependencies
        self.relatedSourcesSeen = relatedSourcesSeen
        self.resolvedByUser = resolvedByUser
        self.lastEventAt = lastEventAt
    }

    public var focusConcept: String? { activeConcepts.first }

    public func isResolved(_ concept: String) -> Bool { resolvedByUser.contains(concept) }
}

/// Folds explicit events into state. Pure function of the event log, so the
/// same log always projects to the same state.
public struct UnderstandingStateProjector: Sendable {
    public init() {}

    public func project(events: [LearningEvent],
                        extractionVersion: String = SourceSpan.currentExtractionVersion) -> UnderstandingState {
        var state = UnderstandingState(extractionVersion: extractionVersion)
        for event in events.sorted(by: { $0.timestamp < $1.timestamp }) {
            state.lastEventAt = event.timestamp
            if let concept = event.concept {
                state.activeConcepts.removeAll { $0 == concept }
                state.activeConcepts.insert(concept, at: 0)
            }
            switch event {
            case .askedQuestion(let text, let concept, let at):
                if !state.unresolvedQuestions.contains(where: { $0.text == text }) {
                    state.unresolvedQuestions.append(UnresolvedQuestion(text: text, concept: concept, raisedAt: at))
                }
            case .savedQuestion(let questionID, let concept, let at):
                let text = "saved question \(questionID)"
                if !state.unresolvedQuestions.contains(where: { $0.text == text }) {
                    state.unresolvedQuestions.append(UnresolvedQuestion(text: text, concept: concept, raisedAt: at))
                }
            case .attemptedExplanation(let concept, let text, let verdict, let at):
                state.attemptedExplanations.append(ExplanationAttempt(concept: concept, text: text, verdict: verdict, at: at))
            case .changedExplanation(let concept, let previous, let updated, let at):
                if let index = state.attemptedExplanations.lastIndex(where: { $0.concept == concept && $0.text == previous }) {
                    state.attemptedExplanations[index].revisedTo = updated
                } else {
                    state.attemptedExplanations.append(ExplanationAttempt(concept: concept,
                                                                          text: previous,
                                                                          verdict: .ambiguous,
                                                                          at: at,
                                                                          revisedTo: updated))
                }
            case .openedPrerequisite(let concept, _):
                if !state.visitedDependencies.contains(concept) { state.visitedDependencies.append(concept) }
            case .openedRelatedSource(let documentID, _, _):
                if !state.relatedSourcesSeen.contains(documentID) { state.relatedSourcesSeen.append(documentID) }
            case .markedResolved(let concept, _):
                if !state.resolvedByUser.contains(concept) { state.resolvedByUser.append(concept) }
                state.unresolvedQuestions.removeAll { $0.concept == concept }
            case .requestedExplanation:
                break
            }
        }
        return state
    }

    /// What changed between two explanations of the same concept, in terms of
    /// claims rather than characters.
    public func explanationDelta(previous: String,
                                 updated: String,
                                 concept: String?,
                                 in graph: KnowledgeGraph) -> ExplanationDelta {
        let aligner = ExplanationAligner()
        let before = aligner.align(explanation: previous, concept: concept, in: graph)
        let after = aligner.align(explanation: updated, concept: concept, in: graph)
        let beforeTypes = Set(before.findings.map(\.type))
        let afterTypes = Set(after.findings.map(\.type))
        return ExplanationDelta(resolved: beforeTypes.subtracting(afterTypes).sorted { $0.rawValue < $1.rawValue },
                                introduced: afterTypes.subtracting(beforeTypes).sorted { $0.rawValue < $1.rawValue },
                                verdictBefore: before.verdict,
                                verdictAfter: after.verdict)
    }
}

public struct ExplanationDelta: Codable, Equatable, Sendable {
    public var resolved: [MisconceptionType]
    public var introduced: [MisconceptionType]
    public var verdictBefore: AlignmentVerdict
    public var verdictAfter: AlignmentVerdict

    public init(resolved: [MisconceptionType],
                introduced: [MisconceptionType],
                verdictBefore: AlignmentVerdict,
                verdictAfter: AlignmentVerdict) {
        self.resolved = resolved
        self.introduced = introduced
        self.verdictBefore = verdictBefore
        self.verdictAfter = verdictAfter
    }

    public var improved: Bool {
        !resolved.isEmpty && introduced.isEmpty
    }
}
