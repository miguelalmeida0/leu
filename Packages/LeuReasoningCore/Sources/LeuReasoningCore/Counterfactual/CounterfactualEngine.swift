import Foundation

/// The change a learner is asking about.
public enum KnowledgeChange: Codable, Equatable, Sendable {
    /// The thing is absent ("what if there were no cache?").
    case removed(String)
    /// The thing is present but no longer has the property the source requires
    /// ("what if the key is not stable?").
    case propertyLost(subject: String, property: String)
    /// A stated condition is false ("what if the failure is not transient?").
    case conditionFalse(String)
    /// The thing is swapped for something else the sources also describe.
    case replaced(String, with: String)

    public var focusText: String {
        switch self {
        case .removed(let text): return text
        case .propertyLost(let subject, _): return subject
        case .conditionFalse(let text): return text
        case .replaced(let text, _): return text
        }
    }
}

public enum ConsequencePolarity: String, Codable, CaseIterable, Sendable {
    /// The source states this depends on what changed, so it no longer holds.
    case noLongerHolds
    /// The source states a failure that follows from the change.
    case failureFollows
    /// The stated support is gone, but another source still supports it.
    case supportWeakenedButHolds
    /// The rule the source gives simply stops applying; nothing replaces it.
    case ruleNoLongerApplies
}

public struct CounterfactualConsequence: Codable, Equatable, Sendable {
    public var label: String
    public var polarity: ConsequencePolarity
    public var viaChain: CausalChain
    public var admissibility: Admissibility
    public var provenance: Provenance
    /// The one-line, source-anchored reason this consequence is listed.
    public var justification: String

    public init(label: String,
                polarity: ConsequencePolarity,
                viaChain: CausalChain,
                admissibility: Admissibility,
                provenance: Provenance,
                justification: String) {
        self.label = label
        self.polarity = polarity
        self.viaChain = viaChain
        self.admissibility = admissibility
        self.provenance = provenance
        self.justification = justification
    }
}

public struct CounterfactualResult: Codable, Equatable, Sendable {
    public var change: KnowledgeChange
    public var focusLabel: String?
    public var consequences: [CounterfactualConsequence]
    /// Edges the change switches off, listed so the reasoning is inspectable.
    public var invalidatedRelations: [StableID]
    /// Questions the sources cannot answer. Naming them is part of the answer.
    public var openQuestions: [String]
    public var unansweredReason: String?

    public init(change: KnowledgeChange,
                focusLabel: String?,
                consequences: [CounterfactualConsequence],
                invalidatedRelations: [StableID],
                openQuestions: [String],
                unansweredReason: String? = nil) {
        self.change = change
        self.focusLabel = focusLabel
        self.consequences = consequences
        self.invalidatedRelations = invalidatedRelations
        self.openQuestions = openQuestions
        self.unansweredReason = unansweredReason
    }
}

/// Bounded "what changes if…" reasoning.
///
/// The engine has no simulator and no world model. It does exactly one thing:
/// it switches off the graph edges the change invalidates, then reports what
/// the sources said those edges were holding up. Anything it cannot reach
/// through an existing edge becomes an open question instead of a prediction.
public struct CounterfactualEngine: Sendable {
    public var maxDepth: Int

    public init(maxDepth: Int = 3) {
        self.maxDepth = maxDepth
    }

    public func evaluate(_ change: KnowledgeChange, in graph: KnowledgeGraph) -> CounterfactualResult {
        switch change {
        case .conditionFalse(let condition):
            return evaluateCondition(condition, change: change, in: graph)
        case .removed, .propertyLost, .replaced:
            return evaluateNodeChange(change, in: graph)
        }
    }

    // MARK: - Node-level change

