import Foundation
@testable import ShelfCore

/// The predictors the generalization harness compares, the V34 fixture read as judgements, and
/// the meaning-preserving rewrites used for metamorphic checks.
extension GeneralizationEvaluation {
    // MARK: - The V34 baseline, as a predictor

    /// V34 commits to every verdict: its level is its judgement and it records whatever the
    /// diagnosis shows. `text` lets metamorphic variants reuse the same input.
    static func v34(_ input: Input, _ text: String) -> Judged {
        let diagnosis = UnderstandingDiagnoser().diagnose(text, target: input.target)
        let evidence = LearnerEvidenceMapper(knowledge: input.knowledge).evidence(from: diagnosis, documentID: input.documentID,
                                                                                    identity: input.item.id + "|" + text, at: input.at)
        // V34 also holds back when it learns nothing and its next step asks something.
        let asks = evidence.isEmpty && diagnosis.intervention.followUp != nil
        return Judged(state: v34State(diagnosis.level), confidence: 1, asksProbe: asks, evidence: evidence,
                      probeClaims: asks ? diagnosis.intervention.followUp?.rubricClaimIDs ?? [] : [],
                      probeConcept: asks ? diagnosis.intervention.relatedConcept : nil)
    }

    /// V35: the judgement decides what the learner model may learn from the answer, and whether
    /// it should wait for one discriminating answer first. The prior is the learner model so far.
    static func v35(_ input: Input, _ text: String) -> Judged {
        let concepts = input.target.concept.map { [LearnerConceptID(documentID: input.documentID, concept: $0)] } ?? []
        let assessment = UnderstandingDiagnoser().assess(text, target: input.target, prior: LearnerPrior(input.prior, concepts: concepts, at: input.at))
        let evidence = LearnerEvidenceMapper(knowledge: input.knowledge).evidence(from: assessment, documentID: input.documentID,
                                                                                    identity: input.item.id + "|" + text, at: input.at)
        let state = assessment.judgement.state == .insufficientEvidence ? "insufficient" : assessment.judgement.state.rawValue
        let asks = assessment.judgement.needsEvidence
        return Judged(state: state, confidence: assessment.judgement.confidence, asksProbe: asks, evidence: evidence,
                      probeClaims: asks ? assessment.diagnosis.intervention.followUp?.rubricClaimIDs ?? [] : [],
                      probeConcept: asks ? assessment.diagnosis.intervention.relatedConcept : nil)
    }

    static func v34State(_ level: UnderstandingLevel) -> String {
        switch level {
        case .solid: return "understood"
        case .mostly: return "mostlyUnderstood"
        case .partial, .surface: return "fragile"
        case .misconceived: return "misconception"
        case .circular, .unrelated, .insufficient: return "insufficient"
        }
    }

    /// The V34 fixture read as judgements, without touching its labels: a required contradiction,
    /// reversal, confusion or overgeneralization is a misconception; covered claims without one
    /// are understanding (the labels cannot tell understood from mostly); partial-only or verbatim
    /// is fragile; nothing covered is insufficient. Coarse metrics only.
    static func legacy(_ split: String) -> Fixture {
        let wrong = ["contradiction": "contradiction", "causalReversal": "reversal", "confusedConcept": "confusion", "overgeneralization": "overgeneralization"]
        let cases = DiagnosisEvaluation.fixture.cases.filter { $0.split == split }.map { item -> Case in
            let misconceptions = item.issues.compactMap { wrong[$0] }.map { Misconception(kind: $0, claim: nil, confusedWith: nil) }
            let state: String
            if !misconceptions.isEmpty { state = "misconception" }
            else if item.issues.contains("verbatim") || (item.covered.isEmpty && !item.partial.isEmpty) { state = "fragile" }
            else if !item.covered.isEmpty { state = "mostlyUnderstood" }
            else { state = "insufficient" }
            return Case(id: item.id, document: item.document, text: item.text, state: state, concept: item.concept, page: item.page,
                        misconceptions: misconceptions, credits: [], categories: ["legacy"], paraphraseGroup: nil)
        }
        return Fixture(split: "legacy-" + split, cases: cases)
    }

    /// Meaning-preserving rewrites a teacher would not grade differently.
    static let metamorphic: [(String) -> String] = [
        { "I think " + lowercasingLead($0) },
        { "Basically, " + lowercasingLead($0) },
        { $0.trimmingCharacters(in: .whitespaces) + " That's how I understand it." },
        { text in
            [("don't", "do not"), ("doesn't", "does not"), ("can't", "cannot"), ("isn't", "is not"), ("aren't", "are not"),
             ("won't", "will not"), ("it's", "it is"), ("It's", "It is"), ("you're", "you are"), ("that's", "that is")]
                .reduce(text) { $0.replacingOccurrences(of: $1.0, with: $1.1) }
        }
    ]

    static func lowercasingLead(_ text: String) -> String {
        guard let first = text.first, first.isUppercase else { return text }
        let word = text.prefix { !$0.isWhitespace }
        // Acronyms and identifiers keep their spelling ("JWTs", "CORS", "useMemo").
        if word.count > 1, word.dropFirst().contains(where: { $0.isUppercase }) { return text }
        return first.lowercased() + text.dropFirst()
    }
}
