import Foundation

/// The trust boundary for real documents. Proposed atoms are compared with a
/// fresh, deterministic parse of the canonical page, including every guard and
/// exact source locator. A real quote attached to a fabricated predicate fails.
public struct CertifiedReasoningIndex: Sendable {
    public let atoms: [KnowledgeAtom]
    public let graph: KnowledgeGraph
    public let inferred: [KnowledgeRelation]
    public let crossDocument: [KnowledgeRelation]
    public let rejected: [String]

    public init(documents: [CanonicalDocument], sampledPages: [Int]) {
        var atoms: [KnowledgeAtom] = []
        var rejected: [String] = []
        for document in documents {
            let cardDocument = document.pages.contains { CanonicalSource.card(in: $0, documentID: document.id) != nil }
            for page in document.pages {
                if let card = CanonicalSource.card(in: page, documentID: document.id) {
                    let result = PacketAtomExtractor().extract(card)
                    // Non-sampled cards may provide library context, but never
                    // contribute to the separately reported 40-page yield.
                    atoms += sampledPages.contains(page.number) ? result.atoms : result.atoms.filter {
                        $0.claimType == .definition && $0.provenance.spans.contains { $0.sourceRole == .structure }
                    }
                    rejected += result.unresolved.map { "\(document.id)#p\(page.number): unresolved: \($0)" }
                } else if !cardDocument {
                    for span in CanonicalSource.noteSpans(in: page, documentID: document.id) {
                        let result = PacketAtomExtractor().extractProse(span)
                        atoms += result.atoms
                        rejected += result.unresolved.map { "\(document.id)#p\(page.number): unresolved: \($0)" }
                    }
                }
            }
        }
        atoms = atoms.filter { atom in
            atom.provenance.spans.allSatisfy { CanonicalSource.verifies($0, documents: documents) }
                && !atom.subject.isEmpty && !atom.object.isEmpty
        }
        let base = KnowledgeGraphBuilder().build(atoms: atoms)
        let inferred = Self.definitionSubstitutions(atoms)
        let cross = Self.definitionConnections(atoms)
        let admission = GraphValidator().validate(atoms: atoms, relations: base.relations + inferred + cross)
        self.atoms = admission.admittedAtoms
        self.inferred = inferred.filter { admission.admittedRelations.contains($0) }
        self.crossDocument = cross.filter { admission.admittedRelations.contains($0) }
        self.graph = KnowledgeGraph(atoms: admission.admittedAtoms, nodes: base.nodes, relations: admission.admittedRelations)
        self.rejected = rejected + admission.rejections.map { "\($0.artifactID): \($0.reason.rawValue): \($0.detail)" }
    }

    public func admits(_ proposed: KnowledgeAtom) -> Bool { atoms.contains(proposed) }
    public func admits(_ proposed: KnowledgeRelation) -> Bool {
        graph.relations.contains(proposed) || crossDocument.contains(proposed)
    }

    /// A noun-phrase definition names the same thing as the card title. Its
    /// stated effect can therefore be read using that definition as subject.
    /// This is definitional substitution, NOT transitive causation. The full
    /// effect, conditions and modality remain untouched, with both parents.
    static func definitionSubstitutions(_ atoms: [KnowledgeAtom]) -> [KnowledgeRelation] {
        var results: [KnowledgeRelation] = []
        for definition in atoms where definition.claimType == .definition && definition.relation == "explains" && !definition.isNegated {
            guard definition.provenance.spans.count == 2,
                  ["a", "an", "the"].contains(definition.object.split(separator: " ").first?.lowercased() ?? ""),
                  !definition.object.contains(";"),
                  definition.qualifiers.isEmpty, definition.conditions.isEmpty else { continue }
            for effect in atoms where effect.sourceDocumentID == definition.sourceDocumentID && effect.page == definition.page && effect.claimType != .definition && !effect.isNegated {
                guard SemanticIdentity.phrase(effect.subject) == SemanticIdentity.phrase(definition.subject),
                      let kind = RelationKind(rawValue: effect.relation) else { continue }
                let from = KnowledgeNode(label: definition.object), to = KnowledgeNode(label: effect.object)
                guard from.id != to.id else { continue }
                results.append(KnowledgeRelation(kind: kind, subject: .node(from.id), object: .node(to.id),
                                                 conditions: effect.conditions, qualifiers: effect.qualifiers,
                                                 supportingAtoms: [definition.id, effect.id],
                                                 provenance: .inferred(from: [definition.provenance, effect.provenance],
                                                                       ids: [definition.id, effect.id], rule: .definitionSubstitution)))
            }
        }
        return results
    }

    /// A definition can explain an explicitly named term in another source.
    /// This licenses a contextual reading only: it does not establish that the
    /// two entire claims are equivalent, that either refutes the other, or that
    /// a causal edge connects them. Exact whole-term reference is mandatory.
    static func definitionConnections(_ atoms: [KnowledgeAtom]) -> [KnowledgeRelation] {
        var results: [KnowledgeRelation] = []
        let definitions = atoms.filter { $0.claimType == .definition && $0.provenance.spans.contains { $0.sourceRole == .structure } }
        for definition in definitions {
            let term = SemanticIdentity.phrase(definition.subject)
            guard term.count >= 4, !["principle", "pattern", "function", "state", "module", "return", "inference", "grounding", "queue", "request", "interface", "context"].contains(term) else { continue }
            for use in atoms where use.sourceDocumentID != definition.sourceDocumentID {
                let text = " " + SemanticIdentity.phrase(use.canonicalSpan ?? "") + " "
                let direct = text.contains(" " + term + " ") || text.contains(" " + term + "s ")
                // Qualified technical names may omit the namespace only inside
                // a document explicitly named for that namespace. This is a
                // scoped name binding, not a similarity/entailment score.
                let words = definition.subject.split(separator: " ").map(String.init)
                let namespace = words.first ?? ""
                let localName = SemanticIdentity.phrase(words.dropFirst().joined(separator: " "))
                let qualified = words.count == 2 && namespace.first?.isUppercase == true
                    && TextScanning.normalizedTokens(use.sourceDocumentID ?? "").contains(namespace.lowercased())
                    && !localName.isEmpty && (text.contains(" " + localName + " ") || text.contains(" " + localName + "s "))
                guard direct || qualified else { continue }
                results.append(KnowledgeRelation(kind: .explains, subject: .atom(definition.id), object: .atom(use.id),
                                                 supportingAtoms: [definition.id, use.id],
                                                 provenance: .inferred(from: [definition.provenance, use.provenance],
                                                                       ids: [definition.id, use.id], rule: .definitionContext)))
            }
        }
        return results
    }
}
