import Foundation

/// Reads a learner's explanation against grounded claims and says what was understood,
/// what is missing and what is wrong — with the evidence for each verdict.
///
/// Deterministic and local. Every verdict names its evidence tier; lexical agreement is
/// never presented as proof of understanding, and nothing here invents a fact: messages
/// are built from fixed templates, the learner's words and the source's words.
public struct UnderstandingDiagnoser: Sendable {
    public init() {}

    public func diagnose(_ explanation: String, target: DiagnosisTarget) -> UnderstandingDiagnosis {
        let text = String(explanation.prefix(4000))
        let rubrics = target.rubric.map(ClaimRubric.init)
        let supporting = target.supporting.map(ClaimRubric.init)
        let competitors = target.competitors.map(ClaimRubric.init)
        let context = AlignmentContext(target: target)
        let clauses = Array(DiagnosisText.clauses(text).prefix(24).map(LearnerClause.init))

        // A list of keywords names the right things but says nothing about how they relate.
        if clauses.isEmpty || isNoise(text, target: target) || clauses.allSatisfy({ Self.isKeywordList($0.text) }) {
            return finish(target: target, rubrics: rubrics, statements: clauses.map {
                StatementDiagnosis(learnerText: $0.text, verdict: .noise, claimID: nil, tier: nil, matchedTerms: [], missingTerms: [])
            }, best: [:], issues: [UnderstandingIssue(kind: .nonsense)])
        }

        var statements: [StatementDiagnosis] = []
        var issues: [UnderstandingIssue] = []
        var best: [String: (coverage: ClaimCoverage, missing: MissingElement?, text: String)] = [:]
        func record(_ rubric: ClaimRubric, _ coverage: ClaimCoverage, _ missing: MissingElement?, _ text: String) {
            guard rubric.claim.role == .core else { return }
            let rank: [ClaimCoverage: Int] = [.missing: 0, .partial: 1, .covered: 2, .contradicted: 3]
            if let existing = best[rubric.claim.id], rank[existing.coverage]! >= rank[coverage]! { return }
            best[rubric.claim.id] = (coverage, missing, text)
        }
        let own = rubrics + supporting
        let ownConcept = target.concept

        for clause in clauses {
            if Self.isKeywordList(clause.text) {
                statements.append(StatementDiagnosis(learnerText: clause.text, verdict: .noise, claimID: nil, tier: nil, matchedTerms: [], missingTerms: []))
                continue
            }
            let penalties = subjectPenalties(clause, own)
            let alignments = own.enumerated().map { Alignment(clause: clause, rubric: $1, context: context, subjectPenalty: penalties[$0]) }

            // 1. Opposite of a source claim, or its direction reversed.
            // One clause, one misconception: the most central claim it contradicts (core before
            // supporting, then the target's own order, which puts the definition first).
            if let strongest = alignments.enumerated().filter({ $0.element.contradicts })
                .min(by: { ($0.element.rubric.claim.role == .core ? 0 : 1, $0.offset) < ($1.element.rubric.claim.role == .core ? 0 : 1, $1.offset) })?.element {
                record(strongest.rubric, .contradicted, nil, clause.text)
                issues.append(UnderstandingIssue(kind: .contradiction, claimID: strongest.rubric.claim.id, learnerText: clause.text))
                // The same words may be another concept's definition: "Throttling waits until events stop".
                if let ownConcept, let rival = strongestRival(clause, context: context, own: ownConcept) {
                    issues.append(UnderstandingIssue(kind: .confusedConcept, claimID: rival.claim?.id, relatedConcept: rival.concept, learnerText: clause.text))
                }
                statements.append(strongest.statement(.contradicts)); continue
            }
            if let reversal = alignments.filter(\.reversed).max(by: { $0.score < $1.score }) {
                record(reversal.rubric, .contradicted, nil, clause.text)
                issues.append(UnderstandingIssue(kind: .causalReversal, claimID: reversal.rubric.claim.id, learnerText: clause.text))
                statements.append(reversal.statement(.reverses)); continue
            }
            let covering = alignments.compactMap { alignment in alignment.coverage.map { (alignment, $0) } }
            // 2. Circular: the concept explained by its own name.
            if let concept = context.circularConcept(clause), !covering.contains(where: { $0.1 == .covered || $0.0.recall >= 0.5 }) {
                issues.append(UnderstandingIssue(kind: .circular, relatedConcept: concept, learnerText: clause.text))
                statements.append(StatementDiagnosis(learnerText: clause.text, verdict: .circular, claimID: nil, tier: .lexical,
                                                     matchedTerms: [], missingTerms: [])); continue
            }
            // 3. Confusion: this concept described in another concept's words.
            if let ownConcept, context.refersToTarget(clause), !covering.contains(where: { $0.1 == .covered }),
               let rival = strongestRival(clause, context: context, own: ownConcept) {
                issues.append(UnderstandingIssue(kind: .confusedConcept, claimID: rival.claim?.id, relatedConcept: rival.concept, learnerText: clause.text))
                statements.append(StatementDiagnosis(learnerText: clause.text, verdict: .confuses, claimID: rival.claim?.id, tier: .lexical,
                                                     matchedTerms: [], missingTerms: [])); continue
            }
            // Passage mode: a page claim attributed to the wrong subject.
            if ownConcept == nil, covering.isEmpty, let subject = clause.subject {
                let rivals = competitors.map { Alignment(clause: clause, rubric: $0, context: context) }
                if let rival = rivals.filter({ $0.recall >= 0.5 && $0.precision >= 0.6 && $0.rubric.subjectOverlap(subject) < 0.34 }).max(by: { $0.score < $1.score }),
                   own.allSatisfy({ $0.subjectOverlap(subject) < 0.5 }) == false {
                    issues.append(UnderstandingIssue(kind: .confusedConcept, claimID: rival.rubric.claim.id,
                                                     relatedConcept: rival.rubric.claim.concept, learnerText: clause.text))
                    statements.append(rival.statement(.confuses)); continue
                }
            }
            // 4. Coverage of every claim this clause expresses.
            guard let top = covering.max(by: { ($0.1 == .covered ? 1 : 0, $0.0.score) < ($1.1 == .covered ? 1 : 0, $1.0.score) }) else {
                let consistent = ownConcept.map { context.precision(clause, against: $0) } ?? (own.map { Alignment(clause: clause, rubric: $0, context: context).precision }.max() ?? 0)
                if consistent >= 0.6 && clause.complement.count >= 2 {
                    statements.append(StatementDiagnosis(learnerText: clause.text, verdict: .partiallySupports, claimID: nil, tier: .lexical,
                                                         matchedTerms: [], missingTerms: [])); continue
                }
                issues.append(UnderstandingIssue(kind: .unsupported, learnerText: clause.text))
                statements.append(StatementDiagnosis(learnerText: clause.text, verdict: .unsupported, claimID: nil, tier: nil,
                                                     matchedTerms: [], missingTerms: [])); continue
            }
            for (alignment, coverage) in covering {
                record(alignment.rubric, coverage, alignment.missingElement, clause.text)
                if alignment.overgeneralizes {
                    issues.append(UnderstandingIssue(kind: .overgeneralization, claimID: alignment.rubric.claim.id, learnerText: clause.text))
                }
            }
            var verdict: StatementVerdict = top.1 == .covered ? .supports : .partiallySupports
            if top.0.overgeneralizes { verdict = .overgeneralizes }
            if top.0.verbatim { issues.append(UnderstandingIssue(kind: .verbatim, claimID: top.0.rubric.claim.id, learnerText: clause.text)); verdict = .restates }
            statements.append(top.0.statement(verdict))
        }
        // Whole-text coverage: one idea can span clauses ("an index ... ; without one, big queries ...").
        let whole = LearnerClause(text)
        let wholePenalties = subjectPenalties(whole, rubrics)
        for (index, rubric) in rubrics.enumerated() where best[rubric.claim.id]?.coverage != .covered && best[rubric.claim.id]?.coverage != .contradicted {
            let alignment = Alignment(clause: whole, rubric: rubric, context: context, subjectPenalty: wholePenalties[index])
            if alignment.coverage == .covered, !issues.contains(where: { $0.kind == .confusedConcept }) {
                record(rubric, .covered, nil, text)
            }
        }
        issues = Array(NSOrderedSet(array: issues).array as! [UnderstandingIssue])
        return finish(target: target, rubrics: rubrics, statements: statements, best: best, issues: issues)
    }

