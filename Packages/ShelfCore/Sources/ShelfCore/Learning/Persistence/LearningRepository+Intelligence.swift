import Foundation

/// Teach Leu attempts, understanding events and model questions: each admitted only while its
/// source is current and it passes the same validation it was created under.
extension LearningRepository {
    public func storeUnderstandingAttempt(_ attempt: UnderstandingAttempt) throws {
        try transaction { snapshot in
            guard attempt.source.isCurrent(in: snapshot.analyses), attempt.learnerExplanation.count <= 6000 else {
                throw LearningIntelligenceError.sourceIntegrityFailed
            }
            if let result = attempt.result {
                guard result.source == attempt.source,
                      TeachLeuValidator.isValid(result, explanation: attempt.learnerExplanation, analyses: snapshot.analyses) else {
                    throw LearningIntelligenceError.invalidResponse
                }
            }
            snapshot.understandingAttempts.removeAll { $0.id == attempt.id }
            snapshot.understandingAttempts.append(attempt)
        }
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
