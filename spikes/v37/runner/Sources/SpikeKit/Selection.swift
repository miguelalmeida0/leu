import Foundation

// THROWAWAY — V37 capability spike only.

/// The raw guided-generation outputs, before aliases and numbers are mapped back.
struct RawReading: Decodable {
    struct Segment: Decodable { let n, role, claim, relation, misconception, polarity, specificity, describes, confidence: String; let says: String? }
    struct Link: Decodable { let reason, conclusion: String }
    let segments: [Segment]
    let links: [Link]
}

struct RawAnswerCheck: Decodable { let verdict: String }

struct RawLocate: Decodable { let segment, instead, mistake, kind, claim: String }

struct RawOpinion: Decodable {
    struct Verdict: Decodable { let item, verdict: String }
    let verdicts: [Verdict]
}

struct RawAnswerKey: Decodable {
    struct Mistake: Decodable { let claim, text, kind, confusedWith, question: String }
    let mistakes: [Mistake]
}

public enum Selection {
    /// Claim aliases back to ids ("none" stays). An unknown value is kept as it is, so the harness's
    /// structural check (V1) rejects the reading.
    static func map(_ raw: RawReading, input: SpikeInput) -> SpikeReading {
        let ids = Dictionary(input.claims.map { ($0.alias, $0.id) }, uniquingKeysWith: { a, _ in a })
        let relations = Dictionary(uniqueKeysWithValues: zip(SpikeSchemas.relationWords, SpikeSchemas.relations))
        let segments = raw.segments.map { s in
            var label = SpikeSegmentLabel(n: Int(s.n) ?? -1, role: s.role, claim: s.claim == "none" ? "none" : ids[s.claim] ?? s.claim,
                                          relation: relations[s.relation] ?? s.relation, misconception: s.misconception, polarity: s.polarity,
                                          specificity: s.specificity, describes: s.describes, confidence: s.confidence)
            label.says = s.says
            return label
        }
        return SpikeReading(segments: segments, links: raw.links.map { SpikeLink(reason: Int($0.reason) ?? -1, conclusion: Int($0.conclusion) ?? -1) })
    }

    /// V37: the locator's placement merged into the rows. The located segment reads as contradicting the
    /// claim the locator names (or the row's own claim when it names none); "otherConcept" keeps a
    /// neighbour the row named. Every other label is the row call's. Nothing is placed for "none".
    /// The reading's links are the answer's marker links first, then the model's own (deduplicated).
    public static func refine(_ reading: SpikeReading, locate: SpikeOpinionItem?, input: SpikeInput) -> SpikeReading {
        var links = input.links ?? []
        for link in reading.links where !links.contains(link) { links.append(link) }
        guard let locate, locate.segment > 0, let index = reading.segments.firstIndex(where: { $0.n == locate.segment }) else {
            return SpikeReading(segments: reading.segments, links: links, rows: reading.segments)
        }
        var segments = reading.segments
        let row = segments[index]
        var label = SpikeSegmentLabel(n: row.n, role: row.role, claim: locate.claimID ?? (row.claim), relation: "contradicts",
                                      misconception: locate.mistakeID ?? row.misconception, polarity: row.polarity, specificity: row.specificity,
                                      describes: locate.neighbour ?? (row.describes == "target" ? "target" : row.describes),
                                      confidence: row.confidence)
        label.says = row.says
        segments[index] = label
        return SpikeReading(segments: segments, links: links, rows: reading.segments)
    }

    /// A pair for the second opinion: the item as recorded, and the two statements it compares.
    public struct Pair: Sendable {
        public let item: SpikeOpinionItem
        public let a, b: String
    }

