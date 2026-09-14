import Foundation

/// Ranking is separate from the quality gate: interest never rescues bad English.
public struct ConceptImportanceModel: Sendable {
    public init() {}

    public func sourceScore(_ question: LearningQuestion, index: SemanticIndex?, analysis: DocumentAnalysis?) -> Double {
        guard let index, let proposition = index.propositions.first(where: { $0.id == question.propositionID }),
              let concept = index.concepts.first(where: { $0.id == proposition.subjectID }) else { return question.qualityScore }
        let claims = index.propositions.filter { $0.subjectID == concept.id }
        let pages = Set(claims.map { $0.evidence.pageIndex }).count
        let sections = analysis?.pages.flatMap(\.segments) ?? []
        let heading = sections.contains { $0.kind == .heading && $0.text.localizedCaseInsensitiveContains(concept.canonicalName) }
        let section = proposition.evidence.sectionTitle?.localizedCaseInsensitiveContains(concept.canonicalName) == true
        let density = Set(claims.map(\.relation)).count
        let definition = claims.contains { $0.relation == .definedAs }
        return question.qualityScore * 0.55 + (heading ? 0.14 : section ? 0.08 : 0)
            + (definition ? 0.06 : 0) + min(0.12, Double(claims.count) * 0.025)
            + min(0.10, Double(pages) * 0.025) + min(0.10, Double(density) * 0.025)
    }

    public func score(_ question: LearningQuestion, snapshot: LearningSnapshot, annotations: [StudyAnnotation] = []) -> Double {
        let source = question.source
        let base = sourceScore(question, index: snapshot.semanticIndexes[source.documentID], analysis: snapshot.analyses[source.documentID])
        let objects = snapshot.learningObjects.filter { $0.source.documentID == source.documentID && $0.source.pageIndex == source.pageIndex }
        let ids = Set(objects.map(\.id))
        let marked = objects.contains { $0.origin == .userSelection }
        let trail = snapshot.trails.contains { trail in trail.nodes.contains { node in
            node.referenceID == question.id || node.referenceID.map { ids.contains($0) } == true ||
                (node.documentID == source.documentID && (node.pageRange?.contains(source.pageIndex) ?? true))
        } }
        let connected = snapshot.relationships.contains { ids.contains($0.sourceObjectID) || ids.contains($0.targetObjectID) }
        let wrong = snapshot.attempts.filter { $0.questionID == question.id && $0.wasCorrect == false }.count
        let mismatches = snapshot.confidenceRecords.filter { $0.questionID == question.id && !$0.wasCorrect && $0.confidence.numericValue >= 0.65 }.count
        let marks = annotations.filter { $0.bookID == source.documentID && $0.pageIndex == source.pageIndex }
        let interest = (marks.contains { $0.kind.isStudyMarker } ? 0.08 : 0)
            + (marks.contains { $0.kind == .highlight || $0.kind == .underline } ? 0.06 : 0)
            + (marks.contains { $0.kind == .confusing } ? 0.10 : 0)
        let lens = min(0.10, Double(snapshot.lensUsage["\(source.documentID)|\(source.pageIndex)"] ?? 0) * 0.02)
        return base + interest + lens + (marked ? 0.12 : 0) + (trail ? 0.10 : 0) + (connected ? 0.08 : 0)
            + min(0.18, Double(wrong) * 0.06) + min(0.16, Double(mismatches) * 0.08)
    }

    public func ranked(_ questions: [LearningQuestion], snapshot: LearningSnapshot, annotations: [StudyAnnotation] = []) -> [LearningQuestion] {
        questions.sorted {
            if ($0.v4 != nil) != ($1.v4 != nil) { return $0.v4 != nil }
            let a = score($0, snapshot: snapshot, annotations: annotations), b = score($1, snapshot: snapshot, annotations: annotations)
            return a == b ? $0.stableKey < $1.stableKey : a > b
        }
    }
}
