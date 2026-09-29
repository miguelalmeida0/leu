import XCTest
@testable import ShelfCore

// THROWAWAY — V37 capability spike only (branch `claude/v37-capability-spike`, never merged).

/// Scores one recorded run (SPIKE_SPEC §8, PREREGISTRATION §4): A0 and A directly, B/C/D from the
/// recorded readings through the checks and the adapter. Open sets (P, C) also get per-case rows.
/// Blind sets (the gate, sealed36) print aggregates only; their per-case signatures go only to the
/// output file, which must sit in a `blind/` directory and is never printed.
enum SpikeScore {
    struct Refusal: Error { let reason: String }

    struct Recorded {
        var records: [String: SpikeRecord] = [:]
        var keys: [String: SpikeAnswerKey] = [:]
    }

    /// What each predictor concluded per case, filled while `GeneralizationEvaluation.evaluate` runs.
    final class Tally {
        var judged: [String: [String: GeneralizationEvaluation.Judged]] = [:]
        var outcomes: [String: [String: SpikeAdapter.Outcome]] = [:]
        var spikes: [String: SpikeInput] = [:]
    }

    static func capturing(_ name: String, _ predictor: @escaping GeneralizationEvaluation.Predictor, _ tally: Tally) -> GeneralizationEvaluation.Predictor {
        { input, text in
            let judged = predictor(input, text)
            tally.judged[name, default: [:]][input.item.id] = judged
            return judged
        }
    }

    static func predictor(_ config: SpikeConfig, set: String, recorded: Recorded, tally: Tally) -> GeneralizationEvaluation.Predictor {
        { input, _ in
            let spike = SpikeInput.make(input.item, set: set, target: input.target)
            let outcome = SpikeAdapter.judge(input, spike: spike, record: recorded.records[input.item.id],
                                             key: recorded.keys[spike.targetKey], config: config)
            tally.spikes[input.item.id] = spike
            tally.outcomes[config.rawValue, default: [:]][input.item.id] = outcome
            tally.judged[config.rawValue, default: [:]][input.item.id] = outcome.judged
            return outcome.judged
        }
    }

    static func signature(_ judged: GeneralizationEvaluation.Judged) -> String {
        "\(judged.state)|\(judged.asksProbe)|\(judged.recordsMastery)|\(judged.recordsMisconception)"
    }

    static func goldCoarse(_ item: GeneralizationEvaluation.Case) -> String {
        GeneralizationEvaluation.coarse(item.state, misconception: !item.misconceptions.isEmpty)
    }

    static func report(_ r: GeneralizationEvaluation.Report) -> [String: Any] {
        var result: [String: Any] = [
            "cases": r.cases, "unavailable": r.unavailable, "exact": r.exact, "coarseRight": r.coarseRight,
            "goldNotPositive": r.goldNotPositive, "falseMastery": r.falseMastery, "goldPositive": r.goldPositive,
            "masteryCredited": r.masteryCredited, "goldMisconception": r.goldMisconception, "misconceptionRecorded": r.misconceptionRecorded,
            "misconceptionProbed": r.misconceptionProbed, "misconceptionCredited": r.misconceptionCredited,
            "goldNoMisconception": r.goldNoMisconception, "falseMisconception": r.falseMisconception,
            "goldWeakReasoning": r.goldWeakReasoning, "weakReasoningDetected": r.weakReasoningDetected,
            "predictedWeakReasoning": r.predictedWeakReasoning, "probes": r.probes, "committed": r.committed,
            "committedRight": r.committedRight, "overCredit": r.overCredit, "falseAlarm": r.falseAlarm,
            "missedMisconception": r.missedMisconception, "underCredit": r.underCredit, "targetedProbes": r.targetedProbes,
            "harmfulWrites": r.harmfulWrites, "brier": r.brierScore, "ece": r.ece,
            "groups": r.groups, "stableGroups": r.stableGroups, "coarseStableGroups": r.coarseStableGroups
        ]
        result["perCategory"] = r.perCategory.mapValues { ["n": $0.n, "right": $0.right, "falseMastery": $0.falseMastery] }
        result["perState"] = r.perState.mapValues { ["n": $0.n, "right": $0.right, "probed": $0.probed] }
        return result
    }

