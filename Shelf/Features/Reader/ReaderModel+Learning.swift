import Foundation
import ShelfCore

extension ReaderModel {
    func currentLearningSource() -> LearningSource? {
        if displayMode == .read, let selectedReadSource { return selectedReadSource }
        if displayMode == .original {
            let fragments = controller.captureSelection()
            if let fragment = fragments.first,
               !fragment.quote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let firstRect = fragment.rects.first.map { rect in
                    SourceBounds(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
                }
                let range = textRange(of: fragment.quote, pageIndex: fragment.pageIndex)
                return LearningSource(documentID: book.id, pageIndex: fragment.pageIndex,
                                      sourceText: fragment.quote, range: range, bounds: firstRect,
                                      sectionTitle: sectionTitle(for: fragment.pageIndex))
            }
        }

        let text = readablePage.blocks.map(\.text).joined(separator: "\n\n")
        let fallback = text.isEmpty ? (document?.page(at: pageIndex)?.string ?? "") : text
        let clean = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        let sourceText = String(clean.prefix(1_500))
        return canonicalSource(sourceText, pageIndex: pageIndex, sectionTitle: currentOutlineTitle)
    }


    func selectReadBlock(_ block: ReadableBlock, pageIndex: Int) {
        let clean = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count >= 2 else { return }
        if pageIndex != self.pageIndex { go(to: pageIndex) }
        selectedReadSource = canonicalSource(clean, pageIndex: pageIndex, sectionTitle: sectionTitle(for: pageIndex))
        playHaptic(.selectionChanged)
        showLearningActions = true
    }

    private func textRange(of quote: String, pageIndex: Int) -> SourceTextRange? {
        guard let pageText = document?.page(at: pageIndex)?.string,
              let range = SourcePassageMatcher.range(of: quote, in: pageText) else { return nil }
        return SourceTextRange(location: range.location, length: range.length)
    }

    private func canonicalSource(_ passage: String, pageIndex: Int, sectionTitle: String?) -> LearningSource {
        let range = textRange(of: passage, pageIndex: pageIndex)
        let canonical = document?.page(at: pageIndex)?.string as NSString?
        let exact = range.flatMap { range in
            canonical?.substring(with: NSRange(location: range.location, length: range.length))
        }
        return LearningSource(documentID: book.id, pageIndex: pageIndex,
            sourceText: exact ?? passage, range: range, sectionTitle: sectionTitle)
    }
}
