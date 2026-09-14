import Foundation

/// The grounded knowledge graph: atoms, the phrase nodes they connect, and the
/// provenance-carrying edges between them.
///
/// The graph is an immutable value. Re-extraction produces a new graph rather
/// than mutating one in place, which keeps understanding state comparable
/// across extraction versions.
public struct KnowledgeGraph: Codable, Equatable, Sendable {
    public private(set) var atomsByID: [String: KnowledgeAtom]
    public private(set) var nodesByID: [String: KnowledgeNode]
    public private(set) var relationsByID: [String: KnowledgeRelation]
    private var outgoingIndex: [String: [String]]
    private var incomingIndex: [String: [String]]
    private var nodesByKey: [String: String]
    private var atomsByConcept: [String: [String]]

    public init(atoms: [KnowledgeAtom], nodes: [KnowledgeNode], relations: [KnowledgeRelation]) {
        var atomsByID: [String: KnowledgeAtom] = [:]
        for atom in atoms { atomsByID[atom.id.rawValue] = atom }
        var nodesByID: [String: KnowledgeNode] = [:]
        var nodesByKey: [String: String] = [:]
        for node in nodes {
            nodesByID[node.id.rawValue] = node
            nodesByKey[node.key] = node.id.rawValue
        }
        var relationsByID: [String: KnowledgeRelation] = [:]
        var outgoing: [String: [String]] = [:]
        var incoming: [String: [String]] = [:]
        for relation in relations.sorted(by: { $0.id.rawValue < $1.id.rawValue }) {
            relationsByID[relation.id.rawValue] = relation
            outgoing[relation.subject.id.rawValue, default: []].append(relation.id.rawValue)
            incoming[relation.object.id.rawValue, default: []].append(relation.id.rawValue)
            if relation.kind.isSymmetric {
                outgoing[relation.object.id.rawValue, default: []].append(relation.id.rawValue)
                incoming[relation.subject.id.rawValue, default: []].append(relation.id.rawValue)
            }
        }
        var byConcept: [String: [String]] = [:]
        for atom in atoms {
            for concept in atom.concepts {
                byConcept[concept, default: []].append(atom.id.rawValue)
            }
        }
        self.atomsByID = atomsByID
        self.nodesByID = nodesByID
        self.relationsByID = relationsByID
        self.outgoingIndex = outgoing
        self.incomingIndex = incoming
        self.nodesByKey = nodesByKey
        self.atomsByConcept = byConcept
    }

    public var atoms: [KnowledgeAtom] { atomsByID.values.sorted { $0.id.rawValue < $1.id.rawValue } }
    public var nodes: [KnowledgeNode] { nodesByID.values.sorted { $0.id.rawValue < $1.id.rawValue } }
    public var relations: [KnowledgeRelation] { relationsByID.values.sorted { $0.id.rawValue < $1.id.rawValue } }

    public func atom(_ id: StableID) -> KnowledgeAtom? { atomsByID[id.rawValue] }
    public func node(_ id: StableID) -> KnowledgeNode? { nodesByID[id.rawValue] }
    public func relation(_ id: StableID) -> KnowledgeRelation? { relationsByID[id.rawValue] }

    public func outgoing(from node: StableID) -> [KnowledgeRelation] {
        (outgoingIndex[node.rawValue] ?? []).compactMap { relationsByID[$0] }
            .filter { relation in
                relation.kind.isSymmetric ? true : relation.subject.id == node
            }
    }

    public func incoming(to node: StableID) -> [KnowledgeRelation] {
        (incomingIndex[node.rawValue] ?? []).compactMap { relationsByID[$0] }
            .filter { relation in
                relation.kind.isSymmetric ? true : relation.object.id == node
            }
    }

    /// The far end of a relation when traversed from `node`.
    public func counterpart(of relation: KnowledgeRelation, from node: StableID) -> StableID {
        relation.subject.id == node ? relation.object.id : relation.subject.id
    }

    public func atoms(forConcept concept: String) -> [KnowledgeAtom] {
        (atomsByConcept[concept] ?? []).compactMap { atomsByID[$0] }
            .sorted { $0.id.rawValue < $1.id.rawValue }
    }

