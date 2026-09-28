import Foundation

public enum InterventionKind: String, Codable, Sendable {
    /// Understanding is solid: ask a harder, different kind of question.
    case deepen
    /// Core right, limiting condition missing.
    case addCondition
    /// A key idea is missing: cue it without revealing it.
    case cueMissingIdea
    /// The learner stated the opposite of the source: show the source sentence.
    case correctContradiction
    /// Cause and effect (or subject and object) are swapped.
    case clarifyDirection
    /// Another concept's property was attributed to this one.
    case distinguishConcepts
    /// Universal wording where the source is qualified.
    case qualify
    /// The concept was explained with its own name.
    case rephraseWithoutName
    /// Source wording reproduced: ask for the learner's own words.
    case explainInOwnWords
    /// Nothing comparable, or only statements the source does not settle.
    case returnToSource
}

/// One targeted question. Its rubric is the grounded claims that answer it.
public struct FollowUpQuestion: Codable, Equatable, Hashable, Sendable {
    public let prompt: String
    public let rubricClaimIDs: [String]
    public let operation: ProbeOperation
    public let concept: ConceptKey?
}

/// The smallest useful next step. Messages are fixed templates plus source or learner words.
public struct LearningIntervention: Codable, Equatable, Sendable {
    public let kind: InterventionKind
    public let message: String
    public let followUp: FollowUpQuestion?
    public let focusClaimID: String?
    /// Where to look in the document.
    public let source: SourceSpan?
    public let relatedConcept: ConceptKey?
    /// True only when the message quotes the source sentence (a contradiction must be corrected).
    public let revealsSource: Bool

    static let placeholder = LearningIntervention(kind: .returnToSource, message: "", followUp: nil, focusClaimID: nil,
                                                  source: nil, relatedConcept: nil, revealsSource: false)
}

struct InterventionPlanner {
    /// When the judgement needs one more answer, the next step is the question that tells its
    /// leading readings apart; otherwise it follows from the diagnosis.
    func plan(_ diagnosis: UnderstandingDiagnosis, target: DiagnosisTarget, judgement: UnderstandingJudgement) -> LearningIntervention {
        // Nothing comparable, or source wording copied: the diagnosis's own next step already asks.
        // A wrong idea the diagnosis states is still shown beside the source, as the comparison
        // shows it ("check this"); the judgement only holds back recording it until it is settled.
        guard let question = judgement.question, question.between.first != .insufficientEvidence, diagnosis.level != .surface,
              !diagnosis.hasMisconception, let followUp = FollowUps.discriminating(question, target: target) else { return plan(diagnosis, target: target) }
        let focus = question.claimIDs.first.flatMap { id in target.allClaims.first { $0.id == id } }
        // Nothing is revealed yet: the answer to the follow-up is what decides. The message states
        // only the doubt (a recall card shows the message without the question).
        if let other = question.relatedConcept, question.operation == .contrast {
            let otherName = target.names[other]?.first ?? other.value
            return make(.distinguishConcepts, "Your explanation could also describe \(otherName).", followUp, focus, related: other)
        }
        let message = question.between.contains(.misconception)
            ? "Leu can't tell yet how you read one part of your source."
            : "You may have this already, but Leu can't tell from these words yet."
        return make(.cueMissingIdea, message, followUp, focus)
    }

