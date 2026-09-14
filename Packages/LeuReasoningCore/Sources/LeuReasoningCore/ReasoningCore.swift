import Foundation

/// What a build of the knowledge model produced, including everything it
/// refused. Nothing is discarded silently.
public struct KnowledgeBuildResult: Sendable {
    public var graph: KnowledgeGraph
    public var roleAssignments: [SourceRoleAssignment]
    public var skipped: [SkippedSentence]
    public var admission: AdmissionReport
    public var proposalRejections: [ProposalRejection]
    public var providerIdentifier: String

    public init(graph: KnowledgeGraph,
                roleAssignments: [SourceRoleAssignment],
                skipped: [SkippedSentence],
                admission: AdmissionReport,
                proposalRejections: [ProposalRejection],
                providerIdentifier: String) {
        self.graph = graph
        self.roleAssignments = roleAssignments
        self.skipped = skipped
        self.admission = admission
        self.proposalRejections = proposalRejections
        self.providerIdentifier = providerIdentifier
    }
}

/// The single entry point an integrator needs.
///
/// Everything below it is composable on its own: this type only wires the
/// pieces together in the order the pipeline expects. It holds no mutable
/// state, owns no cache, and has no knowledge of any UI.
public struct ReasoningCore {
    public let provider: any ReasoningProposalProvider
    public let classifier: SourceRoleClassifier
    public let gate: ProposalAdmissionGate
    public let validator: GraphValidator

    public init(provider: any ReasoningProposalProvider = DeterministicReasoningProposalProvider(),
                classifier: SourceRoleClassifier = SourceRoleClassifier(),
                gate: ProposalAdmissionGate = ProposalAdmissionGate(),
                validator: GraphValidator = GraphValidator()) {
        self.provider = provider
        self.classifier = classifier
        self.gate = gate
        self.validator = validator
    }

    /// Blocks in, certified graph out.
    public func build(from blocks: [SourceBlock]) async -> KnowledgeBuildResult {
        let assignments = classifier.classify(blocks: blocks)
        var atoms: [KnowledgeAtom] = []
        var rejections: [ProposalRejection] = []
        var skipped: [SkippedSentence] = []

        let extractor = AtomExtractor()
        for assignment in assignments {
            let proposals = await provider.proposeAtoms(for: assignment)
            let admitted = gate.admit(proposals, from: assignment)
            rejections.append(contentsOf: admitted.rejections)
            for atom in admitted.atoms where !atoms.contains(atom) { atoms.append(atom) }
            skipped.append(contentsOf: extractor.extract(from: [assignment]).skipped)
        }

        var graph = KnowledgeGraphBuilder().build(atoms: atoms)
        let relationProposals = await provider.proposeRelations(among: atoms)
        let admittedRelations = gate.admit(relationProposals, into: graph)
        rejections.append(contentsOf: admittedRelations.rejections)

        let report = validator.validate(atoms: atoms,
                                        relations: graph.relations + admittedRelations.relations)
        graph = KnowledgeGraph(atoms: report.admittedAtoms,
                               nodes: graph.nodes,
                               relations: report.admittedRelations)

        return KnowledgeBuildResult(graph: graph,
                                    roleAssignments: assignments,
                                    skipped: skipped,
                                    admission: report,
                                    proposalRejections: rejections,
                                    providerIdentifier: provider.identifier)
    }

    // MARK: - The interactions this engine is meant to support

    public func why(_ subject: String, in graph: KnowledgeGraph) -> MechanismAnswer {
        MechanismEngine().answer(.why(subject), in: graph)
    }

    public func whatBreaksWithout(_ subject: String, in graph: KnowledgeGraph) -> MechanismAnswer {
        MechanismEngine().answer(.whatBreaksWithoutThis(subject), in: graph)
    }

    public func whatDependsOn(_ subject: String, in graph: KnowledgeGraph) -> MechanismAnswer {
        MechanismEngine().answer(.whatDependsOnThis(subject), in: graph)
    }

    public func whatChangesIf(_ change: KnowledgeChange, in graph: KnowledgeGraph) -> CounterfactualResult {
        CounterfactualEngine().evaluate(change, in: graph)
    }

    public func understand(_ concept: String, in graph: KnowledgeGraph) -> ConceptModel {
        ConceptCompressor().compress(concept: concept, in: graph)
    }

    public func acrossMyLibrary(_ concept: String, in graph: KnowledgeGraph) -> GroundedSynthesis {
        let synthesizer = MultiSourceSynthesizer()
        return synthesizer.render(synthesizer.plan(concept: concept, in: graph))
    }

    public func check(explanation: String, about concept: String?, in graph: KnowledgeGraph) -> ExplanationAlignmentReport {
        ExplanationAligner().align(explanation: explanation, concept: concept, in: graph)
    }

    public func nextExplanation(for concept: String,
                                in graph: KnowledgeGraph,
                                state: UnderstandingState = UnderstandingState(),
                                alignment: ExplanationAlignmentReport? = nil,
                                alreadyUsed: [ExplanationStrategy] = []) -> [ExplanationMove] {
        ExplanationStrategySelector().select(concept: concept,
                                             in: graph,
                                             state: state,
                                             alignment: alignment,
                                             alreadyUsed: alreadyUsed)
    }

    public func whatToAsk(about concept: String,
                          in graph: KnowledgeGraph,
                          state: UnderstandingState = UnderstandingState(),
                          alignment: ExplanationAlignmentReport? = nil) -> [QuestionPlan] {
        QuestionPlanner().plan(concept: concept, in: graph, state: state, alignment: alignment)
    }
}
