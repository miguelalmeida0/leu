import Foundation

/// Whether a clause that says a claim's words in other words expresses that claim. How similar
/// the words are never decides it alone: every V35 safety check vetoes it, and each part of the
/// claim that carries its meaning (subject, relation, polarity, scope, condition) must be there,
/// in the same words or in others. Every reason a clause is refused is listed, in the order checked.
struct SemanticGate: Sendable {
    enum Block: String, Sendable {
        // Vetoes: evidence that the clause says something else. Similarity never overrides them.
        case contradiction, reversal, omittedNegation, opposite, polarity, universal, otherConcept
        // Parts of the claim the clause does not express, or credit its own words already settled.
        case subject, relation, thin, ownWords
        // Another concept's wording explains the clause clearly better, or another claim fits it
        // about as well (`SemanticReader`).
        case rival, ambiguous
    }

    let coverage: ClaimCoverage?
    let blocks: [Block]
    /// The clause restates the claim's content (its words, or others that stand for them) with the
    /// sense reversed: an opposite word, or the opposite polarity on the proposition it carries.
    let reversesSense: Bool

    init(_ alignment: Alignment, evidence: SemanticEvidence, space: SemanticSpace, context: AlignmentContext) {
        let clause = alignment.clause, rubric = alignment.rubric
        var blocks: [Block] = []
        if alignment.contradicts || alignment.propositionConflict { blocks.append(.contradiction) }
        if alignment.reversed { blocks.append(.reversal) }
        if alignment.unexpressedNegation { blocks.append(.omittedNegation) }
        if !evidence.opposites.isEmpty { blocks.append(.opposite) }
        let polarity = Self.polarity(clause, rubric, space: space)
        if polarity != .agrees { blocks.append(.polarity) }
        if Self.overgeneralizes(clause, rubric, space: space) { blocks.append(.universal) }
        if Self.namesOtherConcept(clause, rubric, context: context) { blocks.append(.otherConcept) }
        if !Self.subjectExpressed(alignment, space: space) { blocks.append(.subject) }
        let relation = Self.relationExpressed(alignment, evidence: evidence, space: space)
        let condition = Self.conditionExpressed(alignment, space: space)
        // Credit in other words rests on the other words: a level the clause's own words already
        // reach was the lexical reader's to give, under its own checks.
        let covered = evidence.recall >= SemanticThresholds.expressed && evidence.lexicalRecall < SemanticThresholds.expressed && relation && condition
        let touched = evidence.recall >= SemanticThresholds.touched && evidence.lexicalRecall < SemanticThresholds.touched &&
            (relation || evidence.substitutions.count >= 2)
        if !covered && !touched {
            blocks.append(evidence.recall < SemanticThresholds.touched ? .thin : !relation ? .relation : .ownWords)
        }
        self.blocks = blocks
        coverage = blocks.isEmpty ? (covered ? .covered : .partial) : nil
        // A reversed sense is only read where the clause is about the claim and says enough of it.
        // An opposite word under the opposite polarity agrees ("not slow" for "fast"): no reversal,
        // though still no credit.
        reversesSense = (!evidence.opposites.isEmpty) != (polarity == .reversed) && evidence.recall >= SemanticThresholds.touched &&
            !blocks.contains(.subject) && !blocks.contains(.otherConcept) && !alignment.contradicts
    }

    enum Polarity: Sendable { case agrees, reversed, unclear }

    /// Each claim proposition the clause says (in any words) keeps its polarity: "nobody can read
    /// them" reverses "anyone can read the payload". A reversal is only read where both polarities
    /// are plain: one cue at most on each side, no negated universal ("not every event"), and no
    /// restrictive the negation can restate ("alone ... does not" for "only part"). Otherwise, and
    /// when no proposition is carried whole, a polarity difference is unclear: no credit, no doubt.
    static func polarity(_ clause: LearnerClause, _ rubric: ClaimRubric, space: SemanticSpace) -> Polarity {
        var carried = false, unclear = false
        for part in rubric.propositions {
            let readings = clause.propositions.map { learner -> (Proposition, Double) in
                let view = LexicalProfileView(terms: learner.terms)
                return (learner, SemanticMatcher.evidence(claim: part.terms, learner: learner.terms, lexical: view.match, space: space).recall)
            }
            guard let (learner, overlap) = readings.max(by: { $0.1 < $1.1 }), overlap >= SemanticThresholds.touched else { continue }
            guard learner.negative != part.negative else { carried = true; continue }
            let (negated, other) = part.negative ? (part, learner) : (learner, part)
            // Opposite polarity only disagrees about what the negation governs: a proposition that
            // leaves that out ("a longer-lasting credential" beside "without signing in again") is
            // neither agreement nor reversal.
            guard let wording = Self.expression(of: negated.scope, in: other, space: space) else { continue }
            carried = true
            // A reversal is read only on the claim's own words: a stand-in can be the very opposite
            // the negation undoes ("no more than once" read through "repeatedly" for "at most once").
            let plain = learner.cues <= 1 && part.cues <= 1 && !learner.restrictive && !part.restrictive &&
                !(negated.universalInScope && !other.universal) && wording == .ownWords
            if plain { return .reversed }
            unclear = true
        }
        if unclear { return .unclear }
        if carried { return .agrees }
        return rubric.propositions.contains(where: \.negative) == clause.propositions.contains(where: \.negative) ? .agrees : .unclear
    }