    /// Per case, any failure in any model call (PREREGISTRATION §4); V1 failures count as schema errors.
    static func failures(_ fixture: GeneralizationEvaluation.Fixture, _ recorded: Recorded, _ tally: Tally) -> [String: Int] {
        var result = ["cases": fixture.cases.count, "schemaError": 0, "refused": 0, "timeout": 0, "other": 0, "missing": 0, "empty": 0]
        for item in fixture.cases {
            if tally.spikes[item.id]?.segments.isEmpty == true { result["empty"]! += 1; continue }
            guard let record = recorded.records[item.id] else { result["missing"]! += 1; continue }
            let statuses = [record.reading.status, record.secondOpinion?.status ?? "none"]
            let invalid = tally.outcomes.values.contains { $0[item.id]?.fallback == .invalidReading }
            if statuses.contains("schemaError") || invalid { result["schemaError"]! += 1 }
            if statuses.contains("refused") { result["refused"]! += 1 }
            if statuses.contains("timeout") { result["timeout"]! += 1 }
            if statuses.contains(where: { !["ok", "none", "schemaError", "refused", "timeout"].contains($0) }) { result["other"]! += 1 }
        }
        return result
    }

    /// How often the second opinion agreed with the reading, by item kind (reported, not decided).
    static func opinion(_ recorded: Recorded) -> [String: Any] {
        var byKind: [String: [String: Int]] = [:]
        var agreeing = 0, items = 0
        for record in recorded.records.values {
            guard let output = record.secondOpinion?.output else { continue }
            let verdicts = Dictionary(output.verdicts.map { ($0.item, $0.verdict) }, uniquingKeysWith: { a, _ in a })
            for item in output.items {
                let verdict = verdicts[item.item] ?? "missing"
                byKind[item.kind, default: [:]][verdict, default: 0] += 1
                items += 1
                let agrees: Set<String> = item.kind == "contradiction" ? ["opposite"] : item.kind == "reason" ? ["opposite", "different"] : ["same", "part"]
                if agrees.contains(verdict) { agreeing += 1 }
            }
        }
        return ["items": items, "agreeing": agreeing, "byKind": byKind]
    }

    static func latency(_ recorded: Recorded, _ tally: Tally) -> [[String: Any]] {
        recorded.records.values.sorted { ($0.device, $0.run, $0.processCallIndex) < ($1.device, $1.run, $1.processCallIndex) }.map { record in
            ["words": tally.spikes[record.caseID]?.wordCount ?? -1, "cold": record.cold, "processCallIndex": record.processCallIndex,
             "device": record.device, "run": record.run, "readingMs": record.reading.latencyMs, "readingStatus": record.reading.status,
             "readingRetries": record.reading.retries, "opinionMs": record.secondOpinion?.latencyMs ?? 0,
             "opinionStatus": record.secondOpinion?.status ?? "none", "totalMs": record.totalLatencyMs]
        }
    }

    static func load(_ env: [String: String]) throws -> (GeneralizationEvaluation.Fixture, Recorded) {
        let cases = env["LEU_SPIKE_SCORE_CASES"]!
        let fixture: GeneralizationEvaluation.Fixture
        if cases == "sealed36" { fixture = try XCTUnwrap(GeneralizationEvaluation.fixture("sealed36")) }
        else { fixture = try JSONDecoder().decode(GeneralizationEvaluation.Fixture.self, from: Data(contentsOf: URL(fileURLWithPath: cases))) }
        var recorded = Recorded()
        if let readings = env["LEU_SPIKE_SCORE_READINGS"] { recorded.records = try SpikeRecord.load(readings) }
        if let keys = env["LEU_SPIKE_SCORE_KEYS"] {
            recorded.keys = try JSONDecoder().decode(SpikeAnswerKeyFile.self, from: Data(contentsOf: URL(fileURLWithPath: keys))).keys
        }
        return (fixture, recorded)
    }
}

/// Runs only when `LEU_SPIKE_SCORE_CASES` (a fixture path, or `sealed36`), `LEU_SPIKE_SCORE_SET`,
/// `LEU_SPIKE_SCORE_LABEL` and `LEU_SPIKE_SCORE_OUT` are set. Optional: `LEU_SPIKE_SCORE_READINGS`
/// (JSONL; without it only A0 and A are scored), `LEU_SPIKE_SCORE_KEYS`, `LEU_SPIKE_SCORE_INPUTS`
/// (the runner's input file, checked against the recomputed inputs) and `LEU_SPIKE_SCORE_BLIND=1`.
final class ZZSpikeScoreRun: XCTestCase {
    func testScoreRecordedRun() throws {
        _ = try Self.score(ProcessInfo.processInfo.environment)
    }

