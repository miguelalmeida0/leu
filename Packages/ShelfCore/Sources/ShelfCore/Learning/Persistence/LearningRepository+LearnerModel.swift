import Foundation

/// A snapshot with the repository revision it was read at. Revisions only grow within a
/// repository's lifetime, so an older read can be recognised and discarded.
public struct RevisionedLearningSnapshot: Sendable {
    public let snapshot: LearningSnapshot
    public let revision: Int
}

/// Admits a fetched snapshot only when it is not older than the one already applied. Two
/// refreshes can finish out of order; the older one must never overwrite the newer.
public struct SnapshotRevisionGate: Sendable {
    public private(set) var applied = -1
    public init() {}
    public mutating func admit(_ revision: Int) -> Bool {
        guard revision >= applied else { return false }
        applied = revision
        return true
    }
}

extension LearningRepository {
    /// Folds evidence into the learner model. Evidence about documents that are no longer in
    /// the library is ignored; the same evidence is never counted twice.
    public func recordEvidence(_ evidence: [LearningEvidence]) throws {
        guard !evidence.isEmpty else { return }
        try transaction { snapshot in apply(evidence, to: &snapshot) }
    }

    func apply(_ evidence: [LearningEvidence], to snapshot: inout LearningSnapshot) {
        let admissible = evidence.prefix(24).filter { snapshot.analyses[$0.concept.documentID] != nil }
        reducer.apply(Array(admissible), to: &snapshot.learnerModel)
    }
}
