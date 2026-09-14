import Foundation

/// A proposed atom. A proposal is a *suggestion*, never knowledge: it carries
/// no provenance of its own and cannot be persisted. It becomes an atom only
/// if `ProposalAdmissionGate` can ground it in the source text.
public struct AtomProposal: Codable, Equatable, Sendable {
    public var claimType: ClaimType
    public var subject: String
    public var relation: String
    public var object: String
    public var conditions: [ClaimCondition]
    public var qualifiers: [Qualifier]
    public var isNegated: Bool
    /// The sentence the proposer claims this came from.
    public var claimedSpan: String

    public init(claimType: ClaimType,
                subject: String,
                relation: String,
                object: String,
                conditions: [ClaimCondition] = [],
                qualifiers: [Qualifier] = [],
                isNegated: Bool = false,
                claimedSpan: String) {
        self.claimType = claimType
        self.subject = subject
        self.relation = relation
        self.object = object
        self.conditions = conditions
        self.qualifiers = qualifiers
        self.isNegated = isNegated
        self.claimedSpan = claimedSpan
    }
}

public struct RelationProposal: Codable, Equatable, Sendable {
    public var kind: RelationKind
    public var subjectLabel: String
    public var objectLabel: String
    public var supportingAtomIDs: [StableID]

    public init(kind: RelationKind, subjectLabel: String, objectLabel: String, supportingAtomIDs: [StableID]) {
        self.kind = kind
        self.subjectLabel = subjectLabel
        self.objectLabel = objectLabel
        self.supportingAtomIDs = supportingAtomIDs
    }
}

public struct ParaphraseProposal: Codable, Equatable, Sendable {
    public var propositionID: StableID
    public var atomID: StableID
    public var similarity: Double

    public init(propositionID: StableID, atomID: StableID, similarity: Double) {
        self.propositionID = propositionID
        self.atomID = atomID
        self.similarity = similarity
    }
}

/// Anything that can propose structure. Implementations may be statistical,
/// on-device models, or plain code. None of them decide what is true.
public protocol ReasoningProposalProvider: Sendable {
    var identifier: String { get }
    var isAvailable: Bool { get }

    func proposeAtoms(for assignment: SourceRoleAssignment) async -> [AtomProposal]
    func proposeRelations(among atoms: [KnowledgeAtom]) async -> [RelationProposal]
    func proposeParaphrases(for proposition: LearnerProposition,
                            candidates: [KnowledgeAtom]) async -> [ParaphraseProposal]
}

/// Why a proposal was refused. Counted by the evaluation harness: a provider
/// that produces many refusals is a provider that is guessing.
public struct ProposalRejection: Codable, Equatable, Sendable {
    public enum Reason: String, Codable, Sendable {
        case spanNotFoundInSource
        case subjectNotInSpan
        case objectNotInSpan
        case unknownRelationKind
        case roleDoesNotYieldClaims
        case endpointNotInGraph
        case duplicate
    }

    public var reason: Reason
    public var detail: String

    public init(reason: Reason, detail: String) {
        self.reason = reason
        self.detail = detail
    }
}

public struct ProposalAdmissionResult: Codable, Equatable, Sendable {
    public var atoms: [KnowledgeAtom]
    public var relations: [KnowledgeRelation]
    public var rejections: [ProposalRejection]

    public init(atoms: [KnowledgeAtom], relations: [KnowledgeRelation], rejections: [ProposalRejection]) {
        self.atoms = atoms
        self.relations = relations
        self.rejections = rejections
    }
}

/// The boundary between "a model said so" and "this is in the graph".
///
/// Admission is purely mechanical: the claimed span must exist verbatim in the
/// block, the subject and object must appear in that span, and the relation
/// must be part of the fixed vocabulary. A model cannot widen this gate.
public struct ProposalAdmissionGate: Sendable {
    public var requireVerbatimSpan: Bool
    public var minimumTokenCoverage: Double

    public init(requireVerbatimSpan: Bool = true, minimumTokenCoverage: Double = 0.8) {
        self.requireVerbatimSpan = requireVerbatimSpan
        self.minimumTokenCoverage = minimumTokenCoverage
    }

