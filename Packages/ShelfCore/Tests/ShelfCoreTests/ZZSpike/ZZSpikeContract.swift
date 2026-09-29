import Foundation
@testable import ShelfCore

// THROWAWAY — V37 capability spike only (branch `test`, never merged into dev before a pass).
// The JSON contract between the ShelfCore side (export, adapter, scorer) and the Mac/iPhone runner
// (`spikes/v37/runner`). Both sides decode the same keys; see `spikes/v37/runner/README.md`.

/// One case as the runner sees it: the target's claims and neighbours, and the answer in segments.
struct SpikeInput: Codable, Equatable {
    struct Claim: Codable, Equatable { let id, alias, kind, role, text: String }
    struct Neighbour: Codable, Equatable { let name, key, definition: String }
    struct Segment: Codable, Equatable { let n: Int; let text: String }
    let caseID, set, targetKey, targetName, question: String
    let claims: [Claim]
    let neighbours: [Neighbour]
    let segments: [Segment]
    let wordCount: Int
    /// V37: reason → conclusion links fixed by the answer's own discourse markers (`SpikeSegmenter.links`).
    var links: [SpikeLink]? = nil
}

struct SpikeInputFile: Codable { let set: String; let cases: [SpikeInput] }

/// The misconception menu compiled once per target (only kept mistakes carry ids m1…).
struct SpikeAnswerKey: Codable, Equatable {
    struct Mistake: Codable, Equatable {
        let id, text, contradicts, kind, confusedWith, question: String
    }
    let status: String
    let mistakes: [Mistake]
}

struct SpikeAnswerKeyFile: Codable { let keys: [String: SpikeAnswerKey] }

/// What the model said about one segment (claim and mistake ids already mapped back from aliases).
struct SpikeSegmentLabel: Codable, Equatable {
    let n: Int
    let role, claim, relation, misconception, polarity, specificity, describes: String
    /// high · medium · low (the model's own confidence in this label).
    var confidence: String? = nil    /// The model's few-word gist of the segment (V37): a scratch field, never judged.
    var says: String? = nil
}

struct SpikeLink: Codable, Equatable { let reason, conclusion: Int }

struct SpikeReading: Codable, Equatable {
    let segments: [SpikeSegmentLabel]
    let links: [SpikeLink]
    /// V37: the row call's own labels before the locator's placement was merged in (audit only).
    var rows: [SpikeSegmentLabel]? = nil
}

/// One second-opinion item the runner selected, and the verdict it got.
struct SpikeOpinionItem: Codable, Equatable {
    let item: Int
    let kind: String            // credit · contradiction · confusion · reason
    let segment: Int
    let claimID: String?
    let neighbour: String?
}

struct SpikeVerdict: Codable, Equatable { let item: Int; let verdict: String }

struct SpikeCall<Output: Codable & Equatable>: Codable, Equatable {
    let status: String          // ok · refused · timeout · schemaError · contextOverflow · rateLimited · unavailable · error
    let latencyMs: Int
    let retries: Int
    let output: Output?
}

struct SpikeSecondOpinionOutput: Codable, Equatable {
    let items: [SpikeOpinionItem]
    let verdicts: [SpikeVerdict]
}

/// One answer read once: the JSONL line the runner writes.
struct SpikeRecord: Codable, Equatable {
    let caseID, set, device: String
    let run: Int
    let cold: Bool
    let processCallIndex: Int
    let osBuild, promptSHA: String
    let reading: SpikeCall<SpikeReading>
    let secondOpinion: SpikeCall<SpikeSecondOpinionOutput>?
    let totalLatencyMs: Int

    static func load(_ path: String) throws -> [String: SpikeRecord] {
        let text = try String(contentsOfFile: path, encoding: .utf8)
        var result: [String: SpikeRecord] = [:]
        for line in text.split(separator: "\n") where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            let record = try JSONDecoder().decode(SpikeRecord.self, from: Data(line.utf8))
            result[record.caseID] = record   // the last record of a case wins (a restarted run rewrites it)
        }
        return result
    }
}

extension SpikeInput {
    /// Builds the runner's view of a case from the same target the harness scores against.
    static func make(_ item: GeneralizationEvaluation.Case, set: String, target: DiagnosisTarget) -> SpikeInput {
        let normalize = CanonicalWhitespaceResolver.normalize
        var core = 0, support = 0
        let claims = target.rubric.map { claim -> Claim in
            core += 1
            return Claim(id: claim.id, alias: "c\(core)", kind: claim.kind.rawValue, role: "core", text: normalize(claim.evidence.text))
        } + target.supporting.map { claim -> Claim in
            support += 1
            return Claim(id: claim.id, alias: "s\(support)", kind: claim.kind.rawValue, role: "supporting", text: normalize(claim.evidence.text))
        }
        let name = target.conceptName ?? item.concept ?? "this page"
        let question = target.concept == nil ? "Explain what this page says in your own words."
            : "Explain \(name) in your own words."
        let segments = SpikeSegmenter.segments(item.text).enumerated().map { Segment(n: $0.offset + 1, text: $0.element) }
        let key = item.concept.map { "\(item.document)|\($0)" } ?? "\(item.document)|p\(item.page ?? -1)"
        return SpikeInput(caseID: item.id, set: set, targetKey: key, targetName: name, question: question, claims: claims,
                          neighbours: neighbours(of: target), segments: segments,
                          wordCount: item.text.split(whereSeparator: \.isWhitespace).count,
                          links: SpikeSegmenter.links(segments.map(\.text), text: item.text).map { SpikeLink(reason: $0.reason, conclusion: $0.conclusion) })
    }

    /// Up to four neighbouring concepts, each with its definition: the contrast partner first, then
    /// the concepts whose definitions share the most words with the target's own claims, core and
    /// supporting (the likeliest to be mixed up). A claim belongs to the concept V35 says owns it. Page targets have none: their
    /// competitors are other claims on the page, not concepts.
    static func neighbours(of target: DiagnosisTarget) -> [Neighbour] {
        guard let own = target.concept else { return [] }
        var byConcept: [ConceptKey: LearningClaim] = [:]
        for claim in target.competitors {
            let owner = AlignmentContext.owner(of: claim, names: target.names)
            guard owner != own, target.names[owner] != nil else { continue }
            if let existing = byConcept[owner], existing.kind == .definition || claim.kind != .definition { continue }
            byConcept[owner] = claim
        }
        let partner = target.contrastDefinition.map { AlignmentContext.owner(of: $0, names: target.names) }
        let ownStems = Set((target.rubric + target.supporting).flatMap { LexicalProfile($0.evidence.text).stems })
        let overlap = byConcept.mapValues { LexicalProfile($0.evidence.text).stems.intersection(ownStems).count }
        let ordered = byConcept.keys.sorted { lhs, rhs in
            (lhs == partner ? 0 : 1, -(overlap[lhs] ?? 0), lhs.value) < (rhs == partner ? 0 : 1, -(overlap[rhs] ?? 0), rhs.value)
        }
        return ordered.prefix(4).compactMap { key in
            byConcept[key].map { Neighbour(name: target.names[key]?.first ?? key.value, key: key.value,
                                           definition: CanonicalWhitespaceResolver.normalize($0.evidence.text)) }
        }
    }
}