    /// Another concept whose grounded wording explains the clause far better than the target's.
    private func strongestRival(_ clause: LearnerClause, context: AlignmentContext, own: ConceptKey) -> (concept: ConceptKey, claim: LearningClaim?)? {
        let ownPrecision = context.precision(clause, against: own)
        // Two shared words ("transaction", "slow") are not enough to name what was confused.
        guard let rival = context.conceptProfiles.keys.filter({ $0 != own })
            .map({ ($0, context.evidence(clause, against: $0)) }).max(by: { ($0.1.precision, $1.0.value) < ($1.1.precision, $0.0.value) }),
              rival.1.precision >= 0.75, rival.1.matched >= 2.5, rival.1.precision >= ownPrecision + 0.25 else { return nil }
        let stems = LexicalProfile(clause.text).stems
        let claim = context.target.competitors.filter { AlignmentContext.owner(of: $0, names: context.target.names) == rival.0 }
            .max { stems.intersection(LexicalProfile($0.statement).stems).count < stems.intersection(LexicalProfile($1.statement).stems).count }
        return (rival.0, claim)
    }

    /// When another claim's subject fits the learner's subject clearly better and shares its head
    /// noun ("a block body" vs "an expression body"), the weaker claim's subject evidence is halved.
    private func subjectPenalties(_ clause: LearnerClause, _ rubrics: [ClaimRubric]) -> [Double] {
        guard let subject = clause.subject else { return rubrics.map { _ in 1 } }
        let overlaps = rubrics.map { $0.subjectOverlap(subject) }
        return rubrics.enumerated().map { index, rubric in
            let head = rubric.subject.last?.stem
            let better = rubrics.enumerated().contains { other, candidate in
                other != index && overlaps[other] > overlaps[index] + 0.2 && candidate.subject.last?.stem == head
            }
            return better ? 0.5 : 1
        }
    }

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

