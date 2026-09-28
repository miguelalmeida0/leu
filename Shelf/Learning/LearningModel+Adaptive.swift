import Foundation
import ShelfCore

/// The learner model in the study flow: grounded knowledge, stale-snapshot protection, typed
/// recall compared with the source, and the evidence every answer adds to the learner model.
@MainActor extension LearningModel {
    /// Applies the repository's snapshot unless a newer one is already on screen: two refreshes
    /// can finish out of order, and the older one must never undo the newer.
    func refreshSnapshot() async throws {
        let fetched = try await repository.revisionedSnapshot()
        if snapshotGate.admit(fetched.revision) { snapshot = fetched.snapshot }
    }

    /// The knowledge compiled so far for every document, merged in document order so every
    /// launch sees the same knowledge. Never waits: planning without it is the planning Leu
    /// always did.
    var readyKnowledge: ConceptKnowledgeBase {
        let current = snapshot.analyses
        let ready = knowledgeByDocument.filter { documentID, entry in
            current[documentID].map { ConceptKnowledgeCache.key($0) == entry.key } == true
        }.sorted { $0.key.uuidString < $1.key.uuidString }
        let key = ready.map { "\($0.key)|\($0.value.key)" }.joined(separator: ",")
        if let merged = mergedKnowledge, merged.key == key { return merged.base }
        let base = ConceptKnowledgeBase.merged(ready.map(\.value.base))
        mergedKnowledge = (key, base)
        return base
    }

    /// One document's knowledge, when current. Concept names repeat across documents, so an
    /// answer is always read against the knowledge of the document it came from.
    func readyKnowledge(for documentID: UUID) -> ConceptKnowledgeBase {
        guard let entry = knowledgeByDocument[documentID], let analysis = snapshot.analyses[documentID],
              ConceptKnowledgeCache.key(analysis) == entry.key else { return .empty }
        return entry.base
    }

    /// Compiles, off the main actor, the knowledge of documents whose extraction changed.
    func warmKnowledge() {
        let pending = snapshot.analyses.values.filter { analysis in
            analysis.extractionVersion == SourceExtractionVersion.current &&
                knowledgeByDocument[analysis.documentID]?.key != ConceptKnowledgeCache.key(analysis)
        }
        guard !pending.isEmpty else { return }
        Task { [weak self] in
            for analysis in pending { _ = await self?.knowledge(for: analysis) }
        }
    }

    func knowledge(for analysis: DocumentAnalysis) async -> ConceptKnowledgeBase {
        let key = ConceptKnowledgeCache.key(analysis)
        if let entry = knowledgeByDocument[analysis.documentID], entry.key == key { return entry.base }
        let base = await knowledgeCache.knowledge(for: analysis)
        knowledgeByDocument[analysis.documentID] = (key, base)
        return base
    }

    /// Compares the typed recall with the claims it should express (the activity's question when
    /// there is one, otherwise the passage). Lexical evidence only; shown as a next step, not a
    /// grade. Runs off the main actor and is dropped if the learner has moved on.
    func diagnoseRecall() {
        recallDiagnosis = nil
        recallAssessment = nil
        let draft = recallDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !recallMarkedUnknown, !draft.isEmpty, let object = currentObject else { return }
        let knowledge = readyKnowledge(for: object.source.documentID)
        guard !knowledge.isEmpty else { return }
        let probe = currentActivity?.probe, activity = currentActivity?.id
        // Read against what the learner model already holds: a live misconception is not papered over.
        let model = snapshot.learnerModel, now = Date()
        Task { [weak self] in
            let assessment = await Task.detached(priority: .userInitiated) { () -> UnderstandingAssessment? in
                let target = probe.flatMap { DiagnosisTarget.probe($0, in: knowledge) } ?? DiagnosisTarget.passage(object.source, in: knowledge)
                let concepts = probe.map { [$0.concept] } ?? LearnerEvidenceMapper(knowledge: knowledge).concepts(in: object.source).map(\.id)
                return target.map { UnderstandingDiagnoser().assess(draft, target: $0, prior: LearnerPrior(model, concepts: concepts, at: now)) }
            }.value
            guard let self, self.currentActivity?.id == activity, self.recallDraft.trimmingCharacters(in: .whitespacesAndNewlines) == draft else { return }
            self.recallAssessment = assessment
            self.recallDiagnosis = assessment?.diagnosis
        }
    }

    /// What a wrong option reveals, when it can be traced to the source. Computed off the main
    /// actor; the feedback note appears once it is known, only for the answer still on screen.
    func explainChosenOption(_ question: LearningQuestion) {
        answerFeedbackNote = nil
        guard let selectedAnswerID, selectedAnswerID != question.correctOptionID,
              let chosen = question.options.first(where: { $0.id == selectedAnswerID }) else { return }
        let knowledge = readyKnowledge(for: question.source.documentID)
        guard !knowledge.isEmpty else { return }
        let activity = currentActivity?.id
        Task { [weak self] in
            let note = await Task.detached(priority: .userInitiated) { () -> String? in
                let tested = LearnerEvidenceMapper(knowledge: knowledge).concept(for: question)
                return DistractorAnalysis.analyze(question: question, selected: chosen, tested: tested, in: knowledge).explanation
            }.value
            guard let self, self.currentActivity?.id == activity, self.selectedAnswerID == chosen.id else { return }
            self.answerFeedbackNote = note
        }
    }

    /// Everything the current answer shows about the learner, committed with the review itself.
    /// The inputs are read here; the analysis runs off the main actor.
    func adaptiveEvidence(for object: LearningObject, rating: RecallRating, at date: Date) async -> [LearningEvidence] {
        let knowledge = readyKnowledge(for: object.source.documentID)
        guard !knowledge.isEmpty else { return [] }
        let input = AdaptiveEvidenceInput(knowledge: knowledge, object: object, rating: rating, question: currentQuestion,
                                          selected: selectedAnswerID, confidence: selectedConfidence, probe: currentActivity?.probe,
                                          detour: currentActivity?.remediation, assessment: recallAssessment, date: date)
        return await Task.detached(priority: .userInitiated) { input.evidence() }.value
    }

    /// A fresh activity starts with no answer, no recall and nothing noticed yet.
    func resetActivityState() {
        recallDraft = ""
        recallMarkedUnknown = false
        recallDiagnosis = nil
        recallAssessment = nil
        answerFeedbackNote = nil
        selectedAnswerID = nil
        answerCommitted = false
        selectedConfidence = nil
        revealedHintCount = 0
        activityStartedAt = Date()
    }
}

/// A snapshot of one answer, taken on the main actor, turned into evidence anywhere.
struct AdaptiveEvidenceInput: Sendable {
    let knowledge: ConceptKnowledgeBase
    let object: LearningObject
    let rating: RecallRating
    let question: LearningQuestion?
    let selected: UUID?
    let confidence: ConfidenceLevel?
    let probe: LearningProbe?
    let detour: RemediationObjective?
    let assessment: UnderstandingAssessment?
    let date: Date

    func evidence() -> [LearningEvidence] {
        let mapper = LearnerEvidenceMapper(knowledge: knowledge)
        if let question {
            return mapper.evidence(answering: question, selected: selected, confidence: confidence,
                                   operation: probe?.operation, probeID: probe?.id, at: date, startsObjective: detour)
        }
        return mapper.evidence(recall: object.source, rating: rating, probe: probe, assessment: assessment, at: date, startsObjective: detour)
    }
}
