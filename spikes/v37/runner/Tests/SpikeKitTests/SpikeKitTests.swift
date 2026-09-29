import XCTest
@testable import SpikeKit

// THROWAWAY — V37 capability spike only. Linux checks of the runner with scripted models: no Apple
// model is ever called here.

/// Answers each call from a script keyed by what the request asks for.
struct ScriptedModel: SpikeModel {
    let reading: String?, opinion: String?, answerKey: String?
    var status = "ok"

    func respond(_ request: ModelRequest) async -> ModelResponse {
        guard status == "ok" else { return ModelResponse(status: status, latencyMs: 5, retries: 0, json: nil) }
        let json: String?
        if case let .object(name, _) = request.schema {
            json = name == "Reading" ? reading : name == "SecondOpinion" ? opinion : answerKey
        } else { json = nil }
        return ModelResponse(status: "ok", latencyMs: 10, retries: 0, json: json)
    }
}

final class SpikeKitTests: XCTestCase {
    let prompts = PromptSet(answerKey: "compile", reading: "read", secondOpinion: "compare")

    /// C4 as the harness exports it (Closure, Mobile Mastery).
    let closure = SpikeInput(
        caseID: "C4", set: "C", targetKey: "Mobile Mastery|Closure", targetName: "Closure",
        question: "Explain Closure in your own words.",
        claims: [.init(id: "claim-63b3e0f7dcdc4888", alias: "c1", kind: "definition", role: "core",
                       text: "A function plus access to the lexical variables from the scope where it was created."),
                 .init(id: "claim-ea1f1e097d9c8eab", alias: "c2", kind: "purpose", role: "core",
                       text: "Closures power encapsulation, callbacks, hooks, and private state patterns."),
                 .init(id: "claim-329d5dceec7cb700", alias: "s1", kind: "mechanism", role: "supporting",
                       text: "A closure lets a function retain access to its lexical environment after the outer function has finished.")],
        neighbours: [.init(name: "Scope", key: "scope", definition: "Where a variable can be accessed in the program.")],
        segments: [.init(n: 1, text: "The inner function can still access the outer variable"),
                   .init(n: 2, text: "because JavaScript copies all outer variables into it.")],
        wordCount: 17)

    let key = SpikeAnswerKey(status: "ok", mistakes: [
        .init(id: "m1", text: "JavaScript copies the outer variables into the inner function.", contradicts: "claim-329d5dceec7cb700",
              kind: "opposite", confusedWith: "none", question: "Does the inner function see later changes?")])

    let careful = """
    {"segments": [
      {"n": "1", "role": "statement", "claim": "c1", "relation": "entails", "misconception": "none", "polarity": "affirmed", "specificity": "specific", "describes": "target", "confidence": "high"},
      {"n": "2", "role": "reason", "claim": "s1", "relation": "contradicts", "misconception": "m1", "polarity": "affirmed", "specificity": "specific", "describes": "target", "confidence": "medium"}],
     "links": [{"reason": "2", "conclusion": "1"}]}
    """

