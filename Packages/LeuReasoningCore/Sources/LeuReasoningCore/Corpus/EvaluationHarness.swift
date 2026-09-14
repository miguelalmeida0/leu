import Foundation

/// The certification metrics. Every number here is computed from the golden
/// corpus by running the real engine — there is no sampling and no randomness,
/// so two runs on the same corpus produce identical output.
public struct EvaluationReport: Codable, Sendable {
    public struct AtomExtraction: Codable, Sendable {
        public var sentences: Int
        public var extracted: Int
        public var subjectPreserved: Int
        public var qualifierPreserved: Int
        public var negationPreserved: Int
        public var numberPreserved: Int
        public var identifierPreserved: Int
        public var skipped: Int
    }

    public struct Relationships: Codable, Sendable {
        public var admitted: Int
        public var rejected: Int
        public var sourceSupported: Int
        public var inferred: Int
        public var falsePositives: Int
    }

    public struct LearnerAlignment: Codable, Sendable {
        public var paraphraseCases: Int
        public var paraphraseAccepted: Int
        public var contradictionCases: Int
        public var contradictionRejected: Int
        public var overgeneralisationCases: Int
        public var overgeneralisationDetected: Int
        public var mixedCases: Int
        public var mixedCorrect: Int
        public var misconceptionTypeMatches: Int
        public var failures: [String]
    }

    public struct Chains: Codable, Sendable {
        public var expected: Int
        public var reproduced: Int
        public var unsupportedBridges: Int
        public var incompleteProvenance: Int
    }

    public struct Counterfactuals: Codable, Sendable {
        public var queries: Int
        public var groundedConsequences: Int
        public var inventedConsequences: Int
        public var openQuestionsRaised: Int
    }

    public struct Synthesis: Codable, Sendable {
        public var concepts: Int
        public var lines: Int
        public var unsupportedStatements: Int
        public var manufacturedContrasts: Int
    }

    public var atomExtraction: AtomExtraction
    public var relationships: Relationships
    public var learnerAlignment: LearnerAlignment
    public var chains: Chains
    public var counterfactuals: Counterfactuals
    public var synthesis: Synthesis
    public var providerIdentifier: String

    /// The single hard gate: no rendered statement may lack provenance.
    public var unsupportedStatements: Int { synthesis.unsupportedStatements }
}

/// Runs the whole engine over the golden corpus and reports the metrics.
public struct EvaluationHarness: Sendable {
    public var corpus: GoldenCorpus

    public init(corpus: GoldenCorpus) {
        self.corpus = corpus
    }

    public func run(provider: any ReasoningProposalProvider = DeterministicReasoningProposalProvider()) async -> EvaluationReport {
        let built = corpus.buildAtoms()
        let graph = KnowledgeGraphBuilder().build(atoms: built.atoms)

        return EvaluationReport(atomExtraction: extractionMetrics(),
                                relationships: relationshipMetrics(graph: graph, atoms: built.atoms),
                                learnerAlignment: alignmentMetrics(graph: graph),
                                chains: chainMetrics(graph: graph),
                                counterfactuals: counterfactualMetrics(graph: graph),
                                synthesis: synthesisMetrics(graph: graph),
                                providerIdentifier: provider.identifier)
    }

    // MARK: - Extraction

