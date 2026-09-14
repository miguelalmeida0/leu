import Foundation

public struct TradeoffSide: Codable, Equatable, Hashable, Sendable {
    public var subject: String
    public var predicate: String
    public var object: String
    public var statement: String { "\(subject) \(predicate) \(object)" }
    public var action: String { "\(TradeoffExtractor.gerund(predicate)) \(object)" }
}

public struct SemanticTradeoff: Codable, Equatable, Hashable, Sendable {
    public var benefit: TradeoffSide
    public var cost: TradeoffSide

    public var answer: String {
        let costText = benefit.subject == cost.subject ? cost.action : "\(cost.subject) \(cost.action)"
        return "\(benefit.action); \(costText)"
    }

    public var meaning: String {
        "\(benefit.statement). The trade-off is that \(GeneralClaimExtractor.inline(cost.statement))."
    }
}

/// Grammatical contrasts only; neither side comes from a technology dictionary.
struct TradeoffExtractor {
    func extract(_ text: String, evidence: SemanticEvidenceSpan) -> ExtractedClaim? {
        var sides: SemanticTradeoff?
        if let p = captures(#"^although (.+?) (improves?|accelerates?|reduces?|helps?|benefits?) (.+?), (?:it|they) (increases?|adds?|requires?|consumes?) (.+)$"#, text) {
            sides = pair(p[0], p[1], p[2], p[3], p[4])
        } else if let p = captures(#"^(.+?) (accelerates?|improves?|reduces?|helps?|benefits?) (.+?),? (?:but|while) (adds?|increases?|requires?|consumes?|adding|increasing|requiring|consuming) (.+)$"#, text) {
            sides = pair(p[0], p[1], p[2], finite(p[3], firstVerb: p[1]), p[4])
        } else if let p = captures(#"^(.+?) (helps?) (.+?) at the cost of (.+)$"#, text) {
            sides = pair(p[0], p[1], p[2], p[1].lowercased() == "helps" ? "incurs" : "incur", p[3])
        } else if let p = captures(#"^(.+?) (trades?) (.+?) for (.+)$"#, text) {
            let singular = p[1].lowercased() == "trades"
            sides = pair(p[0], singular ? "gains" : "gain", p[3], singular ? "gives up" : "give up", p[2])
        } else if let p = captures(#"^(.+?) (is|are) faster for (.+?) but slower for (.+)$"#, text) {
            sides = pair(p[0], "\(p[1]) faster for", p[2], "\(p[1]) slower for", p[3])
        } else if let p = captures(#"^(.+?) (benefits?) (.+?),? but (.+?) (becomes?) more expensive$"#, text) {
            sides = SemanticTradeoff(benefit: side(p[0], p[1], p[2]), cost: side(p[3], p[4], "more expensive"))
        }
        guard let sides, QuestionSelfContainment.validConcept(GeneralClaimExtractor.canonical(sides.benefit.subject)),
              [sides.benefit, sides.cost].allSatisfy({ !$0.object.isEmpty && !QuestionSelfContainment.hasUnresolvedReference($0.statement) }) else { return nil }
        return ExtractedClaim(subject: GeneralClaimExtractor.canonical(sides.benefit.subject),
            subjectPhrase: sides.benefit.subject, predicate: sides.benefit.predicate, object: sides.benefit.object,
            qualifier: sides.cost.statement, intent: .application, relation: .tradeoff, evidence: evidence,
            tradeoff: sides)
    }

    private func side(_ subject: String, _ predicate: String, _ object: String) -> TradeoffSide {
        TradeoffSide(subject: GeneralClaimExtractor.inline(subject), predicate: predicate.lowercased(), object: object)
    }

    private func pair(_ subject: String, _ verb: String, _ object: String, _ costVerb: String, _ cost: String) -> SemanticTradeoff {
        SemanticTradeoff(benefit: side(subject, verb, object), cost: side(subject, costVerb, cost))
    }

    private func finite(_ verb: String, firstVerb: String) -> String {
        let base = ["adding": "add", "increasing": "increase", "requiring": "require", "consuming": "consume"]
        guard let value = base[verb.lowercased()] else { return verb }
        return value + (firstVerb.lowercased().hasSuffix("s") ? "s" : "")
    }

    static func gerund(_ predicate: String) -> String {
        let forms = ["accelerate": "accelerating", "improve": "improving", "reduce": "reducing",
                     "help": "helping", "benefit": "benefiting", "add": "adding", "increase": "increasing",
                     "require": "requiring", "consume": "consuming", "incur": "incurring", "gain": "gaining",
                     "give up": "giving up", "gives up": "giving up", "become": "becoming",
                     "rerun": "rerunning", "retry": "retrying", "retries": "retrying", "expire": "expiring",
                     "fail": "failing", "block": "blocking"]
        if predicate.hasPrefix("is ") { return "being " + String(predicate.dropFirst(3)) }
        if predicate.hasPrefix("are ") { return "being " + String(predicate.dropFirst(4)) }
        return forms[predicate] ?? forms[String(predicate.dropLast())] ?? predicate
    }

    private func captures(_ pattern: String, _ text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        return (1..<match.numberOfRanges).map { (text as NSString).substring(with: match.range(at: $0)) }
    }
}
