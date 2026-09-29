import Foundation

// THROWAWAY — V37 capability spike only.

/// The three frozen-at-freeze instruction texts (`spikes/v37/prompts/*.txt`, the approved §6 drafts)
/// and one hash over them and the request layout below.
public struct PromptSet: Sendable {
    public static let files = ["answer-key.txt", "reading.txt", "second-opinion.txt", "answer-check.txt", "locate.txt"]
    /// Changes whenever the request layout in `Requests` changes.
    public static let layoutVersion = "v37-spike-request-layout-7"
    public let answerKey, reading, secondOpinion, answerCheck, locate: String
    public let sha: String

    public init(directory: URL) throws {
        let data = try Self.files.map { try Data(contentsOf: directory.appendingPathComponent($0)) }
        func text(_ index: Int) -> String {
            String(decoding: data[index], as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        var hashed = Data()
        for file in data { hashed.append(file); hashed.append(0) }
        hashed.append(Data(Self.layoutVersion.utf8))
        self.init(answerKey: text(0), reading: text(1), secondOpinion: text(2), answerCheck: text(3), locate: text(4), sha: SHA256.hex(hashed))
    }

    public init(answerKey: String, reading: String, secondOpinion: String, answerCheck: String = "", locate: String = "", sha: String = "test") {
        self.answerKey = answerKey; self.reading = reading; self.secondOpinion = secondOpinion; self.answerCheck = answerCheck; self.locate = locate; self.sha = sha
    }
}

/// The request each call sends after its instructions: data only, in a fixed layout. This is the
/// initial layout, not yet exercised against the model; it may change on P before the freeze.
public enum Requests {
    static func claims(_ input: SpikeInput) -> [String] {
        input.claims.map { "\($0.alias) (\($0.kind), \($0.role)): \($0.text)" }
    }

    static func neighbours(_ input: SpikeInput) -> [String] {
        input.neighbours.isEmpty ? ["none"] : input.neighbours.map { "\($0.name): \($0.definition)" }
    }

    /// SPIKE_SPEC §5: the target, the question, the claims, likely mistakes, neighbours and the
    /// numbered segments, each given once.
    public static func reading(_ input: SpikeInput, key: SpikeAnswerKey?) -> String {
        let aliases = Dictionary(input.claims.map { ($0.id, $0.alias) }, uniquingKeysWith: { a, _ in a })
        let mistakes = key?.mistakes ?? []
        var lines = ["Target: \(input.targetName)", "Question: \(input.question)", "", "Claims:"] + claims(input)
        lines += ["", "Likely mistakes:"]
        lines += mistakes.isEmpty ? ["none"] : mistakes.map { "\($0.id) (contradicts \(aliases[$0.contradicts] ?? "none")): \($0.text)" }
        lines += ["", "Neighbouring concepts:"] + neighbours(input)
        lines += ["", "Student's explanation, in numbered segments:"] + input.segments.map { "\($0.n). \($0.text)" }
        return lines.joined(separator: "\n")
    }

    /// The second opinion: numbered pairs; `b` is already worded (quoted, or the reason form).
    public static func opinion(_ pairs: [(a: String, b: String)]) -> String {
        pairs.enumerated().map { "\($0.offset + 1).\nA: \"\($0.element.a)\"\nB: \($0.element.b)" }.joined(separator: "\n\n")
    }

    /// The independent second opinion (configuration D): the whole answer against the source's facts
    /// and the neighbours, with no segment, label or claim id from the reading.
    public static func answerCheck(_ input: SpikeInput) -> String {
        (["Concept: \(input.targetName)", "Textbook facts:"] + input.claims.map { "- \($0.text)" }
            + ["Neighbouring concepts (not this one):"] + (input.neighbours.isEmpty ? ["none"] : input.neighbours.map { "- \($0.name): \($0.definition)" })
            + ["", "Student's explanation:", input.segments.map(\.text).joined(separator: " ")]).joined(separator: "\n")
    }

    /// The locator: where the false thing is, if anywhere (claims by alias, numbered segments).
    public static func locate(_ input: SpikeInput, key: SpikeAnswerKey?) -> String {
        let mistakes = key?.mistakes ?? []
        return (["Target: \(input.targetName)", "", "Claims:"] + input.claims.map { "\($0.alias) (\($0.kind)): \($0.text)" }
            + ["", "Likely mistakes:"] + (mistakes.isEmpty ? ["none"] : mistakes.map { "\($0.id): \($0.text)" })
            + ["", "Neighbouring concepts:"] + neighbours(input)
            + ["", "Student's explanation, in numbered segments:"] + input.segments.map { "\($0.n). \($0.text)" }).joined(separator: "\n")
    }

    /// The answer-key compile: the concept, its claims and its neighbours.
    public static func answerKey(_ input: SpikeInput) -> String {
        (["Concept: \(input.targetName)", "", "Claims:"] + claims(input) + ["", "Neighbouring concepts:"] + neighbours(input))
            .joined(separator: "\n")
    }

    /// A deliberately pessimistic size estimate (about three bytes per token), for the dry run's
    /// 3,500-token budget (SPIKE_SPEC §6): instructions, request and the schema the model is shown.
    public static func estimatedTokens(_ parts: String...) -> Int {
        Int((Double(parts.reduce(0) { $0 + $1.utf8.count }) / 3).rounded(.up))
    }
}
