import Foundation
@testable import ShelfCore

// THROWAWAY — V37 capability spike only (branch `test`, never merged into dev before a pass).

/// Weak reasoning scored apart from the state (PREREGISTRATION §4, amended 2026-09-29). A case can
/// hold a misconception and a reasoning fault at once; the state's precedence (misconception first)
/// must not hide the fault, on either the gold or the predicted side.
enum SpikeReasoning {
    /// The guide's reasoning faults: a right conclusion from a wrong reason, a wrong conclusion from a
    /// plausible reason, and co-occurrence read as cause.
    static let tags: Set<String> = ["rightConclusionWrongReasoning", "wrongConclusionPlausibleReason", "causeVsCorrelation"]

    /// Gold: an explicit `reasoningIssue` label when the fixture carries one (the new holdout does);
    /// otherwise a weak-reasoning state or a reasoning-fault tag.
    static func gold(_ item: GeneralizationEvaluation.Case, explicit: Bool?) -> Bool {
        explicit ?? (item.state == "weakReasoning" || !tags.isDisjoint(with: item.categories))
    }

    /// Predicted: the judgement names weak reasoning (the judge adds a weak-reasoning reading only
    /// when it decides on it), or — for a model reading — a surviving reason → conclusion link whose
    /// reason earns no credit, or whose conclusion is a wrong idea.
    static func predicted(_ judged: GeneralizationEvaluation.Judged, checked: SpikeChecked?) -> Bool {
        judged.state == "weakReasoning" || (checked.map(readingFlags) ?? false)
    }

    static func readingFlags(_ checked: SpikeChecked) -> Bool {
        checked.links.contains { link in
            let reason = checked.segments[link.reason - 1], conclusion = checked.segments[link.conclusion - 1]
            return (conclusion.credit != nil && reason.credit == nil) || conclusion.wrong != nil
        }
    }

    struct Count { var gold = 0, predicted = 0, detected = 0 }

    /// Explicit labels, read from the fixture file itself (the harness's `Case` does not carry them).
    static func explicitLabels(_ path: String) -> [String: Bool] {
        struct File: Decodable { struct Case: Decodable { let id: String; let reasoningIssue: Bool? }; let cases: [Case] }
        let url = path == "sealed36" ? LearningCorpus.fixtures.appendingPathComponent("diagnosis-generalization-sealed36.json")
            : URL(fileURLWithPath: path)
        guard let data = try? Data(contentsOf: url), let file = try? JSONDecoder().decode(File.self, from: data) else { return [:] }
        return Dictionary(file.cases.compactMap { item in item.reasoningIssue.map { (item.id, $0) } }, uniquingKeysWith: { a, _ in a })
    }

    /// Per configuration: gold and predicted reasoning issues, and how many predictions are right.
    static func count(_ fixture: GeneralizationEvaluation.Fixture, explicit: [String: Bool], tally: SpikeScore.Tally) -> [String: Count] {
        var result: [String: Count] = [:]
        for (name, cases) in tally.judged {
            var count = Count()
            for item in fixture.cases {
                guard let judged = cases[item.id] else { continue }
                let isGold = gold(item, explicit: explicit[item.id])
                let isPredicted = predicted(judged, checked: tally.outcomes[name]?[item.id]?.checked)
                if isGold { count.gold += 1 }
                if isPredicted { count.predicted += 1 }
                if isGold && isPredicted { count.detected += 1 }
            }
            result[name] = count
        }
        return result
    }
}
