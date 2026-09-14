import Foundation

/// Maps surface verb phrases onto the fixed relation vocabulary.
///
/// The lexicon is intentionally explicit rather than learned: an unknown verb
/// must fail to produce a relation, because a wrong edge is far more damaging
/// than a missing one.
public enum RelationLexicon {

    public struct Cue: Sendable {
        public var phrase: String
        public var kind: RelationKind
        public var claimType: ClaimType
        /// When true, subject and object swap ("X is caused by Y" -> Y causes X).
        public var inverts: Bool

        init(_ phrase: String, _ kind: RelationKind, _ claimType: ClaimType, inverts: Bool = false) {
            self.phrase = phrase
            self.kind = kind
            self.claimType = claimType
            self.inverts = inverts
        }
    }

    /// Ordered longest-first at lookup time so that "is required by" wins over
    /// "is" and "depends on" wins over "depends". `baseFormVariants` appends
    /// the bare-verb conjugation of every single-word cue here, so the hand
    /// authored list only needs the third-person-singular spelling.
    public static let cues: [Cue] = cuesBase + baseFormVariants

    /// Third-person-singular verb cues ("enables", "prevents") only match a
    /// singular subject. A plural or "you"-subject sentence, or the bare verb
    /// under "does not" negation ("does not enable"), uses the base form
    /// instead — the same claim, different conjugation. Deriving that form
    /// here (rather than hand-listing both spellings above) keeps the
    /// authored list free of duplication and guarantees the two forms always
    /// carry the same relation kind.
    private static var baseFormVariants: [Cue] {
        var seen = Set(cuesBase.map(\.phrase))
        var derived: [Cue] = []
        for cue in cuesBase {
            guard !cue.phrase.contains(" "), cue.phrase.hasSuffix("s"), cue.phrase.count > 4 else { continue }
            let base = String(cue.phrase.dropLast())
            guard base.count >= 4, !seen.contains(base) else { continue }
            seen.insert(base)
            derived.append(Cue(base, cue.kind, cue.claimType, inverts: cue.inverts))
        }
        return derived
    }

    /// The hand-authored cues, kept separate from `cues` so `baseFormVariants`
    /// can derive from them without recursing into its own output.
    private static let cuesBase: [Cue] = [
        Cue("makes it possible for", .enables, .mechanism),
        Cue("makes it possible to", .enables, .mechanism),
        Cue("allows for", .enables, .mechanism),
        Cue("enables", .enables, .mechanism),
        Cue("allows", .enables, .mechanism),
        Cue("lets", .enables, .mechanism),
        Cue("helps", .enables, .mechanism),
        Cue("supports", .supports, .mechanism),
        Cue("is enabled by", .enables, .mechanism, inverts: true),

        Cue("fixes", .enables, .mechanism),
        Cue("fix", .enables, .mechanism),
        Cue("solves", .enables, .mechanism),
        Cue("handles", .enables, .mechanism),
        Cue("improves", .enables, .mechanism),

        // Causation
        Cue("results in", .causes, .cause),
        Cue("leads to", .causes, .cause),
        Cue("causes", .causes, .cause),
        Cue("produces", .causes, .cause),
        Cue("triggers", .causes, .cause),
        Cue("reduces", .causes, .cause),
        Cue("increases", .causes, .cause),
        Cue("is caused by", .causes, .cause, inverts: true),
        Cue("happens because of", .causes, .cause, inverts: true),

        // Prevention
        Cue("prevents", .prevents, .consequence),
        Cue("avoids", .prevents, .consequence),
        Cue("stops", .prevents, .consequence),
        Cue("protects against", .prevents, .consequence),

        // Dependency
        Cue("depends on", .requires, .prerequisite),
        Cue("relies on", .requires, .prerequisite),
        Cue("requires", .requires, .prerequisite),
        Cue("needs", .requires, .prerequisite),
        Cue("must have", .requires, .constraint),
        Cue("is required for", .prerequisiteOf, .prerequisite),
        Cue("is needed for", .prerequisiteOf, .prerequisite),

        // Definition / explanation
        Cue("is defined as", .explains, .definition),
        Cue("refers to", .explains, .definition),
        Cue("means", .explains, .definition),
        Cue("is a way to", .explains, .definition),
        Cue("is the practice of", .explains, .definition),
        Cue("explains", .explains, .mechanism),
        Cue("describes", .explains, .definition),

        // Consequence / failure
        Cue("may appear", .consequenceOf, .consequence),
        Cue("can appear", .consequenceOf, .consequence),
        Cue("breaks", .failureOf, .failureMode),
        Cue("fails", .failureOf, .failureMode),
        Cue("becomes stale", .failureOf, .failureMode),

        // Contrast / distinction
        Cue("unlike", .contrastsWith, .distinction),
        Cue("differs from", .contrastsWith, .distinction),
        Cue("in contrast to", .contrastsWith, .distinction),
        Cue("rather than", .contrastsWith, .distinction),
        Cue("instead of", .contrastsWith, .distinction),

        // Instantiation
        Cue("is an example of", .exampleOf, .example, inverts: false),
        Cue("is a form of", .exampleOf, .example),
        Cue("is one kind of", .exampleOf, .example),
        Cue("implements", .implementationOf, .example),
        Cue("applies the same idea as", .samePrincipleAs, .distinction),

        // Trade-off
        Cue("trades off", .contrastsWith, .tradeoff),
        Cue("at the cost of", .contrastsWith, .tradeoff),

        // Scoping
        Cue("only applies to", .scopes, .constraint),
        Cue("applies only to", .scopes, .constraint),
        Cue("is limited to", .scopes, .constraint),
        Cue("must be", .qualifies, .constraint),
        Cue("should be", .qualifies, .constraint),
        Cue("is", .explains, .definition),
        Cue("are", .explains, .definition)
    ]

    /// Longest matching cue starting at or after `from`, searching left to right
    /// so the main verb wins over a verb inside a trailing clause.
    public static func firstCue(in sentence: String) -> (cue: Cue, range: Range<String.Index>)? {
        let lowered = " " + sentence.lowercased() + " "
        var best: (cue: Cue, lowerStart: Int, length: Int)?
        for cue in cues {
            guard let found = lowered.range(of: " \(cue.phrase) ") else { continue }
            let offset = lowered.distance(from: lowered.startIndex, to: found.lowerBound)
            if let current = best {
                // Earlier position wins; on a tie the longer phrase wins.
                if offset < current.lowerStart || (offset == current.lowerStart && cue.phrase.count > current.length) {
                    best = (cue, offset, cue.phrase.count)
                }
            } else {
                best = (cue, offset, cue.phrase.count)
            }
        }
        guard let winner = best else { return nil }
        // Re-locate in the original string (same offsets: lowercasing preserves
        // length for the ASCII text we extract from PDFs; guarded below).
        guard sentence.count + 2 == lowered.count else { return nil }
        let start = sentence.index(sentence.startIndex, offsetBy: winner.lowerStart)
        let end = sentence.index(start, offsetBy: winner.length)
        guard end <= sentence.endIndex else { return nil }
        return (winner.cue, start..<end)
    }
}
