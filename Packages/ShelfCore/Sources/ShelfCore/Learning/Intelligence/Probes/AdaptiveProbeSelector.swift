import Foundation

/// Why a probe was chosen. Internal: it steers wording in logs and tests, never the UI.
public enum ProbeReason: String, Codable, Sendable {
    /// Re-test a live misconception.
    case misconception
    /// Repair a weak prerequisite before returning to the concept.
    case prerequisite
    /// Climb to the next operation level.
    case climb
    /// Stated confidence outruns results: ask for an explanation, not a recognition.
    case overconfidence
    /// Nothing is weak: keep it alive with a different kind of question.
    case consolidate
    /// Follow through on a Teach It Back explanation: the question that settles an undecided
    /// reading, or a transfer check after an understood one.
    case verification
}

public struct ProbeDecision: Equatable, Sendable {
    public let probe: LearningProbe
    public let reason: ProbeReason
    /// A detour to start, when the probe repairs a prerequisite.
    public let startsObjective: RemediationObjective?
}

/// Keeps practice varied: the same prompt is not repeated soon, and one kind of question is
/// not asked three times in a row about the same concept.
public struct ProbeDiversity: Sendable {
    public static let repeatWindow = 6
    public init() {}

    public func admits(_ probe: LearningProbe, history: [ProbeRecord]) -> Bool {
        if history.suffix(Self.repeatWindow).contains(where: { $0.probeID == probe.id }) { return false }
        let recent = history.filter { $0.concept == probe.concept }.suffix(2)
        return !(recent.count == 2 && recent.allSatisfy { $0.operation == probe.operation })
    }

    /// Operations least recently asked about this concept come first.
    public func freshness(_ operation: ProbeOperation, concept: LearnerConceptID, history: [ProbeRecord]) -> Int {
        guard let last = history.lastIndex(where: { $0.concept == concept && $0.operation == operation }) else { return Int.max }
        return history.count - last
    }
}

/// Chooses the next question about a concept from what the learner model knows:
/// live misconceptions first, then a weak prerequisite (once, remembering the way back),
/// then the next level of understanding — recognise, explain, connect, transfer.
public struct AdaptiveProbeSelector: Sendable {
    public let knowledge: ConceptKnowledgeBase
    private let generator: ProbeGenerator
    public init(knowledge: ConceptKnowledgeBase) { self.knowledge = knowledge; generator = ProbeGenerator(knowledge: knowledge) }

    public enum Preference: Sendable { case open, choice, any }

