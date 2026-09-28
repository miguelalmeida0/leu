import Foundation

/// Folds evidence into the learner model. Pure and deterministic: the same evidence in the
/// same order always produces the same model.
public struct LearnerModelReducer: Sendable {
    /// Evidence older than this counts half as much as fresh evidence.
    public static let evidenceHalfLifeDays = 45.0
    /// A detour that has not returned to its objective within this long is dropped.
    public static let objectiveLifetime: TimeInterval = 7 * 86_400

    public init() {}

    /// Returns false when nothing changed (a duplicate, or a model written by a newer Leu).
    @discardableResult
    public func apply(_ evidence: LearningEvidence, to state: inout LearnerModelState) -> Bool {
        guard state.isWritable, !state.appliedEvidence.contains(where: { $0.id == evidence.id }) else { return false }
        // Older than anything the id record still remembers: it may already have been counted.
        if let watermark = state.evidenceWatermark, evidence.occurredAt <= watermark { return false }
        let now = evidence.occurredAt
        if state.objective == nil, let objective = evidence.startsObjective { state.objective = objective }
        updateMastery(evidence, in: &state)
        if evidence.channel == .choice, let confidence = evidence.confidence, evidence.outcome != .partial {
            state.calibration.record(confidence, correct: evidence.outcome == .correct)
        }
        updateMisconceptions(evidence, in: &state)
        if let probeID = evidence.probeID {
            state.recentProbes.append(ProbeRecord(probeID: probeID, concept: evidence.concept, operation: evidence.operation,
                                                  askedAt: now, outcome: evidence.outcome))
        }
        updateObjective(evidence, in: &state)
        state.appliedEvidence.append(AppliedEvidence(id: evidence.id, at: evidence.occurredAt))
        bound(&state)
        return true
    }

    public func apply(_ evidence: [LearningEvidence], to state: inout LearnerModelState) {
        for item in evidence.sorted(by: { ($0.occurredAt, $0.id) < ($1.occurredAt, $1.id) }) { apply(item, to: &state) }
    }

    private func updateMastery(_ evidence: LearningEvidence, in state: inout LearnerModelState) {
        let now = evidence.occurredAt
        var concept = state.mastery(evidence.concept) ?? ConceptMastery(concept: evidence.concept, name: evidence.conceptName, operations: [],
                                                                         confidentErrors: 0, lastConfidentErrorAt: nil,
                                                                         firstSeenAt: now, lastSeenAt: now)
        if !evidence.conceptName.isEmpty { concept.name = evidence.conceptName }
        concept.lastSeenAt = max(concept.lastSeenAt, now)
        var operation = concept.operation(evidence.operation) ?? OperationMastery(operation: evidence.operation, successWeight: 0, failureWeight: 0,
                                                                                  attempts: 0, lastEvidenceAt: now, lastSuccessAt: nil, successDays: 0)
        let days = max(0, now.timeIntervalSince(operation.lastEvidenceAt)) / 86_400
        let decay = pow(0.5, days / Self.evidenceHalfLifeDays)
        let weight = evidence.channel.weight
        operation.successWeight = operation.successWeight * decay + weight * evidence.outcome.value
        operation.failureWeight = operation.failureWeight * decay + weight * (1 - evidence.outcome.value)
        operation.attempts += 1
        operation.lastEvidenceAt = max(operation.lastEvidenceAt, now)
        if evidence.outcome == .correct {
            if operation.lastSuccessAt.map({ !Self.sameDay($0, now) }) ?? true { operation.successDays += 1 }
            operation.lastSuccessAt = now
        }
        if evidence.outcome == .incorrect, let confidence = evidence.confidence, [.fairlySure, .certain].contains(confidence) {
            concept.confidentErrors += 1
            concept.lastConfidentErrorAt = now
        }
        if let index = concept.operations.firstIndex(where: { $0.operation == evidence.operation }) { concept.operations[index] = operation }
        else { concept.operations.append(operation); concept.operations.sort { $0.operation.rawValue < $1.operation.rawValue } }
        if let index = state.concepts.firstIndex(where: { $0.concept == evidence.concept }) { state.concepts[index] = concept }
        else { state.concepts.append(concept) }
    }

    private func updateMisconceptions(_ evidence: LearningEvidence, in state: inout LearnerModelState) {
        let now = evidence.occurredAt
        if let seen = evidence.misconception {
            let id = MisconceptionRecord.id(concept: evidence.concept, kind: seen.kind, claimID: seen.claimID, related: seen.relatedConcept)
            if let index = state.misconceptions.firstIndex(where: { $0.id == id }) {
                state.misconceptions[index].occurrences += 1
                state.misconceptions[index].lastSeenAt = max(state.misconceptions[index].lastSeenAt, now)
                state.misconceptions[index].learnerWording = seen.learnerWording
                state.misconceptions[index].status = .active
                state.misconceptions[index].correctionDays = 0
            } else {
                state.misconceptions.append(MisconceptionRecord(id: id, concept: evidence.concept, kind: seen.kind, claimID: seen.claimID,
                    relatedConcept: seen.relatedConcept, learnerWording: seen.learnerWording, occurrences: 1, firstSeenAt: now,
                    lastSeenAt: now, status: .active, correctionDays: 0, lastCorrectAt: nil))
            }
            return
        }
        guard evidence.outcome != .partial else { return }
        for index in state.misconceptions.indices where state.misconceptions[index].concept == evidence.concept &&
            state.misconceptions[index].status != .resolved && Self.addresses(evidence, state.misconceptions[index]) {
            if evidence.outcome == .incorrect {
                state.misconceptions[index].status = .active
                state.misconceptions[index].correctionDays = 0
                continue
            }
            // A correction must be an answer Leu checked; "Knew it" is the learner's own read.
            // Only a correct answer after the misconception was last seen counts, once per day.
            guard evidence.channel != .selfRating, now > state.misconceptions[index].lastSeenAt,
                  state.misconceptions[index].lastCorrectAt.map({ !Self.sameDay($0, now) }) ?? true else { continue }
            state.misconceptions[index].correctionDays += 1
            state.misconceptions[index].lastCorrectAt = now
            state.misconceptions[index].status = state.misconceptions[index].correctionDays >= 2 ? .resolved : .resolving
        }
    }

