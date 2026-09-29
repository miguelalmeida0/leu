import Foundation
@testable import ShelfCore

// THROWAWAY — V37 capability spike only (branch `test`, never merged into dev before a pass).

/// Into the unchanged judge (SPIKE_SPEC §7). A checked reading becomes the diagnosis and signals
/// `UnderstandingJudge` already consumes; the unchanged judge, planner and evidence mapper decide.
/// The judge is this branch's (V35's rules plus V36's evidence-only rules). The V36 semantic inputs
/// (`semantic`, `semanticCoverage`, `semanticLevel`) stay empty, so its semantic rules never fire; the
/// one V36-era input used is `ClauseSignal.reason`, for §7's "an unconfirmed reason is asked about".
enum SpikeAdapter {
    /// Why a case was judged by Tier 0 (`GeneralizationEvaluation.v35`) instead of the reading.
    enum Fallback: String, CaseIterable {
        case none, empty, missingRecord, readingFailed, invalidReading, opinionFailed
        /// An empty answer needs no model call; every other fallback is a model failure (preregistration §4).
        var isFailure: Bool { self != .none && self != .empty }
    }

    struct Outcome {
        let judged: GeneralizationEvaluation.Judged
        let fallback: Fallback
        let checked: SpikeChecked?
        let assessment: UnderstandingAssessment?
        /// The claims the one next question asks about, whether or not the judgement waits for it.
        let nextClaims: [String]
        /// Claim, reasoning and misconception state, kept apart (dev13).
        var facets: SpikeFacets? { checked.map(SpikeFacets.init) }
    }

    static func judge(_ input: GeneralizationEvaluation.Input, spike: SpikeInput, record: SpikeRecord?, key: SpikeAnswerKey?,
                      config: SpikeConfig) -> Outcome {
        func tier0(_ reason: Fallback) -> Outcome {
            let judged = GeneralizationEvaluation.v35(input, input.text)
            return Outcome(judged: judged, fallback: reason, checked: nil, assessment: nil, nextClaims: judged.probeClaims)
        }
        guard !spike.segments.isEmpty else { return tier0(.empty) }
        guard let record else { return tier0(.missingRecord) }
        guard record.reading.status == "ok", let reading = record.reading.output else { return tier0(.readingFailed) }
        var opinion: SpikeSecondOpinionOutput?
        if config == .d {
            // "none": nothing decisive to check, so no call was made.
            guard let call = record.secondOpinion else { return tier0(.opinionFailed) }
            if call.status == "none" { opinion = SpikeSecondOpinionOutput(items: [], verdicts: []) }
            else if call.status == "ok", let output = call.output { opinion = output }
            else { return tier0(.opinionFailed) }
        }
        guard let checked = SpikeChecks.check(reading, input: spike, text: input.text, key: key, target: input.target,
                                              config: config, opinion: opinion) else { return tier0(.invalidReading) }
        let assessment = assess(checked, input: input)
        var judged = judged(assessment, input)
        let next = nextClaims(checked, state: judged.state, assessment: assessment, target: input.target)
        if judged.asksProbe && judged.state == "weakReasoning" { judged.probeClaims = next }
        return Outcome(judged: judged, fallback: .none, checked: checked, assessment: assessment, nextClaims: next)
    }

    /// The one next question (amended 2026-09-29): a reasoning fault is repaired where it breaks. When
    /// the judgement is weak reasoning and the model tied the wrong reason to a claim, the question asks
    /// about that claim (C4: the access mechanism, not the concept's purpose); otherwise it is the
    /// planner's own next question. What is recorded is unchanged: that stays the judge's and mapper's.
    /// V37: the fault is where the reason meets its conclusion, so the question asks how the conclusion's
    /// claim works: the claim (canonical family) of the conclusion the wrong reason was given for.
    static func nextClaims(_ checked: SpikeChecked, state: String, assessment: UnderstandingAssessment, target: DiagnosisTarget) -> [String] {
        let known = Set(target.allClaims.map(\.id))
        if state == "weakReasoning", let reason = checked.segments.first(where: { $0.reasonOf != nil }), let c = reason.reasonOf {
            let conclusion = checked.segments[c - 1]
            if let claim = conclusion.familyID ?? conclusion.claimID, known.contains(claim) { return [claim] }
            if let named = reason.named, known.contains(named) { return [named] }
        }
        return assessment.diagnosis.intervention.followUp?.rubricClaimIDs ?? []
    }