    public func next(for concept: LearnerConceptID, state: LearnerModelState, preferring preference: Preference = .any,
                     now: Date, verification: PendingVerification? = nil) -> ProbeDecision? {
        let diversity = ProbeDiversity()
        let misconceptions = state.misconceptions(for: concept)
        let all = generator.probes(for: concept.concept, documentID: concept.documentID, misconceptions: misconceptions)
        func fitting(_ probes: [LearningProbe]) -> [LearningProbe] {
            probes.filter { probe in
                switch preference {
                case .open: return !probe.format.isChoice
                case .choice: return probe.format.isChoice
                case .any: return true
                }
            }
        }
        func usable(_ probes: [LearningProbe], freshOnly: Bool = false) -> [LearningProbe] {
            let fitting = fitting(probes)
            let fresh = fitting.filter { diversity.admits($0, history: state.recentProbes) }
            if !fresh.isEmpty || freshOnly { return fresh }
            // Everything was asked recently: anything but the very last question.
            let last = state.recentProbes.last?.probeID
            let others = fitting.filter { $0.id != last }
            return others.isEmpty ? fitting : others
        }
        func pick(_ probes: [LearningProbe], _ reason: ProbeReason, objective: RemediationObjective? = nil, freshOnly: Bool = false) -> ProbeDecision? {
            let ordered = usable(probes, freshOnly: freshOnly).sorted { a, b in
                let fa = diversity.freshness(a.operation, concept: concept, history: state.recentProbes)
                let fb = diversity.freshness(b.operation, concept: concept, history: state.recentProbes)
                return (fa, b.id) > (fb, a.id)
            }
            return ordered.first.map { ProbeDecision(probe: $0, reason: reason, startsObjective: objective) }
        }

        // 1. A detour in progress: repair the prerequisite first. A detour older than its lifetime
        // is over even if no answer has arrived since to close it.
        let objective = state.objective.flatMap { now.timeIntervalSince($0.startedAt) <= LearnerModelReducer.objectiveLifetime ? $0 : nil }
        if let objective, objective.objective == concept, objective.prerequisite != concept,
           let decision = definitionProbe(for: objective.prerequisite, state: state, preferring: preference, reason: .prerequisite) {
            return decision
        }
        // 2. A live misconception.
        if let record = state.strongestMisconception(for: concept, at: now), record.salience(at: now) >= 0.2 {
            let targeted = all.filter { probe in
                record.kind == .confusion ? probe.relatedConcept == record.relatedConcept && probe.operation == .contrast
                    : probe.operation == .misconceptionCheck && probe.rubricClaimIDs == [record.claimID ?? ""]
            }
            let discriminating = record.kind == .confusion ? all.filter { $0.operation == .recognizeDefinition || $0.operation == .recognizeExample } : []
            if let decision = pick(targeted, .misconception) ?? pick(discriminating, .misconception) { return decision }
        }
        // 2b. A Teach It Back explanation waiting on one more answer.
        if let verification, verification.concept == concept {
            switch verification.kind {
            case .discriminate:
                if preference != .choice, let probe = verification.question.flatMap({ asked(concept, $0) }) {
                    return ProbeDecision(probe: probe, reason: .verification, startsObjective: nil)
                }
            case .transfer:
                if let decision = pick(all.filter { $0.level >= 3 && $0.operation != .misconceptionCheck }, .verification) { return decision }
            }
        }
        let mastery = state.mastery(concept)
        let level = mastery?.level(at: now) ?? 0
        // 3. Failing at the basics with a weak prerequisite: detour once, then come back. A detour
        // that just ended is not followed by another before the concept itself is asked again.
        let prerequisites = knowledge.prerequisites(of: concept.concept).map { LearnerConceptID(documentID: concept.documentID, concept: $0) }
        let sinceLastAsked = state.recentProbes.reversed().prefix { $0.concept != concept }
        let justReturned = sinceLastAsked.contains { prerequisites.contains($0.concept) }
        if let mastery, level == 0, mastery.failsBasics, objective == nil, !justReturned {
            for id in prerequisites {
                let weak = state.mastery(id).flatMap { $0.coreStrength(at: now) }.map { $0 < 0.5 } ?? true
                guard weak, let decision = definitionProbe(for: id, state: state, preferring: preference, reason: .prerequisite,
                    objective: RemediationObjective(objective: concept, prerequisite: id, startedAt: now)) else { continue }
                return decision
            }
        }
        // 4. Overconfident learners explain rather than recognise.
        let overconfident = state.calibration.isOverconfident ||
            (mastery?.lastConfidentErrorAt.map { now.timeIntervalSince($0) < 14 * 86_400 } ?? false)
        let target = min(4, level + 1)
        let byDistance = Dictionary(grouping: all, by: { abs($0.level - target) })
        let reason: ProbeReason = overconfident ? .overconfidence : (level >= 4 ? .consolidate : .climb)
        // A fresh question one level away beats repeating one at the target level.
        for distance in byDistance.keys.sorted() {
            var candidates = byDistance[distance]!.filter { $0.operation != .misconceptionCheck }
            if overconfident, fitting(candidates).contains(where: { !$0.format.isChoice }) { candidates = candidates.filter { !$0.format.isChoice } }
            if let decision = pick(candidates, reason, freshOnly: true) { return decision }
        }
        // Everything was asked recently: the question asked longest ago, never the very last one.
        var pool = fitting(all.filter { $0.operation != .misconceptionCheck })
        if overconfident, pool.contains(where: { !$0.format.isChoice }) { pool = pool.filter { !$0.format.isChoice } }
        let last = state.recentProbes.last?.probeID
        let lastAsked = { (probe: LearningProbe) in state.recentProbes.lastIndex { $0.probeID == probe.id } ?? -1 }
        return pool.filter { $0.id != last || pool.count == 1 }
            .min { (lastAsked($0), abs($0.level - target), $0.id) < (lastAsked($1), abs($1.level - target), $1.id) }
            .map { ProbeDecision(probe: $0, reason: reason, startsObjective: nil) }
    }

    /// The question a Teach It Back comparison ended with, as an open probe — only while every
    /// claim that answers it is still in the source and the question passes the probe checks.
    private func asked(_ concept: LearnerConceptID, _ question: FollowUpQuestion) -> LearningProbe? {
        let claims = question.rubricClaimIDs.compactMap { id in knowledge.claims.first { $0.id == id } }
        guard !claims.isEmpty, claims.count == question.rubricClaimIDs.count,
              claims.allSatisfy({ $0.evidence.documentID == concept.documentID }) else { return nil }
        let name = knowledge.concept(concept.concept)?.name ?? claims[0].conceptName
        let related = question.operation == .contrast ? claims.map { $0.topic ?? $0.concept }.first { $0 != concept.concept } : nil
        let probe = LearningProbe(concept: concept, conceptName: name, operation: question.operation, prompt: question.prompt,
                                  format: .open, rubric: claims, relatedConcept: related)
        return ProbeValidator.failure(probe, in: knowledge) == nil ? probe : nil
    }

    private func definitionProbe(for concept: LearnerConceptID, state: LearnerModelState, preferring preference: Preference,
                                 reason: ProbeReason, objective: RemediationObjective? = nil) -> ProbeDecision? {
        let probes = generator.probes(for: concept.concept, documentID: concept.documentID)
            .filter { [.define, .recognizeDefinition].contains($0.operation) }
            .filter { preference == .any || (preference == .choice) == $0.format.isChoice }
        let diversity = ProbeDiversity()
        guard let probe = probes.first(where: { diversity.admits($0, history: state.recentProbes) }) ?? probes.first else { return nil }
        return ProbeDecision(probe: probe, reason: reason, startsObjective: objective)
    }
}