    public func admit(_ proposals: [AtomProposal],
                      from assignment: SourceRoleAssignment) -> ProposalAdmissionResult {
        var atoms: [KnowledgeAtom] = []
        var rejections: [ProposalRejection] = []
        let blockText = assignment.block.text

        guard assignment.role.yieldsFactualClaims else {
            return ProposalAdmissionResult(atoms: [],
                                           relations: [],
                                           rejections: proposals.map {
                                               ProposalRejection(reason: .roleDoesNotYieldClaims,
                                                                 detail: "\($0.subject) \($0.relation) \($0.object)")
                                           })
        }

        for proposal in proposals {
            guard !requireVerbatimSpan || blockText.contains(proposal.claimedSpan) else {
                rejections.append(ProposalRejection(reason: .spanNotFoundInSource, detail: proposal.claimedSpan))
                continue
            }
            guard RelationKind(rawValue: proposal.relation) != nil else {
                rejections.append(ProposalRejection(reason: .unknownRelationKind, detail: proposal.relation))
                continue
            }
            guard TextScanning.coverage(of: proposal.subject, in: proposal.claimedSpan) >= minimumTokenCoverage else {
                rejections.append(ProposalRejection(reason: .subjectNotInSpan, detail: proposal.subject))
                continue
            }
            guard TextScanning.coverage(of: proposal.object, in: proposal.claimedSpan) >= minimumTokenCoverage else {
                rejections.append(ProposalRejection(reason: .objectNotInSpan, detail: proposal.object))
                continue
            }
            let span = SourceSpan(documentID: assignment.block.documentID,
                                  page: assignment.block.page,
                                  canonicalSpan: proposal.claimedSpan,
                                  sourceRole: assignment.role)
            let atom = KnowledgeAtom(claimType: proposal.claimType,
                                     subject: proposal.subject,
                                     relation: proposal.relation,
                                     object: proposal.object,
                                     concepts: [TextScanning.conceptSlug(proposal.subject),
                                                TextScanning.conceptSlug(proposal.object)].filter { !$0.isEmpty },
                                     qualifiers: proposal.qualifiers,
                                     isNegated: proposal.isNegated,
                                     numbers: TextScanning.numbers(in: proposal.claimedSpan),
                                     identifiers: TextScanning.identifiers(in: proposal.claimedSpan),
                                     conditions: proposal.conditions,
                                     sourceIntegrity: .normalized,
                                     // A model-proposed parse is treated as a
                                     // slightly less certain *parse*, never as a
                                     // less certain source.
                                     provenance: Provenance.stated(span, confidenceInParsing: 0.9))
            if atoms.contains(atom) {
                rejections.append(ProposalRejection(reason: .duplicate, detail: atom.statement))
            } else {
                atoms.append(atom)
            }
        }
        return ProposalAdmissionResult(atoms: atoms, relations: [], rejections: rejections)
    }

    public func admit(_ proposals: [RelationProposal], into graph: KnowledgeGraph) -> ProposalAdmissionResult {
        var relations: [KnowledgeRelation] = []
        var rejections: [ProposalRejection] = []
        for proposal in proposals {
            guard let subject = graph.resolveNode(proposal.subjectLabel),
                  let object = graph.resolveNode(proposal.objectLabel) else {
                rejections.append(ProposalRejection(reason: .endpointNotInGraph,
                                                    detail: "\(proposal.subjectLabel) -> \(proposal.objectLabel)"))
                continue
            }
            let supporting = proposal.supportingAtomIDs.compactMap { graph.atom($0) }
            guard !supporting.isEmpty else {
                rejections.append(ProposalRejection(reason: .endpointNotInGraph,
                                                    detail: "no supporting atom for \(proposal.kind.rawValue)"))
                continue
            }
            let provenance = Provenance.inferred(from: supporting.map(\.provenance),
                                                 ids: supporting.map(\.id),
                                                 rule: .crossSourceEquivalence)
            relations.append(KnowledgeRelation(kind: proposal.kind,
                                               subject: .node(subject.id),
                                               object: .node(object.id),
                                               supportingAtoms: supporting.map(\.id),
                                               provenance: provenance))
        }
        return ProposalAdmissionResult(atoms: [], relations: relations, rejections: rejections)
    }
}
