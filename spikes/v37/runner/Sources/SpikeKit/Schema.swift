import Foundation

// THROWAWAY — V37 capability spike only.

/// A platform-neutral description of a guided-generation schema. `SpikeFoundation` turns it into
/// Foundation Models' `DynamicGenerationSchema`; the fake model and the dry run read it directly.
public indirect enum SchemaNode: Equatable, Sendable {
    public struct Property: Equatable, Sendable {
        public let name: String
        public let description: String?
        public let node: SchemaNode
        public init(_ name: String, _ node: SchemaNode, _ description: String? = nil) {
            self.name = name; self.node = node; self.description = description
        }
    }
    case object(name: String, properties: [Property])
    /// One of a fixed list of strings (an enumeration).
    case choice(name: String, values: [String])
    case text
    case array(of: SchemaNode, min: Int, max: Int)

    /// A compact JSON-like rendering, used to estimate prompt size (guided generation also shows
    /// the model its schema).
    public var rendered: String {
        switch self {
        case let .object(name, properties):
            return name + "{" + properties.map { "\"\($0.name)\":" + $0.node.rendered }.joined(separator: ",") + "}"
        case let .choice(_, values): return "(" + values.map { "\"\($0)\"" }.joined(separator: "|") + ")"
        case .text: return "string"
        case let .array(of, min, max): return "[" + of.rendered + "]{\(min),\(max)}"
        }
    }
}

public enum SpikeSchemas {
    public static let roles = ["statement", "reason", "example", "analogy", "hedge", "filler"]
    public static let relations = ["entails", "partiallyEntails", "contradicts", "unrelated"]
    public static let polarities = ["affirmed", "negated"]
    public static let specificities = ["specific", "vague"]
    public static let confidences = ["high", "medium", "low"]
    public static let verdicts = ["same", "part", "opposite", "different"]
    public static let mistakeKinds = ["opposite", "reversed", "overgeneralized", "confused"]

    /// Unique, non-empty values in their first order (an enumeration may not repeat a value).
    static func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    static func numbers(_ count: Int) -> [String] { (1...max(1, count)).map(String.init) }

    /// The reading (SPIKE_SPEC §5): exactly one entry per segment, ids as enumerations, then links.
    public static func reading(_ input: SpikeInput, key: SpikeAnswerKey?) -> SchemaNode {
        let k = input.segments.count
        let segment = SchemaNode.object(name: "SegmentLabel", properties: [
            .init("n", .choice(name: "SegmentNumber", values: numbers(k))),
            .init("role", .choice(name: "SegmentRole", values: roles)),
            .init("claim", .choice(name: "ClaimID", values: unique(input.claims.map(\.alias) + ["none"]))),
            .init("relation", .choice(name: "Relation", values: relations)),
            .init("misconception", .choice(name: "MistakeID", values: unique((key?.mistakes.map(\.id) ?? []) + ["none"]))),
            .init("polarity", .choice(name: "Polarity", values: polarities)),
            .init("specificity", .choice(name: "Specificity", values: specificities)),
            .init("describes", .choice(name: "Describes", values: unique(["target"] + input.neighbours.map(\.name) + ["unclear"]))),
            .init("confidence", .choice(name: "Confidence", values: confidences))
        ])
        let link = SchemaNode.object(name: "ReasonLink", properties: [
            .init("reason", .choice(name: "ReasonSegment", values: numbers(k))),
            .init("conclusion", .choice(name: "ConclusionSegment", values: numbers(k)))
        ])
        return .object(name: "Reading", properties: [
            .init("segments", .array(of: segment, min: k, max: k)),
            .init("links", .array(of: link, min: 0, max: k))
        ])
    }

    /// The second opinion: exactly one verdict per item.
    public static func opinion(items: Int) -> SchemaNode {
        let verdict = SchemaNode.object(name: "PairVerdict", properties: [
            .init("item", .choice(name: "PairNumber", values: numbers(items))),
            .init("verdict", .choice(name: "Verdict", values: verdicts))
        ])
        return .object(name: "SecondOpinion", properties: [.init("verdicts", .array(of: verdict, min: items, max: items))])
    }

    /// The answer key: 3–6 mistakes, each tied to a claim by its alias. No field descriptions: the
    /// approved prompts carry every instruction.
    public static func answerKey(_ input: SpikeInput) -> SchemaNode {
        let mistake = SchemaNode.object(name: "LikelyMistake", properties: [
            .init("claim", .choice(name: "RulingClaim", values: unique(input.claims.map(\.alias)))),
            .init("text", .text),
            .init("kind", .choice(name: "MistakeKind", values: mistakeKinds)),
            .init("confusedWith", .choice(name: "ConfusedWith", values: unique(input.neighbours.map(\.name) + ["none"]))),
            .init("question", .text)
        ])
        return .object(name: "AnswerKey", properties: [.init("mistakes", .array(of: mistake, min: 3, max: 6))])
    }
}