    /// SPIKE_SPEC §5: at most 8 items, core-claim credits first, then contradictions (a confusion is
    /// compared with the neighbour's definition), then reasons linked to a credited conclusion (A is
    /// the source's how/why claim). The wrong-idea kind follows the harness's own rule
    /// (`SpikeChecks.check`); a segment that is both a contradiction and a linked reason gets both items.
    public static func items(_ reading: SpikeReading, input: SpikeInput, key: SpikeAnswerKey?, limit: Int = 8) -> [Pair] {
        let claims = Dictionary(input.claims.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let neighbours = Dictionary(input.neighbours.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })
        let text = Dictionary(input.segments.map { ($0.n, $0.text) }, uniquingKeysWith: { a, _ in a })
        let credited = { (label: SpikeSegmentLabel) in ["entails", "partiallyEntails"].contains(label.relation) && claims[label.claim] != nil }
        var credits: [(Int, String, String, String)] = [], wrongs: [(Int, String, String?, String?, String, String)] = []
        var reasons: [(Int, String, String, String)] = []
        for label in reading.segments {
            guard let segment = text[label.n] else { continue }
            if credited(label), let claim = claims[label.claim], claim.role == "core" {
                credits.append((label.n, claim.id, claim.text, segment))
            } else if label.relation == "contradicts" {
                let mistake = key?.mistakes.first { $0.id == label.misconception }
                let neighbour = mistake.flatMap { neighbours[$0.confusedWith] } ?? neighbours[label.describes]
                let confusion = (mistake.map { $0.kind == "confused" } ?? true) && neighbour != nil
                if confusion, let neighbour {
                    wrongs.append((label.n, "confusion", nil, neighbour.name, neighbour.definition, segment))
                } else if let claim = claims[label.claim] ?? mistake.flatMap({ claims[$0.contradicts] }) {
                    wrongs.append((label.n, "contradiction", claim.id, nil, claim.text, segment))
                }
            }
        }
        let byN = Dictionary(reading.segments.map { ($0.n, $0) }, uniquingKeysWith: { a, _ in a })
        let why = input.claims.first { $0.role == "core" && ["purpose", "mechanism", "cause", "consequence"].contains($0.kind) }
        var seen = Set<Int>()
        for link in reading.links where link.reason != link.conclusion && seen.insert(link.reason).inserted {
            guard let conclusion = byN[link.conclusion], credited(conclusion), let reason = byN[link.reason], !credited(reason),
                  !reading.links.contains(where: { $0.reason == link.conclusion && $0.conclusion == link.reason }),
                  let claim = why ?? claims[conclusion.claim], let reasonText = text[link.reason], let conclusionText = text[link.conclusion]
            else { continue }
            reasons.append((link.reason, claim.id, claim.text, "a reason the student gives for \"\(conclusionText)\": \"\(reasonText)\""))
        }
        var pairs: [Pair] = []
        func add(_ kind: String, _ n: Int, _ claimID: String?, _ neighbour: String?, _ a: String, _ b: String) {
            guard pairs.count < limit else { return }
            pairs.append(Pair(item: SpikeOpinionItem(item: pairs.count + 1, kind: kind, segment: n, claimID: claimID, neighbour: neighbour), a: a, b: b))
        }
        for credit in credits { add("credit", credit.0, credit.1, nil, credit.2, "\"\(credit.3)\"") }
        for wrong in wrongs { add(wrong.1, wrong.0, wrong.2, wrong.3, wrong.4, "\"\(wrong.5)\"") }
        for reason in reasons { add("reason", reason.0, reason.1, nil, reason.2, reason.3) }
        return pairs
    }

    /// The locator's claim, checked against its own words (dev06): kept unless what it says the textbook
    /// says instead shares no content stem with that claim while clearly matching another listed claim.
    static func resolveClaim(_ picked: String, instead: String, input: SpikeInput) -> String {
        let said = stems(instead).subtracting(stems(input.targetName))
        func overlap(_ alias: String) -> Int { input.claims.first { $0.alias == alias }.map { said.intersection(stems($0.text)).count } ?? 0 }
        guard overlap(picked) == 0 else { return picked }
        let scored = input.claims.map { ($0.alias, overlap($0.alias)) }.sorted { $0.1 > $1.1 }
        guard let best = scored.first, best.1 >= 2, scored.count < 2 || best.1 > scored[1].1 else { return picked }
        return best.0
    }

    // MARK: - Answer keys

    static let stopwords: Set<String> = ["the", "and", "for", "that", "this", "with", "are", "was", "were", "its", "it's", "they", "them",
                                         "their", "can", "not", "but", "you", "your", "has", "have", "had", "does", "from", "into",
                                         "only", "any", "all", "one", "what", "when", "which", "who", "how", "why", "also", "just", "than"]

    /// Crude content-word stems: lower-cased words of three or more letters, common endings removed.
    public static func stems(_ text: String) -> Set<String> {
        let words = text.lowercased().split { !$0.isLetter && $0 != "'" }.map(String.init).filter { $0.count >= 3 && !stopwords.contains($0) }
        return Set(words.map { word in
            for suffix in ["ing", "ed", "es", "ly", "s"] where word.hasSuffix(suffix) && word.count - suffix.count >= 3 {
                return String(word.dropLast(suffix.count))
            }
            return word
        })
    }

    static let negations: Set<String> = ["not", "never", "no", "nobody", "none", "nothing", "cannot", "can't", "doesn't", "don't",
                                         "isn't", "aren't", "won't", "without"]

    /// A candidate mistake that restates a listed claim (dev06): its content stems all appear in one claim and
    /// the two agree on negation. The compile copied true claims as "mistakes" (24 of 49 kept on P).
    static func restates(_ text: String, input: SpikeInput) -> Bool {
        let own = stems(text).subtracting(stems(input.targetName))
        func negated(_ s: String) -> Bool { !Set(s.lowercased().split { !$0.isLetter && $0 != "'" }.map(String.init)).isDisjoint(with: negations) }
        return !own.isEmpty && input.claims.contains { own.isSubset(of: stems($0.text)) && negated($0.text) == negated(text) }
    }

    /// SPIKE_SPEC §5 self-check, first half: a mistake must share grounding with its claim, or with
    /// the neighbour it confuses. (The second half — the second opinion calling it "opposite" — is a call.)
    static func grounded(_ mistake: RawAnswerKey.Mistake, claim: SpikeInput.Claim, input: SpikeInput) -> Bool {
        var source = stems(claim.text)
        if let neighbour = input.neighbours.first(where: { $0.name == mistake.confusedWith }) { source.formUnion(stems(neighbour.definition)) }
        source.subtract(stems(input.targetName))
        return !stems(mistake.text).subtracting(stems(input.targetName)).isDisjoint(with: source)
    }
}
