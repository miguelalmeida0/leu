import Foundation

/// A concept a passage or question is about, with the grounded claims that make it so.
public struct ConceptReference: Equatable, Sendable {
    public let id: LearnerConceptID
    public let name: String
    public let claims: [LearningClaim]
}

/// Turns study interactions into learner-model evidence. Only grounded concepts receive
/// evidence: when a source has no compiled claims, the model learns nothing rather than guessing.
public struct LearnerEvidenceMapper: Sendable {
    public let knowledge: ConceptKnowledgeBase
    private let byPage: [String: [LearningClaim]]
    public init(knowledge: ConceptKnowledgeBase) {
        self.knowledge = knowledge
        byPage = Dictionary(grouping: knowledge.claims, by: { "\($0.evidence.documentID)|\($0.evidence.pageIndex)" })
    }

    /// Core claims inside a passage (exact range when known, else its normalised text).
    func claims(within source: LearningSource) -> [LearningClaim] {
        let page = (byPage["\(source.documentID)|\(source.pageIndex)"] ?? []).filter { $0.role == .core }
        if let range = source.range, range.length > 0 {
            return page.filter { $0.evidence.range.location >= range.location &&
                $0.evidence.range.location + $0.evidence.range.length <= range.location + range.length }
        }
        let passage = CanonicalWhitespaceResolver.normalize(source.sourceText)
        return page.filter { passage.contains(CanonicalWhitespaceResolver.normalize($0.evidence.text)) }
    }

    /// Concepts a passage teaches, most claims first (at most three). A passage without claims of
    /// its own (a heading, a memory hook) belongs to the concept cards of its page.
    public func concepts(in source: LearningSource) -> [ConceptReference] {
        var inside = claims(within: source)
        if inside.isEmpty {
            inside = (byPage["\(source.documentID)|\(source.pageIndex)"] ?? []).filter { $0.role == .core && $0.topic != nil }
        }
        let grouped = Dictionary(grouping: inside, by: { $0.topic ?? $0.concept })
        return grouped.sorted { lhs, rhs in
            (lhs.value.count, -(lhs.value.map(\.evidence.range.location).min() ?? 0)) > (rhs.value.count, -(rhs.value.map(\.evidence.range.location).min() ?? 0))
        }.prefix(3).map { key, claims in reference(key, documentID: source.documentID, claims: claims) }
    }

    /// The concept a question tests: the grounded claim that best matches its prompt and answer.
    public func concept(for question: LearningQuestion) -> ConceptReference? {
        let answer = question.correctOption?.text ?? ""
        // "Which concept is described as …?" — the answer is the concept's own name.
        let named = ConceptKey(answer)
        if knowledge.concept(named) != nil, !knowledge.claims(teaching: named).isEmpty,
           knowledge.claims(teaching: named).contains(where: { $0.evidence.documentID == question.source.documentID }) {
            return reference(named, documentID: question.source.documentID, claims: knowledge.claims(teaching: named))
        }
        let words = LexicalProfile(question.prompt + " " + answer).stems
        let candidates = knowledge.claims(within: question.source, roles: [.core, .supporting])
        let pool = candidates.isEmpty ? knowledge.claims(onPage: question.source.documentID, pageIndex: question.source.pageIndex) : candidates
        let scored = pool.map { claim in (claim, LexicalProfile(claim.statement).stems.intersection(words).count) }
            .filter { candidates.isEmpty ? $0.1 >= 2 : $0.1 >= 1 }
        guard let best = scored.max(by: { ($0.1, -$0.0.evidence.range.location) < ($1.1, -$1.0.evidence.range.location) })?.0 else { return nil }
        let key = best.topic ?? best.concept
        return reference(key, documentID: question.source.documentID, claims: knowledge.claims(teaching: key).filter { $0.evidence.documentID == question.source.documentID })
    }

    public static func operation(for question: LearningQuestion) -> ProbeOperation {
        switch question.kind {
        case .definition, .termMatching, .fillKeyConcept, .cloze: return .recognizeDefinition
        case .codeInterpretation: return .applyExample
        case .sourceStatement, .listMembership: return .sourceQuestion
        case .semanticRelationship:
            switch question.semanticOperator {
            case "purpose": return .purpose
            case "distinguish": return .contrast
            case "application", "debugging": return .applyExample
            default: return .mechanism
            }
        }
    }

