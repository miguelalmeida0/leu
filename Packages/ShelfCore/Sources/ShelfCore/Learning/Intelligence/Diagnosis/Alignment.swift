import Foundation

/// Evidence that one learner clause expresses (or opposes) one claim.
struct Alignment {
    let clause: LearnerClause
    let rubric: ClaimRubric
    let recall: Double
    let precision: Double
    let subjectMatch: Double
    let relationMatch: Double
    let conditionCoverage: Double
    let flips: Int
    let polarityMismatch: Bool
    let propositionConflict: Bool
    /// How much of the conflicting claim proposition the learner restated.
    let conflictOverlap: Double
    /// A learner proposition that restates one claim proposition nearly whole ("both are stuck").
    let propositionSupport: Double
    let verbatim: Bool
    let reversed: Bool
    let genusMatch: Bool
    let matched: [String]
    let missing: [String]

    /// `subjectPenalty` scales subject evidence down when another claim's subject fits better
    /// ("a block body" is not "an expression body").
    init(clause: LearnerClause, rubric: ClaimRubric, context: AlignmentContext, subjectPenalty: Double = 1) {
        self.clause = clause; self.rubric = rubric
        var opposedClaim = Set<String>(), opposedLearner = Set<String>()
        for (dimension, _) in rubric.complementProfile.poles {
            guard let claimPole = rubric.complementProfile.unambiguousPole(dimension),
                  let learnerPole = clause.complementProfile.unambiguousPole(dimension), claimPole != learnerPole else { continue }
            for term in rubric.complement where (Lexicon.dimensionIndex[term.stem] ?? []).contains(where: { $0.0 == dimension }) { opposedClaim.insert(term.stem) }
            for term in clause.complement where (Lexicon.dimensionIndex[term.stem] ?? []).contains(where: { $0.0 == dimension }) { opposedLearner.insert(term.stem) }
        }
        // Polarity is compared proposition by proposition ("is not A and does not stop B" holds
        // two). Each claim proposition is settled by the learner proposition that restates it best.
        var conflict: PropositionComparison?, agreement: PropositionComparison?
        for claimPart in rubric.propositions {
            let comparisons = clause.propositions.compactMap { PropositionComparison(claim: claimPart, learner: $0) }
            let against = comparisons.filter(\.contradicts).max { $0.overlap < $1.overlap }
            let with = comparisons.filter { !$0.contradicts }.max { $0.overlap < $1.overlap }
            if let against, against.overlap >= (with?.overlap ?? 0) {
                if against.overlap > (conflict?.overlap ?? -1) { conflict = against }
            } else if let with, with.overlap > (agreement?.overlap ?? -1) { agreement = with }
        }
        propositionConflict = conflict != nil
        conflictOverlap = conflict?.overlap ?? 0
        propositionSupport = agreement.map { min($0.overlap, $0.learnerShare) } ?? 0
        let decisive = conflict ?? agreement
        flips = decisive?.flips ?? 0
        polarityMismatch = decisive?.polarityMismatch ?? false
        // Opposite wording under a flipped polarity is agreement: "should not inherit another's
        // state" and "keeps its own state" say the same thing.
        let agreesByNegation = agreement?.agreesByNegation ?? false
        let countOpposed = agreesByNegation || propositionConflict
        // "does not fire" expresses "avoids firing": a negative verb is said by a negation.
        let negationExpressed = !propositionConflict && (clause.profile.negationCount > 0 || clause.profile.words.contains("without"))
        func weighted(_ terms: [LexicalTerm], against profile: LexicalProfile, opposed: Set<String>) -> (Double, [String], [String]) {
            guard !terms.isEmpty else { return (0, [], []) }
            var earned = 0.0, total = 0.0, hit: [String] = [], miss: [String] = []
            for term in terms {
                total += term.weight
                let negativeVerb = negationExpressed && profile.stems == clause.profile.stems && Proposition.negativeVerbs.contains(term.stem)
                let score = (countOpposed && opposed.contains(term.stem)) || negativeVerb ? 1 : profile.match(term)
                earned += term.weight * score
                if score > 0 { hit.append(term.surface) } else if term.weight == 1 { miss.append(term.surface) }
            }
            return (total > 0 ? earned / total : 0, hit, miss)
        }
        let recallResult = weighted(rubric.complement, against: clause.profile, opposed: opposedClaim)
        recall = recallResult.0; matched = recallResult.1; missing = recallResult.2
        let learnerTerms = clause.complement.filter { term in !(context.target.concept.map { context.mentions(term.surface, $0) } ?? false) }
        precision = weighted(learnerTerms, against: rubric.profile, opposed: opposedLearner).0
        conditionCoverage = rubric.condition.isEmpty ? 1 : weighted(rubric.condition, against: clause.profile, opposed: []).0

        // A claim inside the target's card whose grammatical subject is something else
        // ("Identity alone is not permission") is not a predicate of the target itself.
        let teachesTarget = rubric.subjectIsConcept &&
            (context.target.concept.map { AlignmentContext.owner(of: rubric.claim, names: context.target.names) == $0 } ?? false)
        if let subject = clause.subject {
            let text = subject.words.joined(separator: " ")
            let direct = rubric.subjectOverlap(subject)
            if teachesTarget, let concept = context.target.concept, context.mentions(text, concept) { subjectMatch = 1 }
            else if teachesTarget, context.otherConcept(in: text) != nil { subjectMatch = 0 }
            else if teachesTarget { subjectMatch = max(direct, 0.6) * subjectPenalty }
            else {
                // The claim's subject may appear elsewhere in the clause ("... when the list is reordered").
                let elsewhere = rubric.subjectOverlap(clause.profile) * 0.7
                subjectMatch = max(direct, elsewhere) * subjectPenalty
            }
        } else { subjectMatch = teachesTarget ? 1 : 0.5 }

        if let verb = rubric.verbStem {
            relationMatch = clause.profile.match(LexicalTerm(surface: verb, stem: verb)) >= 0.85 ? 1 : 0
        } else { relationMatch = rubric.copular && clause.definitional ? 1 : 0 }
        genusMatch = clause.definitional && rubric.claim.kind == .definition && rubric.objectHead != nil &&
            clause.complementHead.map { head in AlignmentContext.sameRoot(head, rubric.objectHead!) ||
                clause.profile.match(LexicalTerm(surface: rubric.objectHead!, stem: rubric.objectHead!)) >= 0.85 && head == rubric.objectHead! } == true

        let words = clause.normalized.split(separator: " ").map(String.init)
        let source = rubric.normalized.split(separator: " ").map(String.init)
        verbatim = source.count >= 8 && Double(Self.lcs(words, source)) / Double(source.count) >= 0.9 &&
            Double(words.count) <= Double(source.count) * 1.25

        if relationMatch == 1, let subject = clause.subject, !rubric.subject.isEmpty {
            let subjectToObject = weighted(subject.terms, against: rubric.complementProfile, opposed: []).0
            let objectToSubject = weighted(rubric.subject, against: clause.complementProfile, opposed: []).0
            reversed = subjectToObject >= 0.6 && objectToSubject >= 0.6 && rubric.subjectOverlap(subject) < 0.5
        } else { reversed = false }
    }

