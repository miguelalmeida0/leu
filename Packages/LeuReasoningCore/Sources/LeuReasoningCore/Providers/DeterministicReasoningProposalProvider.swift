import Foundation

/// The always-available provider. It is the reference behaviour of the engine:
/// every capability in this package works with nothing but this provider, on
/// any device, offline, with no model of any kind.
public struct DeterministicReasoningProposalProvider: ReasoningProposalProvider {
    public var identifier: String { "deterministic" }
    public var isAvailable: Bool { true }

    private let extractor: AtomExtractor

    public init(extractor: AtomExtractor = AtomExtractor()) {
        self.extractor = extractor
    }

    public func proposeAtoms(for assignment: SourceRoleAssignment) async -> [AtomProposal] {
        let result = extractor.extract(from: [assignment])
        return result.atoms.map { atom in
            AtomProposal(claimType: atom.claimType,
                         subject: atom.subject,
                         relation: atom.relation,
                         object: atom.object,
                         conditions: atom.conditions,
                         qualifiers: atom.qualifiers,
                         isNegated: atom.isNegated,
                         claimedSpan: atom.canonicalSpan ?? assignment.block.text)
        }
    }

    /// Proposes the two cross-source relations that can be established by
    /// comparison alone: equivalent claims from different documents, and a
    /// claim that adds a restriction to another.
    public func proposeRelations(among atoms: [KnowledgeAtom]) async -> [RelationProposal] {
        var proposals: [RelationProposal] = []
        let sorted = atoms.sorted { $0.id.rawValue < $1.id.rawValue }
        for (index, lhs) in sorted.enumerated() {
            for rhs in sorted.dropFirst(index + 1) {
                guard lhs.sourceDocumentID != rhs.sourceDocumentID else { continue }
                guard lhs.isNegated == rhs.isNegated else { continue }
                let subjectOverlap = TextScanning.overlap(lhs.subject, rhs.subject)
                let objectOverlap = TextScanning.overlap(lhs.object, rhs.object)
                guard subjectOverlap >= 0.6 else { continue }
                if objectOverlap >= 0.6, lhs.relation == rhs.relation {
                    proposals.append(RelationProposal(kind: .samePrincipleAs,
                                                      subjectLabel: lhs.subject,
                                                      objectLabel: rhs.subject,
                                                      supportingAtomIDs: [lhs.id, rhs.id]))
                } else if objectOverlap >= 0.4,
                          lhs.conditions.count != rhs.conditions.count {
                    let narrower = lhs.conditions.count > rhs.conditions.count ? lhs : rhs
                    let broader = lhs.conditions.count > rhs.conditions.count ? rhs : lhs
                    proposals.append(RelationProposal(kind: .refines,
                                                      subjectLabel: narrower.subject,
                                                      objectLabel: broader.subject,
                                                      supportingAtomIDs: [narrower.id, broader.id]))
                }
            }
        }
        return proposals
    }

    public func proposeParaphrases(for proposition: LearnerProposition,
                                   candidates: [KnowledgeAtom]) async -> [ParaphraseProposal] {
        let aligner = ExplanationAligner()
        return candidates
            .map { ParaphraseProposal(propositionID: proposition.id,
                                      atomID: $0.id,
                                      similarity: aligner.score(proposition, against: $0)) }
            .filter { $0.similarity > 0 }
            .sorted { lhs, rhs in
                if lhs.similarity != rhs.similarity { return lhs.similarity > rhs.similarity }
                return lhs.atomID.rawValue < rhs.atomID.rawValue
            }
    }
}
