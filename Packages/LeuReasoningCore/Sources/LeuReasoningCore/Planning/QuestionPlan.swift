import Foundation

/// The understanding operation a question should exercise.
///
/// This package plans operations; it never writes question text. Realisation
/// (wording, format, distractors) belongs to the question layer.
public enum UnderstandingOperation: String, Codable, CaseIterable, Sendable {
    case explainMechanism
    case predictConsequence
    case distinguishConcepts
    case identifyMissingCondition
    case traceCausalChain
    case transferPrinciple
    case diagnoseFailure
    case compareTradeoffs
    case reconstructSequence
}

/// What a question should be *about*, and why that is worth asking now.
public struct QuestionPlan: Codable, Equatable, Sendable, Identifiable {
    public var id: StableID
    public var operation: UnderstandingOperation
    public var concept: String
    /// The specific thing the question must make the learner produce.
    public var target: String
    public var atomIDs: [StableID]
    public var relationIDs: [StableID]
    /// 0…1. Higher means more valuable to ask next.
    public var priority: Double
    public var reason: SuggestionReason
    /// What a correct answer must contain, expressed as source claims.
    public var answerMustInclude: [GroundedLine]

    public init(operation: UnderstandingOperation,
                concept: String,
                target: String,
                atomIDs: [StableID],
                relationIDs: [StableID],
                priority: Double,
                reason: SuggestionReason,
                answerMustInclude: [GroundedLine]) {
        self.id = StableID(namespace: "qplan", components: [operation.rawValue, concept, target])
        self.operation = operation
        self.concept = concept
        self.target = target
        self.atomIDs = atomIDs
        self.relationIDs = relationIDs
        self.priority = priority
        self.reason = reason
        self.answerMustInclude = answerMustInclude
    }
}

/// Decides which understanding operations are worth exercising, from what the
/// sources actually contain and what the learner has explicitly done.
public struct QuestionPlanner: Sendable {
    public init() {}