    func plan(_ diagnosis: UnderstandingDiagnosis, target: DiagnosisTarget) -> LearningIntervention {
        let name = target.conceptName.map { PromptRealizer.inline($0) } ?? "this idea"
        let display = target.conceptName ?? "this idea"
        func issue(_ kind: UnderstandingIssueKind) -> UnderstandingIssue? { diagnosis.issues.first { $0.kind == kind } }
        func claim(_ id: String?) -> LearningClaim? { id.flatMap { id in target.allClaims.first { $0.id == id } } }
        let definition = target.rubric.first { $0.kind == .definition } ?? target.rubric.first

        switch diagnosis.level {
        case .insufficient:
            return make(.returnToSource, "Leu couldn't compare this with your source yet. Read the passage again, then explain it in one or two sentences.",
                        FollowUps.define(target), definition)
        case .misconceived:
            if let found = issue(.contradiction), let wrong = claim(found.claimID) {
                let learner = Self.quote(found.learnerText)
                return make(.correctContradiction, "You wrote “\(learner)”. \(wrong.citation()).",
                            FollowUps.restate(wrong, operation: .misconceptionCheck), wrong, reveals: true)
            }
            if let found = issue(.causalReversal), let reversed = claim(found.claimID) {
                return make(.clarifyDirection, "You have the right pieces, but the direction is reversed. Look again at which one acts on the other.",
                            FollowUps.restate(reversed, operation: .misconceptionCheck), reversed)
            }
            if let found = issue(.confusedConcept), let other = claim(found.claimID) {
                let otherName = other.topic.flatMap { target.names[$0]?.first } ?? other.conceptName
                let prompt = target.concept != nil ? FollowUps.contrast(target, other: other) : FollowUps.restate(other, operation: .misconceptionCheck)
                return make(.distinguishConcepts, "That describes \(otherName), not \(display). \(other.citation()).",
                            prompt, definition, related: other.topic ?? other.concept, reveals: true)
            }
        case .circular:
            return make(.rephraseWithoutName, "Try explaining \(name) without using the word “\(display)”: what does it do, or what is it made of?",
                        FollowUps.define(target), definition)
        case .surface:
            return make(.explainInOwnWords, "That matches your source's wording closely. Now say it in your own words: why does it matter?",
                        FollowUps.deeper(target, after: diagnosis), definition)
        default: break
        }
        if let found = issue(.overgeneralization), let limited = claim(found.claimID) {
            return make(.qualify, "Your source is more careful than that: it does not say this holds in every case.",
                        FollowUps.condition(limited) ?? FollowUps.restate(limited, operation: .condition), limited)
        }
        if let found = issue(.droppedCondition), let limited = claim(found.claimID), let question = FollowUps.condition(limited) {
            return make(.addCondition, "You have the core idea. What condition limits it?", question, limited)
        }
        let missing = diagnosis.missing.sorted { ($0.kind == .definition ? 0 : 1, $0.evidence.range.location) < ($1.kind == .definition ? 0 : 1, $1.evidence.range.location) }
        if diagnosis.level == .unrelated {
            return make(.returnToSource, "Your source doesn't settle what you wrote. What does the passage itself say about \(name)?",
                        FollowUps.define(target), definition)
        }
        // Only an explanation that covers every key idea is told so; anything less is cued.
        if let next = missing.first ?? diagnosis.partial.first {
            let message = diagnosis.covered.isEmpty && diagnosis.partial.isEmpty ? "Start from one key idea in your source."
                : missing.isEmpty ? "You have most of it. One key idea is only partly there." : "You have part of it. One key idea is still missing."
            return make(.cueMissingIdea, message, FollowUps.restate(next, operation: FollowUps.operation(for: next)), next)
        }
        return make(.deepen, "Your explanation covers each key idea in your source.", FollowUps.deeper(target, after: diagnosis), definition)
    }

    private func make(_ kind: InterventionKind, _ message: String, _ followUp: FollowUpQuestion?, _ focus: LearningClaim?,
                      related: ConceptKey? = nil, reveals: Bool = false) -> LearningIntervention {
        LearningIntervention(kind: kind, message: message, followUp: followUp, focusClaimID: focus?.id,
                             source: focus?.evidence, relatedConcept: related, revealsSource: reveals)
    }

    static func quote(_ text: String?) -> String {
        let clean = CanonicalWhitespaceResolver.normalize(text ?? "").trimmingCharacters(in: CharacterSet(charactersIn: ".;, "))
        return clean.count > 160 ? String(clean.prefix(157)) + "…" : clean
    }
}

/// Follow-up questions built from grounded claims only.
enum FollowUps {
    static func operation(for claim: LearningClaim) -> ProbeOperation {
        switch claim.kind {
        case .definition: return .define
        case .purpose, .consequence: return .purpose
        case .constraint, .cause: return claim.qualifier != nil ? .condition : .mechanism
        case .contrast: return .contrast
        default: return .mechanism
        }
    }