    /// Evidence tests a misconception when it is about the corrected claim, or — for a
    /// confusion — when the learner had to tell the same two concepts apart.
    static func addresses(_ evidence: LearningEvidence, _ record: MisconceptionRecord) -> Bool {
        if record.kind == .confusion {
            guard let rival = record.relatedConcept else { return [.contrast, .recognizeDefinition, .recognizeExample].contains(evidence.operation) }
            return evidence.rivals.contains(rival)
        }
        if let claim = record.claimID { return evidence.claimIDs.contains(claim) }
        return evidence.operation.level >= 2
    }

    private func updateObjective(_ evidence: LearningEvidence, in state: inout LearnerModelState) {
        guard var objective = state.objective else { return }
        if evidence.occurredAt.timeIntervalSince(objective.startedAt) > Self.objectiveLifetime { state.objective = nil; return }
        guard evidence.concept == objective.prerequisite else { return }
        objective.detourAttempts += 1
        // Repaired, or three attempts spent: return to the concept the learner came for.
        state.objective = evidence.outcome == .correct || objective.detourAttempts >= 3 ? nil : objective
    }

    private func bound(_ state: inout LearnerModelState) {
        if state.recentProbes.count > LearnerModelState.probeLimit {
            state.recentProbes.removeFirst(state.recentProbes.count - LearnerModelState.probeLimit)
        }
        if state.appliedEvidence.count > LearnerModelState.evidenceIDLimit {
            let evicted = state.appliedEvidence.prefix(state.appliedEvidence.count - LearnerModelState.evidenceIDLimit)
            // What leaves the id record is still refused, by time.
            if let latest = evicted.map(\.at).max() { state.evidenceWatermark = max(state.evidenceWatermark ?? latest, latest) }
            state.appliedEvidence.removeFirst(evicted.count)
        }
        if state.misconceptions.count > LearnerModelState.misconceptionLimit {
            // Resolved records go first, then the oldest.
            state.misconceptions.sort { ($0.status == .resolved ? 0 : 1, $0.lastSeenAt, $0.id) > ($1.status == .resolved ? 0 : 1, $1.lastSeenAt, $1.id) }
            state.misconceptions.removeLast(state.misconceptions.count - LearnerModelState.misconceptionLimit)
            state.misconceptions.sort { ($0.firstSeenAt, $0.id) < ($1.firstSeenAt, $1.id) }
        }
        if state.concepts.count > LearnerModelState.conceptLimit {
            state.concepts.sort { ($0.lastSeenAt, $0.concept) > ($1.lastSeenAt, $1.concept) }
            state.concepts.removeLast(state.concepts.count - LearnerModelState.conceptLimit)
            state.concepts.sort { ($0.firstSeenAt, $0.concept) < ($1.firstSeenAt, $1.concept) }
        }
    }

    static func sameDay(_ a: Date, _ b: Date) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        return calendar.isDate(a, inSameDayAs: b)
    }
}

/// How much a concept needs retrieval practice now (0…1), from what the learner model knows.
/// Zero when the model has no evidence, so planning without evidence is unchanged.
public struct RetrievalPriority: Sendable {
    public init() {}

    public struct Components: Equatable, Sendable {
        public let misconception: Double
        public let weakness: Double
        public let confidentError: Double
        public let forgetting: Double
        public var score: Double { min(1, 0.45 * misconception + 0.25 * weakness + 0.2 * confidentError + 0.1 * forgetting) }
    }

    public func components(for concept: LearnerConceptID, in state: LearnerModelState, at date: Date) -> Components {
        let misconception = state.misconceptions(for: concept).map { $0.salience(at: date) }.max() ?? 0
        guard let mastery = state.mastery(concept) else {
            return Components(misconception: misconception, weakness: 0, confidentError: 0, forgetting: 0)
        }
        let weakness = mastery.coreStrength(at: date).map { 1 - $0 } ?? 0
        let confidentError = mastery.lastConfidentErrorAt.map { pow(0.5, max(0, date.timeIntervalSince($0)) / 86_400 / 14) } ?? 0
        let succeeded = mastery.operations.filter { $0.lastSuccessAt != nil }
        let forgetting = succeeded.isEmpty ? 0 : 1 - (succeeded.map { $0.retention(at: date) }.max() ?? 1)
        return Components(misconception: misconception, weakness: weakness, confidentError: confidentError, forgetting: forgetting)
    }

    public func score(for concept: LearnerConceptID, in state: LearnerModelState, at date: Date) -> Double {
        components(for: concept, in: state, at: date).score
    }
}
