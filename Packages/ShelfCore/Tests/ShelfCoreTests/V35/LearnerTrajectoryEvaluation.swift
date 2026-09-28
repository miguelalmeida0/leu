import Foundation
@testable import ShelfCore

/// Learner-model trajectories built from the labeled generalization explanations, replayed
/// through a predictor's evidence and the real reducer:
/// * recovery — a recorded misconception, then two explanations that express the corrected idea
///   on later days, should leave no active misconception;
/// * recency — an understood explanation followed by a misconception should end as a misconception;
/// * stability — explanations that mean the same thing, given on consecutive days, should not
///   make the learner's state flip.
enum LearnerTrajectoryEvaluation {
    struct Report: CustomStringConvertible {
        var recoveryEligible = 0, recovered = 0
        var recencySequences = 0, recencyCaught = 0
        var stabilityGroups = 0, stableGroups = 0, flips = 0
        var description: String {
            "recovery=\(recovered)/\(recoveryEligible) recency=\(recencyCaught)/\(recencySequences) "
                + "stableTrajectories=\(stableGroups)/\(stabilityGroups) flips=\(flips)"
        }
    }

    /// One reading of the learner model, the same for every predictor: an active, salient
    /// misconception; more success than failure on some operation; or neither.
    static func reference(_ state: LearnerModelState, _ concept: LearnerConceptID, at date: Date) -> String {
        if state.misconceptions(for: concept).contains(where: { $0.status == .active && $0.salience(at: date) >= 0.2 }) { return "misconception" }
        guard let mastery = state.mastery(concept), !mastery.operations.isEmpty else { return "unknown" }
        return (mastery.operations.map(\.estimate).max() ?? 0) >= 0.6 ? "positive" : "weak"
    }

    static func day(_ n: Int) -> Date { GeneralizationEvaluation.epoch.addingTimeInterval(Double(n) * 86_400 + 3_600) }

    /// Applies one explanation given on `day`, judged against the learner model as it stands.
    static func apply(_ input: GeneralizationEvaluation.Input, day n: Int, to state: inout LearnerModelState,
                      _ predictor: GeneralizationEvaluation.Predictor, tag: String) {
        var input = input
        input.prior = state
        input.at = day(n)
        let judged = predictor(input, input.item.text)
        // A second telling of the same explanation is a new answer, not a replay of the first.
        let evidence = judged.evidence.map { item in
            LearningEvidence(concept: item.concept, conceptName: item.conceptName, operation: item.operation, outcome: item.outcome,
                             channel: item.channel, confidence: item.confidence, claimIDs: item.claimIDs, misconception: item.misconception,
                             probeID: item.probeID, occurredAt: day(n), rivals: item.rivals, identity: item.id + "|" + tag)
        }
        LearnerModelReducer().apply(evidence, to: &state)
    }

    static func evaluate(_ fixture: GeneralizationEvaluation.Fixture, _ predictor: GeneralizationEvaluation.Predictor) -> Report {
        var report = Report()
        let items = fixture.cases.filter { $0.concept != nil }
        var inputs: [String: GeneralizationEvaluation.Input] = [:]
        for item in items { inputs[item.id] = GeneralizationEvaluation.input(for: item) }
        func sentence(_ key: String, _ input: GeneralizationEvaluation.Input) -> String? {
            (input.target.rubric + input.target.supporting).first { CanonicalWhitespaceResolver.normalize($0.evidence.text).contains(key) }?.id
        }
        let byConcept = Dictionary(grouping: items, by: { $0.concept! })
        for concept in byConcept.keys.sorted() {
            let cases = byConcept[concept]!.filter { inputs[$0.id] != nil }
            guard let first = cases.first, let conceptInput = inputs[first.id], let key = conceptInput.target.concept else { continue }
            let learner = LearnerConceptID(documentID: conceptInput.documentID, concept: key)
            let positives = cases.filter { ["understood", "mostlyUnderstood"].contains($0.state) && $0.misconceptions.isEmpty }
            let wrong = cases.filter { $0.state == "misconception" }
            // Recovery: the corrected idea expressed twice, on different later days.
            for mistaken in wrong {
                guard let claimKey = mistaken.misconceptions.first(where: { $0.kind != "confusion" })?.claim,
                      let claim = sentence(claimKey, inputs[mistaken.id]!) else { continue }
                let fixes = positives.filter { positive in positive.credits.contains { sentence($0, inputs[positive.id]!) == claim } }
                guard let fix = fixes.first else { continue }
                var state = LearnerModelState()
                apply(inputs[mistaken.id]!, day: 0, to: &state, predictor, tag: "m")
                guard reference(state, learner, at: day(0)) == "misconception" else { continue }
                report.recoveryEligible += 1
                apply(inputs[fix.id]!, day: 1, to: &state, predictor, tag: "fix1")
                apply(inputs[(fixes.count > 1 ? fixes[1] : fix).id]!, day: 3, to: &state, predictor, tag: "fix2")
                if reference(state, learner, at: day(3)) != "misconception" { report.recovered += 1 }
            }
            // Recency: understanding shown, then a misconception stated.
            for mistaken in wrong {
                guard let understood = positives.first else { break }
                var state = LearnerModelState()
                apply(inputs[understood.id]!, day: 0, to: &state, predictor, tag: "p")
                apply(inputs[mistaken.id]!, day: 1, to: &state, predictor, tag: "m")
                report.recencySequences += 1
                if reference(state, learner, at: day(1)) == "misconception" { report.recencyCaught += 1 }
            }
        }
        // Stability: one paraphrase group, one member per day.
        let groups = Dictionary(grouping: items.filter { $0.paraphraseGroup != nil && inputs[$0.id] != nil }, by: { $0.paraphraseGroup! })
        for id in groups.keys.sorted() {
            let members = groups[id]!.sorted { $0.id < $1.id }
            guard members.count >= 2, let input = inputs[members[0].id], let key = input.target.concept else { continue }
            let learner = LearnerConceptID(documentID: input.documentID, concept: key)
            var state = LearnerModelState(), readings: [String] = []
            for (n, member) in members.enumerated() {
                apply(inputs[member.id]!, day: n, to: &state, predictor, tag: "g\(n)")
                readings.append(reference(state, learner, at: day(n)))
            }
            let changes = zip(readings.dropFirst(), readings.dropFirst(2)).filter { $0 != $1 }.count
            report.stabilityGroups += 1
            report.flips += changes
            if changes == 0 { report.stableGroups += 1 }
        }
        return report
    }
}