    /// An answered multiple-choice question. A wrong answer carries what its distractor reveals.
    public func evidence(answering question: LearningQuestion, selected: UUID?, confidence: ConfidenceLevel?,
                         operation: ProbeOperation? = nil, probeID: String? = nil, at date: Date,
                         startsObjective: RemediationObjective? = nil) -> [LearningEvidence] {
        guard let selected, let option = question.options.first(where: { $0.id == selected }),
              let tested = concept(for: question) else { return [] }
        let correct = selected == question.correctOptionID
        let distractor = correct ? nil : DistractorAnalysis.analyze(question: question, selected: option, tested: tested, in: knowledge)
        let observation = distractor.flatMap { analysis in
            analysis.kind.map { MisconceptionObservation(kind: $0, claimID: analysis.claimID, relatedConcept: analysis.relatedConcept,
                                                         learnerWording: option.text) }
        }
        // The concepts offered beside the answer: choosing right among them tells them apart.
        let rivals = question.options.filter { $0.id != question.correctOptionID }.map { ConceptKey($0.text) }
            .filter { $0 != tested.id.concept && knowledge.concept($0) != nil }
        return [LearningEvidence(concept: tested.id, conceptName: tested.name, operation: operation ?? Self.operation(for: question),
                                 outcome: correct ? .correct : .incorrect, channel: .choice, confidence: confidence,
                                 claimIDs: tested.claims.filter { question.source.range == nil || $0.evidence.pageIndex == question.source.pageIndex }.prefix(4).map(\.id),
                                 misconception: observation, probeID: probeID, occurredAt: date, startsObjective: startsObjective, rivals: rivals)]
    }

    /// "Forgot / Difficult / Knew it" after an open probe: the learner's own read of that question.
    public func evidence(rating probe: LearningProbe, rating: RecallRating, at date: Date,
                         startsObjective: RemediationObjective? = nil) -> [LearningEvidence] {
        let outcome: EvidenceOutcome = rating == .knewIt ? .correct : rating == .difficult ? .partial : .incorrect
        return [LearningEvidence(concept: probe.concept, conceptName: probe.conceptName, operation: probe.operation, outcome: outcome,
                                 channel: .selfRating, claimIDs: probe.rubricClaimIDs, probeID: probe.id,
                                 occurredAt: date, startsObjective: startsObjective, rivals: probe.relatedConcept.map { [$0] } ?? [])]
    }

    /// A revealed recall card, answered once. Typed recall compared with the source speaks for
    /// the answer; the learner's own rating stands in only when nothing was typed.
    public func evidence(recall source: LearningSource, rating: RecallRating, probe: LearningProbe?, diagnosis: UnderstandingDiagnosis?,
                         at date: Date, startsObjective: RemediationObjective? = nil) -> [LearningEvidence] {
        let compared = diagnosis.map {
            evidence(from: $0, documentID: source.documentID, operation: probe?.operation, probeID: probe?.id,
                     rivals: probe?.relatedConcept.map { [$0] } ?? [], at: date, startsObjective: startsObjective)
        } ?? []
        if !compared.isEmpty { return compared }
        if let probe { return evidence(rating: probe, rating: rating, at: date, startsObjective: startsObjective) }
        return evidence(recalling: source, rating: rating, at: date)
    }

    /// "Forgot / Difficult / Knew it" after revealing a passage: the learner's own read, half weight.
    public func evidence(recalling source: LearningSource, rating: RecallRating, operation: ProbeOperation = .define,
                         probeID: String? = nil, at date: Date) -> [LearningEvidence] {
        let outcome: EvidenceOutcome = rating == .knewIt ? .correct : rating == .difficult ? .partial : .incorrect
        return concepts(in: source).map { reference in
            LearningEvidence(concept: reference.id, conceptName: reference.name, operation: operation, outcome: outcome,
                             channel: .selfRating, claimIDs: reference.claims.prefix(4).map(\.id), probeID: probeID, occurredAt: date)
        }
    }