    /// Re-extracts every corpus span from raw text and checks that the parts
    /// that must survive extraction actually did.
    func extractionMetrics() -> EvaluationReport.AtomExtraction {
        let extractor = AtomExtractor()
        var extracted = 0, subject = 0, qualifier = 0, negation = 0, number = 0, identifier = 0, skipped = 0
        let specs = corpus.atoms.filter { $0.role.yieldsFactualClaims }
        for spec in specs {
            let block = SourceBlock(documentID: spec.doc, page: spec.page, indexOnPage: 0, text: spec.span)
            let assignment = SourceRoleAssignment(block: block, role: spec.role, confidence: 1, evidence: ["corpus"])
            let result = extractor.extract(from: [assignment])
            guard let atom = result.atoms.first else {
                skipped += 1
                continue
            }
            extracted += 1
            if TextScanning.coverage(of: atom.subject, in: spec.subject) >= 0.6
                || TextScanning.coverage(of: spec.subject, in: atom.subject) >= 0.6 { subject += 1 }
            let expectedQualifiers = spec.qualifiers.count
            if expectedQualifiers == 0 || !atom.qualifiers.isEmpty { qualifier += 1 }
            if atom.isNegated == spec.isNegated { negation += 1 }
            let expectedNumbers = TextScanning.numbers(in: spec.span)
            if atom.numbers.map(\.value).sorted() == expectedNumbers.map(\.value).sorted() { number += 1 }
            let expectedIdentifiers = Set(TextScanning.identifiers(in: spec.span).map(\.text))
            if Set(atom.identifiers.map(\.text)) == expectedIdentifiers { identifier += 1 }
        }
        return EvaluationReport.AtomExtraction(sentences: specs.count,
                                               extracted: extracted,
                                               subjectPreserved: subject,
                                               qualifierPreserved: qualifier,
                                               negationPreserved: negation,
                                               numberPreserved: number,
                                               identifierPreserved: identifier,
                                               skipped: skipped)
    }

    // MARK: - Relationships

    func relationshipMetrics(graph: KnowledgeGraph, atoms: [KnowledgeAtom]) -> EvaluationReport.Relationships {
        let report = GraphValidator().validate(atoms: atoms, relations: graph.relations)
        // A false positive is an edge whose endpoints are not both mentioned by
        // at least one of its supporting atoms.
        var falsePositives = 0
        for relation in report.admittedRelations {
            guard let subject = graph.node(relation.subject.id),
                  let object = graph.node(relation.object.id) else {
                falsePositives += 1
                continue
            }
            let supported = relation.supportingAtoms.compactMap { graph.atom($0) }.contains { atom in
                TextScanning.coverage(of: subject.label, in: atom.subject) >= 0.5
                    && TextScanning.coverage(of: object.label, in: atom.object) >= 0.5
            }
            if !supported && relation.provenance.admissibility == .sourceSupported { falsePositives += 1 }
        }
        return EvaluationReport.Relationships(
            admitted: report.admittedRelations.count,
            rejected: report.rejections.count,
            sourceSupported: report.admittedRelations.filter(\.isSourceSupported).count,
            inferred: report.admittedRelations.filter { !$0.isSourceSupported }.count,
            falsePositives: falsePositives)
    }

    // MARK: - Learner alignment

    func alignmentMetrics(graph: KnowledgeGraph) -> EvaluationReport.LearnerAlignment {
        let aligner = ExplanationAligner()
        var paraphrase = (total: 0, ok: 0)
        var contradiction = (total: 0, ok: 0)
        var overgeneralisation = (total: 0, ok: 0)
        var mixed = (total: 0, ok: 0)
        var typeMatches = 0
        var failures: [String] = []

        for testCase in corpus.learnerCases {
            let report = aligner.align(explanation: testCase.text, concept: testCase.concept, in: graph)
            let matched = report.verdict == testCase.expectedVerdict
            let foundTypes = Set(report.findings.map(\.type))
            if !testCase.expectedMisconceptions.isEmpty,
               foundTypes.isSuperset(of: Set(testCase.expectedMisconceptions)) {
                typeMatches += 1
            }
            if !matched {
                failures.append("\(testCase.key): expected \(testCase.expectedVerdict.rawValue), got \(report.verdict.rawValue)")
            }
            switch testCase.note {
            case let note where note.hasPrefix("paraphrase"):
                paraphrase.total += 1
                if report.verdict == .supported { paraphrase.ok += 1 }
            case let note where note.hasPrefix("contradicts"):
                contradiction.total += 1
                if report.verdict == .contradicted { contradiction.ok += 1 }
            case let note where note.hasPrefix("overgeneralisation"):
                overgeneralisation.total += 1
                if foundTypes.contains(.scopeTooBroad) || report.verdict == .contradicted { overgeneralisation.ok += 1 }
            default:
                mixed.total += 1
                if matched { mixed.ok += 1 }
            }
        }
        return EvaluationReport.LearnerAlignment(paraphraseCases: paraphrase.total,
                                                 paraphraseAccepted: paraphrase.ok,
                                                 contradictionCases: contradiction.total,
                                                 contradictionRejected: contradiction.ok,
                                                 overgeneralisationCases: overgeneralisation.total,
                                                 overgeneralisationDetected: overgeneralisation.ok,
                                                 mixedCases: mixed.total,
                                                 mixedCorrect: mixed.ok,
                                                 misconceptionTypeMatches: typeMatches,
                                                 failures: failures)
    }