    var contradicts: Bool {
        guard subjectMatch >= 0.6, propositionConflict else { return false }
        // One assertion of a longer claim restated with the opposite sense is enough.
        if conflictOverlap >= 0.75 { return true }
        if flips > 0 { return recall >= 0.3 || precision >= 0.5 }
        return (recall >= 0.3 && precision >= 0.4) || precision >= 0.6
    }

    /// Coverage this clause gives the claim, if any.
    var coverage: ClaimCoverage? {
        guard !contradicts, !reversed else { return nil }
        if verbatim { return .covered }
        guard subjectMatch >= 0.5 || (subjectMatch >= 0.34 && precision >= 0.5) else { return nil }
        let expressesRelation = relationMatch == 1 || rubric.verbStem == nil || recall >= 0.8
        if recall >= 0.62 && subjectMatch >= 0.5 && conditionCoverage >= 0.5 && expressesRelation && !overgeneralizes { return .covered }
        // One shared word ("render") is not evidence that a claim was expressed.
        let substantive = matched.count >= 2 || (rubric.complement.count <= 2 && relationMatch == 1)
        let related = relationMatch == 1 || rubric.verbStem == nil || recall >= 0.5 || precision >= 0.6
        if recall >= 0.3 && substantive && related && (precision >= 0.35 || recall >= 0.5) { return .partial }
        if genusMatch || (recall >= 0.2 && precision >= 0.75 && substantive) { return .partial }
        if propositionSupport >= 0.75 { return .partial }
        return nil
    }

    /// Universal wording the source does not support. Universals that describe the rejected
    /// alternative ("instead of a listener on every child") do not count.
    var overgeneralizes: Bool {
        guard recall >= 0.2, rubric.profile.universals.isEmpty, rubric.hedged, !propositionConflict else { return false }
        let text = clause.text
        let asserted = DiagnosisText.rejectedAlternative.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
        return !LexicalProfile(asserted).universals.subtracting(["all", "any"]).isEmpty
    }

    var missingElement: MissingElement? {
        if recall >= 0.62 && !rubric.condition.isEmpty && conditionCoverage < 0.5 { return .condition }
        if relationMatch == 0 && rubric.verbStem != nil && recall < 0.62 { return .relation }
        return recall < 0.62 ? .detail : nil
    }

    var score: Double { 0.45 * recall + 0.35 * precision + 0.2 * subjectMatch }

    func statement(_ verdict: StatementVerdict) -> StatementDiagnosis {
        StatementDiagnosis(learnerText: clause.text, verdict: verdict, claimID: rubric.claim.id,
                           tier: verbatim || clause.normalized == rubric.normalized ? .exact : .lexical,
                           matchedTerms: Array(matched.prefix(8)), missingTerms: Array(missing.prefix(8)))
    }

    static func lcs(_ a: [String], _ b: [String]) -> Int {
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        var previous = [Int](repeating: 0, count: b.count + 1)
        for x in a {
            var current = [Int](repeating: 0, count: b.count + 1)
            for (j, y) in b.enumerated() { current[j + 1] = x == y ? previous[j] + 1 : max(previous[j + 1], current[j]) }
            previous = current
        }
        return previous[b.count]
    }
}