    public func plan(concept: String,
                     in graph: KnowledgeGraph,
                     state: UnderstandingState = UnderstandingState(),
                     alignment: ExplanationAlignmentReport? = nil,
                     limit: Int = 6) -> [QuestionPlan] {
        let atoms = ConceptCompressor().relevantAtoms(for: concept, in: graph)
        guard !atoms.isEmpty else { return [] }
        var plans: [QuestionPlan] = []

        // 1. Conditions are the highest-value target: they are what learners
        //    drop, and dropping them is what makes an explanation wrong.
        for atom in atoms where !atom.conditions.isEmpty {
            guard let condition = atom.conditions.first else { continue }
            let learnerMissedIt = alignment?.findings.contains {
                $0.type == .missingCondition && $0.atomID == atom.id
            } ?? false
            plans.append(QuestionPlan(operation: .identifyMissingCondition,
                                      concept: concept,
                                      target: condition.text,
                                      atomIDs: [atom.id],
                                      relationIDs: [],
                                      priority: learnerMissedIt ? 0.98 : 0.8,
                                      reason: SuggestionReason(
                                        cause: learnerMissedIt ? .yourExplanation : .sourceStatesACondition,
                                        text: learnerMissedIt
                                            ? "Because your explanation left out the condition \"\(condition.text)\"."
                                            : "Because your source states this only when \(condition.text).",
                                        evidence: [atom.id],
                                        provenance: atom.provenance),
                                      answerMustInclude: [GroundedLine.fromAtom(atom)]))
        }

        // 2. Mechanism and causal chains, where the graph actually has depth.
        let chainEngine = CausalChainEngine()
        for atom in atoms.prefix(6) {
            for chain in chainEngine.chains(from: atom.subject, in: graph).prefix(1) {
                guard chain.length >= 3 else { continue }
                let line = GroundedLine(text: chain.rendered,
                                        atomIDs: chain.links.compactMap(\.viaRelation),
                                        admissibility: chain.admissibility,
                                        provenance: chain.provenance)
                plans.append(QuestionPlan(operation: .traceCausalChain,
                                          concept: concept,
                                          target: chain.links.map(\.label).joined(separator: " → "),
                                          atomIDs: [atom.id],
                                          relationIDs: chain.links.compactMap(\.viaRelation),
                                          priority: 0.75,
                                          reason: SuggestionReason(cause: .currentPassageDependsOnIt,
                                                                   text: "Because your source connects \(chain.links.first?.label ?? concept) to \(chain.links.last?.label ?? "") through \(chain.length - 1) stated steps.",
                                                                   evidence: chain.links.compactMap(\.viaRelation),
                                                                   provenance: chain.provenance),
                                          answerMustInclude: [line]))
            }
        }
        for atom in atoms where atom.claimType == .mechanism {
            plans.append(QuestionPlan(operation: .explainMechanism,
                                      concept: concept,
                                      target: "\(atom.subject) → \(atom.object)",
                                      atomIDs: [atom.id],
                                      relationIDs: [],
                                      priority: 0.7,
                                      reason: SuggestionReason(cause: .sourceStatesACondition,
                                                               text: "Because your source explains how \(atom.subject) produces \(atom.object).",
                                                               evidence: [atom.id],
                                                               provenance: atom.provenance),
                                      answerMustInclude: [GroundedLine.fromAtom(atom)]))
        }

        // 3. Failure modes, trade-offs, distinctions, sequences, transfer.
        for atom in atoms where atom.claimType == .failureMode {
            plans.append(make(.diagnoseFailure, concept: concept, atom: atom, priority: 0.85,
                              reasonText: "Because your source names a way this fails."))
        }
        for atom in atoms where atom.claimType == .tradeoff {
            plans.append(make(.compareTradeoffs, concept: concept, atom: atom, priority: 0.72,
                              reasonText: "Because your source states a cost as well as a benefit."))
        }
        for atom in atoms where atom.claimType == .distinction {
            plans.append(make(.distinguishConcepts, concept: concept, atom: atom, priority: 0.68,
                              reasonText: "Because your source contrasts this with something close to it."))
        }
        for atom in atoms where atom.claimType == .sequence {
            plans.append(make(.reconstructSequence, concept: concept, atom: atom, priority: 0.66,
                              reasonText: "Because your source states an order that matters."))
        }
        for atom in atoms where atom.claimType == .consequence {
            plans.append(make(.predictConsequence, concept: concept, atom: atom, priority: 0.7,
                              reasonText: "Because your source states what follows from this."))
        }
        for relation in graph.relations where relation.kind == .samePrincipleAs {
            let documents = Set(relation.provenance.spans.map(\.documentID))
            guard documents.count > 1 else { continue }
            guard let subject = graph.node(relation.subject.id), let object = graph.node(relation.object.id) else { continue }
            guard TextScanning.coverage(of: concept, in: "\(subject.label) \(object.label)") >= 0.5 else { continue }
            plans.append(QuestionPlan(operation: .transferPrinciple,
                                      concept: concept,
                                      target: "\(subject.label) ⇄ \(object.label)",
                                      atomIDs: relation.supportingAtoms,
                                      relationIDs: [relation.id],
                                      priority: 0.6,
                                      reason: SuggestionReason(cause: .anotherSourceExplainsIt,
                                                               text: "Because two of your sources describe the same principle in different settings.",
                                                               evidence: [relation.id],
                                                               provenance: relation.provenance),
                                      answerMustInclude: []))
        }

        // 4. Explicit learner signals raise priority; resolved concepts drop out.
        plans = plans.map { plan in
            var adjusted = plan
            if state.unresolvedQuestions.contains(where: { $0.concept == concept }) {
                adjusted.priority = min(1.0, adjusted.priority + 0.1)
            }
            if state.isResolved(concept) {
                adjusted.priority = max(0.0, adjusted.priority - 0.3)
            }
            return adjusted
        }

        var deduplicated: [QuestionPlan] = []
        for plan in plans.sorted(by: { lhs, rhs in
            if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
            return lhs.id.rawValue < rhs.id.rawValue
        }) where !deduplicated.contains(where: { $0.id == plan.id }) {
            deduplicated.append(plan)
        }
        return Array(deduplicated.prefix(limit))
    }

    func make(_ operation: UnderstandingOperation,
              concept: String,
              atom: KnowledgeAtom,
              priority: Double,
              reasonText: String) -> QuestionPlan {
        QuestionPlan(operation: operation,
                     concept: concept,
                     target: "\(atom.subject) \(atom.relation) \(atom.object)",
                     atomIDs: [atom.id],
                     relationIDs: [],
                     priority: priority,
                     reason: SuggestionReason(cause: .sourceStatesACondition,
                                              text: reasonText,
                                              evidence: [atom.id],
                                              provenance: atom.provenance),
                     answerMustInclude: [GroundedLine.fromAtom(atom)])
    }
}