    // MARK: - Chains

    func chainMetrics(graph: KnowledgeGraph) -> EvaluationReport.Chains {
        let engine = CausalChainEngine()
        var reproduced = 0, bridges = 0, provenanceGaps = 0
        for spec in corpus.chains {
            let chains = engine.chains(from: spec.start, in: graph)
            let match = chains.first { chain in
                let labels = chain.links.map { KnowledgeNode.key(for: $0.label) }
                let expected = spec.labels.map { KnowledgeNode.key(for: $0) }
                return labels.count >= expected.count && Array(labels.prefix(expected.count)) == expected
            }
            if match != nil { reproduced += 1 }
            for chain in chains {
                for problem in engine.problems(in: chain, graph: graph) {
                    switch problem.kind {
                    case .unsupportedBridge: bridges += 1
                    case .incompleteProvenance: provenanceGaps += 1
                    case .conditionDropped: break
                    }
                }
            }
        }
        return EvaluationReport.Chains(expected: corpus.chains.count,
                                       reproduced: reproduced,
                                       unsupportedBridges: bridges,
                                       incompleteProvenance: provenanceGaps)
    }

    // MARK: - Counterfactuals

    func counterfactualMetrics(graph: KnowledgeGraph) -> EvaluationReport.Counterfactuals {
        let engine = CounterfactualEngine()
        let changes: [KnowledgeChange] = [
            .propertyLost(subject: "a stable key", property: "stable"),
            .removed("an index"),
            .removed("a timeout"),
            .removed("caching"),
            .conditionFalse("the failure is transient"),
            .conditionFalse("the underlying data changes"),
            .removed("an idempotent operation"),
            .removed("a circuit breaker"),
            .removed("exponential backoff"),
            .removed("batching the lookups")
        ]
        var grounded = 0, invented = 0, openQuestions = 0
        for change in changes {
            let result = engine.evaluate(change, in: graph)
            openQuestions += result.openQuestions.count
            for consequence in result.consequences {
                // Grounded means: every link in the chain names a real relation
                // and the whole chain carries complete provenance.
                let linksGrounded = consequence.viaChain.links.dropFirst().allSatisfy { link in
                    guard let id = link.viaRelation else { return false }
                    return graph.relation(id) != nil || graph.atom(id) != nil
                }
                if linksGrounded && consequence.provenance.isComplete { grounded += 1 } else { invented += 1 }
            }
        }
        return EvaluationReport.Counterfactuals(queries: changes.count,
                                                groundedConsequences: grounded,
                                                inventedConsequences: invented,
                                                openQuestionsRaised: openQuestions)
    }

    // MARK: - Synthesis

    func synthesisMetrics(graph: KnowledgeGraph) -> EvaluationReport.Synthesis {
        let synthesizer = MultiSourceSynthesizer()
        let concepts = ["caching", "retrying", "an index", "a stable key", "an idempotent operation",
                        "a timeout", "a circuit breaker", "a closure", "a queue", "`useMemo`"]
        var lines = 0, unsupported = 0, manufactured = 0
        for concept in concepts {
            let plan = synthesizer.plan(concept: concept, in: graph)
            let rendered = synthesizer.render(plan)
            for section in rendered.sections {
                for line in section.lines {
                    lines += 1
                    // "OPEN QUESTION" lines are Leu speaking about the absence of
                    // sources, and are exempt from carrying a span; every other
                    // line must trace to one.
                    if section.title != "OPEN QUESTION" && !line.provenance.isComplete { unsupported += 1 }
                }
                if section.title == "WHERE THEY DIFFER" {
                    for line in section.lines where line.atomIDs.count < 2 { manufactured += 1 }
                }
            }
        }
        return EvaluationReport.Synthesis(concepts: concepts.count,
                                          lines: lines,
                                          unsupportedStatements: unsupported,
                                          manufacturedContrasts: manufactured)
    }
}
