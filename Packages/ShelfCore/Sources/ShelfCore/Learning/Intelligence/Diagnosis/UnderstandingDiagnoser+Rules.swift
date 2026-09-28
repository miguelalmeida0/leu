import Foundation

/// The diagnoser's fixed rules: what an answer is before any claim is compared (noise, a keyword
/// list), which claims a stored diagnosis keeps, and the level a finding stands for.
extension UnderstandingDiagnoser {
    /// Eight or more words without a single article, preposition, conjunction, pronoun or
    /// auxiliary: "constraint linking value one table key another table referential integrity".
    /// Real sentences that short of function words are shorter ("Foreign keys protect integrity").
    static func isKeywordList(_ text: String) -> Bool {
        let words = Lexicon.words(text)
        guard words.count >= 8 else { return false }
        let connective: Set<String> = ["and", "or", "but", "not", "no", "so", "it", "its", "they", "their", "them", "this", "these", "those",
                                       "that", "which", "who", "what", "when", "if", "because", "than", "as", "you", "your", "we", "i"]
        return !words.contains { ["a", "an", "the"].contains($0) || ClauseLexicon.prepositions.contains($0) ||
            ClauseLexicon.auxiliaries.contains($0) || ClauseLexicon.subordinators.contains($0) || connective.contains($0) }
    }

    func isNoise(_ text: String, target: DiagnosisTarget) -> Bool {
        let words = Lexicon.words(Lexicon.normalizePhrases(text)).filter { $0.first?.isLetter == true }
        guard !words.isEmpty else { return true }
        let vocabulary = Set(target.allClaims.flatMap { LexicalProfile($0.statement).terms.map(\.stem) })
        let known = words.filter { Lexicon.common.contains(Lexicon.stem($0)) || vocabulary.contains(Lexicon.stem($0)) ||
            ClauseLexicon.forms[$0] != nil || Lexicon.familyIndex[Lexicon.stem($0)] != nil }
        return Double(known.count) / Double(words.count) < 0.34
    }

    /// Keep only claims the diagnosis actually points at, so persisted diagnoses stay small.
    static func referenced(_ diagnosis: UnderstandingDiagnosis, intervention: LearningIntervention, all: [LearningClaim]) -> [LearningClaim] {
        var ids = Set(diagnosis.claims.map(\.claimID))
        ids.formUnion(diagnosis.statements.compactMap(\.claimID))
        ids.formUnion(diagnosis.issues.compactMap(\.claimID))
        if let focus = intervention.focusClaimID { ids.insert(focus) }
        ids.formUnion(intervention.followUp?.rubricClaimIDs ?? [])
        return all.filter { ids.contains($0.id) }.reduce(into: [LearningClaim]()) { result, claim in
            if !result.contains(where: { $0.id == claim.id }) { result.append(claim) }
        }
    }

    static func level(issues: [UnderstandingIssue], coverage: Double, statements: [StatementDiagnosis]) -> UnderstandingLevel {
        let kinds = Set(issues.map(\.kind))
        if kinds.contains(.nonsense) { return .insufficient }
        if !kinds.isDisjoint(with: [.contradiction, .causalReversal, .confusedConcept]) { return .misconceived }
        let supported = statements.filter { [.supports, .partiallySupports, .overgeneralizes].contains($0.verdict) }
        if kinds.contains(.verbatim) && supported.isEmpty { return .surface }
        if kinds.contains(.circular) && coverage < 0.3 { return .circular }
        if coverage >= 0.75 { return kinds.contains(.overgeneralization) ? .mostly : .solid }
        if coverage >= 0.45 { return .mostly }
        if coverage > 0 { return .partial }
        return statements.isEmpty ? .insufficient : .unrelated
    }
}
