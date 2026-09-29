import Foundation

// THROWAWAY — V37 capability spike only. The JSON contract shared with ShelfCore's spike harness
// (`Packages/ShelfCore/Tests/ShelfCoreTests/ZZSpike/ZZSpikeContract.swift`): same types, same keys.

/// One case as exported by the harness: the target's claims and neighbours, and the answer in segments.
public struct SpikeInput: Codable, Equatable, Sendable {
    public struct Claim: Codable, Equatable, Sendable { public let id, alias, kind, role, text: String }
    public struct Neighbour: Codable, Equatable, Sendable { public let name, key, definition: String }
    public struct Segment: Codable, Equatable, Sendable { public let n: Int; public let text: String }
    public let caseID, set, targetKey, targetName, question: String
    public let claims: [Claim]
    public let neighbours: [Neighbour]
    public let segments: [Segment]
    public let wordCount: Int
}

public struct SpikeInputFile: Codable, Sendable {
    public let set: String
    public let cases: [SpikeInput]
}

/// The misconception menu compiled once per target (kept mistakes carry ids m1…).
public struct SpikeAnswerKey: Codable, Equatable, Sendable {
    public struct Mistake: Codable, Equatable, Sendable {
        public let id, text, contradicts, kind, confusedWith, question: String
        public init(id: String, text: String, contradicts: String, kind: String, confusedWith: String, question: String) {
            self.id = id; self.text = text; self.contradicts = contradicts; self.kind = kind
            self.confusedWith = confusedWith; self.question = question
        }
    }
    public let status: String
    public let mistakes: [Mistake]
    public init(status: String, mistakes: [Mistake]) { self.status = status; self.mistakes = mistakes }
}

public struct SpikeAnswerKeyFile: Codable, Sendable {
    public let keys: [String: SpikeAnswerKey]
    public init(keys: [String: SpikeAnswerKey]) { self.keys = keys }
}

/// What the model said about one segment, with claim ids mapped back from aliases.
public struct SpikeSegmentLabel: Codable, Equatable, Sendable {
    public let n: Int
    public let role, claim, relation, misconception, polarity, specificity, describes: String
    /// high · medium · low: the model's own confidence in this label.
    public var confidence: String?
    public init(n: Int, role: String, claim: String, relation: String, misconception: String, polarity: String,
                specificity: String, describes: String, confidence: String? = nil) {
        self.n = n; self.role = role; self.claim = claim; self.relation = relation; self.misconception = misconception
        self.polarity = polarity; self.specificity = specificity; self.describes = describes; self.confidence = confidence
    }
}

public struct SpikeLink: Codable, Equatable, Sendable {
    public let reason, conclusion: Int
    public init(reason: Int, conclusion: Int) { self.reason = reason; self.conclusion = conclusion }
}

public struct SpikeReading: Codable, Equatable, Sendable {
    public let segments: [SpikeSegmentLabel]
    public let links: [SpikeLink]
    public init(segments: [SpikeSegmentLabel], links: [SpikeLink]) { self.segments = segments; self.links = links }
}

/// One second-opinion item, and the verdict it got.
public struct SpikeOpinionItem: Codable, Equatable, Sendable {
    public let item: Int
    public let kind: String            // credit · contradiction · confusion · reason
    public let segment: Int
    public let claimID: String?
    public let neighbour: String?
    public init(item: Int, kind: String, segment: Int, claimID: String?, neighbour: String?) {
        self.item = item; self.kind = kind; self.segment = segment; self.claimID = claimID; self.neighbour = neighbour
    }
}

public struct SpikeVerdict: Codable, Equatable, Sendable {
    public let item: Int
    public let verdict: String
    public init(item: Int, verdict: String) { self.item = item; self.verdict = verdict }
}

/// One model call: `ok`, `none` (nothing to ask, no call), `empty` (no segment, no call), or a
/// failure: `refused`, `timeout`, `schemaError`, `contextOverflow`, `rateLimited`, `unavailable`, `error`.
public struct SpikeCall<Output: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
    public let status: String
    public let latencyMs: Int
    public let retries: Int
    public let output: Output?
    public init(status: String, latencyMs: Int, retries: Int, output: Output?) {
        self.status = status; self.latencyMs = latencyMs; self.retries = retries; self.output = output
    }
}

public struct SpikeSecondOpinionOutput: Codable, Equatable, Sendable {
    public let items: [SpikeOpinionItem]
    public let verdicts: [SpikeVerdict]
    public init(items: [SpikeOpinionItem], verdicts: [SpikeVerdict]) { self.items = items; self.verdicts = verdicts }
}

/// One answer read once: one JSONL line.
public struct SpikeRecord: Codable, Equatable, Sendable {
    public let caseID, set, device: String
    public let run: Int
    public let cold: Bool
    public let processCallIndex: Int
    public let osBuild, promptSHA: String
    public let reading: SpikeCall<SpikeReading>
    public let secondOpinion: SpikeCall<SpikeSecondOpinionOutput>?
    public let totalLatencyMs: Int
}

/// How one answer key was compiled (reported, never read by the harness).
public struct SpikeKeyDetail: Codable, Equatable, Sendable {
    public struct Dropped: Codable, Equatable, Sendable { public let text, reason: String }
    public let targetKey, status: String
    public let compileStatus: String, compileLatencyMs: Int
    public let selfCheckStatus: String, selfCheckLatencyMs: Int
    public let proposed: Int
    public let dropped: [Dropped]
}