    /// Exact key lookup, then a bounded similarity fallback. The fallback is
    /// deliberately strict: resolving the wrong node silently answers a
    /// different question than the learner asked.
    public func resolveNode(_ text: String, minimumSimilarity: Double = 0.6) -> KnowledgeNode? {
        let key = KnowledgeNode.key(for: text)
        if let id = nodesByKey[key], let node = nodesByID[id] { return node }
        var best: (node: KnowledgeNode, score: Double)?
        for node in nodes {
            let score = TextScanning.overlap(node.label, text)
            if score >= minimumSimilarity, best == nil || score > best!.score {
                best = (node, score)
            }
        }
        return best?.node
    }

    /// Concepts present anywhere in the graph, sorted for stable iteration.
    public var concepts: [String] { atomsByConcept.keys.sorted() }

    public var documentIDs: [String] {
        var seen: [String] = []
        for atom in atoms {
            for span in atom.provenance.spans where !seen.contains(span.documentID) {
                seen.append(span.documentID)
            }
        }
        return seen.sorted()
    }
}

/// Builds the graph from atoms, folding duplicate edges together and keeping
/// source-supported and inferred edges strictly separate.
public struct KnowledgeGraphBuilder: Sendable {
    public init() {}

    public func build(atoms: [KnowledgeAtom], additionalRelations: [KnowledgeRelation] = []) -> KnowledgeGraph {
        var nodesByKey: [String: KnowledgeNode] = [:]
        var relationsByKey: [String: KnowledgeRelation] = [:]

        func node(for label: String, concepts: [String], atomID: StableID) -> KnowledgeNode {
            let key = KnowledgeNode.key(for: label)
            if var existing = nodesByKey[key] {
                if !existing.atomIDs.contains(atomID) { existing.atomIDs.append(atomID) }
                for concept in concepts where !existing.concepts.contains(concept) {
                    existing.concepts.append(concept)
                }
                nodesByKey[key] = existing
                return existing
            }
            let created = KnowledgeNode(label: label, concepts: concepts, atomIDs: [atomID])
            nodesByKey[key] = created
            return created
        }

        for atom in atoms.sorted(by: { $0.id.rawValue < $1.id.rawValue }) {
            guard atom.sourceRole.yieldsFactualClaims || atom.sourceRole == .unknown else { continue }
            guard let kind = RelationKind(rawValue: atom.relation) else { continue }
            let subjectNode = node(for: atom.subject, concepts: atom.concepts, atomID: atom.id)
            let objectNode = node(for: atom.object, concepts: atom.concepts, atomID: atom.id)
            // A negated claim is not an edge: "X does not prevent Y" must never
            // be traversable as "X prevents Y".
            guard !atom.isNegated else { continue }

            let key = [kind.rawValue,
                       subjectNode.id.rawValue,
                       objectNode.id.rawValue,
                       atom.conditions.map(\.text).sorted().joined(separator: "|")].joined(separator: "/")
            if var existing = relationsByKey[key] {
                if !existing.supportingAtoms.contains(atom.id) {
                    existing.supportingAtoms.append(atom.id)
                    for span in atom.provenance.spans where !existing.provenance.spans.contains(span) {
                        existing.provenance.spans.append(span)
                    }
                    existing.provenance.confidenceInParsing = max(existing.provenance.confidenceInParsing,
                                                                  atom.provenance.confidenceInParsing)
                }
                relationsByKey[key] = existing
            } else {
                relationsByKey[key] = KnowledgeRelation(kind: kind,
                                                        subject: .node(subjectNode.id),
                                                        object: .node(objectNode.id),
                                                        conditions: atom.conditions,
                                                        qualifiers: atom.qualifiers,
                                                        supportingAtoms: [atom.id],
                                                        provenance: atom.provenance)
            }
        }

        var relations = Array(relationsByKey.values)
        relations.append(contentsOf: additionalRelations)
        return KnowledgeGraph(atoms: atoms, nodes: Array(nodesByKey.values), relations: relations)
    }
}