    /// Scores the run the environment names and writes the output file; nil when nothing is named.
    @discardableResult
    static func score(_ env: [String: String]) throws -> [String: Any]? {
        guard env["LEU_SPIKE_SCORE_CASES"] != nil, let set = env["LEU_SPIKE_SCORE_SET"], let label = env["LEU_SPIKE_SCORE_LABEL"],
              let out = env["LEU_SPIKE_SCORE_OUT"] else { return nil }
        let blind = env["LEU_SPIKE_SCORE_BLIND"] == "1"
        guard !blind || out.contains("/blind/") else { throw SpikeScore.Refusal(reason: "blind output must go to a blind/ directory") }
        let (fixture, recorded) = try SpikeScore.load(env)
        let tally = SpikeScore.Tally()
        var result: [String: Any] = ["label": label, "set": set, "blind": blind, "cases": fixture.cases.count]
        var reports: [String: Any] = [:]
        var predictors: [(String, GeneralizationEvaluation.Predictor)] = [
            ("A0", SpikeScore.capturing("A0", GeneralizationEvaluation.v35, tally)),
            ("A", SpikeScore.capturing("A", GeneralizationEvaluation.v36, tally))]
        if !recorded.records.isEmpty {
            predictors += SpikeConfig.allCases.map { ($0.rawValue, SpikeScore.predictor($0, set: set, recorded: recorded, tally: tally)) }
        }
        for (name, predictor) in predictors {
            let report = GeneralizationEvaluation.evaluate(fixture, predictor, metamorphic: false)
            XCTAssertEqual(report.unavailable, 0, "\(name): every case needs a comparable target")
            reports[name] = SpikeScore.report(report)
            print("SPIKE|\(label)|\(name)|\(report)")
            print("SPIKE|\(label)|\(name)|\(report.breakdown)")
        }
        result["reports"] = reports
        if let inputs = env["LEU_SPIKE_SCORE_INPUTS"], !recorded.records.isEmpty {
            let file = try JSONDecoder().decode(SpikeInputFile.self, from: Data(contentsOf: URL(fileURLWithPath: inputs)))
            let mismatched = file.cases.filter { tally.spikes[$0.caseID] != $0 }.count
            XCTAssertEqual(mismatched, 0, "the runner's inputs must equal the recomputed inputs")
            result["inputsMismatched"] = mismatched
        }
        let byID = Dictionary(fixture.cases.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        // Per case: the signature (for consistency) and correctness (for paired tests). Blind sets keep
        // these only in the blind output file.
        result["perCase"] = tally.judged.mapValues { cases -> [String: Any] in
            var entries: [String: Any] = [:]
            for (id, judged) in cases {
                guard let item = byID[id] else { continue }
                entries[id] = ["signature": SpikeScore.signature(judged), "exactRight": judged.state == item.state,
                               "coarseRight": GeneralizationEvaluation.coarse(judged.state) == SpikeScore.goldCoarse(item)]
            }
            return entries
        }
        if !recorded.records.isEmpty {
            result["failures"] = SpikeScore.failures(fixture, recorded, tally)
            result["fallbacks"] = tally.outcomes.mapValues { cases in
                Dictionary(grouping: cases.values, by: \.fallback.rawValue).mapValues(\.count)
            }
            result["checksFired"] = tally.outcomes.mapValues { cases in
                cases.values.reduce(into: [String: Int]()) { counts, outcome in
                    for check in Set(outcome.checked?.fired ?? []) { counts[check, default: 0] += 1 }
                }
            }
            result["opinion"] = SpikeScore.opinion(recorded)
            result["latency"] = SpikeScore.latency(recorded, tally)
            print("SPIKE|\(label)|failures|\(result["failures"]!)")
            print("SPIKE|\(label)|fallbacks|\(result["fallbacks"]!)")
            print("SPIKE|\(label)|checksFired|\(result["checksFired"]!)")
        }
        if !blind {
            result["rows"] = SpikeRows.rows(fixture, tally: tally, recorded: recorded)
            if let canonical = SpikeCanonical.evaluate(env["LEU_SPIKE_SCORE_CASES"]!, tally: tally, recorded: recorded) {
                result["canonical"] = canonical
            }
        }
        let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: URL(fileURLWithPath: out))
        print("SPIKE|\(label)|written|\(blind ? "blind file (not printed)" : out)")
        return result
    }
}
