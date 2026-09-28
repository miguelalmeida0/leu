import Foundation

/// What the semantic reader makes of one clause: the claim it reads best in other words, whether
/// that claim passes the gate, how clearly it beats the next reading, and the concept whose
/// wording explains the clause.
struct SemanticClauseReading: Sendable {
    /// The claim the clause expresses in other words (nil when the gate refuses it), and the claim
    /// it reads closest to either way.
    let claimID: String?
    let closest: String?
    let coverage: ClaimCoverage?
    let evidence: SemanticEvidence
    /// The share of the clause the closest claim's wording explains, and the balance of that with
    /// how much of the claim the clause says (`evidence.recall`): how the closest claim is chosen.
    let share: Double
    let fit: Double
    /// Best fit minus the next claim's fit.
    let margin: Double
    /// Why the closest claim was refused, in the order checked (the gate's checks, then the reader's).
    let blocks: [SemanticGate.Block]
    /// The clause says the closest claim with its sense reversed (`SemanticGate.reversesSense`).
    let reversesSense: Bool
    /// How much of the clause the target's wording explains, and the best other concept's.
    let ownShare: Double
    let rival: ConceptKey?
    let rivalShare: Double
    /// How much of the clause the rival explains, in weighted words (two distinctive words are 2).
    let rivalMatched: Double
}

/// The semantic side of the reader. For each clause it finds the claim the clause says best in
/// other words, submits it to `SemanticGate`, and reads which concept the clause is about.
/// Transient: it feeds the judgement and never the stored diagnosis, so it can change what Leu
/// believes and asks, never what it records.
struct SemanticReader {
    let space: SemanticSpace
    let context: AlignmentContext

    /// The clause's content words, without the words that only name the target concept.
    func learnerTerms(_ clause: LearnerClause) -> [LexicalTerm] {
        clause.assertedProfile.terms.filter { term in !(context.target.concept.map { context.mentions(term.surface, $0) } ?? false) }
    }

    func read(_ clause: LearnerClause, alignments: [Alignment]) -> SemanticClauseReading {
        let terms = learnerTerms(clause)
        // Recall alone favours short claims (two matched words are all of them); the clause's share
        // alone favours long ones. Their balance picks the claim the clause is about.
        let scored = alignments.map { alignment -> (alignment: Alignment, evidence: SemanticEvidence, share: Double, fit: Double) in
            let evidence = SemanticMatcher.evidence(claim: alignment.rubric.complement, learner: terms,
                                                    lexical: { clause.profile.match($0) }, space: space)
            let share = SemanticMatcher.share(of: terms, in: alignment.rubric.profile.terms, space: space)
            let fit = evidence.recall + share > 0 ? 2 * evidence.recall * share / (evidence.recall + share) : 0
            return (alignment, evidence, share, fit)
        }.sorted { ($0.fit, $1.alignment.rubric.claim.id) > ($1.fit, $0.alignment.rubric.claim.id) }
        let best = scored.first
        let gate = best.map { SemanticGate($0.alignment, evidence: $0.evidence, space: space, context: context) }
        var ownShare = 0.0, rival: ConceptKey?, rivalShare = 0.0, rivalMatched = 0.0
        if let own = context.target.concept {
            for (concept, profile) in context.conceptProfiles {
                let (share, matched) = SemanticMatcher.explained(terms, by: profile.terms, space: space)
                if concept == own { ownShare = share }
                else if share > rivalShare || (share == rivalShare && rival.map { concept.value < $0.value } == true) {
                    rival = concept; rivalShare = share; rivalMatched = matched
                }
            }
        }
        let closest = best?.alignment.rubric.claim.id
        // A clause another concept's wording clearly explains better, where the target's explains
        // it poorly (the lexical reader's own rule), is not credited to the target in other words:
        // the doubt about which concept it describes comes first.
        let rivalExplains = rival != nil && ownShare < JudgementReading.ownShare && rivalShare >= ownShare + SemanticThresholds.rivalMargin &&
            rivalShare >= SemanticThresholds.rivalShare && rivalMatched >= JudgementReading.rivalWeight
        // Two claims the clause fits about equally well: it is not clear which one it says.
        let margin = (best?.fit ?? 0) - (scored.dropFirst().first?.fit ?? 0)
        let blocks = (gate?.blocks ?? []) + (rivalExplains ? [.rival] : []) + (margin < SemanticThresholds.margin ? [.ambiguous] : [])
        let coverage = blocks.isEmpty ? gate?.coverage : nil
        return SemanticClauseReading(claimID: coverage == nil ? nil : closest, closest: closest, coverage: coverage,
                                     evidence: best?.evidence ?? .none, share: best?.share ?? 0, fit: best?.fit ?? 0,
                                     margin: margin, blocks: blocks,
                                     reversesSense: gate?.reversesSense ?? false, ownShare: ownShare, rival: rival, rivalShare: rivalShare,
                                     rivalMatched: rivalMatched)
    }
}

