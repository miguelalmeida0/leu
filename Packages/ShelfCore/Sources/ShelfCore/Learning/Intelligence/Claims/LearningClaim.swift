import Foundation

/// A normalized concept identity shared by claims, the learner model and probes.
/// "Query parameters", "query parameter" and "the Query Parameters" are one concept.
/// Acronyms keep their final letter ("HTTPS", "CORS").
public struct ConceptKey: Codable, Hashable, Comparable, Sendable, CustomStringConvertible {
    public let value: String
    public init(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        let unarticled = trimmed.replacingOccurrences(of: #"^(?i:a|an|the)\s+"#, with: "", options: .regularExpression)
        var words = unarticled.split(whereSeparator: \.isWhitespace).map(String.init)
        if let last = words.last {
            let isAcronym = last.count >= 2 && last.allSatisfy { $0.isUppercase || $0.isNumber }
            if !isAcronym { words[words.count - 1] = Self.singular(last.lowercased()) }
        }
        value = words.map { $0.lowercased() }.joined(separator: " ")
    }
    public init(raw: String) { value = raw }
    public var description: String { value }
    public var isEmpty: Bool { value.isEmpty }
    public static func < (lhs: ConceptKey, rhs: ConceptKey) -> Bool { lhs.value < rhs.value }

    static func singular(_ word: String) -> String {
        guard word.count > 3, word.last == "s" else { return word }
        if word.hasSuffix("ss") || word.hasSuffix("us") || word.hasSuffix("is") { return word }
        if word.hasSuffix("ies") { return String(word.dropLast(3)) + "y" }
        if word.hasSuffix("sses") || word.hasSuffix("xes") || word.hasSuffix("ches") || word.hasSuffix("shes") {
            return String(word.dropLast(2))
        }
        return String(word.dropLast())
    }
}

/// An exact, re-checkable citation into a page's canonical text.
public struct SourceSpan: Codable, Hashable, Sendable {
    public let documentID: UUID
    public let pageIndex: Int
    public let range: SourceTextRange
    public let text: String
    public init(documentID: UUID, pageIndex: Int, range: SourceTextRange, text: String) {
        self.documentID = documentID; self.pageIndex = pageIndex; self.range = range; self.text = text
    }
    /// Resolves `text` to its unique canonical range. Ambiguous or absent text fails closed.
    public init?(resolving text: String, in canonical: String, documentID: UUID, pageIndex: Int) {
        guard let span = CanonicalWhitespaceResolver.resolve(text, in: canonical) else { return nil }
        self.init(documentID: documentID, pageIndex: pageIndex, range: span.range, text: span.text)
    }
    public var learningSource: LearningSource {
        LearningSource(documentID: documentID, pageIndex: pageIndex, sourceText: text, range: range)
    }
    /// True when the stored text still sits at the stored range of the current canonical page.
    public func isCurrent(in analysis: DocumentAnalysis) -> Bool {
        guard analysis.documentID == documentID,
              let canonical = analysis.pages.first(where: { $0.pageIndex == pageIndex })?.canonicalText else { return false }
        let ns = canonical as NSString
        guard range.location + range.length <= ns.length else { return false }
        return ns.substring(with: NSRange(location: range.location, length: range.length)) == text
    }
}

/// How a claim's subject is known. Anything the system inferred is named and cited.
public enum ClaimGrounding: Codable, Hashable, Sendable {
    /// The sentence states its own subject.
    case literal
    /// The subject comes from the concept heading directly above the sentence:
    /// a definitional fragment ("A constraint linking ...") or a leading "It"/"They".
    case resolvedSubject(antecedent: SourceSpan, via: SubjectResolution)

    public var isInferred: Bool { if case .literal = self { return false } else { return true } }
}

public enum SubjectResolution: String, Codable, Sendable {
    case definitionFragment, leadingPronoun
}

/// Core claims come from explanatory prose. Supporting claims come from summary/interview
/// regions: they may confirm a learner's statement but never become a quiz answer.
public enum ClaimRole: String, Codable, Sendable { case core, supporting }

public enum ClaimKind: String, Codable, CaseIterable, Sendable {
    case definition, purpose, mechanism, cause, consequence, constraint, contrast, tradeoff, sequence, property
}

/// A source-grounded proposition. `evidence` is the exact canonical sentence; `statement`
/// is what the learner should understand, identical to the evidence unless the subject was
/// resolved (then the resolution is recorded in `grounding`).
public struct LearningClaim: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    /// The concept this claim teaches about (the card topic when the sentence sits in its scope).
    public let concept: ConceptKey
    public let conceptName: String
    public let kind: ClaimKind
    public let subject: String
    public let predicate: String
    public let object: String
    public let qualifier: String?
    public let negated: Bool
    public let evidence: SourceSpan
    public let grounding: ClaimGrounding
    public let role: ClaimRole
    /// The concept card whose scope contains this sentence ("Without useful indexes, large
    /// queries may scan ..." belongs to the Database index card). Nil outside a confirmed card.
    public var topic: ConceptKey?

