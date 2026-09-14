import Foundation
import ShelfCore

extension ReaderModel {
    /// External navigation is explicit. Passive vertical scrolling never feeds back into a jump.
    func go(to page: Int) {
        speech.stop()
        selectedReadSource = nil
        let target = min(max(page, 0), max(book.pageCount - 1, 0))
        if displayMode == .original { controller.go(to: target) }
        let previous = pageIndex
        if pageIndex != target {
            pageIndex = target
            updateReadingAnchorForPageChange(target)
            playHaptic(.pageTurn)
            considerBlindPage(previous: previous, new: target)
        }
        refreshReadablePage()
        recorder.schedule(ReadingPosition(pageIndex: target, scaleRatio: preferences.pdfZoomScale))
        navigationRevision &+= 1
    }

    func receivePDFPosition(_ position: ReadingPosition) {
        // A detached PDFView is not allowed to overwrite the visible Read-mode location.
        guard displayMode == .original else { return }
        let previous = pageIndex
        let changed = previous != position.pageIndex
        pageIndex = position.pageIndex
        if changed {
            refreshReadablePage()
            updateReadingAnchorForPageChange(position.pageIndex)
            if isLoaded { playHaptic(.pageTurn); considerBlindPage(previous: previous, new: position.pageIndex) }
        }
        recorder.schedule(position)
    }

    func didScrollReadPage(to page: Int) {
        guard displayMode == .read, preferences.pageFlow == .vertical,
              (0..<book.pageCount).contains(page), pageIndex != page else { return }
        let previous = pageIndex
        selectedReadSource = nil
        pageIndex = page
        refreshReadablePage()
        if !speech.isSpeaking { updateReadingAnchorForPageChange(page) }
        considerBlindPage(previous: previous, new: page)
        recorder.schedule(ReadingPosition(pageIndex: page, scaleRatio: preferences.pdfZoomScale))
    }

    /// Bounded synchronous cache, consumed by lazy page views on the main actor.
    /// No observable mutation from a View body and no whole-document extraction on slider drags.
    func readablePage(at index: Int) -> ReadablePage {
        if let cached = readableCache[index] { return cached }
        guard let document else { return ReadablePage(pageIndex: index, blocks: []) }
        if documentFurniture == nil { documentFurniture = PDFDocumentFurniture(document: document) }
        let value = readableExtractor.extract(document: document, pageIndex: index, furniture: documentFurniture)
        readableCache[index] = value
        readableCacheOrder.append(index)
        while readableCacheOrder.count > 16 {
            let old = readableCacheOrder.removeFirst()
            readableCache.removeValue(forKey: old)
        }
        return value
    }
}
