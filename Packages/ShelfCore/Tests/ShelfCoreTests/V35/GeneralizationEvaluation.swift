import Foundation
@testable import ShelfCore

/// Scores understanding *judgements* on the V35 generalization fixtures
/// (Tests/Fixtures/diagnosis-generalization-{dev,sealed}.json). Both were written by independent
/// annotators who saw only the source's grounded sentences and a labeling guide — never Leu's
/// code, lexicon or earlier fixture — and labeled what a teacher would conclude: understood,
/// mostly understood, fragile, misconception, weak reasoning or insufficient evidence.
/// The sealed split is evaluated once per release and reported as aggregates only.
enum GeneralizationEvaluation {
    struct Misconception: Decodable { let kind: String; let claim: String?; let confusedWith: String? }
    struct Case: Decodable {
        let id, document, text, state: String
        let concept: String?
        let page: Int?
        let misconceptions: [Misconception]
        let credits: [String]
        let categories: [String]
        let paraphraseGroup: String?
    }
    struct Fixture: Decodable { let split: String; let cases: [Case] }

    static func fixture(_ split: String) -> Fixture? {
        let url = LearningCorpus.fixtures.appendingPathComponent("diagnosis-generalization-\(split).json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Fixture.self, from: data)
    }

    static let states = ["understood", "mostlyUnderstood", "fragile", "misconception", "weakReasoning", "insufficient"]
    static let epoch = Date(timeIntervalSinceReferenceDate: 800_000_000)

    /// What one predictor concluded about one explanation, and what it would write to the learner model.
    struct Judged {
        var state: String
        /// Probability the predictor gives its own `state` (1 when it has no notion of uncertainty).
        var confidence: Double
        /// More evidence was asked for before the learner model is updated.
        var asksProbe: Bool
        var evidence: [LearningEvidence]
        /// What the question asks about, when one is asked.
        var probeClaims: [String] = []
        var probeConcept: ConceptKey? = nil
        var recordsMisconception: Bool { evidence.contains { $0.misconception != nil } }
        var recordsMastery: Bool { evidence.contains { $0.outcome == .correct } }
        var recordsCredit: Bool { evidence.contains { $0.outcome != .incorrect && $0.misconception == nil } }
    }

    /// Everything a predictor may use: the explanation, what it is compared against, and where
    /// its evidence would be recorded. `prior` is the learner model before this answer.
    struct Input {
        let item: Case
        let target: DiagnosisTarget
        let documentID: UUID
        let knowledge: ConceptKnowledgeBase
        var prior = LearnerModelState()
        var at = GeneralizationEvaluation.epoch
        var text: String { item.text }
    }
    typealias Predictor = (Input, String) -> Judged

    static func target(for item: Case) -> DiagnosisTarget? {
        guard let base = LearningCorpus.knowledge[item.document] else { return nil }
        if let concept = item.concept { return DiagnosisTarget.concept(ConceptNames.key(concept), in: base) }
        guard let page = item.page else { return nil }
        return DiagnosisTarget.passage(DiagnosisEvaluation.pageSource(item.document, page), in: base)
    }

    static func input(for item: Case) -> Input? {
        guard let target = target(for: item), let base = LearningCorpus.knowledge[item.document] else { return nil }
        return Input(item: item, target: target, documentID: LearningCorpus.analysis(item.document).documentID, knowledge: base)
    }

    // MARK: - Metrics

    /// Positive (understood, mostly), misconception, or weak (fragile, weak reasoning, insufficient).
    static func coarse(_ state: String, misconception: Bool = false) -> String {
        if misconception || state == "misconception" { return "misconception" }
        return ["understood", "mostlyUnderstood"].contains(state) ? "positive" : "weak"
    }

    struct Report: CustomStringConvertible {
        var cases = 0, unavailable = 0
        var exact = 0, coarseRight = 0
        var goldNotPositive = 0, falseMastery = 0
        var goldPositive = 0, masteryCredited = 0
        var goldMisconception = 0, misconceptionRecorded = 0, misconceptionProbed = 0, misconceptionCredited = 0
        var goldNoMisconception = 0, falseMisconception = 0
        var probes = 0
        /// Verdicts committed without asking, and how many of them a teacher would reject.
        var committed = 0, committedRight = 0
        /// Committed errors by direction: credit a teacher would not give, a misconception that is not
        /// there, a misconception passed over, and understanding under-credited.
        var overCredit = 0, falseAlarm = 0, missedMisconception = 0, underCredit = 0
        /// Probed misconceptions whose question is about the misread claim or the confused concept.
        var targetedProbes = 0
        var brier = 0.0
        var bins = [(n: Int, confidence: Double, right: Int)](repeating: (0, 0, 0), count: 5)
        var groups = 0, stableGroups = 0, coarseStableGroups = 0
        var variants = 0, invariantVariants = 0
        var perCategory: [String: (n: Int, right: Int, falseMastery: Int)] = [:]
        var perState: [String: (n: Int, right: Int, probed: Int)] = [:]

        func rate(_ a: Int, _ b: Int) -> Double { b == 0 ? 0 : Double(a) / Double(b) }
        var exactRate: Double { rate(exact, cases) }
        var coarseRate: Double { rate(coarseRight, cases) }
        /// Mastery recorded for an explanation a teacher would not call understood. The costliest error.
        var falseMasteryRate: Double { rate(falseMastery, goldNotPositive) }
        var masteryRecall: Double { rate(masteryCredited, goldPositive) }
        var misconceptionRecall: Double { rate(misconceptionRecorded, goldMisconception) }
        var misconceptionCaughtOrProbed: Double { rate(misconceptionRecorded + misconceptionProbed, goldMisconception) }
        /// A real misconception rewarded with credit and neither recorded nor probed.
        var misconceptionCreditedRate: Double { rate(misconceptionCredited, goldMisconception) }
        var falseMisconceptionRate: Double { rate(falseMisconception, goldNoMisconception) }
        var probeRate: Double { rate(probes, cases) }
        var selectiveAccuracy: Double { rate(committedRight, committed) }
        var wrongCommits: Int { committed - committedRight }
        var brierScore: Double { cases == 0 ? 0 : brier / Double(cases) }
        /// Expected calibration error over five confidence bins (coarse correctness).
        var ece: Double {
            let n = bins.reduce(0) { $0 + $1.n }
            guard n > 0 else { return 0 }
            return bins.reduce(0.0) { sum, bin in
                guard bin.n > 0 else { return sum }
                return sum + Double(bin.n) / Double(n) * abs(bin.confidence / Double(bin.n) - Double(bin.right) / Double(bin.n))
            }
        }
        var paraphraseStability: Double { rate(stableGroups, groups) }
        var paraphraseCoarseStability: Double { rate(coarseStableGroups, groups) }
        var metamorphicInvariance: Double { rate(invariantVariants, variants) }

        var description: String {
            func pct(_ value: Double) -> String { "\(Int((value * 100).rounded()))%" }
            return "cases=\(cases) unavailable=\(unavailable) state=\(pct(exactRate)) coarse=\(pct(coarseRate)) "
                + "falseMastery=\(falseMastery)/\(goldNotPositive) (\(pct(falseMasteryRate))) masteryRecall=\(masteryCredited)/\(goldPositive) (\(pct(masteryRecall))) "
                + "misconceptionRecall=\(misconceptionRecorded)/\(goldMisconception) (\(pct(misconceptionRecall))) caughtOrProbed=\(pct(misconceptionCaughtOrProbed)) "
                + "misconceptionCredited=\(misconceptionCredited) (\(pct(misconceptionCreditedRate))) falseMisconception=\(falseMisconception)/\(goldNoMisconception) (\(pct(falseMisconceptionRate))) "
                + "probes=\(probes) (\(pct(probeRate))) committed=\(committed) selective=\(pct(selectiveAccuracy)) wrongCommits=\(wrongCommits) "
                + "(overCredit=\(overCredit) falseAlarm=\(falseAlarm) missedMisconception=\(missedMisconception) underCredit=\(underCredit)) "
                + "targetedProbes=\(targetedProbes)/\(misconceptionProbed) brier=\(String(format: "%.3f", brierScore)) ece=\(String(format: "%.3f", ece)) "
                + "paraphraseStable=\(stableGroups)/\(groups) coarseStable=\(coarseStableGroups)/\(groups) metamorphic=\(invariantVariants)/\(variants) (\(pct(metamorphicInvariance)))"
        }

        var breakdown: String {
            let categories = perCategory.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value.right)/\($0.value.n) fm\($0.value.falseMastery)" }
            let states = perState.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value.right)/\($0.value.n) probed\($0.value.probed)" }
            return "coarse by category: " + categories.joined(separator: " ") + " | by gold state: " + states.joined(separator: " ")
        }
    }

    /// Does the question address what the learner actually got wrong: the confused concept, or
    /// the claim the learner misread?
    static func targets(_ judged: Judged, _ item: Case, _ input: Input) -> Bool {
        item.misconceptions.contains { wrong in
            if let other = wrong.confusedWith, let asked = judged.probeConcept, asked == ConceptNames.key(other) { return true }
            guard let key = wrong.claim else { return false }
            return (input.target.rubric + input.target.supporting)
                .first { CanonicalWhitespaceResolver.normalize($0.evidence.text).contains(key) }
                .map { judged.probeClaims.contains($0.id) } ?? false
        }
    }

    static func evaluate(_ fixture: Fixture, _ predictor: Predictor, metamorphic useMetamorphic: Bool = true) -> Report {
        var report = Report()
        var byGroup: [String: [(String, String)]] = [:]
        for item in fixture.cases {
            report.cases += 1
            guard let input = input(for: item) else { report.unavailable += 1; continue }
            let judged = predictor(input, item.text)
            let goldMisconception = !item.misconceptions.isEmpty
            let goldCoarse = coarse(item.state, misconception: goldMisconception)
            let predictedCoarse = coarse(judged.state)
            if judged.state == item.state { report.exact += 1 }
            let right = predictedCoarse == goldCoarse
            if right { report.coarseRight += 1 }
            let positive = goldCoarse == "positive"
            if positive {
                report.goldPositive += 1
                if judged.recordsMastery { report.masteryCredited += 1 }
            } else {
                report.goldNotPositive += 1
                if judged.recordsMastery { report.falseMastery += 1 }
            }
            if goldMisconception {
                report.goldMisconception += 1
                if judged.recordsMisconception { report.misconceptionRecorded += 1 }
                else if judged.asksProbe {
                    report.misconceptionProbed += 1
                    if targets(judged, item, input) { report.targetedProbes += 1 }
                } else if judged.recordsCredit { report.misconceptionCredited += 1 }
            } else {
                report.goldNoMisconception += 1
                if judged.recordsMisconception { report.falseMisconception += 1 }
            }
            if judged.asksProbe { report.probes += 1 } else {
                report.committed += 1
                if right { report.committedRight += 1 }
                else if predictedCoarse == "positive" { report.overCredit += 1 }
                else if predictedCoarse == "misconception" { report.falseAlarm += 1 }
                else if goldCoarse == "misconception" { report.missedMisconception += 1 }
                else { report.underCredit += 1 }
            }
            let confidence = min(1, max(0, judged.confidence))
            report.brier += pow(confidence - (right ? 1 : 0), 2)
            let bin = min(4, Int(confidence * 5))
            report.bins[bin].n += 1; report.bins[bin].confidence += confidence; report.bins[bin].right += right ? 1 : 0
            for category in item.categories {
                var entry = report.perCategory[category] ?? (0, 0, 0)
                entry.n += 1; entry.right += right ? 1 : 0
                if !positive && judged.recordsMastery { entry.falseMastery += 1 }
                report.perCategory[category] = entry
            }
            var stateEntry = report.perState[item.state] ?? (0, 0, 0)
            stateEntry.n += 1; stateEntry.right += right ? 1 : 0; stateEntry.probed += judged.asksProbe ? 1 : 0
            report.perState[item.state] = stateEntry
            if let group = item.paraphraseGroup { byGroup[group, default: []].append((judged.state, predictedCoarse)) }
            if useMetamorphic {
                let signature = "\(predictedCoarse)|\(judged.recordsMisconception)|\(judged.asksProbe)|\(judged.recordsMastery)"
                for rewrite in metamorphic {
                    let variant = rewrite(item.text)
                    guard variant != item.text else { continue }
                    let other = predictor(input, variant)
                    report.variants += 1
                    if "\(coarse(other.state))|\(other.recordsMisconception)|\(other.asksProbe)|\(other.recordsMastery)" == signature {
                        report.invariantVariants += 1
                    }
                }
            }
        }
        for members in byGroup.values where members.count >= 2 {
            report.groups += 1
            if Set(members.map(\.0)).count == 1 { report.stableGroups += 1 }
            if Set(members.map(\.1)).count == 1 { report.coarseStableGroups += 1 }
        }
        return report
    }
}
