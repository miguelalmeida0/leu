import Foundation
@testable import ShelfCore

// THROWAWAY — V37 capability spike only (branch `test`, never merged into dev before a pass).

/// The canonical cases' pass criteria (SPIKE_SPEC §3.2, encoded in `cases/canonical.json`), checked
/// automatically from the recorded reading and the judgement. Every criterion must hold.
enum SpikeCanonical {
    struct Criteria: Decodable {
        /// A segment's label: its claim and relation (and polarity), or a mistake "about" the named idea.
        struct Reading: Decodable {
            let claimIDs: [String]?
            let relations: [String]?
            let polarity: String?
            let orMisconceptionAbout: String?
            let secondOpinionMustNotBe: String?
        }
        let reading: Reading?, conclusion: Reading?, reason: Reading?
        let segmentContaining: String?
        let reasonLinkedToConclusion: Bool?
        let states: [String]?
        let recordsCredit, recordsMastery, recordsMisconception, asksProbe: Bool?
        let misconceptionRecordedOrMisconceptionCheckAsked: Bool?
        let ifAskedClaimIDsInclude: [String]?
        /// The one next question asks about one of these claims (C4, amended 2026-09-29).
        let nextQuestionClaimIDsInclude: [String]?
    }
    struct Case: Decodable { let id: String; let passCriteria: Criteria? }
    struct File: Decodable { let cases: [Case] }

    /// What makes an answer-key mistake "about" an idea: its text names it. Fixed before any model run.
    static let mistakeTopics: [String: [String]] = [
        "copying values": ["cop"],
        "signing versus encryption": ["encrypt", "read", "secret", "hidden", "private"]
    ]

    /// The failed criteria (empty when the case passes).
    static func check(_ c: Criteria, config: SpikeConfig, outcome: SpikeAdapter.Outcome, record: SpikeRecord?,
                      key: SpikeAnswerKey?, spike: SpikeInput) -> [String] {
        var failed: [String] = []
        let judged = outcome.judged
        let labels = record?.reading.output?.segments ?? []
        let links = record?.reading.output?.links ?? []
        if outcome.fallback != .none { failed.append("fallback:" + outcome.fallback.rawValue) }
        func text(_ n: Int) -> String { spike.segments.first { $0.n == n }?.text.lowercased() ?? "" }
        func about(_ label: SpikeSegmentLabel, _ idea: String?) -> Bool {
            guard let idea, let words = mistakeTopics[idea], let mistake = key?.mistakes.first(where: { $0.id == label.misconception }) else { return false }
            return words.contains { mistake.text.lowercased().contains($0) }
        }
        func matches(_ label: SpikeSegmentLabel, _ r: Criteria.Reading) -> Bool {
            let direct = (r.claimIDs?.contains(label.claim) ?? true) && (r.relations?.contains(label.relation) ?? true)
                && (r.polarity.map { $0 == label.polarity } ?? true)
            return direct || about(label, r.orMisconceptionAbout)
        }
        if let r = c.reading {
            let candidates = labels.filter { label in c.segmentContaining.map { text(label.n).contains($0.lowercased()) } ?? true }
            if !candidates.contains(where: { matches($0, r) }) { failed.append("reading") }
        }
        if let r = c.conclusion {
            let conclusions = labels.filter { matches($0, r) }.map(\.n)
            if conclusions.isEmpty { failed.append("conclusion") }
            let linked = links.filter { conclusions.contains($0.conclusion) && $0.reason != $0.conclusion }
            if c.reasonLinkedToConclusion == true && linked.isEmpty { failed.append("link") }
            if let reason = c.reason {
                let reasons = linked.compactMap { link in labels.first { $0.n == link.reason } }
                if !reasons.contains(where: { matches($0, reason) }) { failed.append("reason") }
                // D only: the second opinion must not call the reason the source's own.
                if config == .d, let forbidden = reason.secondOpinionMustNotBe, let output = record?.secondOpinion?.output {
                    let verdicts = Dictionary(output.verdicts.map { ($0.item, $0.verdict) }, uniquingKeysWith: { a, _ in a })
                    let said = output.items.filter { item in item.kind == "reason" && linked.contains { $0.reason == item.segment } }
                        .compactMap { verdicts[$0.item] }
                    if said.contains(forbidden) { failed.append("secondOpinion") }
                }
            }
        }
        if let states = c.states {
            let stated = states.contains(judged.state)
            if c.misconceptionRecordedOrMisconceptionCheckAsked == true {
                // §3.2: "state misconception, committed or asked as a misconception check": committed is
                // the state without a question; asked is a question that weighs a misconception.
                let committed = stated && !judged.asksProbe
                let asked = judged.asksProbe && (outcome.assessment?.judgement.question?.between.contains(.misconception) ?? false)
                if !(committed || asked) { failed.append("state") }
            } else if !stated { failed.append("state") }
        }
        if let v = c.recordsCredit, judged.recordsCredit != v { failed.append("recordsCredit") }
        if let v = c.recordsMastery, judged.recordsMastery != v { failed.append("recordsMastery") }
        if let v = c.recordsMisconception, judged.recordsMisconception != v { failed.append("recordsMisconception") }
        if let v = c.asksProbe, judged.asksProbe != v { failed.append("asksProbe") }
        if let ids = c.ifAskedClaimIDsInclude, judged.asksProbe, Set(ids).isDisjoint(with: judged.probeClaims) { failed.append("question") }
        if let ids = c.nextQuestionClaimIDsInclude, Set(ids).isDisjoint(with: outcome.nextClaims) { failed.append("nextQuestion") }
        return failed
    }

