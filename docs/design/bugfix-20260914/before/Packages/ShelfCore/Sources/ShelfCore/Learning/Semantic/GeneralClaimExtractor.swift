import Foundation

public enum QuestionIntent: String, Codable, CaseIterable, Sendable {
    case define, mechanism, cause, consequence, distinguish, prerequisite, constraint
    case sequence, application, debugging, reconstruction
}

/// A grammatical claim, not a bag of co-occurring technical nouns. All fields are
/// copied from a single source sentence; no ontology supplies missing predicates.
public struct ExtractedClaim: Codable, Equatable, Hashable, Sendable {
    public var subject: String
    public var subjectPhrase: String
    public var predicate: String
    public var object: String
    public var qualifier: String?
    public var qualifierJoiner: String? = nil
    public var intent: QuestionIntent
    public var relation: SemanticRelation
    public var evidence: SemanticEvidenceSpan
    public var tradeoff: SemanticTradeoff? = nil
    public var constraintScope: String? = nil
}

public struct GeneralClaimExtractor: Sendable {
    public init() {}

    public func extract(_ text: String, evidence: SemanticEvidenceSpan) -> [ExtractedClaim] {
        // A period within Promise.all or a decimal is not a sentence boundary.
        let pattern = #"[^.!?;]+(?:[.!?](?!\s|$)[^.!?;]+)*[.!?;]?(?:\s|$)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap { match in
            let raw = ns.substring(with: match.range).trimmingCharacters(in: .whitespacesAndNewlines)
            var span = evidence
            span.sourceText = raw
            let local = (ns.substring(with: match.range) as NSString).range(of: raw)
            span.charStart = evidence.charStart + match.range.location + local.location
            span.charLength = (raw as NSString).length
            span.sourceHash = String(StableIdentity.hash64("\(span.documentID)|\(span.pageIndex)|\(span.charStart)|\(raw)"), radix: 16)
            return claim(raw, evidence: span)
        }
    }

    private func claim(_ raw: String, evidence: SemanticEvidenceSpan) -> ExtractedClaim? {
        let text = raw.trimmingCharacters(in: CharacterSet(charactersIn: ".!?; \n\r\t"))
        if let parts = captures(#"^(.+?): first (.+?), then (.+)$"#, text) {
            return make(subject: parts[0], predicate: "steps", object: "First \(parts[1]), then \(parts[2])", qualifier: nil,
                        intent: .reconstruction, relation: .before, evidence: evidence)
        }
        if let parts = captures(#"^(.+?) (reruns?|fails?|blocks?|retries|retry|expires?) when (.+)$"#, text) {
            return make(subject: parts[0], predicate: parts[1], object: "\(parts[0]) \(parts[1])", qualifier: parts[2],
                        intent: .debugging, relation: .causes, evidence: evidence)
        }
        if let parts = captures(#"^Unlike (.+?), (.+?) (determines|decides|controls|provides|uses|requires|allows) (.+)$"#, text) {
            return make(subject: parts[1], predicate: parts[2], object: parts[3], qualifier: parts[0],
                        intent: .distinguish, relation: .contrastsWith, evidence: evidence)
        }
        if let parts = captures(#"^(.+?) differs from (.+?) because (.+)$"#, text) {
            return make(subject: parts[0], predicate: "differs from", object: parts[1], qualifier: parts[2],
                        intent: .distinguish, relation: .contrastsWith, evidence: evidence)
        }
        if let tradeoff = TradeoffExtractor().extract(text, evidence: evidence) { return tradeoff }
        let rules: [(String, QuestionIntent, SemanticRelation)] = [
            (#"works by|operates by"#, .mechanism, .usedFor),
            (#"happens when|occurs when|arises when"#, .cause, .requires),
            (#"runs after|run after|happens after|occurs after"#, .sequence, .after),
            (#"runs before|run before|happens before|occurs before"#, .sequence, .before),
            (#"depends on|depend on|requires|require"#, .prerequisite, .dependsOn),
            (#"prevents|prevent|protects against|protect against|avoids|avoid"#, .constraint, .prevents),
            (#"guarantees|guarantee"#, .constraint, .enables),
            (#"reduces|reduce|improves|improve|enables|enable|allows|allow"#, .consequence, .enables),
            (#"causes|cause|results in|result in|leads to|lead to"#, .consequence, .causes),
            (#"is used to|are used to|is used for|are used for"#, .mechanism, .purpose),
            (#"memoizes|memoize"#, .mechanism, .memoizes),
            (#"returns|return"#, .mechanism, .returns),
            (#"describes|describe|calculates|calculate|applies|apply|requests|request|selects|select|creates|create"#, .mechanism, .purpose),
            (#"differs from|differ from"#, .distinguish, .contrastsWith),
            (#"means|mean|refers to|refer to|represents|represent|is|are"#, .define, .definedAs)
        ]
        for (verbs, intent, relation) in rules {
            guard let parts = captures("^(.+?) (" + verbs + ") (.+)$", text) else { continue }
            var object = parts[2], qualifier: String?, joiner: String?, scope: String?
            var selectedIntent = intent
            if relation == .prevents || relation == .enables, let split = captures(#"^(.+?) (by|through|because|when) (.+)$"#, object) {
                if split[1].lowercased() == "through",
                   split[2].range(of: #"^(?i:a|an|the|each|any)\s"#, options: .regularExpression) != nil {
                    scope = "through " + split[2]
                } else {
                    object = split[0]; joiner = split[1].lowercased(); qualifier = split[2]
                    selectedIntent = joiner == "when" ? .constraint : joiner == "because" ? .cause : .mechanism
                }
            }
            var result = make(subject: parts[0], predicate: parts[1], object: object, qualifier: qualifier,
                        intent: selectedIntent, relation: relation, evidence: evidence)
            result?.constraintScope = scope
            result?.qualifierJoiner = joiner
            return result
        }
        return nil
    }

    private func make(subject: String, predicate: String, object: String, qualifier: String?,
                      intent: QuestionIntent, relation: SemanticRelation, evidence: SemanticEvidenceSpan) -> ExtractedClaim? {
        let canonical = Self.canonical(subject)
        guard evidence.sourceText.range(of: #"(?i)\b(?:in the example|for example|shown above|shown below|is illustrated|is mentioned)\b"#, options: .regularExpression) == nil else { return nil }
        guard QuestionSelfContainment.validConcept(canonical), object.count >= 6,
              !QuestionSelfContainment.hasUnresolvedReference(subject),
              !QuestionSelfContainment.hasUnresolvedReference(object),
              qualifier.map({ !QuestionSelfContainment.hasUnresolvedReference($0) }) ?? true else { return nil }
        return ExtractedClaim(subject: canonical, subjectPhrase: Self.inline(subject), predicate: predicate.lowercased(),
                              object: object, qualifier: qualifier, intent: intent, relation: relation, evidence: evidence)
    }

    public static func canonical(_ value: String) -> String {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.replacingOccurrences(of: #"^(?i:a|an|the)\s+"#, with: "", options: .regularExpression)
    }

    public static func inline(_ value: String) -> String {
        value.replacingOccurrences(of: #"^A "#, with: "a ", options: .regularExpression)
            .replacingOccurrences(of: #"^An "#, with: "an ", options: .regularExpression)
            .replacingOccurrences(of: #"^The "#, with: "the ", options: .regularExpression)
    }

    private func captures(_ pattern: String, _ text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        let ns = text as NSString
        return (1..<match.numberOfRanges).map { ns.substring(with: match.range(at: $0)) }
    }
}
