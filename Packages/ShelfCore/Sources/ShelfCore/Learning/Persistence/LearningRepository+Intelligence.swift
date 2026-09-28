import Foundation

/// Teach Leu attempts, understanding events and model questions: each admitted only while its
/// source is current and it passes the same validation it was created under.
extension LearningRepository {
    public func storeUnderstandingAttempt(_ attempt: UnderstandingAttempt) throws {
        try transaction { snapshot in try store(attempt, in: &snapshot) }
    }

    /// What a Teach It Back attempt shows, committed with the attempt itself. An attempt adds
    /// evidence once, however often and however much later it is compared again: the stored
    /// attempt remembers that it was counted, so no id record has to.
    public func recordEvidence(_ evidence: [LearningEvidence], for attempt: UnderstandingAttempt) throws {
        try transaction { snapshot in
            var attempt = attempt
            attempt.evidenceRecordedAt = snapshot.understandingAttempts.first { $0.id == attempt.id }?.evidenceRecordedAt ?? attempt.evidenceRecordedAt
            if attempt.evidenceRecordedAt == nil, let first = evidence.first {
                apply(evidence, to: &snapshot)
                attempt.evidenceRecordedAt = first.occurredAt
            }
            try store(attempt, in: &snapshot)
        }
    }

    private func store(_ attempt: UnderstandingAttempt, in snapshot: inout LearningSnapshot) throws {
        guard attempt.source.isCurrent(in: snapshot.analyses), attempt.learnerExplanation.count <= 6000 else {
            throw LearningIntelligenceError.sourceIntegrityFailed
        }
        if let result = attempt.result {
            guard result.source == attempt.source,
                  TeachLeuValidator.isValid(result, explanation: attempt.learnerExplanation, analyses: snapshot.analyses) else {
                throw LearningIntelligenceError.invalidResponse
            }
        }
        var attempt = attempt
        // A later save of the draft never forgets that the attempt was already counted.
        if let existing = snapshot.understandingAttempts.first(where: { $0.id == attempt.id }) {
            attempt.evidenceRecordedAt = attempt.evidenceRecordedAt ?? existing.evidenceRecordedAt
        }
        snapshot.understandingAttempts.removeAll { $0.id == attempt.id }
        snapshot.understandingAttempts.append(attempt)
    }

    public func storeUnderstandingEvent(_ event: UnderstandingEvent) throws {
        try transaction { snapshot in
            guard event.source.isCurrent(in: snapshot.analyses) else { throw LearningIntelligenceError.sourceIntegrityFailed }
            if !snapshot.understandingEvents.contains(where: { $0.id == event.id }) { snapshot.understandingEvents.append(event) }
        }
    }

    public func storeModelQuestion(_ question: LearningQuestion) throws {
        try transaction { snapshot in
            guard let provenance = question.modelProvenance,
                  let analysis = snapshot.analyses[question.source.documentID],
                  analysis.fingerprint == provenance.packet.fingerprint,
                  analysis.extractionVersion == provenance.packet.extractionVersion,
                  analysis.pages.contains(where: { $0.isIntelligenceEligible && $0.pageIndex == question.source.pageIndex && $0.canonicalText == provenance.packet.sourceText }) else {
                throw LearningIntelligenceError.sourceIntegrityFailed
            }
            guard FinalMCQAdmission.rejectionReason(question, analysis: analysis) == nil else {
                throw LearningIntelligenceError.sourceIntegrityFailed
            }
            if !snapshot.questions.contains(where: { $0.id == question.id }) { snapshot.questions.append(question) }
        }
    }
}