    static func define(_ target: DiagnosisTarget) -> FollowUpQuestion? {
        guard let definition = target.rubric.first(where: { $0.kind == .definition }) ?? target.rubric.first else { return nil }
        if let name = target.conceptName {
            return FollowUpQuestion(prompt: "In one sentence, what is \(PromptRealizer.inline(name))?", rubricClaimIDs: [definition.id],
                                    operation: .define, concept: target.concept)
        }
        return restate(definition, operation: .define)
    }

    /// A question answered by `claim`, without its answer words.
    static func restate(_ claim: LearningClaim, operation: ProbeOperation) -> FollowUpQuestion {
        let prompt = claim.kind == .definition && claim.grounding.isInferred
            ? "In one sentence, what is \(PromptRealizer.inline(claim.conceptName))?"
            : PromptRealizer.objectQuestion(claim) ?? PromptRealizer.conditionQuestion(claim)
                ?? "What does your source say about \(subjectPhrase(claim))?"
        return FollowUpQuestion(prompt: prompt, rubricClaimIDs: [claim.id], operation: operation, concept: claim.topic ?? claim.concept)
    }

    static func condition(_ claim: LearningClaim) -> FollowUpQuestion? {
        PromptRealizer.conditionQuestion(claim).map {
            FollowUpQuestion(prompt: $0, rubricClaimIDs: [claim.id], operation: .condition, concept: claim.topic ?? claim.concept)
        }
    }

    static func contrast(_ target: DiagnosisTarget, other: LearningClaim) -> FollowUpQuestion? {
        guard let name = target.conceptName, let own = target.rubric.first(where: { $0.kind == .definition }) ?? target.rubric.first else { return nil }
        let otherKey = other.topic ?? other.concept
        let otherName = target.names[otherKey]?.first ?? other.conceptName
        let otherDefinition = target.competitors.first { ($0.topic ?? $0.concept) == otherKey && $0.kind == .definition } ?? other
        return FollowUpQuestion(prompt: "How does \(PromptRealizer.inline(name)) differ from \(PromptRealizer.inline(otherName))?",
                                rubricClaimIDs: [own.id, otherDefinition.id], operation: .contrast, concept: target.concept)
    }

    /// The question a discriminating decision asks, worded from its claims.
    static func discriminating(_ question: DiscriminatingQuestion, target: DiagnosisTarget) -> FollowUpQuestion? {
        if question.operation == .contrast, let other = question.relatedConcept {
            let theirs = target.competitors.filter { AlignmentContext.owner(of: $0, names: target.names) == other }
            guard let partner = theirs.first(where: { $0.kind == .definition }) ?? theirs.first else { return nil }
            return contrast(target, other: partner)
        }
        if question.operation == .define { return define(target) }
        guard let claim = question.claimIDs.first.flatMap({ id in target.allClaims.first { $0.id == id } }) else { return define(target) }
        if question.operation == .condition, let asked = condition(claim) { return asked }
        return restate(claim, operation: question.operation)
    }

    /// After solid understanding (or a verbatim restatement): a different, harder angle.
    static func deeper(_ target: DiagnosisTarget, after diagnosis: UnderstandingDiagnosis) -> FollowUpQuestion? {
        let purpose = target.rubric.first { [.purpose, .consequence, .mechanism].contains($0.kind) && $0.kind != .definition }
        if diagnosis.level == .surface, let purpose { return restate(purpose, operation: .purpose) }
        if let other = target.contrastDefinition, target.concept != nil { return contrast(target, other: other) }
        if let purpose { return restate(purpose, operation: operation(for: purpose)) }
        return define(target)
    }

    static func subjectPhrase(_ claim: LearningClaim) -> String {
        claim.grounding.isInferred ? PromptRealizer.inline(claim.conceptName)
            : ConceptText.lowercasingLead(CanonicalWhitespaceResolver.normalize(claim.subject))
    }
}
