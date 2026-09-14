import Foundation

public struct RealizedQuestion: Equatable, Sendable {
    public var intent: QuestionIntent
    public var prompt: String
    public var answer: String
    public var evidence: SemanticEvidenceSpan
}

public struct QuestionRealizer: Sendable {
    public init() {}

    public func realize(_ claim: ExtractedClaim) -> RealizedQuestion? {
        let s = claim.subjectPhrase, o = claim.object
        let answer: String
        let prompt: String
        switch claim.intent {
        case .define:
            prompt = "What is meant by \(claim.subject)?"; answer = o
        case .mechanism:
            if let mechanism = claim.qualifier {
                prompt = "How \(auxiliary(s)) \(s) \(baseVerb(claim.predicate)) \(o)?"
                answer = mechanism
            } else if claim.predicate.contains("works by") || claim.predicate.contains("operates by") {
                prompt = "How \(auxiliary(s)) \(s) work?"; answer = o
            } else if claim.relation == .memoizes || claim.relation == .returns {
                prompt = "What \(auxiliary(s)) \(s) \(baseVerb(claim.predicate))?"; answer = o
            } else if claim.relation == .purpose && !claim.predicate.contains("used") {
                prompt = "What \(auxiliary(s)) \(s) \(baseVerb(claim.predicate))?"; answer = o
            } else {
                prompt = "What is the purpose of \(s)?"; answer = o
            }
        case .cause:
            if let reason = claim.qualifier, claim.qualifierJoiner == "because" {
                prompt = "Why \(auxiliary(s)) \(s) \(baseVerb(claim.predicate)) \(o)?"; answer = reason
            } else { prompt = "What condition causes \(s)?"; answer = o }
        case .consequence:
            prompt = "What \(auxiliary(s)) \(s) \(baseVerb(claim.predicate))?"; answer = o
        case .constraint:
            if let scope = claim.constraintScope, o.hasSuffix(" " + scope) {
                prompt = "What \(auxiliary(s)) \(s) \(baseVerb(claim.predicate)) \(scope)?"
                answer = String(o.dropLast(scope.count + 1))
            } else if let condition = claim.qualifier, claim.qualifierJoiner == "when" {
                prompt = "Under what condition \(auxiliary(s)) \(s) \(baseVerb(claim.predicate)) \(o)?"; answer = condition
            } else { prompt = "What \(auxiliary(s)) \(s) \(baseVerb(claim.predicate))?"; answer = o }
        case .prerequisite:
            prompt = "What \(auxiliary(s)) \(s) \(baseVerb(claim.predicate))?"; answer = o
        case .sequence:
            let event = claim.predicate.replacingOccurrences(of: " after", with: "").replacingOccurrences(of: " before", with: "")
            prompt = claim.relation == .after ? "What must happen before \(s) \(event)?" : "What happens after \(s) \(event)?"
            answer = o
        case .distinguish:
            let other = claim.predicate == "differs from" || claim.predicate == "differ from" ? o : claim.qualifier
            guard let other else { return nil }
            prompt = "How \(auxiliary(s)) \(s) differ from \(GeneralClaimExtractor.inline(other))?"
            answer = claim.predicate.contains("differ") ? (claim.qualifier ?? "") : "\(s) \(claim.predicate) \(o)"
            guard !answer.isEmpty else { return nil } // A bare contrast names two things but explains no difference.
        case .application:
            guard claim.tradeoff != nil || claim.qualifier != nil else { return nil }
            prompt = "What trade-off should you consider when using \(s)?"
            answer = claim.tradeoff?.answer ?? "\(s) \(claim.predicate) \(o) but \(claim.qualifier ?? "")"
        case .debugging:
            guard let condition = claim.qualifier else { return nil }
            prompt = "If \(condition), what behavior should you expect from \(s)?"
            answer = TradeoffExtractor.gerund(claim.predicate)
        case .reconstruction:
            prompt = "How would you reconstruct the steps for \(s)?"; answer = o
        }
        guard QuestionSelfContainment.rejectionReason(prompt: prompt, answer: answer, concept: claim.subject) == nil,
              QuestionTeachingValue.rejectionReason(claim: claim, answer: answer) == nil else { return nil }
        return RealizedQuestion(intent: claim.intent, prompt: prompt, answer: answer, evidence: claim.evidence)
    }

