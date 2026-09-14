import Foundation

/// One atomic assertion made by the learner.
///
/// Deliberately *not* a `KnowledgeAtom`: learner claims have no provenance and
/// must never be able to enter the knowledge graph. The type system enforces
/// the separation.
public struct LearnerProposition: Codable, Equatable, Sendable, Identifiable {
    public var id: StableID
    public var text: String
    public var subject: String
    public var relation: String
    public var object: String
    public var isNegated: Bool
    public var quantifier: Quantifier
    public var qualifiers: [Qualifier]
    public var conditions: [ClaimCondition]
    public var numbers: [NumericFact]
    public var identifiers: [SourceIdentifier]
    /// True when no relation cue was found and the proposition is a bare phrase.
    public var isUnparsed: Bool

    public enum Quantifier: String, Codable, CaseIterable, Sendable {
        /// "every failed request", "always", "all"
        case universal
        /// "some", "sometimes", "often"
        case existential
        /// no explicit quantifier
        case unmarked
    }

    public init(text: String,
                subject: String,
                relation: String,
                object: String,
                isNegated: Bool,
                quantifier: Quantifier,
                qualifiers: [Qualifier],
                conditions: [ClaimCondition],
                numbers: [NumericFact],
                identifiers: [SourceIdentifier],
                isUnparsed: Bool) {
        self.id = StableID(namespace: "prop", components: [text.lowercased()])
        self.text = text
        self.subject = subject
        self.relation = relation
        self.object = object
        self.isNegated = isNegated
        self.quantifier = quantifier
        self.qualifiers = qualifiers
        self.conditions = conditions
        self.numbers = numbers
        self.identifiers = identifiers
        self.isUnparsed = isUnparsed
    }
}

/// Breaks a learner explanation into propositions using the same deterministic
/// machinery as source extraction, so the two sides are comparable.
public struct PropositionSplitter: Sendable {
    public init() {}

    static let universalMarkers: Set<String> = ["every", "all", "always", "any", "each", "never", "must", "everything"]
    static let existentialMarkers: Set<String> = ["some", "sometimes", "often", "usually", "may", "might", "can", "occasionally"]

    public func split(_ text: String) -> [LearnerProposition] {
        var propositions: [LearnerProposition] = []
        for sentence in TextScanning.sentences(in: text) {
            for clause in clauses(in: sentence) {
                guard !TextScanning.contentTokens(clause).isEmpty else { continue }
                propositions.append(parse(clause))
            }
        }
        return propositions
    }

    /// Splits coordinated clauses ("X, and Y", "X but Y") while leaving noun
    /// coordination alone ("keys and indexes").
    func clauses(in sentence: String) -> [String] {
        var parts: [String] = [sentence]
        for connector in [", and ", ", but ", "; ", ", which means ", ", so "] {
            var next: [String] = []
            for part in parts {
                let pieces = part.components(separatedBy: connector)
                next.append(contentsOf: pieces)
            }
            parts = next
        }
        return parts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    public func parse(_ clause: String) -> LearnerProposition {
        let decomposition = Decomposition(sentence: clause)
        let tokens = Set(TextScanning.normalizedTokens(clause))
        let quantifier: LearnerProposition.Quantifier
        if !tokens.isDisjoint(with: PropositionSplitter.universalMarkers) {
            quantifier = .universal
        } else if !tokens.isDisjoint(with: PropositionSplitter.existentialMarkers) {
            quantifier = .existential
        } else {
            quantifier = .unmarked
        }

        guard let cue = RelationLexicon.firstCue(in: decomposition.mainClause) else {
            return LearnerProposition(text: clause,
                                      subject: Cleaner.clean(decomposition.mainClause),
                                      relation: "",
                                      object: "",
                                      isNegated: Cleaner.isNegated(clause),
                                      quantifier: quantifier,
                                      qualifiers: decomposition.qualifiers + Cleaner.modalityQualifiers(in: clause),
                                      conditions: decomposition.conditions,
                                      numbers: TextScanning.numbers(in: clause),
                                      identifiers: TextScanning.identifiers(in: clause),
                                      isUnparsed: true)
        }
        let before = String(decomposition.mainClause[decomposition.mainClause.startIndex..<cue.range.lowerBound])
        let after = String(decomposition.mainClause[cue.range.upperBound...])
        var subject = Cleaner.clean(before)
        var object = Cleaner.clean(after)
        if cue.cue.inverts { swap(&subject, &object) }

        return LearnerProposition(text: clause,
                                  subject: subject,
                                  relation: cue.cue.kind.rawValue,
                                  object: object,
                                  isNegated: Cleaner.isNegated(decomposition.mainClause),
                                  quantifier: quantifier,
                                  qualifiers: decomposition.qualifiers + Cleaner.modalityQualifiers(in: clause),
                                  conditions: decomposition.conditions,
                                  numbers: TextScanning.numbers(in: clause),
                                  identifiers: TextScanning.identifiers(in: clause),
                                  isUnparsed: false)
    }
}