    func evaluateNodeChange(_ change: KnowledgeChange, in graph: KnowledgeGraph) -> CounterfactualResult {
        guard let focus = graph.resolveNode(change.focusText) else {
            return CounterfactualResult(change: change,
                                        focusLabel: nil,
                                        consequences: [],
                                        invalidatedRelations: [],
                                        openQuestions: [],
                                        unansweredReason: "No source in this library describes \"\(change.focusText)\".")
        }

        if case .propertyLost(_, let property) = change,
           !Set(TextScanning.normalizedTokens(property)).isSubset(of: Set(TextScanning.normalizedTokens(focus.label))) {
            return CounterfactualResult(change: change, focusLabel: focus.label, consequences: [], invalidatedRelations: [],
                                        openQuestions: ["The source does not establish that the named property licenses these relationships."],
                                        unansweredReason: "Unbound property: \(property)")
        }

        var invalidated: [StableID] = []
        var consequences: [CounterfactualConsequence] = []
        var openQuestions: [String] = []
        var frontier: [(node: StableID, chainLinks: [CausalLink], depth: Int)] = [
            (focus.id, [CausalLink(label: focus.label, provenance: seedProvenance(graph: graph, node: focus))], 0)
        ]
        var seen: Set<String> = [focus.id.rawValue]

        while let current = frontier.first {
            frontier.removeFirst()
            guard current.depth < maxDepth else { continue }
            // Forward: things this enables/causes lose their stated support.
            let forward = graph.outgoing(from: current.node)
                .filter { [.enables, .causes, .supports, .prevents, .reduces, .increases, .creates, .makes,
                           .keeps, .gives, .separates, .decouples, .replaces, .catches, .derives, .balances,
                           .trades, .updates, .smooths, .communicates, .computes, .centralizes, .improves,
                           .prerequisiteOf].contains($0.kind) }
                .sorted { $0.id.rawValue < $1.id.rawValue }
            // Backward: things that require this break outright.
            let backward = graph.incoming(to: current.node)
                .filter { $0.kind == .requires }
                .sorted { $0.id.rawValue < $1.id.rawValue }

            for relation in forward + backward {
                let isRequirement = relation.kind == .requires || relation.kind == .prerequisiteOf
                let nextID = relation.kind == .requires ? relation.subject.id : relation.object.id
                guard !seen.contains(nextID.rawValue), let next = graph.node(nextID) else { continue }
                seen.insert(nextID.rawValue)
                invalidated.append(relation.id)

                let link = CausalLink(label: next.label,
                                      viaRelation: relation.id,
                                      kind: relation.kind,
                                      conditions: relation.conditions,
                                      provenance: relation.provenance)
                let links = current.chainLinks + [link]
                let chainProvenance = Provenance.inferred(from: links.map(\.provenance),
                                                          ids: links.compactMap(\.viaRelation),
                                                          rule: isRequirement ? .contrapositiveOfRequirement : .supportWithdrawal)
                let chain = CausalChain(links: links,
                                        admissibility: .inferredValidated,
                                        provenance: chainProvenance)
                let polarity: ConsequencePolarity
                if isRequirement && relation.conditions.isEmpty && relation.qualifiers.isEmpty {
                    polarity = .noLongerHolds
                } else {
                    polarity = .ruleNoLongerApplies
                }
                let justification = justify(change: change,
                                            focusLabel: current.chainLinks.last?.label ?? focus.label,
                                            relation: relation,
                                            targetLabel: next.label,
                                            polarity: polarity)
                consequences.append(CounterfactualConsequence(label: next.label,
                                                              polarity: polarity,
                                                              viaChain: chain,
                                                              admissibility: .inferredValidated,
                                                              provenance: chainProvenance,
                                                              justification: justification))
                // Losing a sufficient cause, enabler or prevention is not proof
                // that its outcome is false (or that a failure will occur).
                // Only an unmet, unconditional necessary prerequisite propagates.
                if polarity == .noLongerHolds { frontier.append((nextID, links, current.depth + 1)) }
            }
        }

        if consequences.isEmpty {
            openQuestions.append("Your sources describe \"\(focus.label)\" but never say what depends on it, so Leu cannot say what changes.")
        } else if let deepest = consequences.map({ $0.viaChain.length }).max(), deepest >= maxDepth {
            openQuestions.append("Traversal reaches the configured limit of \(maxDepth) steps; further edges were not evaluated.")
        }

        if consequences.contains(where: { $0.polarity == .ruleNoLongerApplies }) {
            openQuestions.append("The source does not establish what happens instead when this support is removed.")
        }
        return CounterfactualResult(change: change,
                                    focusLabel: focus.label,
                                    consequences: consequences.sorted { $0.viaChain.length < $1.viaChain.length },
                                    invalidatedRelations: invalidated,
                                    openQuestions: openQuestions)
    }

    // MARK: - Condition-level change

