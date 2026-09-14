import Foundation
import ShelfCore

/// A presentation-only projection. It does not create or reinterpret semantic facts.
struct UnderstandingLensFact: Identifiable, Equatable, Sendable {
    let id: String
    let conceptName: String
    let relationshipText: String
    let sourceCaption: String
    let accessibilityIdentifier: String
    let accessibilityLabel: String
    let accessibilityValue: String
    let target: LearningSource
    private let documentOrder: String
    private let pageOrder: Int

    init(concept: SemanticConcept, proposition: SemanticProposition) {
        let evidence: SemanticEvidenceSpan = proposition.evidence
        let pageNumber: Int = evidence.pageIndex + 1
        let relationship: String = proposition.claim == nil
            ? "\(proposition.relation.questionVerb) \(proposition.objectText)" : evidence.sourceText
        id = proposition.id
        conceptName = concept.canonicalName
        relationshipText = relationship
        sourceCaption = "p. \(pageNumber) · \(proposition.truthClass.rawValue)"
        accessibilityIdentifier = "understanding-lens-fact-\(proposition.id)"
        accessibilityLabel = "\(concept.canonicalName): \(relationship)"
        accessibilityValue = "Page \(pageNumber)"
        target = evidence.learningSource
        documentOrder = evidence.documentID.uuidString
        pageOrder = evidence.pageIndex
    }

    var displaySourceCaption: String { "View source · p. \(pageOrder + 1)" }

    static func matching(
        source: LearningSource,
        semanticIndexes: [UUID: SemanticIndex]
    ) -> [UnderstandingLensFact] {
        let selectedText: String = source.sourceText.lowercased()
        var rows: [UnderstandingLensFact] = []
        for index in semanticIndexes.values {
            for proposition in index.propositions {
                guard proposition.isQuizTruth else { continue }
                guard let concept = index.concepts.first(where: { $0.id == proposition.subjectID }) else {
                    continue
                }
                guard selectedText.contains(concept.canonicalName.lowercased()) else { continue }
                rows.append(UnderstandingLensFact(concept: concept, proposition: proposition))
            }
        }
        // Preserve the existing document/page/proposition order and 24-row bound.
        rows.sort(by: orderedBefore)
        return Array(rows.prefix(24))
    }

    private static func orderedBefore(_ left: UnderstandingLensFact, _ right: UnderstandingLensFact) -> Bool {
        if left.documentOrder != right.documentOrder { return left.documentOrder < right.documentOrder }
        if left.pageOrder != right.pageOrder { return left.pageOrder < right.pageOrder }
        return left.id < right.id
    }
}
