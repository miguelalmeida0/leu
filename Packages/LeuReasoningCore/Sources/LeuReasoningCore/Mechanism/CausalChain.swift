import Foundation

/// One link in a causal story: a state, and the edge that got you there.
public struct CausalLink: Codable, Equatable, Sendable {
    public var label: String
    public var viaRelation: StableID?
    public var kind: RelationKind?
    public var conditions: [ClaimCondition]
    public var provenance: Provenance

    public init(label: String,
                viaRelation: StableID? = nil,
                kind: RelationKind? = nil,
                conditions: [ClaimCondition] = [],
                provenance: Provenance) {
        self.label = label
        self.viaRelation = viaRelation
        self.kind = kind
        self.conditions = conditions
        self.provenance = provenance
    }
}

/// A validated sequence of causes. Every adjacency in a chain corresponds to a
/// real edge in the graph; there are no narrative bridges.
public struct CausalChain: Codable, Equatable, Sendable, Identifiable {
    public var id: StableID
    public var links: [CausalLink]
    public var admissibility: Admissibility
    public var provenance: Provenance
    /// Conditions that must hold for the whole chain, unioned from its links.
    public var preconditions: [ClaimCondition]

    public init(links: [CausalLink], admissibility: Admissibility, provenance: Provenance) {
        self.id = StableID(namespace: "chain", components: links.map(\.label))
        self.links = links
        self.admissibility = admissibility
        self.provenance = provenance
        var conditions: [ClaimCondition] = []
        for link in links {
            for condition in link.conditions where !conditions.contains(condition) { conditions.append(condition) }
        }
        self.preconditions = conditions
    }

    public var rendered: String {
        var lines: [String] = []
        for (index, link) in links.enumerated() {
            if index == 0 {
                lines.append(link.label)
            } else {
                lines.append("→ \(link.label)")
            }
        }
        return lines.joined(separator: "\n")
    }

    public var length: Int { links.count }
}

public struct CausalChainProblem: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case unsupportedBridge
        case incompleteProvenance
        case conditionDropped
    }

    public var chainID: StableID
    public var kind: Kind
    public var detail: String

    public init(chainID: StableID, kind: Kind, detail: String) {
        self.chainID = chainID
        self.kind = kind
        self.detail = detail
    }
}

/// Builds and certifies causal chains.
public struct CausalChainEngine: Sendable {
    public var maxLength: Int

    public init(maxLength: Int = 5) {
        self.maxLength = maxLength
    }

    /// All chains that start at `start`, following only causal/enabling edges.
    public func chains(from start: String, in graph: KnowledgeGraph) -> [CausalChain] {
        let engine = MechanismEngine(maxPaths: 12, maxDepth: maxLength - 1)
        let answer = engine.answer(.whatHappensNext(start), in: graph)
        let enabling = engine.answer(.why(start), in: graph)
        let paths = (answer.paths + enabling.paths)
        var chains: [CausalChain] = []
        for path in paths {
            guard let chain = chain(from: path) else { continue }
            if !chains.contains(where: { $0.id == chain.id }) { chains.append(chain) }
        }
        return chains.sorted { $0.length > $1.length }
    }

    public func chain(from path: MechanismPath) -> CausalChain? {
        guard let first = path.steps.first else { return nil }
        var links: [CausalLink] = [CausalLink(label: first.fromLabel, provenance: first.provenance)]
        for step in path.steps {
            links.append(CausalLink(label: step.toLabel,
                                    viaRelation: step.relationID,
                                    kind: step.kind,
                                    conditions: step.conditions,
                                    provenance: step.provenance))
        }
        return CausalChain(links: links,
                           admissibility: path.admissibility,
                           provenance: path.provenance)
    }

    /// Certifies a chain against the graph it claims to come from.
    /// Any adjacency that is not backed by an existing edge is an unsupported
    /// bridge, which the evaluation harness requires to be zero.
    public func problems(in chain: CausalChain, graph: KnowledgeGraph) -> [CausalChainProblem] {
        var problems: [CausalChainProblem] = []
        for (index, link) in chain.links.enumerated() where index > 0 {
            guard let relationID = link.viaRelation else {
                problems.append(CausalChainProblem(chainID: chain.id,
                                                   kind: .unsupportedBridge,
                                                   detail: "link \(index) (\(link.label)) names no relation"))
                continue
            }
            let previous = chain.links[index - 1]
            if let relation = graph.relation(relationID) {
                let fromMatches = graph.node(relation.subject.id)?.label == previous.label
                    || graph.node(relation.object.id)?.label == previous.label
                let toMatches = graph.node(relation.object.id)?.label == link.label
                    || graph.node(relation.subject.id)?.label == link.label
                if !fromMatches || !toMatches {
                    problems.append(CausalChainProblem(chainID: chain.id,
                                                       kind: .unsupportedBridge,
                                                       detail: "relation \(relationID) does not join \(previous.label) to \(link.label)"))
                }
            } else if let atom = graph.atom(relationID) {
                // Failure-mode extensions are backed by an atom rather than an edge.
                let joins = TextScanning.coverage(of: previous.label, in: atom.subject) >= 0.5
                    && TextScanning.coverage(of: link.label, in: atom.object) >= 0.5
                if !joins {
                    problems.append(CausalChainProblem(chainID: chain.id,
                                                       kind: .unsupportedBridge,
                                                       detail: "atom \(relationID) does not join \(previous.label) to \(link.label)"))
                }
            } else {
                problems.append(CausalChainProblem(chainID: chain.id,
                                                   kind: .unsupportedBridge,
                                                   detail: "relation \(relationID) is not in the graph"))
            }
            if !link.provenance.isComplete {
                problems.append(CausalChainProblem(chainID: chain.id,
                                                   kind: .incompleteProvenance,
                                                   detail: "link \(index) has no traceable span"))
            }
        }
        // A chain must not quietly drop a condition that one of its edges carries.
        for link in chain.links {
            for condition in link.conditions where !chain.preconditions.contains(condition) {
                problems.append(CausalChainProblem(chainID: chain.id,
                                                   kind: .conditionDropped,
                                                   detail: "condition \"\(condition.text)\" missing from chain preconditions"))
            }
        }
        return problems
    }
}
