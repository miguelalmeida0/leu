import Foundation

/// What an explanation is compared against. Built only from grounded claims.
public struct DiagnosisTarget: Sendable {
    /// Set when the learner is explaining one concept (recall, Teach It Back on a card).
    public let concept: ConceptKey?
    public let conceptName: String?
    /// Claims the learner is expected to express.
    public let rubric: [LearningClaim]
    /// Summary/interview claims: may confirm or contradict, never required.
    public let supporting: [LearningClaim]
    /// Other concepts' claims, used to recognise confusion between concepts.
    public let competitors: [LearningClaim]
    /// Names (and aliases) of every concept involved, for recognising mentions.
    public let names: [ConceptKey: [String]]
    /// The definition of the concept worth telling this one apart from: one the source contrasts
    /// it with, else its closest sibling of the same kind. Never merely a neighbour or prerequisite.
    public let contrastDefinition: LearningClaim?

    public init(concept: ConceptKey?, conceptName: String?, rubric: [LearningClaim], supporting: [LearningClaim] = [],
                competitors: [LearningClaim] = [], names: [ConceptKey: [String]] = [:], contrastDefinition: LearningClaim? = nil) {
        self.concept = concept; self.conceptName = conceptName; self.rubric = rubric
        self.supporting = supporting; self.competitors = competitors
        self.contrastDefinition = contrastDefinition.flatMap { partner in competitors.contains { $0.id == partner.id } ? partner : nil }
        // Only concept cards are named concepts. A sentence subject inside a card ("Indexes trade
        // ...") is a way of naming that card, not a separate concept.
        var names = names
        if let concept, let conceptName, names[concept] == nil { names[concept] = [conceptName] }
        self.names = names
    }

    public var isEmpty: Bool { rubric.isEmpty }
    public var allClaims: [LearningClaim] { rubric + supporting + competitors }

    /// Explaining one concept: its card's claims, with sibling, contrasted and prerequisite
    /// concepts as competitors.
    public static func concept(_ key: ConceptKey, in base: ConceptKnowledgeBase) -> DiagnosisTarget? {
        let rubric = base.claims(teaching: key, roles: [.core])
        guard !rubric.isEmpty else { return nil }
        let entry = base.concept(key)
        let neighbours = Array(Set(base.siblings(of: key, limit: 8).map(\.key) + base.contrasts(of: key) + base.prerequisites(of: key)))
            .filter { $0 != key }.sorted()
        let competitors = neighbours.flatMap { base.claims(teaching: $0, roles: [.core, .supporting]) }
        var names: [ConceptKey: [String]] = [key: entry?.names ?? [rubric[0].conceptName]]
        for other in neighbours { names[other] = base.concept(other)?.names ?? [other.value] }
        let partner = base.contrasts(of: key).first { base.definition(of: $0) != nil }
            ?? base.definition(of: key).flatMap { ProbeGenerator.closestSibling(of: key, definition: $0, documentID: $0.evidence.documentID, in: base) }
        return DiagnosisTarget(concept: key, conceptName: entry?.name ?? rubric[0].conceptName, rubric: rubric,
                               supporting: base.claims(teaching: key, roles: [.supporting]),
                               competitors: competitors, names: names, contrastDefinition: partner.flatMap(base.definition(of:)))
    }

    /// Explaining a selected passage: the claims inside it. When the passage is a concept card,
    /// the card's own concept becomes the target concept.
    public static func passage(_ source: LearningSource, in base: ConceptKnowledgeBase) -> DiagnosisTarget? {
        let inside = base.claims(within: source)
        let rubric = inside.filter { $0.role == .core }
        guard !rubric.isEmpty else { return nil }
        let topics = Set(rubric.compactMap(\.topic))
        if topics.count == 1, let topic = topics.first, var card = DiagnosisTarget.concept(topic, in: base) {
            let ids = Set(inside.map(\.id))
            card = DiagnosisTarget(concept: card.concept, conceptName: card.conceptName,
                                   rubric: card.rubric.filter { ids.contains($0.id) },
                                   supporting: card.supporting.filter { ids.contains($0.id) },
                                   competitors: card.competitors, names: card.names, contrastDefinition: card.contrastDefinition)
            if !card.rubric.isEmpty { return card }
        }
        let ids = Set(inside.map(\.id))
        let page = base.claims(onPage: source.documentID, pageIndex: source.pageIndex).filter { !ids.contains($0.id) }
        return DiagnosisTarget(concept: nil, conceptName: nil, rubric: rubric,
                               supporting: inside.filter { $0.role == .supporting }, competitors: page)
    }
}