    enum Wording: Sendable { case ownWords, otherWords }

    /// Whether a proposition says at least half of what a negation governs, and how: in the words
    /// themselves (or their lexical paraphrases), or only with words standing in for them. Nil when
    /// it does not say it (an opposite never counts).
    static func expression(of scope: [LexicalTerm], in proposition: Proposition, space: SemanticSpace) -> Wording? {
        guard !scope.isEmpty else { return .ownWords }
        let view = LexicalProfileView(terms: proposition.terms)
        let evidence = SemanticMatcher.evidence(claim: scope, learner: proposition.terms, lexical: view.match, space: space)
        guard evidence.recall >= 0.5 else { return nil }
        return evidence.lexicalRecall >= 0.5 ? .ownWords : .otherWords
    }

    /// A universal ("always", "every", "never") the clause does not negate, where the source is
    /// hedged, over what the source qualifies — in its words or in others. Stricter than the lexical
    /// check: an unqualified hedge ("can") makes any universal an overgeneralization here.
    static func overgeneralizes(_ clause: LearnerClause, _ rubric: ClaimRubric, space: SemanticSpace) -> Bool {
        guard rubric.hedged, rubric.profile.universals.isEmpty else { return false }
        let words = clause.assertedProfile.words
        return words.indices.contains { index in
            guard Lexicon.universals.contains(words[index]), !["all", "any"].contains(words[index]),
                  !words[max(0, index - 2)..<index].contains(where: { Lexicon.negations.contains($0) }) else { return false }
            guard !rubric.qualified.isEmpty else { return true }
            let quantified = words[(index + 1)..<min(words.count, index + 5)].filter { !Lexicon.stopwords.contains($0) }
                .map { LexicalTerm(surface: $0, stem: Lexicon.stem($0)) }
            let view = LexicalProfileView(terms: quantified)
            return rubric.qualified.contains { qualified in
                view.match(qualified) >= 0.85 || quantified.contains { term in
                    (space.similarity(qualified.surface, term.surface) ?? 0) >= SemanticThresholds.word &&
                        !SemanticAntonyms.opposed(qualified.stem, term.stem)
                }
            }
        }
    }

    /// The clause's subject names another concept that the claim is not about.
    static func namesOtherConcept(_ clause: LearnerClause, _ rubric: ClaimRubric, context: AlignmentContext) -> Bool {
        guard let subject = clause.subject else { return false }
        let text = subject.words.joined(separator: " ")
        guard let other = context.otherConcept(in: text) else { return false }
        if let target = context.target.concept, context.mentions(text, target) { return false }
        return !context.mentions(rubric.claim.subject, other)
    }

    /// The lexical subject check, or the claim's subject said in other words: in the clause's
    /// subject, or (discounted as the lexical reader does) elsewhere in the clause.
    static func subjectExpressed(_ alignment: Alignment, space: SemanticSpace) -> Bool {
        if alignment.subjectMatch >= 0.5 || (alignment.subjectMatch >= 0.34 && alignment.precision >= 0.5) { return true }
        guard let subject = alignment.clause.subject, !alignment.rubric.subject.isEmpty else { return false }
        let asserted = alignment.clause.assertedProfile
        let direct = SemanticMatcher.evidence(claim: alignment.rubric.subject, learner: subject.terms, lexical: subject.match, space: space).recall
        let elsewhere = SemanticMatcher.evidence(claim: alignment.rubric.subject, learner: asserted.terms, lexical: asserted.match, space: space).recall * 0.7
        return max(direct, elsewhere) >= SemanticThresholds.subject
    }

    /// The claim's verb, in its words or in a close one that is not its opposite. A claim with no
    /// verb of its own ("is", "can"), or a generic one ("makes", "uses"), constrains nothing here.
    static func relationExpressed(_ alignment: Alignment, evidence: SemanticEvidence, space: SemanticSpace) -> Bool {
        guard let verb = alignment.rubric.verbStem, alignment.relationMatch < 1 else { return true }
        if Lexicon.stopwords.contains(verb) || Lexicon.generic.contains(verb) { return true }
        let profile = alignment.clause.profile
        if profile.match(LexicalTerm(surface: verb, stem: verb)) >= 0.6 { return true }
        if evidence.substitutions.contains(where: { Lexicon.stem($0.claim) == verb && $0.similarity >= SemanticThresholds.relation }) { return true }
        // The verb as the claim writes it: a stem ("cach") is not a word the space knows.
        let surface = alignment.rubric.complement.first { $0.stem == verb }?.surface ?? verb
        guard let vector = space.vector(surface) else { return false }
        return profile.terms.contains { term in
            term.stem != verb && space.vector(term.surface).map { SemanticSpace.similarity(vector, $0) >= SemanticThresholds.relation } == true &&
                !SemanticAntonyms.opposed(verb, term.stem)
        }
    }

    /// The claim's limiting condition ("when items move"), in its words or in others.
    static func conditionExpressed(_ alignment: Alignment, space: SemanticSpace) -> Bool {
        let rubric = alignment.rubric, profile = alignment.clause.profile
        guard !rubric.condition.isEmpty, alignment.conditionCoverage < 0.5 else { return true }
        return SemanticMatcher.evidence(claim: rubric.condition, learner: profile.terms, lexical: profile.match, space: space).recall >= 0.5
    }
}
