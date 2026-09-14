import Foundation
import ShelfCore

extension ReaderModel {
    func toggleSpeech() {
        let blocks = speechInputBlocks()
        let resumeSentence = readingAnchor?.pageIndex == pageIndex ? readingAnchor?.sentence : nil
        speech.toggle(blocks: blocks, documentID: book.id, startAt: resumeSentence)
    }

    func speechInputBlocks() -> [SpeechInputBlock] {
        if let analyzed = learning.snapshot.analyses[book.id]?.pages.first(where: { $0.pageIndex == pageIndex }),
           !analyzed.segments.isEmpty {
            return analyzed.segments.map { segment in
                let kind: SpeechBlockKind
                switch segment.kind {
                case .heading: kind = .heading
                case .listItem: kind = .list
                case .code: kind = .code
                case .definition, .paragraph: kind = .prose
                case .unknown: kind = speechKind(for: segment.text, fallback: .prose)
                }
                return SpeechInputBlock(documentID: book.id, pageIndex: pageIndex, kind: kind, text: segment.text)
            }
        }
        let readable = readablePage.blocks
        if readable.isEmpty {
            let source = document?.page(at: pageIndex)?.string ?? ""
            return [SpeechInputBlock(documentID: book.id, pageIndex: pageIndex,
                                     kind: speechKind(for: source, fallback: .prose), text: source)]
        }
        return readable.map { block in
            let kind: SpeechBlockKind
            switch block.kind {
            case .heading: kind = .heading
            case .bullet: kind = .list
            case .code: kind = .code
            case .paragraph: kind = speechKind(for: block.text, fallback: .prose)
            }
            return SpeechInputBlock(documentID: book.id, pageIndex: pageIndex, kind: kind, text: block.text)
        }
    }

    private func speechKind(for text: String, fallback: SpeechBlockKind) -> SpeechBlockKind {
        let codeSignals = ["const ", "let ", "var ", "=>", "===", "!==", "Promise.", "useState(", "useEffect(", "console.", "function "]
        if codeSignals.contains(where: { text.contains($0) }) { return .code }
        if text.contains("O(") || text.contains("n²") || text.contains("n^2") { return .formula }
        return fallback
    }

    func increaseTextSize() {
        if displayMode == .read {
            preferences.readTextScale = min(1.6, preferences.readTextScale + 0.1)
        } else {
            preferences.pdfZoomScale = min(3.0, preferences.pdfZoomScale + 0.1)
        }
    }

    func decreaseTextSize() {
        if displayMode == .read {
            preferences.readTextScale = max(0.8, preferences.readTextScale - 0.1)
        } else {
            preferences.pdfZoomScale = max(0.75, preferences.pdfZoomScale - 0.1)
        }
    }

    func resetTextSize() {
        if displayMode == .read { preferences.readTextScale = 1.0 }
        else { preferences.pdfZoomScale = 1.0 }
    }

    func fitPDFPage() { preferences.pdfZoomScale = 1.0 }

    func fitPDFWidth() {
        if let multiplier = controller.fitWidthMultiplier() {
            preferences.pdfZoomScale = min(max(Double(multiplier), 0.75), 3.0)
        }
    }

    func readingWindow(minutes: Int) -> TimedReadingPlan? {
        guard let document else { return nil }
        let anchorSentence = readingAnchor?.pageIndex == pageIndex ? readingAnchor?.sentence : nil
        return windowPlanner.plan(document: document, outline: outline, startPage: pageIndex,
                                  startSentence: anchorSentence, minutes: minutes)
    }

    func startReadingWindow(_ plan: TimedReadingPlan) {
        activeTimedPlan = plan
        go(to: plan.startPage)
        savedMessage = "\(plan.requestedMinutes)-minute reading session started"
    }

    func semanticZoomOut() { semanticLevel = semanticLevel.zoomedOut() }
    func semanticZoomIn() { semanticLevel = semanticLevel.zoomedIn() }

}
