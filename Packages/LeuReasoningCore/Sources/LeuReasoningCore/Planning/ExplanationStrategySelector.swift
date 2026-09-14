import Foundation

/// Ways of explaining the same thing differently.
public enum ExplanationStrategy: String, Codable, CaseIterable, Sendable {
    case simplerLanguage
    case concreteExample
    case mechanismFirst
    case contrast
    case prerequisite
    case failureMode
    case causalChain
    case analogyFromSource
    case differentSource
    case interactiveScenario
}

/// A selected strategy together with the source material that makes it possible.
/// A strategy with no material is never selected: this is what stops Leu from
/// inventing an analogy when the library contains none.
public struct ExplanationMove: Codable, Equatable, Sendable {
    public var strategy: ExplanationStrategy
    public var material: [GroundedLine]
    public var reason: SuggestionReason
    public var priority: Double

    public init(strategy: ExplanationStrategy,
                material: [GroundedLine],
                reason: SuggestionReason,
                priority: Double) {
        self.strategy = strategy
        self.material = material
        self.reason = reason
        self.priority = priority
    }
}

/// Picks the next way to explain something, given what the sources hold and
/// what the learner has already been shown.
public struct ExplanationStrategySelector: Sendable {
    public init() {}

    public func select(concept: String,
                       in graph: KnowledgeGraph,
                       state: UnderstandingState = UnderstandingState(),
                       alignment: ExplanationAlignmentReport? = nil,
                       alreadyUsed: [ExplanationStrategy] = [],
                       limit: Int = 3) -> [ExplanationMove] {
        let model = ConceptCompressor().compress(concept: concept, in: graph)
        let atoms = ConceptCompressor().relevantAtoms(for: concept, in: graph)
        var moves: [ExplanationMove] = []

        // What went wrong last time drives the first choice.
        let findings = alignment?.findings ?? []
        let missingCondition = findings.contains { $0.type == .missingCondition || $0.type == .scopeTooBroad }
        let reversed = findings.contains { $0.type == .reversedCauseEffect || $0.type == .wrongDependency }
        let conflated = findings.contains { $0.type == .conflatedConcepts }

        if let example = atoms.first(where: { $0.claimType == .example || $0.sourceRole == .example }) {
            moves.append(ExplanationMove(strategy: .concreteExample,
                                         material: [GroundedLine.fromAtom(example)],
                                         reason: SuggestionReason(cause: .anotherSourceExplainsIt,
                                                                  text: "Your source gives a worked example of this.",
                                                                  evidence: [example.id],
                                                                  provenance: example.provenance),
                                         priority: 0.8))
        }
        if !model.mechanism.isEmpty {
            moves.append(ExplanationMove(strategy: reversed ? .causalChain : .mechanismFirst,
                                         material: model.mechanism,
                                         reason: SuggestionReason(cause: reversed ? .yourExplanation : .currentPassageDependsOnIt,
                                                                  text: reversed
                                                                      ? "Your explanation ran the steps the other way, so here is the order your source states."
                                                                      : "Your source states the steps, so the mechanism can be shown directly.",
                                                                  evidence: model.mechanism.flatMap(\.atomIDs),
                                                                  provenance: model.mechanism.first?.provenance),
                                         priority: reversed ? 0.95 : 0.7))
        }
        if missingCondition, let conditioned = atoms.first(where: { !$0.conditions.isEmpty }) {
            moves.append(ExplanationMove(strategy: .failureMode,
                                         material: [GroundedLine.fromAtom(conditioned)],
                                         reason: SuggestionReason(cause: .yourExplanation,
                                                                  text: "Your explanation stated this without the condition your source attaches to it.",
                                                                  evidence: [conditioned.id],
                                                                  provenance: conditioned.provenance),
                                         priority: 0.97))
        }
        if conflated, !model.connectedIdeas.isEmpty {
            moves.append(ExplanationMove(strategy: .contrast,
                                         material: model.connectedIdeas,
                                         reason: SuggestionReason(cause: .yourExplanation,
                                                                  text: "Two ideas got merged, so the contrast your source draws is the useful next step.",
                                                                  evidence: model.connectedIdeas.flatMap(\.atomIDs),
                                                                  provenance: model.connectedIdeas.first?.provenance),
                                         priority: 0.9))
        }

        // Prerequisites, but only ones the learner has not already opened.
        let mechanismEngine = MechanismEngine()
        let requires = mechanismEngine.answer(.whatThisRequires(concept), in: graph)
        if let path = requires.paths.first, let step = path.steps.first,
           !state.visitedDependencies.contains(step.toLabel) {
            moves.append(ExplanationMove(strategy: .prerequisite,
                                         material: [GroundedLine(text: "\(step.fromLabel) requires \(step.toLabel).",
                                                                 atomIDs: [step.relationID],
                                                                 admissibility: path.admissibility,
                                                                 provenance: step.provenance)],
                                         reason: SuggestionReason(cause: .currentPassageDependsOnIt,
                                                                  text: "Your source states that \(step.fromLabel) requires \(step.toLabel), and you have not opened that yet.",
                                                                  evidence: [step.relationID],
                                                                  provenance: step.provenance),
                                         priority: 0.85))
        }

        // A different document, when one covers the same concept.
        let documents = Set(atoms.compactMap(\.sourceDocumentID))
        if documents.count > 1 {
            let seen = Set(state.relatedSourcesSeen)
            if let unseen = documents.subtracting(seen).sorted().first,
               let atom = atoms.first(where: { $0.sourceDocumentID == unseen }) {
                moves.append(ExplanationMove(strategy: .differentSource,
                                             material: [GroundedLine.fromAtom(atom)],
                                             reason: SuggestionReason(cause: .anotherSourceExplainsIt,
                                                                      text: "\(unseen) explains the same idea and you have not read it yet.",
                                                                      evidence: [atom.id],
                                                                      provenance: atom.provenance),
                                             priority: 0.78))
            }
        }

        // An analogy is only offered when a source actually draws one.
        if let analogy = graph.relations.first(where: { $0.kind == .samePrincipleAs || $0.kind == .exampleOf }),
           let subject = graph.node(analogy.subject.id), let object = graph.node(analogy.object.id),
           TextScanning.coverage(of: concept, in: "\(subject.label) \(object.label)") >= 0.5 {
            moves.append(ExplanationMove(strategy: .analogyFromSource,
                                         material: [GroundedLine(text: "\(subject.label) works on the same principle as \(object.label).",
                                                                 atomIDs: analogy.supportingAtoms,
                                                                 admissibility: analogy.provenance.admissibility,
                                                                 provenance: analogy.provenance)],
                                         reason: SuggestionReason(cause: .anotherSourceExplainsIt,
                                                                  text: "Your source itself draws this comparison.",
                                                                  evidence: [analogy.id],
                                                                  provenance: analogy.provenance),
                                         priority: 0.6))
        }

        // Simpler language: only when a shorter grounded statement exists.
        if let short = atoms.filter({ $0.sourceRole == .compactExplanation })
            .min(by: { TextScanning.words($0.statement).count < TextScanning.words($1.statement).count }) {
            moves.append(ExplanationMove(strategy: .simplerLanguage,
                                         material: [GroundedLine.fromAtom(short)],
                                         reason: SuggestionReason(cause: .anotherSourceExplainsIt,
                                                                  text: "Your source has a shorter statement of the same idea.",
                                                                  evidence: [short.id],
                                                                  provenance: short.provenance),
                                         priority: 0.55))
        }

        // An interactive scenario needs a condition to vary; without one there
        // is nothing to ask the learner to change.
        if let conditioned = atoms.first(where: { !$0.conditions.isEmpty }) {
            moves.append(ExplanationMove(strategy: .interactiveScenario,
                                         material: [GroundedLine.fromAtom(conditioned)],
                                         reason: SuggestionReason(cause: .sourceStatesACondition,
                                                                  text: "Your source states a condition that can be switched on and off.",
                                                                  evidence: [conditioned.id],
                                                                  provenance: conditioned.provenance),
                                         priority: 0.5))
        }

        let unused = moves.filter { !alreadyUsed.contains($0.strategy) }
        let pool = unused.isEmpty ? moves : unused
        var deduplicated: [ExplanationMove] = []
        for move in pool.sorted(by: { lhs, rhs in
            if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
            return lhs.strategy.rawValue < rhs.strategy.rawValue
        }) where !deduplicated.contains(where: { $0.strategy == move.strategy }) {
            deduplicated.append(move)
        }
        return Array(deduplicated.prefix(limit))
    }
}
