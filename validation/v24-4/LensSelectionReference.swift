import Foundation
import ShelfCore

// V24.3 selection reference; only its model dependency is supplied as a parameter.
func legacyFacts(source: LearningSource, semanticIndexes: [UUID: SemanticIndex]) -> [(concept: SemanticConcept, proposition: SemanticProposition)] {
        let selectedText = source.sourceText.lowercased()
        let all = semanticIndexes.values.flatMap { index in
            index.propositions.compactMap { proposition -> (SemanticConcept, SemanticProposition)? in
                guard proposition.isQuizTruth,
                      let concept = index.concepts.first(where: { $0.id == proposition.subjectID }) else { return nil }
                let sameConcept = selectedText.contains(concept.canonicalName.lowercased())
                guard sameConcept else { return nil }
                return (concept, proposition)
            }
        }
        return Array(all.sorted {
            let left = $0.1.evidence, right = $1.1.evidence
            if left.documentID != right.documentID { return left.documentID.uuidString < right.documentID.uuidString }
            if left.pageIndex != right.pageIndex { return left.pageIndex < right.pageIndex }
            return $0.1.id < $1.1.id
        }.prefix(24))
    }
