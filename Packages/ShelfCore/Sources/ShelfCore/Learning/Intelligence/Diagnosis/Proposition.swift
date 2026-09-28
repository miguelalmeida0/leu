import Foundation

/// One atomic assertion inside a sentence: "CORS is not authentication and it does not stop
/// non-browser clients" holds two. Polarity is judged per proposition, so two independent
/// negations never cancel into agreement, and "avoids X" reads as "does not X".
struct Proposition {
    let terms: [LexicalTerm]
    let negative: Bool
    let poles: [Int: Set<Int>]
    /// The terms a negation governs: everything after the first negating cue
    /// ("does not change the variable" -> change, variable).
    let scope: [LexicalTerm]
    /// "avoids firing work for *every* keystroke" negates the universal, not the action.
    let universalInScope: Bool
    let universal: Bool
    /// How many polarity cues it holds (negations, "without", negative verbs): with two or more,
    /// its overall polarity is a parity, not a reading ("wasn't changed, without a lookup").
    let cues: Int
    /// It limits its own scope ("only part", "alone", "merely"), which a negation can restate
    /// with the opposite polarity ("X alone does not close it" for "X is only part of it").
    let restrictive: Bool

    private static let boundaries = [";", ", and ", " and it ", " and they ", ", so ", " so that ", " so ", ", which ", " which ", " that ",
                                     ", but ", " but ", " because ", ", while ", " while ", " whereas ", ", otherwise ", " when "]
    /// Boundaries whose word belongs to the next piece: "signed containers, not encrypted".
    private static let keptBoundaries = [(", not ", "not ")]
    /// Verbs whose meaning carries a negation ("avoids repeating work" = does not repeat work).
    static let negativeVerbs: Set<String> = Set(["avoid", "prevent", "block", "forbid", "prohibit", "disallow", "lack", "hinder"].map(Lexicon.stem))
    /// Paraphrase families of those verbs ("stops", "guards against").
    static let negativeVerbFamilies: Set<Int> = Set(negativeVerbs.flatMap { Lexicon.familyIndex[$0] ?? [] })
    private static let copulaEndings = ["is", "are", "was", "were", "means", "happens", "occurs"]

    static func split(_ text: String) -> [Proposition] {
        // Case is kept: the profile splits identifiers such as "setState" by their capitals.
        var parts = [" " + text + " "]
        for marker in boundaries { parts = parts.flatMap { cut($0, at: marker) } }
        for (marker, kept) in keptBoundaries {
            parts = parts.flatMap { part in cut(part, at: marker).enumerated().map { $0.offset == 0 ? $0.element : kept + $0.element } }
        }
        // "A deadlock is when ..." states one thing: a piece ending in its copula joins the next.
        parts = parts.reduce(into: [String]()) { merged, part in
            if let last = merged.last, let word = last.split(separator: " ").last, copulaEndings.contains(word.lowercased()) {
                merged[merged.count - 1] = last + " " + part
            } else { merged.append(part) }
        }
        // A leading subordinate clause ("Once you know who the user is, they ...") is its own assertion.
        parts = parts.flatMap { part -> [String] in
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            guard let first = trimmed.split(separator: " ").first,
                  ["once", "if", "when", "after", "before", "since", "although", "without", "unless"].contains(first.lowercased()),
                  let comma = trimmed.firstIndex(of: ",") else { return [part] }
            return [String(trimmed[..<comma]), String(trimmed[trimmed.index(after: comma)...])]
        }
        // Two negations joined by "and"/"or" are two predications ("you never repeat work and
        // nothing can go wrong"); their parity must not combine.
        parts = parts.flatMap { part -> [String] in
            for marker in [" and ", " or "] {
                let pieces = cut(part, at: marker)
                guard pieces.count > 1 else { continue }
                if pieces.allSatisfy({ polarityCues(LexicalProfile($0)) > 0 }) { return pieces }
            }
            return [part]
        }
        return parts.compactMap { part in
            let profile = LexicalProfile(part)
            guard !profile.terms.isEmpty else { return nil }
            let negativeVerb = profile.terms.contains { negativeVerbs.contains($0.stem) }
            let without = profile.words.contains("without") ? 1 : 0
            let cue = profile.words.indices.first { index in
                let word = profile.words[index]
                return Lexicon.negations.contains(word) || word == "without" || negativeVerbs.contains(Lexicon.stem(word))
            }
            let scope = cue.map { cue in
                zip(profile.terms, profile.termPositions).filter { $0.1 > cue && !negativeVerbs.contains($0.0.stem) }.map(\.0)
            } ?? []
            let universalInScope = cue.map { cue in profile.words.indices.contains { $0 > cue && Lexicon.universals.contains(profile.words[$0]) } } ?? false
            return Proposition(terms: profile.terms, negative: (profile.negationCount + without) % 2 == 1 ? !negativeVerb : negativeVerb,
                               poles: profile.poles, scope: scope, universalInScope: universalInScope,
                               universal: !profile.universals.subtracting(["any"]).isEmpty, cues: polarityCues(profile),
                               restrictive: profile.words.contains { restrictives.contains($0) })
        }
    }

