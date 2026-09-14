import Foundation
import ShelfCore

extension ReaderModel {
    var returnLabel: String {
        if initialKnowledgeTravel && knowledge.canNavigateBack {
            return knowledge.backStack.last?.restoreLens != nil ? "Back to Understanding Lens" : "Back to previous passage"
        }
        if initialLensSource != nil { return "Back to library" }
        if let sourceReturnLabel { return sourceReturnLabel }
        return initialSourceText == nil ? "Back to library" : "Back to question"
    }

    func restoreSourceHighlight(_ source: String) {
        setDisplayMode(.original)
        if !controller.showSourceHighlight(source, pageIndex: pageIndex) {
            savedMessage = "Source page opened. This PDF's text layer could not uniquely locate the passage."
        }
    }

    func requestLens(_ source: LearningSource) {
        guard readablePage(at: source.pageIndex).sourceIntegrityPassed else {
            savedMessage = "This page is readable, but its layout could not be verified for study."
            return
        }
        learning.prepareIntelligence(for: source)
        Task {
            do {
                try await learning.repository.recordLensUse(source)
                learning.snapshot = try await learning.repository.snapshot()
            } catch { learning.errorMessage = error.localizedDescription }
        }
        pendingLensSource = source
        showLearningActions = false
    }

    func presentRequestedLens() {
        guard let source = pendingLensSource else { return }
        pendingLensSource = nil
        lensSource = source
    }

    func restoreInitialLens() {
        guard let source = initialLensSource, readablePage(at: source.pageIndex).sourceIntegrityPassed else { return }
        selectedReadSource = source
        lensSource = source
    }
}
