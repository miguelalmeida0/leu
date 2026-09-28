import Foundation

/// Concept-name awareness for one diagnosis, plus union profiles per concept for judging
/// which concept a statement is really about.
struct AlignmentContext {
    let target: DiagnosisTarget
    private let nameStems: [ConceptKey: [[String]]]
    /// All grounded wording per concept (claims whose subject is that concept).
    let conceptProfiles: [ConceptKey: LexicalProfile]

    init(target: DiagnosisTarget) {
        self.target = target
        nameStems = target.names.mapValues { names in names.map { ConceptNameMatcher.stems($0) }.filter { !$0.isEmpty } }
        var grouped: [ConceptKey: [String]] = [:]
        let stems = nameStems
        for claim in target.allClaims {
            var text = claim.statement
            // "Path parameters identify ..., while query parameters modify ...": the second half
            // is about the other concept.
            if let range = text.range(of: #",?\s+(?:while|whereas)\s+"#, options: .regularExpression) {
                let tail = String(text[range.upperBound...])
                let tailStems = ConceptNameMatcher.stems(tail)
                if let other = stems.keys.sorted().first(where: { key in (stems[key] ?? []).contains { ConceptNameMatcher.contains(tailStems, $0) } }) {
                    grouped[other, default: []].append(tail)
                    text = String(text[..<range.lowerBound])
                }
            }
            grouped[Self.owner(of: claim, names: target.names), default: []].append(text)
        }
        // Names are identity, not content: "foreign-key references" in a primary-key card must not
        // make "links a value to a key in another table" look like primary-key wording.
        let nameWords = Set(stems.values.flatMap { $0.flatMap { $0 } })
        conceptProfiles = grouped.mapValues { texts in
            let profile = LexicalProfile(texts.joined(separator: " . "))
            return LexicalProfile(profile.words.filter { !nameWords.contains(Lexicon.stem($0)) }.joined(separator: " "))
        }
        self.nameWords = nameWords
    }
    private let nameWords: Set<String>

    /// The concept a claim is about: its subject when that is a known concept, else its card.
    static func owner(of claim: LearningClaim, names: [ConceptKey: [String]]) -> ConceptKey {
        names[claim.concept] != nil ? claim.concept : (claim.topic ?? claim.concept)
    }

    func mentions(_ text: String, _ concept: ConceptKey) -> Bool {
        let stems = ConceptNameMatcher.stems(text)
        return (nameStems[concept] ?? []).contains { ConceptNameMatcher.contains(stems, $0) || headMatch(stems, $0) }
    }

    /// "An index" names "Database index" when no other known concept shares that head noun.
    private func headMatch(_ stems: [String], _ name: [String]) -> Bool {
        guard name.count > 1, let head = name.last, stems.contains(head) else { return false }
        return !nameStems.contains { key, variants in key != target.concept && variants.contains { $0.last == head && ConceptNameMatcher.contains(stems, $0) } }
    }

    /// Another known concept named by the text, if any (never the target).
    func otherConcept(in text: String) -> ConceptKey? {
        let stems = ConceptNameMatcher.stems(text)
        return nameStems.keys.sorted().first { key in
            key != target.concept && (nameStems[key] ?? []).contains { ConceptNameMatcher.contains(stems, $0) }
        }
    }

    /// The clause is about the target concept: it names it, or has no explicit subject.
    func refersToTarget(_ clause: LearnerClause) -> Bool {
        guard let concept = target.concept else { return false }
        guard let subject = clause.subject else { return true }
        let text = subject.words.joined(separator: " ")
        return mentions(text, concept) || otherConcept(in: text) == nil
    }

    /// Share of the clause's own content found in one concept's grounded wording.
    func precision(_ clause: LearnerClause, against concept: ConceptKey) -> Double {
        evidence(clause, against: concept).precision
    }

    /// Share of the clause's content found in a concept's grounded wording, and how much content that is.
    func evidence(_ clause: LearnerClause, against concept: ConceptKey) -> (precision: Double, matched: Double) {
        guard let profile = conceptProfiles[concept] else { return (0, 0) }
        let terms = clause.complement.filter { !nameWords.contains($0.stem) }
        guard !terms.isEmpty else { return (0, 0) }
        let total = terms.reduce(0) { $0 + $1.weight }
        let matched = terms.reduce(0) { $0 + $1.weight * profile.match($1) }
        return (matched / total, matched)
    }

    /// "Keys are keys ...", "Caching means caching ...", "A closure is when a function is closed".
    func circularConcept(_ clause: LearnerClause) -> ConceptKey? {
        guard clause.definitional, let subject = clause.subject, let head = clause.complementHead else { return nil }
        // Only the name's head word makes an explanation circular: "cache invalidation is when
        // the cache stops" explains with a different concept, not with itself.
        let roots = subject.terms.last.map { [$0.stem] } ?? []
        let isWhen = clause.text.range(of: #"(?i)\b(?:is|are|means)\s+(?:when|where)\b"#, options: .regularExpression) != nil
        let related: (String) -> Bool = { stem in roots.contains { Self.sameRoot($0, stem) } }
        guard related(head) || (isWhen && clause.complement.contains { related($0.stem) }) else { return nil }
        return target.concept ?? ConceptKey(subject.words.joined(separator: " "))
    }

    static func sameRoot(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        let shared = zip(a, b).prefix { $0 == $1 }.count
        return shared >= 4 && Double(shared) >= 0.8 * Double(min(a.count, b.count))
    }
}
