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
    /// Calls run one after another (the default since dev06), or the reading alongside the check and
    /// locator with SPIKE_PARALLEL=1 (dev03–05: the parallel calls contend for the on-device model).
    public static var sequential: Bool { ProcessInfo.processInfo.environment["SPIKE_PARALLEL"] != "1" }
}

public struct SpikePipeline: Sendable {
    public let model: SpikeModel
    public let prompts: PromptSet
    public init(model: SpikeModel, prompts: PromptSet) { self.model = model; self.prompts = prompts }

    public static func milliseconds(_ duration: Duration) -> Int {
        Int(duration.components.seconds * 1000 + duration.components.attoseconds / 1_000_000_000_000_000)
    }

    /// Reads one answer (V37). In parallel: the row reading, and the independent whole-answer check
    /// followed, when the check finds the answer wrong, by the locator. The locator's placement is merged
    /// into the rows (the raw rows are kept). The total is wall time from submission to all results decoded.
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
        let readingRequest = ModelRequest(instructions: prompts.reading, prompt: Requests.reading(input, key: key),
                                          schema: SpikeSchemas.reading(input, key: key), maxTokens: Settings.readingTokens,
                                          timeout: Settings.readingTimeout)
        let response: ModelResponse, opinion: SpikeCall<SpikeSecondOpinionOutput>
        if Settings.sequential {
            // One model call at a time: concurrent sessions contend for the on-device model (dev05 p95).
            opinion = await checkAndLocate(input, key: key)
            response = await model.respond(readingRequest)
        } else {
            async let checked = checkAndLocate(input, key: key)
            response = await model.respond(readingRequest)
            opinion = await checked
        }
        let total = Self.milliseconds(start.duration(to: clock.now))
        guard response.status == "ok", let json = response.json else {
            return record(SpikeCall(status: response.status, latencyMs: response.latencyMs, retries: response.retries, output: nil), opinion, total)
        }
        guard let raw = try? JSONDecoder().decode(RawReading.self, from: Data(json.utf8)) else {
            return record(SpikeCall(status: "schemaError", latencyMs: response.latencyMs, retries: response.retries, output: nil), opinion, total)
        }
        let rows = Selection.map(raw, input: input)
        let reading = Selection.refine(rows, locate: opinion.output?.items.first { $0.kind == "locate" }, input: input)
        return record(SpikeCall(status: "ok", latencyMs: response.latencyMs, retries: response.retries, output: reading), opinion, total)
    }

    /// The whole-answer check (item 1, kind "answer"), then — only when it finds the answer wrong — the
    /// locator (item 2, kind "locate": its segment, claim id and kind; segment 0 for "none").
    func checkAndLocate(_ input: SpikeInput, key: SpikeAnswerKey?) async -> SpikeCall<SpikeSecondOpinionOutput> {
        let check = await model.respond(ModelRequest(instructions: prompts.answerCheck, prompt: Requests.answerCheck(input),
                                                     schema: SpikeSchemas.answerCheck(), maxTokens: Settings.opinionTokens,
                                                     timeout: Settings.opinionTimeout))
        guard check.status == "ok", let json = check.json else {
            return SpikeCall(status: check.status, latencyMs: check.latencyMs, retries: check.retries, output: nil)
        }
        guard let verdict = try? JSONDecoder().decode(RawAnswerCheck.self, from: Data(json.utf8)).verdict else {
            return SpikeCall(status: "schemaError", latencyMs: check.latencyMs, retries: check.retries, output: nil)
        }
        var items = [SpikeOpinionItem(item: 1, kind: "answer", segment: 0, claimID: nil, neighbour: nil)]
        var verdicts = [SpikeVerdict(item: 1, verdict: verdict)]
        var latency = check.latencyMs, retries = check.retries
        if verdict == "mistaken" || verdict == "flawedReason" {
            let located = await model.respond(ModelRequest(instructions: prompts.locate, prompt: Requests.locate(input, key: key),
                                                           schema: SpikeSchemas.locate(input, key: key), maxTokens: Settings.opinionTokens,
                                                           timeout: Settings.opinionTimeout))
            latency += located.latencyMs; retries += located.retries
            guard located.status == "ok", let json = located.json else {
                return SpikeCall(status: located.status, latencyMs: latency, retries: retries, output: nil)
            }
            guard let raw = try? JSONDecoder().decode(RawLocate.self, from: Data(json.utf8)) else {
                return SpikeCall(status: "schemaError", latencyMs: latency, retries: retries, output: nil)
            }
            let ids = Dictionary(input.claims.map { ($0.alias, $0.id) }, uniquingKeysWith: { a, _ in a })
            // A chosen likely mistake names its claim (the key ties each mistake to one); otherwise the
            // locator's claim, checked against its own words.
            let mistake = key?.mistakes.first { $0.id == raw.mistake }
            let claim = Selection.resolveClaim(raw.claim, instead: raw.instead, input: input)
            var item = SpikeOpinionItem(item: 2, kind: "locate", segment: Int(raw.segment) ?? 0, claimID: mistake?.contradicts ?? ids[claim], neighbour: nil)
            item.mistakeID = mistake?.id; item.note = raw.instead
            items.append(item)
            verdicts.append(SpikeVerdict(item: 2, verdict: raw.segment == "none" ? "none" : raw.kind))
        }
        return SpikeCall(status: "ok", latencyMs: latency, retries: retries, output: SpikeSecondOpinionOutput(items: items, verdicts: verdicts))
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
            if Selection.restates(mistake.text, input: input) { dropped.append(.init(text: mistake.text, reason: "restatesClaim")); continue }
            candidates.append((mistake, claim))
        }
        guard !candidates.isEmpty else {
            return (SpikeAnswerKey(status: "empty", mistakes: []), detail("empty", compile: "ok", proposed: raw.mistakes.count, dropped: dropped))
        }
        // Self-check (dev06): each candidate is read by the whole-answer check as if a student had said it,
        // and kept only when the check calls it mistaken. A copied true claim reads as correct and is dropped
        // (the pairwise check it replaces called nearly everything "opposite", keeping 22 true claims on P).
        var kept: [SpikeAnswerKey.Mistake] = [], checkStatus = "ok", checkLatency = 0
        for (mistake, claim) in candidates {
            let probe = SpikeInput(caseID: input.caseID, set: input.set, targetKey: input.targetKey, targetName: input.targetName,
                                   question: input.question, claims: input.claims, neighbours: input.neighbours,
                                   segments: [.init(n: 1, text: mistake.text)], wordCount: 0)
            let check = await model.respond(ModelRequest(instructions: prompts.answerCheck, prompt: Requests.answerCheck(probe),
                                                         schema: SpikeSchemas.answerCheck(), maxTokens: Settings.opinionTokens,
                                                         timeout: Settings.opinionTimeout))
            checkLatency += check.latencyMs
            guard check.status == "ok", let json = check.json, let verdict = try? JSONDecoder().decode(RawAnswerCheck.self, from: Data(json.utf8)).verdict
            else { checkStatus = check.status == "ok" ? "schemaError" : check.status; dropped.append(.init(text: mistake.text, reason: "checkFailed")); continue }
            guard verdict == "mistaken" else { dropped.append(.init(text: mistake.text, reason: "readAs-" + verdict)); continue }
            guard kept.count < 6 else { continue }
            kept.append(.init(id: "m\(kept.count + 1)", text: mistake.text, contradicts: claim.id, kind: mistake.kind,
                              confusedWith: mistake.confusedWith, question: mistake.question))
        }
        let check = (checkStatus, checkLatency)
        let status = kept.isEmpty ? "empty" : "ok"
        return (SpikeAnswerKey(status: status, mistakes: kept),
                detail(status, compile: "ok", proposed: raw.mistakes.count, check: check, dropped: dropped))
    }
}
