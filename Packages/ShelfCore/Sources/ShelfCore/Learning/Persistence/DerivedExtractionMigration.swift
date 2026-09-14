import Foundation

/// Invalidates derived material only. Historical object IDs and every learner-owned
/// record remain available for attempts, confidence, trails and session history.
public enum DerivedExtractionMigration {
    @discardableResult public static func apply(to snapshot: inout LearningSnapshot) -> Bool {
        let started = DispatchTime.now().uptimeNanoseconds
        defer { IntelligencePerformance.record("snapshot_validation", since: started, workCount: snapshot.questions.count) }
        let outdated = Set(snapshot.analyses.values.filter {
            ($0.extractionVersion ?? 0) < SourceExtractionVersion.current
        }.map(\.documentID))
        var changed = false
        let count = snapshot.questions.count
        let v4Documents = Set(snapshot.questions.filter { $0.v4 != nil }.map { $0.source.documentID })
        let grouped = Dictionary(grouping: snapshot.questions.filter { $0.v4 != nil }, by: { $0.source.documentID })
        let hits = Set(snapshot.analyses.compactMap { id, analysis -> UUID? in
            snapshot.v4Receipts[id]?.matches(analysis: analysis, questions: grouped[id] ?? []) == true ? id : nil
        })
        IntelligencePerformance.record("validated_snapshot_lookup", since: started, workCount: v4Documents.subtracting(hits).count, cacheHit: v4Documents.isSubset(of: hits))
        let v4Admission = snapshot.analyses.filter { v4Documents.contains($0.key) && !hits.contains($0.key) }.mapValues { V4StudyAdmission(analysis: $0) }
        for id in Array(snapshot.v4Receipts.keys) where !hits.contains(id) { snapshot.v4Receipts.removeValue(forKey: id); changed = true }
        snapshot.questions.removeAll { question in
            if question.v4 != nil {
                if hits.contains(question.source.documentID) { return false }
                guard !outdated.contains(question.source.documentID), let gate = v4Admission[question.source.documentID] else { return true }
                return gate.rejection(question) != nil
            }
            return outdated.contains(question.source.documentID) ||
                FinalMCQAdmission.rejectionReason(question, analysis: snapshot.analyses[question.source.documentID]) != nil
        }
        changed = changed || snapshot.questions.count != count
        for id in v4Documents where !hits.contains(id) && !outdated.contains(id) {
            if let analysis = snapshot.analyses[id] {
                snapshot.v4Receipts[id] = try? ValidatedIntelligenceReceipt(analysis: analysis,
                    questions: snapshot.questions.filter { $0.v4 != nil && $0.source.documentID == id })
                changed = true
            }
        }
        for id in outdated {
            if snapshot.semanticIndexes.removeValue(forKey: id) != nil { changed = true }
        }
        for i in snapshot.learningObjects.indices where snapshot.learningObjects[i].origin == .documentAnalysis {
            let source = snapshot.learningObjects[i].source
            let page = snapshot.analyses[source.documentID]?.pages.first { $0.pageIndex == source.pageIndex }
            if outdated.contains(source.documentID) || page?.isIntelligenceEligible == false ||
                InstructionalText.isStudyFurniture(source.sourceText) ||
                InstructionalText.isMemoryHook(subject: source.sourceText, sentence: source.sourceText) {
                if snapshot.learningObjects[i].sourceIsStale != true { changed = true }
                snapshot.learningObjects[i].sourceIsStale = true
            }
        }
        return changed
    }
}