    /// For a fixture with pass criteria: each configuration's failures per case, printed verbatim
    /// (the canonical set is open). Nil for any other fixture.
    static func evaluate(_ path: String, tally: SpikeScore.Tally, recorded: SpikeScore.Recorded) -> [String: Any]? {
        guard path != "sealed36", let data = FileManager.default.contents(atPath: path),
              let file = try? JSONDecoder().decode(File.self, from: data), file.cases.contains(where: { $0.passCriteria != nil }) else { return nil }
        var result: [String: Any] = [:]
        for config in SpikeConfig.allCases {
            guard let outcomes = tally.outcomes[config.rawValue] else { continue }
            var failures: [String: [String]] = [:]
            for item in file.cases {
                guard let criteria = item.passCriteria, let outcome = outcomes[item.id], let spike = tally.spikes[item.id] else {
                    failures[item.id] = ["notScored"]; continue
                }
                failures[item.id] = check(criteria, config: config, outcome: outcome, record: recorded.records[item.id],
                                          key: recorded.keys[spike.targetKey], spike: spike)
                let verdict = failures[item.id]!.isEmpty ? "PASS" : "FAIL " + failures[item.id]!.joined(separator: ",")
                print("SPIKE-CANONICAL|\(config.rawValue)|\(item.id)|\(verdict)")
            }
            let passed = failures.values.filter(\.isEmpty).count
            print("SPIKE-CANONICAL|\(config.rawValue)|passed \(passed)/\(file.cases.count)")
            result[config.rawValue] = ["failures": failures, "passed": passed, "cases": file.cases.count]
        }
        return result
    }
}

/// Per-case rows for open sets (P and C): the gold label and every configuration's decision.
enum SpikeRows {
    static func rows(_ fixture: GeneralizationEvaluation.Fixture, tally: SpikeScore.Tally, recorded: SpikeScore.Recorded) -> [[String: Any]] {
        fixture.cases.map { item in
            var row: [String: Any] = ["id": item.id, "gold": item.state, "goldCoarse": SpikeScore.goldCoarse(item), "categories": item.categories]
            for (name, cases) in tally.judged {
                guard let judged = cases[item.id] else { continue }
                var entry: [String: Any] = ["state": judged.state, "asks": judged.asksProbe, "mastery": judged.recordsMastery,
                                            "misconception": judged.recordsMisconception, "probeClaims": judged.probeClaims]
                if let outcome = tally.outcomes[name]?[item.id] {
                    entry["fallback"] = outcome.fallback.rawValue
                    entry["fired"] = outcome.checked?.fired ?? []
                }
                row[name] = entry
            }
            if let record = recorded.records[item.id] { row["readingStatus"] = record.reading.status }
            return row
        }
    }
}