    /// The §7 table, segment by segment, then V35's own coverage, missing-idea issues and level.
    static func assess(_ checked: SpikeChecked, input: GeneralizationEvaluation.Input) -> UnderstandingAssessment {
        let target = input.target
        let known = Set(target.allClaims.map(\.id))
        let core = target.rubric.filter { $0.role == .core }
        let coreIDs = Set(core.map(\.id))
        // V35's own reader runs alongside for its verbatim-copy signal. Self-doubt needs nothing: the
        // judge reads it from the statements' own words.
        let copied = UnderstandingDiagnoser(semantics: nil).assess(input.text, target: target)
            .diagnosis.statements.filter { $0.verdict == .restates }.map(\.learnerText)
        var statements: [StatementDiagnosis] = [], issues: [UnderstandingIssue] = []
        var signals = DiagnosisSignals()
        var best: [String: (coverage: ClaimCoverage, text: String)] = [:]
        // As V35: core claims only; a contradiction outranks credit, full credit outranks partial.
        func record(_ id: String?, _ coverage: ClaimCoverage, _ text: String) {
            guard let id, coreIDs.contains(id) else { return }
            let rank: [ClaimCoverage: Int] = [.missing: 0, .partial: 1, .covered: 2, .contradicted: 3]
            if let existing = best[id], rank[existing.coverage]! >= rank[coverage]! { return }
            best[id] = (coverage, text)
        }
        func emit(_ text: String, _ verdict: StatementVerdict, claim: String? = nil, recall: Double = 0, distinctive: Int = 0,
                  conflict: Double = 0, rival: ConceptKey? = nil, reason: ReasonReading? = nil, signalText: String? = nil,
                  negationOmitted: Bool = false) {
            let tier: EvidenceTier? = claim == nil ? nil : .lexical
            statements.append(StatementDiagnosis(learnerText: text, verdict: verdict, claimID: claim, tier: tier, matchedTerms: [], missingTerms: []))
            var signal = ClauseSignal(text: signalText ?? text, verdict: verdict, claimID: claim, recall: recall, precision: recall > 0 ? 1 : 0,
                                      distinctive: distinctive, rival: rival, rivalPrecision: rival == nil ? 0 : 0.6,
                                      rivalMatched: rival == nil ? 0 : 2, ownPrecision: rival == nil ? 1 : 0.1, conflictOverlap: conflict,
                                      unexpressedNegation: negationOmitted, words: LexicalProfile(text).words.count)
            if let claim, !negationOmitted, [.supports, .partiallySupports, .restates, .overgeneralizes].contains(verdict) {
                signal.credited[claim] = (recall, distinctive)
            }
            signal.reason = reason
            signals.clauses.append(signal)
        }

        for s in checked.segments {
            // Recorded against the claim's family (risk 1): a supporting claim counts for its core claim.
            let claim = (s.familyID ?? s.claimID).flatMap { known.contains($0) ? $0 : nil }
            // A premise offered for a wrong conclusion (risk 3) is evidence of nothing on its own.
            if s.premiseOf != nil { emit(s.text, .noise); continue }
            if s.reasonOf != nil {
                // A reason given for a credited conclusion (dev12). Unless both readers take it to be true, it is
                // an unsettled reason: the judge states weak reasoning and asks where it breaks (C4: no mastery, a
                // mechanism-targeted question). Confirmed wrong or merely unconfirmed, it is asked, never committed:
                // committed, it wrote weak reasoning over three misconceptions whose false premise was the reason.
                emit(s.text, .noise, reason: ReasonReading(text: s.text, supported: s.reasonSupported))
                continue
            }
            // A reason clause the reading could not credit — unmatched, or restating a negated claim — is a reason
            // to ask about (dev14): the row's claim choice for it varied by run, and either way it is the reasoning
            // that is in doubt. As an unsupported clause it was also committed by the judge's own rule (P2-22).
            let reasonClause = SpikeSegmenter.leadingMarker(s.text).map(SpikeSegmenter.introducesReason.contains) ?? false
            if reasonClause, s.credit == nil, s.wrong == nil {  // not folded: handled above when it is
                emit(s.text, .noise, reason: ReasonReading(text: s.text, supported: false)); continue
            }
            // An omitted negation: the judge's own rule weighs it as a possible misconception and asks (dev14).
            if s.omittedNegation, let named = s.claimID {
                issues.append(UnderstandingIssue(kind: .unsupported, learnerText: s.text))
                emit(s.text, .partiallySupports, claim: named, recall: 0.5, distinctive: 1, negationOmitted: true)
                continue
            }
            if let coverage = s.credit, let claim {
                // Firm credit is strong evidence; tentative credit is thin, so the judge asks first.
                // Only firm credit on copied source wording is V35's verbatim restatement.
                let copy = s.creditFirm && copied.contains { $0.contains(s.text) }
                if copy { issues.append(UnderstandingIssue(kind: .verbatim, claimID: claim, learnerText: s.text)) }
                record(claim, coverage, s.text)
                emit(s.text, copy ? .restates : coverage == .covered ? .supports : .partiallySupports, claim: claim,
                     recall: s.creditFirm ? 1 : 0.35, distinctive: s.creditFirm ? 2 : 1)
                continue
            }
            if let wrong = s.wrong {
                if s.wrongFirm {
                    switch wrong {
                    case .contradiction:
                        record(claim, .contradicted, s.text)
                        issues.append(UnderstandingIssue(kind: .contradiction, claimID: claim, learnerText: s.text))
                        emit(s.text, .contradicts, claim: claim, recall: 1, distinctive: 2, conflict: 1)
                    case .reversal:
                        record(claim, .contradicted, s.text)
                        issues.append(UnderstandingIssue(kind: .causalReversal, claimID: claim, learnerText: s.text))
                        emit(s.text, .reverses, claim: claim, recall: 1, distinctive: 2)
                    case .overgeneralization:
                        // As V35: the idea without its limit — partial coverage and a stated wrong idea.
                        record(claim, .partial, s.text)
                        issues.append(UnderstandingIssue(kind: .overgeneralization, claimID: claim, learnerText: s.text))
                        emit(s.text, .overgeneralizes, claim: claim, recall: 1, distinctive: 2)
                    case .confusion:
                        issues.append(UnderstandingIssue(kind: .confusedConcept, relatedConcept: s.confusedWith, learnerText: s.text))
                        emit(s.text, .confuses)
                    }
                } else if wrong == .confusion, let rival = s.confusedWith {
                    // A doubtful confusion: the rival-concept signal, which the judge asks about as a contrast.
                    issues.append(UnderstandingIssue(kind: .unsupported, learnerText: s.text))
                    emit(s.text, .unsupported, rival: rival)
                } else {
                    // Any other doubtful wrong idea: a contradiction the answer does not state clearly.
                    record(claim, .contradicted, s.text)
                    issues.append(UnderstandingIssue(kind: .contradiction, claimID: claim, learnerText: s.text))
                    emit(s.text, .contradicts, claim: claim)
                }
                continue
            }
            if ["hedge", "filler"].contains(s.role) { emit(s.text, .noise); continue }
            issues.append(UnderstandingIssue(kind: .unsupported, learnerText: s.text))
            emit(s.text, .unsupported)
        }

        // V35's finish: coverage over core claims (definitions weigh 1.5), missing key ideas, level.
        issues = Array(NSOrderedSet(array: issues).array as! [UnderstandingIssue])
        let assessments = core.map { claim in
            ClaimAssessment(claimID: claim.id, coverage: best[claim.id]?.coverage ?? .missing, missing: nil, learnerText: best[claim.id]?.text)
        }
        let weights = core.map { ClaimRubric($0).weight }
        let earned = zip(core, weights).reduce(0.0) { sum, pair in
            switch best[pair.0.id]?.coverage {
            case .covered?: return sum + pair.1
            case .partial?: return sum + pair.1 * 0.5
            default: return sum
            }
        }
        let total = weights.reduce(0, +)
        let coverage = total > 0 ? earned / total : 0
        for assessment in assessments where assessment.coverage == .missing {
            issues.append(UnderstandingIssue(kind: .missingKeyIdea, claimID: assessment.claimID))
        }
        var level = UnderstandingDiagnoser.level(issues: issues, coverage: coverage, statements: statements)
        // Risk 2 (V37): mastery needs the essential idea — the definition's claim family — fully covered.
        // Partial pieces, or secondary claims without it, never add up to "mostly" or "solid": they are
        // partial but meaningful (fragile), and the judge weighs them as such.
        let definition = (core.first { $0.kind == .definition } ?? core.first)?.id
        if let definition, best[definition]?.coverage != .covered, [.solid, .mostly].contains(level) { level = .partial }
        let draft = UnderstandingDiagnosis(version: UnderstandingDiagnosis.version, concept: target.concept, conceptName: target.conceptName,
            statements: statements, claims: assessments, issues: issues, level: level, coverage: coverage,
            intervention: .placeholder, referencedClaims: target.allClaims)
        let concepts = target.concept.map { [LearnerConceptID(documentID: input.documentID, concept: $0)] } ?? []
        let prior = LearnerPrior(input.prior, concepts: concepts, at: input.at)
        let judgement = UnderstandingJudge().judge(draft, signals: signals, target: target, prior: prior)
        let intervention = InterventionPlanner().plan(draft, target: target, judgement: judgement)
        let diagnosis = UnderstandingDiagnosis(version: draft.version, concept: draft.concept, conceptName: draft.conceptName,
            statements: statements, claims: assessments, issues: issues, level: level, coverage: coverage, intervention: intervention,
            referencedClaims: UnderstandingDiagnoser.referenced(draft, intervention: intervention, all: target.allClaims))
        return UnderstandingAssessment(diagnosis: diagnosis, judgement: judgement, signals: signals)
    }

    /// As `GeneralizationEvaluation.judged` (private there): what the judgement lets the learner model learn.
    static func judged(_ assessment: UnderstandingAssessment, _ input: GeneralizationEvaluation.Input) -> GeneralizationEvaluation.Judged {
        let evidence = LearnerEvidenceMapper(knowledge: input.knowledge).evidence(from: assessment, documentID: input.documentID,
                                                                                    identity: input.item.id + "|" + input.text, at: input.at)
        let state = assessment.judgement.state == .insufficientEvidence ? "insufficient" : assessment.judgement.state.rawValue
        let asks = assessment.judgement.needsEvidence
        return GeneralizationEvaluation.Judged(state: state, confidence: assessment.judgement.confidence, asksProbe: asks, evidence: evidence,
                                               probeClaims: asks ? assessment.diagnosis.intervention.followUp?.rubricClaimIDs ?? [] : [],
                                               probeConcept: asks ? assessment.diagnosis.intervention.relatedConcept : nil)
    }
}
