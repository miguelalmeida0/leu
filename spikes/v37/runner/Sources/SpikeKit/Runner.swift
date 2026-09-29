import Foundation

// THROWAWAY — V37 capability spike only.

public struct ModelRequest: Sendable {
    public let instructions, prompt: String
    public let schema: SchemaNode
    public let maxTokens: Int
    public let timeout: Double
}

public struct ModelResponse: Sendable {
    public let status: String
    public let latencyMs: Int
    public let retries: Int
    public let json: String?
    public init(status: String, latencyMs: Int, retries: Int, json: String?) {
        self.status = status; self.latencyMs = latencyMs; self.retries = retries; self.json = json
    }
}

/// One fresh session per call, greedy sampling; the engine owns timeouts and `rateLimited` retries.
public protocol SpikeModel: Sendable {
    func respond(_ request: ModelRequest) async -> ModelResponse
}

/// SPIKE_SPEC §6 generation settings.
public enum Settings {
    public static let readingTokens = 450, opinionTokens = 120, answerKeyTokens = 700
    public static let readingTimeout = 30.0, opinionTimeout = 15.0, answerKeyTimeout = 60.0
    public static let maxRetries = 2, retryDelay = 2.0
    public static let promptBudget = 3500
}

public struct SpikePipeline: Sendable {
    public let model: SpikeModel
    public let prompts: PromptSet
    public init(model: SpikeModel, prompts: PromptSet) { self.model = model; self.prompts = prompts }

    public static func milliseconds(_ duration: Duration) -> Int {
        Int(duration.components.seconds * 1000 + duration.components.attoseconds / 1_000_000_000_000_000)
    }

    /// Reads one answer: the reading call, then (when anything is decisive) the second opinion. The
    /// total is wall time from submission to both results decoded. No caching, no prewarming.
    public func read(_ input: SpikeInput, key: SpikeAnswerKey?, device: String, run: Int, processCallIndex: Int,
                     osBuild: String) async -> SpikeRecord {
        func record(_ reading: SpikeCall<SpikeReading>, _ opinion: SpikeCall<SpikeSecondOpinionOutput>?, _ total: Int) -> SpikeRecord {
            SpikeRecord(caseID: input.caseID, set: input.set, device: device, run: run, cold: processCallIndex == 0,
                        processCallIndex: processCallIndex, osBuild: osBuild, promptSHA: prompts.sha, reading: reading,
                        secondOpinion: opinion, totalLatencyMs: total)
        }
        guard !input.segments.isEmpty else {
            return record(SpikeCall(status: "empty", latencyMs: 0, retries: 0, output: nil), SpikeCall(status: "none", latencyMs: 0, retries: 0, output: nil), 0)
        }
        let clock = ContinuousClock(), start = clock.now
        let response = await model.respond(ModelRequest(instructions: prompts.reading, prompt: Requests.reading(input, key: key),
                                                        schema: SpikeSchemas.reading(input, key: key), maxTokens: Settings.readingTokens,
                                                        timeout: Settings.readingTimeout))
        guard response.status == "ok", let json = response.json else {
            return record(SpikeCall(status: response.status, latencyMs: response.latencyMs, retries: response.retries, output: nil), nil,
                          Self.milliseconds(start.duration(to: clock.now)))
        }
        guard let raw = try? JSONDecoder().decode(RawReading.self, from: Data(json.utf8)) else {
            return record(SpikeCall(status: "schemaError", latencyMs: response.latencyMs, retries: response.retries, output: nil), nil,
                          Self.milliseconds(start.duration(to: clock.now)))
        }
        let reading = Selection.map(raw, input: input)
        let readingCall = SpikeCall(status: "ok", latencyMs: response.latencyMs, retries: response.retries, output: reading)
        let pairs = Selection.items(reading, input: input, key: key)
        guard !pairs.isEmpty else {
            return record(readingCall, SpikeCall(status: "none", latencyMs: 0, retries: 0, output: nil), Self.milliseconds(start.duration(to: clock.now)))
        }
        let opinion = await secondOpinion(pairs)
        return record(readingCall, opinion, Self.milliseconds(start.duration(to: clock.now)))
    }