    func evaluateCondition(_ condition: String,
                           change: KnowledgeChange,
                           in graph: KnowledgeGraph) -> CounterfactualResult {
        var invalidated: [StableID] = []
        var consequences: [CounterfactualConsequence] = []
        var openQuestions: [String] = []

        for relation in graph.relations.sorted(by: { $0.id.rawValue < $1.id.rawValue }) {
            let matching = relation.conditions.filter { $0.isPositive && SemanticIdentity.phrase($0.text) == SemanticIdentity.phrase(condition) }
            let scoped = relation.qualifiers.filter { $0.kind == .scope && SemanticIdentity.phrase($0.text) == SemanticIdentity.phrase(condition) }
            guard !matching.isEmpty || !scoped.isEmpty else { continue }
            guard let subject = graph.node(relation.subject.id), let object = graph.node(relation.object.id) else { continue }
            invalidated.append(relation.id)

            let links = [
                CausalLink(label: subject.label, provenance: relation.provenance),
                CausalLink(label: object.label,
                           viaRelation: relation.id,
                           kind: relation.kind,
                           conditions: relation.conditions,
                           provenance: relation.provenance)
            ]
            let chain = CausalChain(links: links,
                                    admissibility: .inferredValidated,
                                    provenance: Provenance.inferred(from: [relation.provenance],
                                                                    ids: [relation.id],
                                                                    rule: .conditionPropagation))
            let conditionText = (matching.first?.text ?? scoped.first?.text) ?? condition
            consequences.append(CounterfactualConsequence(
                label: "\(subject.label) \(relation.kind.rawValue) \(object.label)",
                polarity: .ruleNoLongerApplies,
                viaChain: chain,
                admissibility: .inferredValidated,
                provenance: chain.provenance,
                justification: "Your source states this only \(matching.isEmpty ? "for" : "when") \"\(conditionText)\". With that condition false, the source no longer claims it."))
        }

        if consequences.isEmpty {
            return CounterfactualResult(change: change,
                                        focusLabel: condition,
                                        consequences: [],
                                        invalidatedRelations: [],
                                        openQuestions: [],
                                        unansweredReason: "No claim in your sources is conditioned on \"\(condition)\".")
        }
        openQuestions.append("Your sources say what stops applying, not what happens instead.")
        return CounterfactualResult(change: change,
                                    focusLabel: condition,
                                    consequences: consequences,
                                    invalidatedRelations: invalidated,
                                    openQuestions: openQuestions)
    }

    // MARK: - Helpers

    func hasAlternativeSupport(for node: StableID,
                               excluding relation: KnowledgeRelation,
                               in graph: KnowledgeGraph) -> Bool {
        graph.incoming(to: node).contains { candidate in
            candidate.id != relation.id
                && (candidate.kind == .enables || candidate.kind == .causes || candidate.kind == .supports)
                && candidate.provenance.admissibility == .sourceSupported
        }
    }

    func seedProvenance(graph: KnowledgeGraph, node: KnowledgeNode) -> Provenance {
        if let atomID = node.atomIDs.first, let atom = graph.atom(atomID) {
            return atom.provenance
        }
        return Provenance(admissibility: .inferredValidated,
                          spans: [],
                          derivedFrom: [node.id],
                          rule: .conditionPropagation,
                          confidenceInParsing: 0.5)
    }

    func justify(change: KnowledgeChange,
                 focusLabel: String,
                 relation: KnowledgeRelation,
                 targetLabel: String,
                 polarity: ConsequencePolarity) -> String {
        let changeText: String
        switch change {
        case .removed(let text): changeText = "\(text) is gone"
        case .propertyLost(let subject, let property): changeText = "\(subject) is no longer \(property)"
        case .conditionFalse(let text): changeText = "\(text) is false"
        case .replaced(let text, let replacement): changeText = "\(text) is replaced by \(replacement)"
        }
        switch polarity {
        case .noLongerHolds:
            return "Your source states that \(targetLabel) requires \(focusLabel). If \(changeText), that requirement is unmet."
        case .failureFollows:
            return "Your source states that \(focusLabel) prevents \(targetLabel). If \(changeText), nothing in your sources prevents it."
        case .supportWeakenedButHolds:
            return "\(focusLabel) is one stated support for \(targetLabel), but another source supports it independently."
        case .ruleNoLongerApplies:
            return "Your source states that \(focusLabel) \(relation.kind.rawValue) \(targetLabel). If \(changeText), that statement no longer applies."
        }
    }
}