    /// A diagnosed explanation. One observation per concept and operation, so one explanation of
    /// four mechanism claims is one piece of evidence, not four. Misconceptions travel separately.
    /// `rivals` are the concepts the question asked to tell apart; `identity` names the attempt,
    /// so comparing the same attempt again adds nothing.
    public func evidence(from diagnosis: UnderstandingDiagnosis, documentID: UUID, operation: ProbeOperation? = nil,
                         probeID: String? = nil, rivals: [ConceptKey] = [], identity: String? = nil, at date: Date,
                         startsObjective: RemediationObjective? = nil) -> [LearningEvidence] {
        guard diagnosis.level != .insufficient else { return [] }
        let verbatim = Set(diagnosis.issues.filter { $0.kind == .verbatim }.compactMap(\.claimID))
        var groups: [String: (reference: ConceptReference, operation: ProbeOperation, values: [Double], claims: [String])] = [:]
        var result: [LearningEvidence] = []
        func conceptOf(_ claim: LearningClaim) -> ConceptReference {
            let key = diagnosis.concept ?? claim.topic ?? claim.concept
            return reference(key, documentID: documentID, claims: knowledge.claims(teaching: key))
        }
        for assessment in diagnosis.claims where assessment.coverage != .missing {
            guard let claim = diagnosis.claim(assessment.claimID) else { continue }
            let reference = conceptOf(claim)
            let op = operation ?? FollowUps.operation(for: claim)
            if assessment.coverage == .contradicted {
                let issue = diagnosis.issues.first { $0.claimID == claim.id && [.contradiction, .causalReversal].contains($0.kind) }
                let kind: MisconceptionKind = issue?.kind == .causalReversal ? .reversal : .contradiction
                result.append(LearningEvidence(concept: reference.id, conceptName: reference.name, operation: op, outcome: .incorrect,
                    channel: .explanation, claimIDs: [claim.id], misconception: MisconceptionObservation(kind: kind, claimID: claim.id,
                    relatedConcept: nil, learnerWording: issue?.learnerText ?? assessment.learnerText ?? ""), probeID: probeID, occurredAt: date,
                rivals: rivals, identity: identity))
                continue
            }
            // Reproducing the source's words shows memory of the text, not yet understanding.
            let value = assessment.coverage == .covered && !verbatim.contains(claim.id) ? 1.0 : 0.5
            let key = "\(reference.id)|\(op.rawValue)"
            groups[key, default: (reference, op, [], [])].values.append(value)
            groups[key]!.claims.append(claim.id)
        }
        for issue in diagnosis.issues where issue.kind == .confusedConcept || issue.kind == .overgeneralization {
            let claim = diagnosis.claim(issue.claimID)
            guard let key = diagnosis.concept ?? claim.map({ $0.topic ?? $0.concept }) else { continue }
            let reference = reference(key, documentID: documentID, claims: knowledge.claims(teaching: key))
            let confusion = issue.kind == .confusedConcept
            result.append(LearningEvidence(concept: reference.id, conceptName: reference.name,
                operation: operation ?? (confusion ? .define : claim.map(FollowUps.operation(for:)) ?? .define),
                outcome: confusion ? .incorrect : .partial, channel: .explanation, claimIDs: claim.map { [$0.id] } ?? [],
                misconception: MisconceptionObservation(kind: confusion ? .confusion : .overgeneralization,
                    claimID: confusion ? nil : issue.claimID, relatedConcept: confusion ? issue.relatedConcept : nil,
                    learnerWording: issue.learnerText ?? ""), probeID: probeID, occurredAt: date,
                rivals: rivals, identity: identity))
        }
        for key in groups.keys.sorted() {
            let group = groups[key]!
            let mean = group.values.reduce(0, +) / Double(group.values.count)
            result.append(LearningEvidence(concept: group.reference.id, conceptName: group.reference.name, operation: group.operation,
                outcome: mean == 1 ? .correct : .partial, channel: .explanation, claimIDs: group.claims, probeID: probeID, occurredAt: date,
                rivals: rivals, identity: identity))
        }
        if !result.isEmpty { result[0].startsObjective = startsObjective }
        return result
    }

    func reference(_ key: ConceptKey, documentID: UUID, claims: [LearningClaim]) -> ConceptReference {
        let name = knowledge.concept(key)?.name ?? claims.first?.conceptName ?? key.value
        return ConceptReference(id: LearnerConceptID(documentID: documentID, concept: key), name: name,
                                claims: claims.filter { $0.evidence.documentID == documentID })
    }
}