    private static let restrictives: Set<String> = ["only", "alone", "merely", "solely", "just", "purely"]

    private static func polarityCues(_ profile: LexicalProfile) -> Int {
        profile.negationCount + (profile.words.contains("without") ? 1 : 0) + profile.terms.filter { negativeVerbs.contains($0.stem) }.count
    }

    /// Case-insensitive split that keeps the original casing of every piece.
    private static func cut(_ text: String, at marker: String) -> [String] {
        var pieces: [String] = [], rest = text[...]
        while let range = rest.range(of: marker, options: .caseInsensitive) {
            pieces.append(String(rest[..<range.lowerBound])); rest = rest[range.upperBound...]
        }
        pieces.append(String(rest))
        return pieces
    }

    func unambiguousPole(_ dimension: Int) -> Int? {
        guard let set = poles[dimension], set.count == 1 else { return nil }
        return set.first
    }
}

/// How a claim proposition and a learner proposition relate when they talk about the same thing.
struct PropositionComparison {
    let overlap: Double
    /// How much of the learner proposition is made of the claim proposition.
    let learnerShare: Double
    /// Opposite polarity over the same negated content. A negation that governs words the
    /// other side never mentions ("avoids firing work *for every keystroke*") is not a conflict.
    let polarityMismatch: Bool
    let flips: Int
    var contradicts: Bool { polarityMismatch != (flips % 2 == 1) }
    var agreesByNegation: Bool { polarityMismatch && flips % 2 == 1 }

    /// Nil when the two propositions do not share enough content to be compared.
    init?(claim: Proposition, learner: Proposition) {
        let learnerProfile = LexicalProfileView(terms: learner.terms)
        var flips = 0, opposed = Set<String>()
        for (dimension, _) in claim.poles {
            guard let a = claim.unambiguousPole(dimension), let b = learner.unambiguousPole(dimension), a != b else { continue }
            flips += 1
            for term in claim.terms where (Lexicon.dimensionIndex[term.stem] ?? []).contains(where: { $0.0 == dimension }) { opposed.insert(term.stem) }
        }
        let content = claim.terms.filter { $0.weight == 1 }
        guard !content.isEmpty else { return nil }
        var shared = 0.0, strong = 0, exact = 0
        for term in claim.terms {
            let score = opposed.contains(term.stem) ? 1 : learnerProfile.match(term)
            shared += term.weight * score
            if score >= 0.85 && term.weight == 1 { strong += 1 }
            if score == 1 && term.weight == 1 { exact += 1 }
        }
        let total = claim.terms.reduce(0) { $0 + $1.weight }
        let learnerTotal = learner.terms.reduce(0) { $0 + $1.weight }
        overlap = total > 0 ? shared / total : 0
        let learnerShare = learnerTotal > 0 ? min(shared / learnerTotal, 1) : 0
        self.learnerShare = learnerShare
        // Comparable when the learner restates most of the claim proposition, or when a short
        // learner proposition is mostly made of it ("caches never become stale" against
        // "... introduces a second representation that can become stale").
        // A proposition of one or two words is only comparable on the same words.
        // Paraphrase alone never makes two propositions comparable: they must share a word.
        let restatesClaim = (overlap >= 0.5 ? strong >= 1 : content.count <= 2) && (learnerTotal == 0 || learnerShare >= 0.25)
        let madeOfClaim = strong >= 2 && learnerShare >= 0.6
        guard exact >= 1, restatesClaim || madeOfClaim else { return nil }
        self.flips = flips
        guard claim.negative != learner.negative else { polarityMismatch = false; return }
        let (negated, other) = claim.negative ? (claim, learner) : (learner, claim)
        // "Not for every keystroke" is only contradicted by "for every keystroke".
        guard !negated.universalInScope || other.universal else { polarityMismatch = false; return }
        let otherView = LexicalProfileView(terms: other.terms)
        let scopeWeight = negated.scope.reduce(0) { $0 + $1.weight }
        let covered = negated.scope.reduce(0.0) { sum, term in
            sum + term.weight * (Lexicon.dimensionIndex[term.stem] != nil && flips > 0 ? max(otherView.match(term), 0.85) : otherView.match(term))
        }
        polarityMismatch = scopeWeight > 0 && covered / scopeWeight >= 0.5
    }
}

/// Matching over a bare term list (a proposition has no full profile).
struct LexicalProfileView {
    let stems: Set<String>
    let terms: [LexicalTerm]
    init(terms: [LexicalTerm]) { self.terms = terms; stems = Set(terms.map(\.stem)) }
    func match(_ term: LexicalTerm) -> Double {
        if stems.contains(term.stem) { return 1 }
        let families = term.families
        if !families.isEmpty, terms.contains(where: { !$0.families.isDisjoint(with: families) }) { return 0.85 }
        if terms.contains(where: { Lexicon.derivationallyRelated($0.stem, term.stem) }) { return 0.6 }
        return 0
    }
}