    private func auxiliary(_ subject: String) -> String {
        let lower = subject.lowercased()
        if lower.hasPrefix("a ") || lower.hasPrefix("an ") { return "does" }
        let last = lower.split(separator: " ").last.map(String.init) ?? lower
        return last.hasSuffix("s") && !last.hasSuffix("ss") && !["css", "https", "dns", "redis"].contains(last) ? "do" : "does"
    }

    private func baseVerb(_ predicate: String) -> String {
        let forms = ["prevents": "prevent", "protects against": "protect against", "avoids": "avoid",
                     "requires": "require", "depends on": "depend on", "enables": "enable", "allows": "allow",
                     "causes": "cause", "results in": "result in", "leads to": "lead to", "guarantees": "guarantee",
                     "reduces": "reduce", "improves": "improve", "memoizes": "memoize", "returns": "return",
                     "describes": "describe", "calculates": "calculate", "applies": "apply", "requests": "request",
                     "selects": "select", "creates": "create"]
        return forms[predicate] ?? predicate
    }
}

public enum QuestionSelfContainment {
    public static func hasUnresolvedReference(_ text: String) -> Bool {
        let pattern = #"(?i)\b(it|this|here|they|them|these|those|above|below)\b|^(?i:that|there|such)\b"#
        return text.range(of: pattern, options: .regularExpression) != nil
    }

    public static func validConcept(_ name: String) -> Bool {
        let words = name.split(whereSeparator: \.isWhitespace)
        guard name.count >= 2, name.count <= 72, words.count <= 8,
              name.first?.isLetter == true, !hasUnresolvedReference(name) else { return false }
        let incidental: Set<String> = ["example", "note", "chapter", "section", "figure", "table", "introduction", "summary", "something", "thing", "everything", "nothing", "we", "you", "i"]
        guard !incidental.contains(name.lowercased()) else { return false }
        return name.range(of: #"(?i)^(a|an|the)\s|\b(probably|perhaps|might|maybe)\b|[,;:?!]"#, options: .regularExpression) == nil
    }

    public static func rejectionReason(prompt: String, answer: String, concept: String) -> String? {
        guard validConcept(concept) else { return "incidental or malformed concept" }
        if hasUnresolvedReference(prompt) { return "unresolved reference" }
        if prompt.range(of: #"(?i)\b(?:does|do|is|are|can|of) that\b"#, options: .regularExpression) != nil { return "unresolved reference" }
        if prompt.range(of: #"(?i)according to|this source|prevent or require|\bdoes .+? (?:happens|means|prevents|requires)\b"#, options: .regularExpression) != nil { return "filler or malformed predicate" }
        if prompt.range(of: #"\b(?:does|do|of|from|before|after) (?:A|An|The)\b"#, options: .regularExpression) != nil { return "malformed subject article" }
        if prompt.contains("{") || prompt.contains("}") || prompt.contains("___") || prompt.contains("<") { return "template artifact" }
        guard prompt.hasSuffix("?"), prompt.count >= 16, prompt.count <= 240 else { return "incomplete or oversized prompt" }
        guard answer.count >= 2, answer.count <= 320, !hasUnresolvedReference(answer) else { return "answer is not self-contained" }
        let normalizedAnswer = answer.trimmingCharacters(in: .punctuationCharacters.union(.whitespacesAndNewlines)).lowercased()
        if prompt.lowercased().contains(normalizedAnswer) { return "answer leakage" }
        return nil
    }
}

/// Separate from grammar: require a recoverable distinction worth recalling.
public enum QuestionTeachingValue {
    public static func rejectionReason(claim: ExtractedClaim, answer: String) -> String? {
        let normalized = answer.lowercased().trimmingCharacters(in: .punctuationCharacters.union(.whitespacesAndNewlines))
        let subject = claim.subject.lowercased()
        if normalized == subject || normalized == "a " + subject || normalized == "an " + subject { return "circular definition" }
        if normalized.range(of: #"^(?:a |an |the )?(?:thing|concept|mechanism|technique|approach|process|system|method)(?: that is useful)?$"#, options: .regularExpression) != nil { return "no distinguishing information" }
        if claim.evidence.sourceText.isEmpty || claim.evidence.charLength == 0 { return "missing source binding" }
        return nil
    }
}
