import PDFKit
import SwiftUI
import ShelfCore

/// Owns PDFKit interaction only. Persistence and SwiftUI presentation stay elsewhere.
@MainActor
final class PDFSessionController {
    let view = ShelfPDFView()
    private(set) lazy var zoom = PDFZoomState(view: view)
    var onUserZoom: ((Double) -> Void)?
    var onNavigate: (() -> Void)?
    var onPosition: ((ReadingPosition) -> Void)?
    var onSelection: ((Bool) -> Void)?
    private var observers: [NSObjectProtocol] = []
    private var restoring = false
    private var rendered: [UUID: StudyAnnotation] = [:]
    private var speechAnnotations: [(PDFPage, PDFAnnotation)] = []
    private var sourceAnnotations: [(PDFPage, PDFAnnotation)] = []
    private var configuredFlow: PageFlow?
    private var configuredSurround: ReaderSurround?

    init() {
        view.autoScales = false
        view.displayBox = .cropBox
        view.displaysPageBreaks = false
        view.pageBreakMargins = .zero
        view.backgroundColor = UIColor(ShelfTheme.background)
        view.onViewportLayout = { [weak self] in self?.zoom.applyIfNeeded() }
        zoom.onUserZoom = { [weak self] value in self?.onUserZoom?(value) }
        observers.append(NotificationCenter.default.addObserver(forName: .PDFViewScaleChanged, object: view, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.restoring else { return }
                self.zoom.observedScaleChange()
                self.reportPosition()
            }
        })
        for name in [Notification.Name.PDFViewPageChanged] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: view, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.reportPosition() }
            })
        }
        observers.append(NotificationCenter.default.addObserver(forName: .PDFViewSelectionChanged, object: view, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.onSelection?(!(self.view.currentSelection?.string ?? "").isEmpty)
            }
        })
    }

    deinit { for observer in observers { NotificationCenter.default.removeObserver(observer) } }

    func install(_ document: PDFDocument, marks: [StudyAnnotation], position: ReadingPosition) {
        restoring = true
        view.document = document
        view.backgroundColor = UIColor(configuredSurround?.color ?? ShelfTheme.background)
        synchronize(marks)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.view.layoutIfNeeded()
            let clamped = position.clamped(toPageCount: document.pageCount)
            if let page = document.page(at: clamped.pageIndex) {
                self.view.go(to: page)
                if let x = clamped.pointX, let y = clamped.pointY {
                    self.view.go(to: PDFDestination(page: page, at: CGPoint(x: x, y: y)))
                }
                self.zoom.applyIfNeeded()
            }
            self.restoring = false
            self.reportPosition()
        }
    }

    /// Horizontal Original mode is deliberately a true one-page viewport. Page identity belongs
    /// to PDFKit's currentPage, never to an internal UIScrollView content offset. This prevents
    /// settled half-page/half-next-page states on mixed-size PDFs and at non-100% magnification.
    func configure(flow: PageFlow, surround: ReaderSurround) {
        if configuredFlow != flow {
            let preservedPage = view.currentPage
            restoring = true
            onNavigate?()
            view.displaysAsBook = false
            if view.isUsingPageViewController { view.usePageViewController(false, withViewOptions: nil) }
            if flow == .horizontal {
                view.displayMode = .singlePage
                view.displayDirection = .horizontal
                view.displaysPageBreaks = false
                view.pageBreakMargins = .zero
            } else {
                view.displayMode = .singlePageContinuous
                view.displayDirection = .vertical
                view.displaysPageBreaks = true
                view.pageBreakMargins = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
            }
            configuredFlow = flow
            if let preservedPage { view.go(to: preservedPage) }
            view.layoutIfNeeded()
            zoom.applyIfNeeded()
            restoring = false
        }

        if configuredSurround != surround {
            view.backgroundColor = UIColor(surround.color)
            configuredSurround = surround
        }
    }

    func applyReadingScale(_ scale: Double) { zoom.request(scale) }

    func fitWidthMultiplier() -> CGFloat? { zoom.widthMultiplier() }

    func isAtFitScale() -> Bool { zoom.atFit }

    /// Page turning owns the horizontal drag whenever the page has no width left
    /// to pan. Only a genuinely wider-than-viewport zoom keeps PDFKit's native pan.
    func canPageHorizontally() -> Bool { zoom.atFit || zoom.horizontallyContained }

    func goRelative(_ delta: Int) {
        guard let document = view.document, let page = view.currentPage else { return }
        let current = document.index(for: page)
        guard current != NSNotFound else { return }
        let target = min(max(current + delta, 0), max(document.pageCount - 1, 0))
        guard target != current else { return }
        go(to: target)
    }

    func go(to pageIndex: Int) {
        clearSourceHighlight()
        guard let document = view.document,
              let page = document.page(at: min(max(pageIndex, 0), max(document.pageCount - 1, 0))) else { return }
        onNavigate?()
        restoring = true
        view.clearSelection()
        view.go(to: page)
        view.layoutIfNeeded()
        zoom.applyIfNeeded()
        restoring = false
        reportPosition()
    }

    func find(_ result: PassageMatch) {
        guard let page = view.document?.page(at: result.pageIndex) else { return }
        go(to: result.pageIndex)
        if let selection = page.selection(for: NSRange(location: result.location, length: result.length)) {
            view.setCurrentSelection(selection, animate: false)
            view.go(to: selection)
        }
        reportPosition()
    }

    func reveal(_ mark: StudyAnnotation) {
        guard let page = view.document?.page(at: mark.pageIndex) else { return }
        go(to: mark.pageIndex)
        if let first = mark.rects.first {
            let point = CGPoint(x: first.x, y: first.y + first.height)
            view.go(to: PDFDestination(page: page, at: point))
        }
        reportPosition()
    }

    func currentPosition() -> ReadingPosition? {
        guard let document = view.document, let page = view.currentPage else { return nil }
        let index = document.index(for: page)
        guard index != NSNotFound else { return nil }
        let fit = zoom.fitScale
        let destination = view.currentDestination
        return ReadingPosition(pageIndex: index, scaleRatio: fit > 0 ? view.scaleFactor / fit : 1,
            pointX: destination.map { Double($0.point.x) }, pointY: destination.map { Double($0.point.y) })
    }

    func showSpeechHighlight(_ sentence: String?, pageIndex: Int) {
        clearSpeechHighlight()
        guard let sentence, !sentence.isEmpty,
              let document = view.document,
              let page = document.page(at: pageIndex),
              let pageText = page.string,
              let range = SourcePassageMatcher.range(of: sentence, in: pageText) else { return }
        guard let selection = page.selection(for: range) else { return }
        for line in selection.selectionsByLine() {
            let bounds = line.bounds(for: page).intersection(page.bounds(for: .cropBox))
            guard !bounds.isNull, bounds.width > 0, bounds.height > 0 else { continue }
            let annotation = PDFAnnotation(bounds: bounds.insetBy(dx: -1.5, dy: -1), forType: .highlight, withProperties: nil)
            annotation.color = UIColor(red: 0.91, green: 0.84, blue: 0.59, alpha: 0.58)
            page.addAnnotation(annotation)
            speechAnnotations.append((page, annotation))
        }
    }

    func clearSpeechHighlight() {
        for (page, annotation) in speechAnnotations { page.removeAnnotation(annotation) }
        speechAnnotations.removeAll()
    }

    @discardableResult func showSourceHighlight(_ text: String, pageIndex: Int) -> Bool {
        clearSourceHighlight()
        guard !text.isEmpty, let document = view.document, let page = document.page(at: pageIndex),
              let pageText = page.string else { return false }
        guard let range = SourcePassageMatcher.range(of: text, in: pageText),
              let selection = page.selection(for: range) else { return false }
        for line in selection.selectionsByLine() {
            let bounds = line.bounds(for: page).intersection(page.bounds(for: .cropBox))
            guard !bounds.isNull, bounds.width > 0, bounds.height > 0 else { continue }
            let annotation = PDFAnnotation(bounds: bounds.insetBy(dx: -2, dy: -1), forType: .highlight, withProperties: nil)
            annotation.color = UIColor(red: 0.93, green: 0.80, blue: 0.38, alpha: 0.34)
            page.addAnnotation(annotation); sourceAnnotations.append((page, annotation))
        }
        if !sourceAnnotations.isEmpty { view.go(to: selection) }
        return !sourceAnnotations.isEmpty
    }

    func clearSourceHighlight() {
        for (page, annotation) in sourceAnnotations { page.removeAnnotation(annotation) }
        sourceAnnotations.removeAll()
    }

    func clearSelection() { view.clearSelection(); onSelection?(false) }

    func captureSelection() -> [SelectionFragment] {
        guard let selection = view.currentSelection, let document = view.document else { return [] }
        return selection.pages.compactMap { page in
            let pageIndex = document.index(for: page)
            guard pageIndex != NSNotFound else { return nil }
            let lines = selection.selectionsByLine().filter { $0.pages.contains(page) }
            let rects = lines.compactMap { line -> PDFRect? in
                let rect = line.bounds(for: page).intersection(page.bounds(for: .cropBox))
                guard !rect.isNull, !rect.isInfinite, rect.width > 0, rect.height > 0 else { return nil }
                return PDFRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height)
            }
            guard !rects.isEmpty else { return nil }
            return SelectionFragment(pageIndex: pageIndex, rects: rects, quote: lines.compactMap(\.string).joined(separator: " "))
        }
    }

    func synchronize(_ marks: [StudyAnnotation]) {
        guard let document = view.document else { return }
        let next = Dictionary(uniqueKeysWithValues: marks.map { ($0.id, $0) })
        for (id, mark) in rendered where next[id] != mark {
            guard let page = document.page(at: mark.pageIndex) else { continue }
            for annotation in page.annotations where annotation.value(forAnnotationKey: PDFAnnotationRenderer.ownerKey) as? String == id.uuidString {
                page.removeAnnotation(annotation)
            }
        }
        let added = marks.filter { rendered[$0.id] != $0 }
        PDFAnnotationRenderer.apply(added, to: document)
        rendered = next
    }

    private func reportPosition() {
        guard !restoring, let position = currentPosition() else { return }
        onPosition?(position)
    }
}