/// A reason a clause gives for what it says ("..., because the database saves earlier answers"),
/// and whether the source says it, in its words or in others.
struct ReasonReading: Sendable {
    let text: String
    let supported: Bool
}

extension SemanticReader {
    /// Words after which a clause gives its reason.
    static let reasonMarker = try! NSRegularExpression(
        pattern: #"(?i)(?:\b(?:because|since|due to|thanks to|as a result of|the reason (?:is|being|why)|b/c|cuz|coz|"#
            + #"(?:follows|results|stems) from|is caused by|falls (?:\w+ )?out of)\b|'cause\b)"#)

    /// The reason the clause gives, if it gives one with some content (two distinctive words), and
    /// whether any claim of the source (core or supporting) says it: its words credit the claim, or
    /// the gate lets them express it in other words.
    func reason(in clause: LearnerClause, own: [ClaimRubric]) -> ReasonReading? {
        let text = clause.text
        guard let match = Self.reasonMarker.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range, in: text) else { return nil }
        let given = String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        let part = LearnerClause(given)
        guard part.profile.terms.filter({ $0.weight == 1 }).count >= 2 else { return nil }
        let alignments = own.map { Alignment(clause: part, rubric: $0, context: context) }
        let supported = alignments.contains { $0.coverage != nil && !$0.contradicts && !$0.reversed } || read(part, alignments: alignments).coverage != nil
        return ReasonReading(text: given, supported: supported)
    }
}

extension DiagnosisSignals {
    /// Credits what the clauses express in other words on top of the lexical coverage and derives
    /// the level the answer would have with it — the same weights and level rules as the diagnosis
    /// itself. Only missing or partial claims can rise; a contradicted claim stays contradicted.
    mutating func readSemanticLevel(rubrics: [ClaimRubric], lexical: [String: ClaimCoverage], issues: [UnderstandingIssue],
                                    statements: [StatementDiagnosis]) {
        var merged = lexical
        for signal in clauses {
            guard let reading = signal.semantic, let id = reading.claimID, let coverage = reading.coverage else { continue }
            switch merged[id] {
            case .contradicted?, .covered?: continue
            case .partial? where coverage == .partial: continue
            default: merged[id] = coverage
            }
        }
        semanticCoverage = merged.filter { lexical[$0.key] != $0.value }
        guard !semanticCoverage.isEmpty else { return }
        let core = rubrics.filter { $0.claim.role == .core }
        let total = core.reduce(0) { $0 + $1.weight }
        let earned = core.reduce(0.0) { sum, rubric in
            switch merged[rubric.claim.id] {
            case .covered?: return sum + rubric.weight
            case .partial?: return sum + rubric.weight * 0.5
            default: return sum
            }
        }
        semanticLevel = UnderstandingDiagnoser.level(issues: issues, coverage: total > 0 ? earned / total : 0, statements: statements)
    }
}