    private func isNoise(_ text: String, target: DiagnosisTarget) -> Bool {
        let words = Lexicon.words(Lexicon.normalizePhrases(text)).filter { $0.first?.isLetter == true }
        guard !words.isEmpty else { return true }
        let vocabulary = Set(target.allClaims.flatMap { LexicalProfile($0.statement).terms.map(\.stem) })
        let known = words.filter { Lexicon.common.contains(Lexicon.stem($0)) || vocabulary.contains(Lexicon.stem($0)) ||
            ClauseLexicon.forms[$0] != nil || Lexicon.familyIndex[Lexicon.stem($0)] != nil }
        return Double(known.count) / Double(words.count) < 0.34
    }

    private func finish(target: DiagnosisTarget, rubrics: [ClaimRubric], statements: [StatementDiagnosis],
                        best: [String: (coverage: ClaimCoverage, missing: MissingElement?, text: String)],
                        issues rawIssues: [UnderstandingIssue]) -> UnderstandingDiagnosis {
        var issues = rawIssues
        let assessments = rubrics.filter { $0.claim.role == .core }.map { rubric -> ClaimAssessment in
            let found = best[rubric.claim.id]
            return ClaimAssessment(claimID: rubric.claim.id, coverage: found?.coverage ?? .missing,
                                   missing: found?.missing, learnerText: found?.text)
        }
        let totalWeight = rubrics.filter { $0.claim.role == .core }.reduce(0) { $0 + $1.weight }
        let earned = rubrics.filter { $0.claim.role == .core }.reduce(0.0) { sum, rubric in
            switch best[rubric.claim.id]?.coverage {
            case .covered?: return sum + rubric.weight
            case .partial?: return sum + rubric.weight * 0.5
            default: return sum
            }
        }
        let coverage = totalWeight > 0 ? earned / totalWeight : 0
        let substantive = !issues.contains { $0.kind == .nonsense }
        if substantive {
            for assessment in assessments where assessment.coverage == .missing {
                issues.append(UnderstandingIssue(kind: .missingKeyIdea, claimID: assessment.claimID))
            }
            for assessment in assessments where assessment.coverage == .partial && assessment.missing == .condition &&
                !issues.contains(where: { $0.kind == .overgeneralization && $0.claimID == assessment.claimID }) {
                issues.append(UnderstandingIssue(kind: .droppedCondition, claimID: assessment.claimID, learnerText: assessment.learnerText))
            }
        }
        let level = Self.level(issues: issues, coverage: coverage, statements: statements)
        let referenced = target.allClaims
        let draft = UnderstandingDiagnosis(version: UnderstandingDiagnosis.version, concept: target.concept, conceptName: target.conceptName,
            statements: statements, claims: assessments, issues: issues, level: level, coverage: coverage,
            intervention: .placeholder, referencedClaims: referenced)
        let intervention = InterventionPlanner().plan(draft, target: target)
        return UnderstandingDiagnosis(version: draft.version, concept: draft.concept, conceptName: draft.conceptName,
            statements: statements, claims: assessments, issues: issues, level: level, coverage: coverage,
            intervention: intervention, referencedClaims: Self.referenced(draft, intervention: intervention, all: referenced))
    }

    /// Keep only claims the diagnosis actually points at, so persisted diagnoses stay small.
    private static func referenced(_ diagnosis: UnderstandingDiagnosis, intervention: LearningIntervention, all: [LearningClaim]) -> [LearningClaim] {
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
