import XCTest
@testable import ShelfCore

// THROWAWAY — V37 capability spike only (branch `test`, never merged into dev before a pass).

/// Synthetic readings for Linux checks of the harness: no model is involved. A reading is written
/// per segment as a compact label; a second opinion as verdicts per (kind, segment).
enum SpikeSynthetic {
    static var repository: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    static func fixture(_ name: String) throws -> GeneralizationEvaluation.Fixture {
        let url = repository.appendingPathComponent("spikes/v37/cases/\(name).json")
        return try JSONDecoder().decode(GeneralizationEvaluation.Fixture.self, from: Data(contentsOf: url))
    }

    static func label(_ n: Int, _ claim: String = "none", _ relation: String = "unrelated", role: String = "statement",
                      misconception: String = "none", polarity: String = "affirmed", specificity: String = "specific",
                      describes: String = "target", confidence: String? = nil) -> SpikeSegmentLabel {
        SpikeSegmentLabel(n: n, role: role, claim: claim, relation: relation, misconception: misconception, polarity: polarity,
                          specificity: specificity, describes: describes, confidence: confidence)
    }

    /// A second opinion from (kind, segment, verdict) triples; items are numbered in order.
    static func opinion(_ verdicts: [(String, Int, String)]) -> SpikeSecondOpinionOutput {
        SpikeSecondOpinionOutput(items: verdicts.enumerated().map { SpikeOpinionItem(item: $0.offset + 1, kind: $0.element.0, segment: $0.element.1,
                                                                                      claimID: nil, neighbour: nil) },
                                 verdicts: verdicts.enumerated().map { SpikeVerdict(item: $0.offset + 1, verdict: $0.element.2) })
    }

    /// V37's second opinion: the whole-answer check and, when it finds the answer wrong, the locator
    /// (segment, claim id, kind; segment 0 for "none").
    static func check(_ verdict: String, locate: (Int, String?, String)? = nil) -> SpikeSecondOpinionOutput {
        var items = [SpikeOpinionItem(item: 1, kind: "answer", segment: 0, claimID: nil, neighbour: nil)]
        var verdicts = [SpikeVerdict(item: 1, verdict: verdict)]
        if let (segment, claim, kind) = locate {
            items.append(SpikeOpinionItem(item: 2, kind: "locate", segment: segment, claimID: claim, neighbour: nil))
            verdicts.append(SpikeVerdict(item: 2, verdict: segment == 0 ? "none" : kind))
        }
        return SpikeSecondOpinionOutput(items: items, verdicts: verdicts)
    }

    static func record(_ id: String, _ labels: [SpikeSegmentLabel], links: [SpikeLink] = [], opinion: SpikeSecondOpinionOutput? = nil,
                       status: String = "ok", opinionStatus: String = "ok") -> SpikeRecord {
        let reading = SpikeCall(status: status, latencyMs: 900, retries: 0,
                                output: status == "ok" ? SpikeReading(segments: labels, links: links) : nil)
        let second = SpikeCall(status: opinion == nil && opinionStatus == "ok" ? "none" : opinionStatus, latencyMs: 400, retries: 0,
                               output: opinionStatus == "ok" ? opinion : nil)
        return SpikeRecord(caseID: id, set: "synthetic", device: "linux", run: 0, cold: false, processCallIndex: 1, osBuild: "-",
                           promptSHA: "-", reading: reading, secondOpinion: second, totalLatencyMs: 1300)
    }

    /// Canonical answer keys as a compile step might produce them (hand-written here, for tests only).
    static let keys: [String: SpikeAnswerKey] = [
        "Mobile Mastery|Closure": SpikeAnswerKey(status: "ok", mistakes: [
            .init(id: "m1", text: "JavaScript copies the outer variables into the inner function.", contradicts: "claim-329d5dceec7cb700",
                  kind: "opposite", confusedWith: "none", question: "Does the inner function see later changes to the variable?")]),
        "Mobile Mastery|JWT": SpikeAnswerKey(status: "ok", mistakes: [
            .init(id: "m1", text: "Because a JWT is signed, nobody can read what is inside it.", contradicts: "claim-f8f60f6a0a9d8164",
                  kind: "opposite", confusedWith: "none", question: "Can someone decode a signed JWT without the key?")]),
        "Mobile Mastery|Authentication": SpikeAnswerKey(status: "ok", mistakes: [])
    ]

    static let authDefinition = "claim-7485a5102853e2f4", closureDefinition = "claim-63b3e0f7dcdc4888"
    static let closureRetain = "claim-329d5dceec7cb700", jwtNotEncrypted = "claim-f8f60f6a0a9d8164"

    static let jwtDefinition = "claim-ff95fc8d2fc5f02e"

    /// What a careful reader would say about each canonical answer, with D's check and locator. The
    /// links are the answer's own marker links, as the runner records them.
    static func canonicalRecords() -> [String: SpikeRecord] {
        [
            "C1": record("C1", [label(1, authDefinition, "entails")], opinion: check("correct")),
            "C2": record("C2", [label(1, authDefinition, "contradicts", polarity: "negated")],
                         opinion: check("mistaken", locate: (1, authDefinition, "wrongIdea"))),
            "C3": record("C3", [label(1, closureDefinition, "entails")], opinion: check("correct")),
            "C4": record("C4", [label(1, closureDefinition, "entails"), label(2, closureRetain, "contradicts", role: "reason", misconception: "m1")],
                         links: [SpikeLink(reason: 2, conclusion: 1)],
                         opinion: check("mistaken", locate: (2, closureRetain, "wrongReason"))),
            "C5": record("C5", [label(1, jwtDefinition, "entails"), label(2, jwtNotEncrypted, "contradicts", misconception: "m1")],
                         links: [SpikeLink(reason: 1, conclusion: 2)],
                         opinion: check("mistaken", locate: (2, jwtNotEncrypted, "wrongIdea")))
        ]
    }

    /// Judges one case of a fixture with a synthetic record.
    static func judge(_ item: GeneralizationEvaluation.Case, set: String = "synthetic", record: SpikeRecord?, key: SpikeAnswerKey? = nil,
                      config: SpikeConfig) throws -> (SpikeAdapter.Outcome, SpikeInput) {
        let input = try XCTUnwrap(GeneralizationEvaluation.input(for: item))
        let spike = SpikeInput.make(item, set: set, target: input.target)
        let outcome = SpikeAdapter.judge(input, spike: spike, record: record, key: key ?? keys[spike.targetKey], config: config)
        return (outcome, spike)
    }

    /// A one-off case against a concept target, for check tests.
    static func adHoc(_ text: String, concept: String, state: String = "understood", document: String = "Mobile Mastery") -> GeneralizationEvaluation.Case {
        let quoted = String(decoding: try! JSONEncoder().encode(text), as: UTF8.self)
        let json = """
        {"id": "t-\(abs(text.hashValue))", "document": "\(document)", "concept": "\(concept)", "page": null, "text": \(quoted),
         "state": "\(state)", "misconceptions": [], "credits": [], "categories": [], "paraphraseGroup": null}
        """
        return try! JSONDecoder().decode(GeneralizationEvaluation.Case.self, from: Data(json.utf8))
    }
}