    public init(concept: ConceptKey, conceptName: String, kind: ClaimKind, subject: String, predicate: String,
                object: String, qualifier: String?, negated: Bool, evidence: SourceSpan,
                grounding: ClaimGrounding, role: ClaimRole, topic: ConceptKey? = nil) {
        self.concept = concept; self.conceptName = conceptName; self.kind = kind; self.subject = subject
        self.predicate = predicate; self.object = object; self.qualifier = qualifier; self.negated = negated
        self.evidence = evidence; self.grounding = grounding; self.role = role; self.topic = topic
        id = "claim-" + String(StableIdentity.hash64(
            "\(evidence.documentID)|\(evidence.pageIndex)|\(evidence.range.location)|\(evidence.range.length)|\(concept.value)|\(kind.rawValue)"), radix: 16)
    }

    /// The claim as feedback cites it: only the source's own words go inside quotation marks.
    /// When the subject was inferred from a heading, the heading is named outside the quotation
    /// ("Under “Foreign key”, your source says: “It protects …”").
    public func citation(_ says: String = "says") -> String {
        let words = "“" + InterventionPlanner.quote(evidence.text) + "”"
        guard grounding.isInferred else { return "Your source \(says): \(words)" }
        return "Under “\(conceptName)”, your source \(says): \(words)"
    }

    public var statement: String {
        switch grounding {
        case .literal: return CanonicalWhitespaceResolver.normalize(evidence.text).trimmingCharacters(in: CharacterSet(charactersIn: ";: "))
        case .resolvedSubject(_, let via):
            let body = CanonicalWhitespaceResolver.normalize(evidence.text)
            switch via {
            case .definitionFragment:
                // "Normalization: Structure relational data ...", "satisfies operator checks that ...",
                // "Foreign key is a constraint ..." — each reads correctly for its fragment shape.
                let words = body.split(separator: " ").map { String($0).lowercased() }
                let first = words.first ?? "", second = words.count > 1 ? words[1] : ""
                let form = ClauseLexicon.forms[first]?.form
                let gerund = second.hasSuffix("ing") && second.count > 5
                if form == .base || (first.hasSuffix("ly") && (ClauseLexicon.forms[second]?.form == .base || gerund)) {
                    return conceptName + ": " + body
                }
                if form == .thirdPerson { return conceptName + " " + ConceptText.lowercasingLead(body) }
                let verb = ConceptText.isPlural(conceptName) ? "are" : "is"
                return conceptName + " " + verb + " " + ConceptText.lowercasingLead(body)
            case .leadingPronoun:
                let remainder = body.replacingOccurrences(of: #"^(?:It|They)\s+"#, with: "", options: .regularExpression)
                let subject = conceptName.first?.isUppercase == true ? conceptName : ConceptText.capitalized(conceptName)
                return subject + " " + remainder
            }
        }
    }
    /// The part a learner must supply when the subject is given.
    public var content: String { [predicate, object, qualifier].compactMap { $0 }.joined(separator: " ") }
    /// True when the claim teaches about `key`, directly or as part of its card.
    public func teaches(_ key: ConceptKey) -> Bool { concept == key || topic == key }
}

enum ConceptText {
    static func capitalized(_ text: String) -> String { text.prefix(1).uppercased() + text.dropFirst() }

    static func isPlural(_ name: String) -> Bool {
        guard let last = name.split(whereSeparator: \.isWhitespace).last.map(String.init) else { return false }
        if last.count >= 2 && last.allSatisfy({ $0.isUppercase || $0.isNumber }) { return false }
        return ConceptKey.singular(last.lowercased()) != last.lowercased()
    }
    /// "A constraint ..." -> "a constraint ..."; keeps acronyms and identifiers ("HTTP carried ...").
    static func lowercasingLead(_ text: String) -> String {
        guard let first = text.split(separator: " ").first else { return text }
        let word = String(first)
        guard word.first?.isUppercase == true, word != "I",
              word.dropFirst().allSatisfy({ $0.isLowercase || !$0.isLetter }) else { return text }
        return word.lowercased() + text.dropFirst(word.count)
    }
}