    func testSHA256MatchesKnownVectors() {
        XCTAssertEqual(SHA256.hex(""), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
        XCTAssertEqual(SHA256.hex("abc"), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        XCTAssertEqual(SHA256.hex(String(repeating: "a", count: 1000)).prefix(16), "41edece42d63e8d9")
    }

    func testRequestsListEveryPartOnceAndHideIDs() {
        let request = Requests.reading(closure, key: key)
        XCTAssertTrue(request.contains("c1 (definition, core): A function plus access"))
        XCTAssertTrue(request.contains("m1 (contradicts s1): JavaScript copies"))
        XCTAssertTrue(request.contains("Scope: Where a variable"))
        XCTAssertTrue(request.contains("1. The inner function") && request.contains("2. because JavaScript"))
        XCTAssertFalse(request.contains("claim-"), "the model sees aliases only")
        XCTAssertEqual(Requests.opinion([(a: "A text", b: "\"B text\"")]), "1.\nA: \"A text\"\nB: \"B text\"")
    }

    func testReadingSchemaEnumeratesIDsAndFixesTheSegmentCount() {
        guard case let .object(_, properties) = SpikeSchemas.reading(closure, key: key),
              case let .array(segment, min, max) = properties[0].node, case let .object(_, fields) = segment else { return XCTFail() }
        XCTAssertEqual([min, max], [2, 2])
        func values(_ name: String) -> [String] {
            guard case let .choice(_, values)? = fields.first(where: { $0.name == name })?.node else { return [] }
            return values
        }
        XCTAssertEqual(values("n"), ["1", "2"])
        XCTAssertEqual(values("claim"), ["c1", "c2", "s1", "none"])
        XCTAssertEqual(values("misconception"), ["m1", "none"])
        XCTAssertEqual(values("describes"), ["target", "Scope", "unclear"])
        XCTAssertEqual(values("confidence"), ["high", "medium", "low"])
    }

    func testCarefulReadingMapsBackAndAsksCreditContradictionAndReason() async throws {
        let model = ScriptedModel(reading: careful, opinion: #"{"verdicts": [{"item": "1", "verdict": "same"}, {"item": "2", "verdict": "opposite"}, {"item": "3", "verdict": "different"}]}"#,
                                  answerKey: nil)
        let record = await SpikePipeline(model: model, prompts: prompts).read(closure, key: key, device: "linux", run: 1, processCallIndex: 0, osBuild: "-")
        XCTAssertEqual(record.reading.status, "ok")
        XCTAssertTrue(record.cold)
        let reading = try XCTUnwrap(record.reading.output)
        XCTAssertEqual(reading.segments.map(\.claim), ["claim-63b3e0f7dcdc4888", "claim-329d5dceec7cb700"])
        XCTAssertEqual(reading.links, [SpikeLink(reason: 2, conclusion: 1)])
        XCTAssertEqual(reading.segments.map(\.confidence), ["high", "medium"])
        let opinion = try XCTUnwrap(record.secondOpinion?.output)
        XCTAssertEqual(opinion.items.map(\.kind), ["credit", "contradiction", "reason"])
        XCTAssertEqual(opinion.items.map(\.segment), [1, 2, 2])
        XCTAssertEqual(opinion.items[2].claimID, "claim-ea1f1e097d9c8eab", "a reason is compared with the how/why claim")
        XCTAssertEqual(opinion.verdicts.map(\.verdict), ["same", "opposite", "different"])
        // The JSONL line decodes with the same keys the harness reads.
        let line = try JSONEncoder().encode(record)
        XCTAssertEqual(try JSONDecoder().decode(SpikeRecord.self, from: line), record)
    }

    func testItemsAreCappedAndPrioritised() {
        let labels = (1...10).map { SpikeSegmentLabel(n: $0, role: "statement", claim: $0 <= 5 ? "claim-63b3e0f7dcdc4888" : "claim-ea1f1e097d9c8eab",
                                                      relation: $0 <= 5 ? "entails" : "contradicts", misconception: "none", polarity: "affirmed",
                                                      specificity: "specific", describes: "target") }
        let many = SpikeInput(caseID: "x", set: "x", targetKey: closure.targetKey, targetName: "Closure", question: "q", claims: closure.claims,
                              neighbours: closure.neighbours, segments: (1...10).map { .init(n: $0, text: "segment \($0)") }, wordCount: 20)
        let pairs = Selection.items(SpikeReading(segments: labels, links: []), input: many, key: nil)
        XCTAssertEqual(pairs.count, 8)
        XCTAssertEqual(pairs.map(\.item.kind), Array(repeating: "credit", count: 5) + Array(repeating: "contradiction", count: 3))
        XCTAssertEqual(pairs.map(\.item.item), Array(1...8))
    }

    func testFailuresAndEmptyAnswersAreRecordedNotRetried() async {
        let failing = SpikePipeline(model: ScriptedModel(reading: nil, opinion: nil, answerKey: nil, status: "timeout"), prompts: prompts)
        let timedOut = await failing.read(closure, key: key, device: "linux", run: 1, processCallIndex: 3, osBuild: "-")
        XCTAssertEqual(timedOut.reading.status, "timeout")
        XCTAssertNil(timedOut.secondOpinion)
        XCTAssertFalse(timedOut.cold)
        let garbled = SpikePipeline(model: ScriptedModel(reading: "{\"segments\": 3}", opinion: nil, answerKey: nil), prompts: prompts)
        let invalid = await garbled.read(closure, key: key, device: "linux", run: 1, processCallIndex: 1, osBuild: "-")
        XCTAssertEqual(invalid.reading.status, "schemaError")
        let empty = SpikeInput(caseID: "e", set: "x", targetKey: "t", targetName: "t", question: "q", claims: [], neighbours: [], segments: [], wordCount: 1)
        let record = await failing.read(empty, key: nil, device: "linux", run: 1, processCallIndex: 0, osBuild: "-")
        XCTAssertEqual(record.reading.status, "empty")
        XCTAssertEqual(record.secondOpinion?.status, "none")
    }

    func testAnswerKeyKeepsOnlyShortGroundedOppositeMistakes() async throws {
        let proposed = """
        {"mistakes": [
          {"claim": "s1", "text": "JavaScript copies the outer variables into the inner function.", "kind": "opposite", "confusedWith": "none", "question": "q1"},
          {"claim": "c2", "text": "Bananas are yellow.", "kind": "opposite", "confusedWith": "none", "question": "q2"},
          {"claim": "c1", "text": "A closure is just any function inside another function scope.", "kind": "overgeneralized", "confusedWith": "none", "question": "q3"}]}
        """
        let model = ScriptedModel(reading: nil, opinion: #"{"verdicts": [{"item": "1", "verdict": "opposite"}, {"item": "2", "verdict": "part"}]}"#,
                                  answerKey: proposed)
        let (key, detail) = await SpikePipeline(model: model, prompts: prompts).compileKey(closure)
        XCTAssertEqual(key.status, "ok")
        XCTAssertEqual(key.mistakes.map(\.id), ["m1"])
        XCTAssertEqual(key.mistakes[0].contradicts, "claim-329d5dceec7cb700")
        XCTAssertEqual(Set(detail.dropped.map(\.reason)), ["ungrounded", "notOpposite"])
        XCTAssertEqual(detail.proposed, 3)
    }

    func testFakeModelProducesSchemaValidOutput() async throws {
        let record = await SpikePipeline(model: FirstChoiceModel(), prompts: prompts).read(closure, key: key, device: "linux", run: 0,
                                                                                            processCallIndex: 0, osBuild: "-")
        XCTAssertEqual(record.reading.status, "ok")
        XCTAssertEqual(record.reading.output?.segments.map(\.n), [1, 2])
        XCTAssertEqual(record.secondOpinion?.status, "ok")
    }
}
