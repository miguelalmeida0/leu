import Foundation
import ShelfCore

extension KnowledgeModel {
    func search() {
        searchResult = searchEngine.search(searchText, in: snapshot)
    }

    var matchingHighlights: [StudyAnnotation] {
        let clean = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count >= 2 else { return [] }
        return library.snapshot.annotations.filter { annotation in
            !annotation.quote.isEmpty &&
            (annotation.quote.localizedCaseInsensitiveContains(clean) ||
             annotation.note.localizedCaseInsensitiveContains(clean))
        }.sorted { $0.createdAt > $1.createdAt }
    }

    func queueNavigation(to annotation: StudyAnnotation) {
        let source = LearningSource(documentID: annotation.bookID, pageIndex: annotation.pageIndex,
                                    sourceText: annotation.quote)
        if let passage = passage(for: source) {
            queueNavigation(to: passage)
        } else {
            pendingDestination = KnowledgeDestination(documentID: annotation.bookID,
                pageIndex: annotation.pageIndex, sourceText: annotation.quote)
        }
    }
}
