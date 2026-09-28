import Foundation

/// Every threshold the semantic reader uses, in one place. All were set on the development splits
/// only (V35 dev: one author; V36 dev2: three authors, seven documents) and frozen before the
/// V36 sealed split was written. The development metrics are nearly flat across the grid that was
/// tried (word 0.35–0.45, expressed 0.5–0.6, touched 0.35–0.45, margin 0–0.05, relation 0.4–0.6):
/// where settings tie, the one that credits less was kept.
enum SemanticThresholds {
    /// Word similarity from which a learner word may stand in for a claim word. Measured as how
    /// well claim recall separates credited from uncredited claims (AUC 0.82 on dev, 0.64 on dev2,
    /// no better at 0.40 or 0.45); higher floors also let one more misconception through on dev2.
    static let word = 0.35
    /// Semantic recall (the weighted share of a claim's words the clause expresses, lexically or in
    /// other words) from which a clause expresses the claim in other words ...
    static let expressed = 0.5
    /// ... and from which it at least touches the claim.
    static let touched = 0.4
    /// A claim's subject said in other words: the share of its subject words the clause's subject
    /// expresses (the lexical reader's own subject bar).
    static let subject = 0.5
    /// A word that stands in for the claim's verb: closer than an ordinary stand-in, since the
    /// verb carries the relation ("retains" is not "releases"). 0.4 and 0.5 read dev alike; 0.6 lost
    /// exact states on dev2.
    static let relation = 0.5
    /// A clause is read as expressing one claim only when that claim fits it better than every
    /// other claim of the target by this margin (0 and 0.05 read dev alike; the stricter is kept).
    static let margin = 0.05
    /// Another concept explains the clause better than the target by this much, and explains at
    /// least this share of it: a possible confusion. With the lexical reader's own bar on how much
    /// of the clause that is (`JudgementReading.rivalWeight`), two of three such clauses on the
    /// development splits held a misconception; below the share bar, most did not.
    static let rivalMargin = 0.1
    static let rivalShare = 0.3
}