    /// A fresh session comparing numbered statement pairs; exactly one verdict per pair.
    func secondOpinion(_ pairs: [Selection.Pair]) async -> SpikeCall<SpikeSecondOpinionOutput> {
        let response = await model.respond(ModelRequest(instructions: prompts.secondOpinion, prompt: Requests.opinion(pairs.map { ($0.a, $0.b) }),
                                                        schema: SpikeSchemas.opinion(items: pairs.count), maxTokens: Settings.opinionTokens,
                                                        timeout: Settings.opinionTimeout))
        guard response.status == "ok", let json = response.json else {
            return SpikeCall(status: response.status, latencyMs: response.latencyMs, retries: response.retries, output: nil)
        }
        guard let raw = try? JSONDecoder().decode(RawOpinion.self, from: Data(json.utf8)) else {
            return SpikeCall(status: "schemaError", latencyMs: response.latencyMs, retries: response.retries, output: nil)
        }
        let verdicts = raw.verdicts.map { SpikeVerdict(item: Int($0.item) ?? -1, verdict: $0.verdict) }
        return SpikeCall(status: "ok", latencyMs: response.latencyMs, retries: response.retries,
                         output: SpikeSecondOpinionOutput(items: pairs.map(\.item), verdicts: verdicts))
    }

    /// SPIKE_SPEC §5: compile 3–6 likely mistakes for one target, then keep those that are short, grounded
    /// and called "opposite" to their claim by the second-opinion prompt. Never edited by hand.
    public func compileKey(_ input: SpikeInput) async -> (SpikeAnswerKey, SpikeKeyDetail) {
        let response = await model.respond(ModelRequest(instructions: prompts.answerKey, prompt: Requests.answerKey(input),
                                                        schema: SpikeSchemas.answerKey(input), maxTokens: Settings.answerKeyTokens,
                                                        timeout: Settings.answerKeyTimeout))
        func detail(_ status: String, compile: String, proposed: Int = 0, check: (String, Int) = ("none", 0),
                    dropped: [SpikeKeyDetail.Dropped] = []) -> SpikeKeyDetail {
            SpikeKeyDetail(targetKey: input.targetKey, status: status, compileStatus: compile, compileLatencyMs: response.latencyMs,
                           selfCheckStatus: check.0, selfCheckLatencyMs: check.1, proposed: proposed, dropped: dropped)
        }
        guard response.status == "ok", let json = response.json,
              let raw = try? JSONDecoder().decode(RawAnswerKey.self, from: Data(json.utf8)) else {
            let status = response.status == "ok" ? "schemaError" : response.status
            return (SpikeAnswerKey(status: "failed", mistakes: []), detail("failed", compile: status))
        }
        let claims = Dictionary(input.claims.map { ($0.alias, $0) }, uniquingKeysWith: { a, _ in a })
        var dropped: [SpikeKeyDetail.Dropped] = [], candidates: [(RawAnswerKey.Mistake, SpikeInput.Claim)] = []
        for mistake in raw.mistakes {
            guard let claim = claims[mistake.claim] else { dropped.append(.init(text: mistake.text, reason: "unknownClaim")); continue }
            if mistake.text.split(whereSeparator: \.isWhitespace).count > 25 { dropped.append(.init(text: mistake.text, reason: "tooLong")); continue }
            if !Selection.grounded(mistake, claim: claim, input: input) { dropped.append(.init(text: mistake.text, reason: "ungrounded")); continue }
            candidates.append((mistake, claim))
        }
        guard !candidates.isEmpty else {
            return (SpikeAnswerKey(status: "empty", mistakes: []), detail("empty", compile: "ok", proposed: raw.mistakes.count, dropped: dropped))
        }
        let pairs = candidates.enumerated().map { index, pair in
            Selection.Pair(item: SpikeOpinionItem(item: index + 1, kind: "mistake", segment: 0, claimID: pair.1.id, neighbour: nil),
                           a: pair.1.text, b: "\"\(pair.0.text)\"")
        }
        let check = await secondOpinion(pairs)
        let verdicts = Dictionary((check.output?.verdicts ?? []).map { ($0.item, $0.verdict) }, uniquingKeysWith: { a, _ in a })
        var kept: [SpikeAnswerKey.Mistake] = []
        for (index, (mistake, claim)) in candidates.enumerated() {
            guard verdicts[index + 1] == "opposite" else { dropped.append(.init(text: mistake.text, reason: "notOpposite")); continue }
            guard kept.count < 6 else { continue }
            kept.append(.init(id: "m\(kept.count + 1)", text: mistake.text, contradicts: claim.id, kind: mistake.kind,
                              confusedWith: mistake.confusedWith, question: mistake.question))
        }
        let status = kept.isEmpty ? "empty" : "ok"
        return (SpikeAnswerKey(status: status, mistakes: kept),
                detail(status, compile: "ok", proposed: raw.mistakes.count, check: (check.status, check.latencyMs), dropped: dropped))
    }
}
