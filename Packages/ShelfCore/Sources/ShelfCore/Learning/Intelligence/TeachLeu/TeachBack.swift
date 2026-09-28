import Foundation

/// Teach It Back, V34: the learner's explanation of a passage read against the grounded claims
/// of that passage (and, on a concept card, the card's neighbours). The result keeps the Teach
/// Leu sections — captured, worth adding, check this, not settled — and carries the diagnosis
/// and the next step behind them. Deterministic and local; no model is involved.
public enum TeachBack {
    public static let backend = "local source comparison v34"

    /// Nil when the knowledge base holds no claim inside the passage; the caller keeps the V27
    /// comparison in that case.
    public static func assess(_ explanation: String, source: IntelligenceSource, knowledge: ConceptKnowledgeBase) -> TeachLeuResult? {
        guard let target = DiagnosisTarget.passage(source.passage, in: knowledge) else { return nil }
        let diagnosis = UnderstandingDiagnoser().diagnose(explanation, target: target)
        func claim(_ id: String?) -> LearningClaim? { diagnosis.claim(id) }
        // "You captured" lists only ideas the explanation covers in full; an idea it only touches
        // is worth adding, shown in the source's own words.
        let supported = diagnosis.claims.filter { $0.coverage == .covered }.compactMap { assessment -> TeachLeuCapture? in
            guard let claim = claim(assessment.claimID) else { return nil }
            return TeachLeuCapture(claimID: claim.id, learnerText: assessment.learnerText ?? "", description: claim.statement, complete: true)
        }
        let omitted = (diagnosis.missing + diagnosis.partial).map(groundedClaim)
        var challenged: [TeachLeuChallenge] = []
        for issue in diagnosis.issues {
            let learner = issue.learnerText ?? ""
            switch issue.kind {
            case .contradiction:
                guard let wrong = claim(issue.claimID) else { continue }
                challenged.append(TeachLeuChallenge(learnerText: learner, sourceClaimID: wrong.id, explanation: wrong.citation()))
            case .causalReversal:
                guard let reversed = claim(issue.claimID) else { continue }
                challenged.append(TeachLeuChallenge(learnerText: learner, sourceClaimID: reversed.id,
                    explanation: "The direction is reversed. " + reversed.citation()))
            case .confusedConcept:
                let other = issue.relatedConcept.flatMap { key in target.names[key]?.first ?? knowledge.concept(key)?.name } ?? "another idea"
                let own = target.conceptName ?? "this passage"
                let evidence = claim(issue.claimID).map { " " + $0.citation() } ?? ""
                challenged.append(TeachLeuChallenge(learnerText: learner, sourceClaimID: issue.claimID,
                    explanation: "That describes \(other), not \(own).\(evidence)"))
            case .overgeneralization:
                guard let limited = claim(issue.claimID) else { continue }
                challenged.append(TeachLeuChallenge(learnerText: learner, sourceClaimID: limited.id,
                    explanation: limited.citation("is more careful")))
            default: continue
            }
        }
        let unsettled = diagnosis.statements.filter { $0.verdict == .unsupported }.map(\.learnerText)
        return TeachLeuResult(source: source, supported: supported, omitted: omitted, challenged: challenged,
                              unsettled: unsettled, backend: backend, diagnosis: diagnosis)
    }

    /// A stored V34 result is admitted only for the explanation it was made from, and only while
    /// every source sentence it quotes — and every heading a subject was inferred from — still
    /// sits at its recorded place in the current page text.
    public static func isGrounded(_ result: TeachLeuResult, explanation: String, analyses: [UUID: DocumentAnalysis]) -> Bool {
        guard let diagnosis = result.diagnosis, !diagnosis.statements.isEmpty else { return false }
        let written = CanonicalWhitespaceResolver.normalize(String(explanation.prefix(4000)))
        guard diagnosis.statements.allSatisfy({ written.contains(CanonicalWhitespaceResolver.normalize($0.learnerText)) }) else { return false }
        let known = Set(diagnosis.referencedClaims.map(\.id))
        let cited = result.supported.map(\.claimID) + result.omitted.map(\.id) + result.challenged.compactMap(\.sourceClaimID)
        guard cited.allSatisfy(known.contains) else { return false }
        func current(_ span: SourceSpan) -> Bool { analyses[span.documentID].map { span.isCurrent(in: $0) } ?? false }
        return diagnosis.referencedClaims.allSatisfy { claim in
            guard current(claim.evidence) else { return false }
            if case .resolvedSubject(let antecedent, _) = claim.grounding { return current(antecedent) }
            return true
        }
    }

    static func groundedClaim(_ claim: LearningClaim) -> GroundedQuestionClaim {
        GroundedQuestionClaim(id: claim.id, concept: claim.conceptName, cognitiveOperation: FollowUps.operation(for: claim).rawValue,
                              relation: claim.kind.rawValue, predicate: claim.predicate, object: claim.object, qualifier: claim.qualifier,
                              negated: claim.negated, documentID: claim.evidence.documentID, pageIndex: claim.evidence.pageIndex,
                              evidence: CanonicalWhitespaceResolver.Span(range: claim.evidence.range, text: claim.evidence.text), prompt: "")
    }
}

public extension ConceptKnowledgeCompiler {
    /// Knowledge for a few pages only: enough to know whether a passage can be compared at all,
    /// in milliseconds, before the whole document's knowledge is ready.
    func compile(_ analysis: DocumentAnalysis, pageIndices: Set<Int>) -> ConceptKnowledgeBase {
        var partial = analysis
        partial.pages = analysis.pages.filter { pageIndices.contains($0.pageIndex) }
        return compile(partial)
    }
}