/// Pre-analysed claim features for alignment.
struct ClaimRubric {
    let claim: LearningClaim
    let weight: Double
    /// Subject terms with the head noun weighted double; one entry per coordinated conjunct.
    let subjectConjuncts: [[LexicalTerm]]
    let subject: [LexicalTerm]
    let complement: [LexicalTerm]
    /// Only limiting conditions ("when items move"); context phrases ("With an arrow function") are not required.
    let condition: [LexicalTerm]
    let profile: LexicalProfile
    let complementProfile: LexicalProfile
    let verbStem: String?
    let copular: Bool
    let hedged: Bool
    let objectHead: String?
    let normalized: String
    let propositions: [Proposition]
    /// The grammatical subject is the claim's concept (not another noun inside its card).
    let subjectIsConcept: Bool
    /// What the claim qualifies: its limiting condition and the words after its first hedge
    /// ("usually *with a relatively short lifetime*").
    let qualified: [LexicalTerm]

    init(_ claim: LearningClaim) {
        self.claim = claim
        propositions = Proposition.split(claim.statement)
        subjectIsConcept = claim.grounding.isInferred || ConceptKey(claim.subject) == claim.concept && claim.topic.map { $0 == claim.concept } ?? true
        weight = claim.kind == .definition ? 1.5 : 1
        let statement = LexicalProfile(claim.statement)
        profile = statement
        let subjectText = claim.grounding.isInferred ? claim.conceptName : claim.subject
        subject = LexicalProfile(subjectText).terms
        subjectConjuncts = subjectText.components(separatedBy: #" and "#).map { LexicalProfile($0).terms }.filter { !$0.isEmpty }
        let subjectStems = Set(subject.map(\.stem))
        let parsed = ClauseParser.parse(claim.statement)
        let trailing = parsed?.trailingQualifier ?? (claim.qualifier.flatMap { $0.contains("; ") ? nil : $0 })
        let conditional = trailing.flatMap { text -> String? in
            text.range(of: #"^(?i:when|if|unless|until|only if|as long as|provided|once)\b"#, options: .regularExpression) != nil ? text : nil
        }
        condition = LexicalProfile(conditional ?? "").terms.filter { !subjectStems.contains($0.stem) }
        let conditionStems = Set(condition.map(\.stem))
        let context = parsed?.leadingQualifier.map { Set(LexicalProfile($0).terms.map(\.stem)) } ?? []
        let tail = trailing.flatMap { conditional == nil ? $0 : nil } ?? ""
        let body = (parsed.map { $0.predicate + " " + $0.object } ?? (claim.predicate + " " + claim.object)) + " " + tail
        complementProfile = LexicalProfile(body)
        var seen = Set<String>()
        complement = complementProfile.terms.filter {
            !subjectStems.contains($0.stem) && !conditionStems.contains($0.stem) && !context.contains($0.stem) && seen.insert($0.stem).inserted
        }
        let lemma = parsed?.verbLemma
        copular = lemma == "be" || ["is", "are"].contains(claim.predicate.lowercased())
        verbStem = lemma.flatMap { ["be", "can", "may", "must", "should", "will", "do", "have"].contains($0) ? nil : Lexicon.stem($0) }
        hedged = !profile.hedges.isEmpty || !condition.isEmpty
        let hedge = statement.words.firstIndex { Lexicon.hedges.contains($0) }
        let afterHedge = hedge.map { cut in zip(statement.terms, statement.termPositions).filter { $0.1 > cut }.map(\.0) } ?? []
        qualified = condition + afterHedge
        objectHead = LexicalProfile(parsed?.object ?? claim.object).terms.first { $0.weight == 1 }?.stem
        normalized = DiagnosisText.normalized(claim.statement)
    }

    /// Weighted overlap between a learner subject and this claim's subject (best conjunct).
    func subjectOverlap(_ learner: LexicalProfile) -> Double {
        subjectConjuncts.map { terms -> Double in
            var earned = 0.0, total = 0.0
            for (index, term) in terms.enumerated() {
                let isHead = index == terms.count - 1
                let weight = isHead ? 2 : (term.surface.hasSuffix("ly") || term.surface.hasSuffix("ed") ? 0.5 : 1)
                total += weight; earned += weight * learner.match(term)
            }
            return total > 0 ? earned / total : 0
        }.max() ?? 0
    }
}

/// One clause of the learner's explanation.
struct LearnerClause {
    let text: String
    let profile: LexicalProfile
    let subject: LexicalProfile?
    let complement: [LexicalTerm]
    let complementProfile: LexicalProfile
    let negated: Bool
    let definitional: Bool
    let complementHead: String?
    let normalized: String
    let propositions: [Proposition]
    /// What the clause asserts, without the alternative it rejects ("unlike a hash, …").
    let assertedProfile: LexicalProfile

    init(_ text: String) {
        self.text = text
        let asserted = DiagnosisText.asserted(text)
        propositions = Proposition.split(asserted)
        profile = LexicalProfile(text)
        assertedProfile = asserted == text ? profile : LexicalProfile(asserted)
        normalized = DiagnosisText.normalized(text)
        if let parsed = ClauseParser.parse(text) {
            let subjectText = parsed.subject.lowercased()
            let bare = DiagnosisText.addressedSubject.stringByReplacingMatches(in: subjectText, range: NSRange(subjectText.startIndex..., in: subjectText), withTemplate: "$1")
            let pronoun = ["it", "they", "this", "these", "which", "that", "you", "we", "one"].contains(bare)
            subject = pronoun ? nil : LexicalProfile(parsed.subject)
            let subjectStems = Set(subject?.terms.map(\.stem) ?? [])
            let restText = parsed.predicate + " " + parsed.object + " " + (parsed.qualifier ?? "")
            complementProfile = LexicalProfile(restText)
            complement = complementProfile.terms.filter { !subjectStems.contains($0.stem) }
            negated = parsed.negated || LexicalProfile(parsed.predicate).negationCount % 2 == 1
            definitional = ["be", "mean", "refer"].contains(parsed.verbLemma)
            complementHead = LexicalProfile(parsed.object).terms.first { $0.weight == 1 }?.stem ?? LexicalProfile(parsed.object).terms.first?.stem
        } else {
            subject = nil
            complement = profile.terms
            complementProfile = profile
            negated = profile.isNegative
            definitional = false
            complementHead = nil
        }
    }
}

enum DiagnosisText {
    static let addressedSubject = try! NSRegularExpression(pattern: #"^(?:with|without|in|for) .+? (you|we)$"#)
    static let rejectedAlternative = try! NSRegularExpression(pattern: #"(?i)\b(?:instead of|rather than|unlike)\b[^,;]*"#)
    private static let nonWord = try! NSRegularExpression(pattern: #"[^a-z0-9']+"#)

    /// The text without the alternatives it rejects: "unlike a hash", "instead of a listener on
    /// every child" name what the learner is contrasting, not what they assert.
    static func asserted(_ text: String) -> String {
        rejectedAlternative.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
    }

    /// Lowercased words only, for comparing wording sequences.
    static func normalized(_ text: String) -> String {
        let lowered = text.lowercased().replacingOccurrences(of: "’", with: "'")
        return nonWord.stringByReplacingMatches(in: lowered, range: NSRange(lowered.startIndex..., in: lowered), withTemplate: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    /// Learner text split into comparable clauses: sentences, then ";", ", but", ", so", ", which",
    /// ", while", and ", and" when a new clause (with its own verb) follows.
    static func clauses(_ text: String) -> [String] {
        let sentences = text.components(separatedBy: .newlines).flatMap(ClaimSentenceSplitter.sentences)
        var result: [String] = []
        for sentence in sentences {
            var parts = [sentence]
            for marker in [";", ", but ", " but ", ", so ", ", which ", ", while ", ", whereas ", " whereas ", ", otherwise "] {
                parts = parts.flatMap { $0.components(separatedBy: marker) }
            }
            parts = parts.flatMap { part -> [String] in
                let pieces = part.components(separatedBy: ", and ")
                guard pieces.count > 1 else { return [part] }
                var merged: [String] = [pieces[0]]
                for piece in pieces.dropFirst() {
                    let tokens = piece.split(separator: " ").map(String.init)
                    if ClauseParser.mainVerbIndex(tokens) != nil { merged.append(piece) } else { merged[merged.count - 1] += ", and " + piece }
                }
                return merged
            }
            for part in parts {
                let clean = part.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ",;:")))
                if clean.split(separator: " ").count >= 2 { result.append(clean) }
            }
        }
        return result
    }
}
