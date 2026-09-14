import Foundation

/// A rejected artifact, kept so that evaluation can count what the engine
/// refused rather than silently dropping it.
public struct AdmissionRejection: Codable, Equatable, Sendable {
    public enum Reason: String, Codable, Sendable {
        case missingProvenance
        case missingSupportingAtoms
        case unknownEndpoint
        case nonFactualRole
        case inferredWithoutParents
        case negatedEdge
        case selfLoop
        case unsupportedBridge
    }

    public var artifactID: StableID
    public var reason: Reason
    public var detail: String

    public init(artifactID: StableID, reason: Reason, detail: String) {
        self.artifactID = artifactID
        self.reason = reason
        self.detail = detail
    }
}

public struct AdmissionReport: Codable, Equatable, Sendable {
    public var admittedAtoms: [KnowledgeAtom]
    public var admittedRelations: [KnowledgeRelation]
    public var rejections: [AdmissionRejection]

    public init(admittedAtoms: [KnowledgeAtom],
                admittedRelations: [KnowledgeRelation],
                rejections: [AdmissionRejection]) {
        self.admittedAtoms = admittedAtoms
        self.admittedRelations = admittedRelations
        self.rejections = rejections
    }

    public var isClean: Bool { rejections.isEmpty }
}

/// Owns admission. Model providers may *propose* anything; nothing enters the
/// graph without passing these deterministic checks.
public struct GraphValidator: Sendable {
    public init() {}

    public func validate(atoms: [KnowledgeAtom], relations: [KnowledgeRelation]) -> AdmissionReport {
        var admittedAtoms: [KnowledgeAtom] = []
        var rejections: [AdmissionRejection] = []
        var atomIDs: Set<String> = []

        for atom in atoms.sorted(by: { $0.id.rawValue < $1.id.rawValue }) {
            guard atom.provenance.isComplete else {
                rejections.append(AdmissionRejection(artifactID: atom.id,
                                                     reason: .missingProvenance,
                                                     detail: "atom has no traceable span"))
                continue
            }
            guard atom.sourceRole.yieldsFactualClaims || atom.sourceRole == .unknown else {
                rejections.append(AdmissionRejection(artifactID: atom.id,
                                                     reason: .nonFactualRole,
                                                     detail: "role \(atom.sourceRole.rawValue) does not yield factual claims"))
                continue
            }
            admittedAtoms.append(atom)
            atomIDs.insert(atom.id.rawValue)
        }

        let expectedStated = KnowledgeGraphBuilder().build(atoms: admittedAtoms).relations
        let expectedInferred = CertifiedReasoningIndex.definitionSubstitutions(admittedAtoms)
            + CertifiedReasoningIndex.definitionConnections(admittedAtoms)
        var admittedRelations: [KnowledgeRelation] = []
        for relation in relations.sorted(by: { $0.id.rawValue < $1.id.rawValue }) {
            if relation.subject.id == relation.object.id {
                rejections.append(AdmissionRejection(artifactID: relation.id,
                                                     reason: .selfLoop,
                                                     detail: "relation points at itself"))
                continue
            }
            guard relation.provenance.isComplete else {
                rejections.append(AdmissionRejection(artifactID: relation.id,
                                                     reason: .missingProvenance,
                                                     detail: "relation has no traceable span"))
                continue
            }
            switch relation.provenance.admissibility {
            case .sourceSupported:
                let supported = relation.supportingAtoms.allSatisfy { atomIDs.contains($0.rawValue) }
                guard !relation.supportingAtoms.isEmpty, supported else {
                    rejections.append(AdmissionRejection(artifactID: relation.id,
                                                         reason: .missingSupportingAtoms,
                                                         detail: "source-supported relation must cite admitted atoms"))
                    continue
                }
                guard expectedStated.contains(relation) else {
                    rejections.append(AdmissionRejection(artifactID: relation.id, reason: .unsupportedBridge,
                                                         detail: "edge endpoints, predicate, guards or provenance differ from the supporting atoms"))
                    continue
                }
            case .inferredValidated:
                guard !relation.provenance.derivedFrom.isEmpty, relation.provenance.rule != .none else {
                    rejections.append(AdmissionRejection(artifactID: relation.id,
                                                         reason: .inferredWithoutParents,
                                                         detail: "inferred relation must name its parents and rule"))
                    continue
                }
                guard expectedInferred.contains(relation) else {
                    rejections.append(AdmissionRejection(artifactID: relation.id, reason: .unsupportedBridge,
                                                         detail: "named rule and parents do not establish this edge"))
                    continue
                }
            }
            admittedRelations.append(relation)
        }

        return AdmissionReport(admittedAtoms: admittedAtoms,
                               admittedRelations: admittedRelations,
                               rejections: rejections)
    }
}
