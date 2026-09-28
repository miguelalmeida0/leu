import Foundation

/// Word-level semantic evidence that a learner clause says a claim's words in other words.
/// Inspectable: every word it credits is listed with the learner word that stands in for it.
struct SemanticEvidence: Sendable, Equatable {
    struct Substitution: Sendable, Equatable {
        let claim: String
        let learner: String
        let similarity: Double
    }
    /// Weighted share of the claim's terms the clause expresses, by the same words or by others ...
    let recall: Double
    /// ... and by its own words alone (the lexical reader's scores).
    let lexicalRecall: Double
    /// Claim words carried only by a learner word used in their place.
    let substitutions: [Substitution]
    /// Claim words whose closest learner word is their opposite ("slower" for "faster"): never credit.
    let opposites: [Substitution]

    static let none = SemanticEvidence(recall: 0, lexicalRecall: 0, substitutions: [], opposites: [])
}

enum SemanticMatcher {
    /// `lexical(term)` is the score the lexical reader already gives a claim term (1 same word,
    /// 0.85 paraphrase family, 0.6 derivational relative, else 0); a semantic match can only add
    /// to it, and only for a learner word that is not the claim word's opposite.
    static func evidence(claim terms: [LexicalTerm], learner: [LexicalTerm], lexical: (LexicalTerm) -> Double,
                         space: SemanticSpace) -> SemanticEvidence {
        guard !terms.isEmpty else { return .none }
        let candidates = learner.compactMap { term in space.vector(term.surface).map { (term, $0) } }
        var earned = 0.0, known = 0.0, total = 0.0
        var substitutions: [SemanticEvidence.Substitution] = [], opposites: [SemanticEvidence.Substitution] = []
        for term in terms {
            total += term.weight
            let lexicalScore = lexical(term)
            known += term.weight * lexicalScore
            var score = lexicalScore
            if lexicalScore < 1, let vector = space.vector(term.surface),
               let (closest, similarity) = best(vector, among: candidates, excluding: term.stem),
               similarity >= SemanticThresholds.word {
                let substitution = SemanticEvidence.Substitution(claim: term.surface, learner: closest.surface, similarity: similarity)
                if SemanticAntonyms.opposed(term.stem, closest.stem) { opposites.append(substitution) }
                else if similarity > lexicalScore { score = similarity; substitutions.append(substitution) }
            }
            earned += term.weight * score
        }
        return SemanticEvidence(recall: total > 0 ? earned / total : 0, lexicalRecall: total > 0 ? known / total : 0,
                                substitutions: substitutions, opposites: opposites)
    }

    /// How much of a learner clause a body of wording explains, by the same words or by others
    /// (opposites excluded): which concept a clause is about.
    static func share(of learner: [LexicalTerm], in wording: [LexicalTerm], space: SemanticSpace) -> Double {
        explained(learner, by: wording, space: space).share
    }

    /// The share of a learner clause a body of wording explains, and how much that is in weighted
    /// words.
    static func explained(_ learner: [LexicalTerm], by wording: [LexicalTerm], space: SemanticSpace) -> (share: Double, matched: Double) {
        guard !learner.isEmpty, !wording.isEmpty else { return (0, 0) }
        let stems = Set(wording.map(\.stem))
        let candidates = wording.compactMap { term in space.vector(term.surface).map { (term, $0) } }
        var earned = 0.0, total = 0.0
        for term in learner {
            total += term.weight
            if stems.contains(term.stem) { earned += term.weight; continue }
            guard let vector = space.vector(term.surface),
                  let (closest, similarity) = best(vector, among: candidates, excluding: term.stem),
                  similarity >= SemanticThresholds.word, !SemanticAntonyms.opposed(term.stem, closest.stem) else { continue }
            earned += term.weight * similarity
        }
        return (total > 0 ? earned / total : 0, earned)
    }

    private static func best(_ vector: SemanticSpace.Vector, among candidates: [(LexicalTerm, SemanticSpace.Vector)],
                             excluding stem: String) -> (LexicalTerm, Double)? {
        var result: (LexicalTerm, Double)?
        for (term, other) in candidates where term.stem != stem {
            let similarity = SemanticSpace.similarity(vector, other)
            if similarity > (result?.1 ?? -1) { result = (term, similarity) }
        }
        return result
    }
}
