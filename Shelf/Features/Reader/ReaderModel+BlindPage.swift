import Foundation
import ShelfCore

extension ReaderModel {
    func considerBlindPage(previous: Int, new: Int) {
        guard preferences.blindPagePromptsEnabled, !blindPagePresented, !speech.isSpeaking,
              new != previous, abs(new - previous) == 1 else { return }
        blindPagesSincePrompt += 1
        let oldSection = sectionTitle(for: previous)
        let newSection = sectionTitle(for: new)
        let boundary = oldSection != nil && newSection != nil && oldSection != newSection
        let context = BlindPageContext(pagesSincePrompt: blindPagesSincePrompt,
                                       secondsSincePrompt: Date().timeIntervalSince(blindLastPromptAt),
                                       atSectionBoundary: boundary,
                                       consecutiveSkips: blindPageSkips)
        guard BlindPagePolicy().shouldPrompt(context) else { return }
        blindPagePreviousIndex = previous
        blindPageDraft = ""
        blindPagePresented = true
        blindPagesSincePrompt = 0
        blindLastPromptAt = Date()
    }

    func skipBlindPage() {
        blindPageSkips += 1
        blindPagePresented = false
    }

    func completeBlindPage() {
        blindPageSkips = max(0, blindPageSkips - 1)
        blindPagePresented = false
    }

    func blindPageSourceText() -> String {
        guard let index = blindPagePreviousIndex else { return "" }
        return readablePage(at: index).blocks.map(\.text).joined(separator: "\n\n")
    }
}
