import PDFKit
import SwiftUI

@MainActor
struct PDFReaderSurface: UIViewRepresentable {
    let controller: PDFSessionController
    let flow: PageFlow
    let surround: ReaderSurround
    let readingScale: Double
    var reduceMotion = false

    func makeUIView(context: Context) -> PDFPagingViewport { PDFPagingViewport(controller: controller) }

    func updateUIView(_ view: PDFPagingViewport, context: Context) {
        view.update(flow: flow, surround: surround, scale: readingScale, reduceMotion: reduceMotion)
    }

    static func dismantleUIView(_ view: PDFPagingViewport, coordinator: ()) { view.detach() }
}

/// The PDF stays mounted. Only horizontal transitions move it; a zoomed PDF keeps native pan.
@MainActor
final class PDFPagingViewport: UIView {
    let controller: PDFSessionController
    let driver = ReaderPageTurnDriver()
    private var flow: PageFlow = .horizontal
    private var surround: ReaderSurround = .warm
    private var lastSize = CGSize.zero
    private var previewPage: PDFView?

    init(controller: PDFSessionController) {
        self.controller = controller
        super.init(frame: .zero)
        clipsToBounds = true
        accessibilityIdentifier = "original-viewport"
        isAccessibilityElement = false
        accessibilityContainerType = .semanticGroup
        accessibilityLabel = "Original PDF reading area"
        shouldGroupAccessibilityChildren = true
        addSubview(controller.view)
        driver.install(viewport: self, content: controller.view)
        driver.consumesVerticalAtFit = true
        driver.diagnosticContext = { [weak self] in
            guard let self else { return "mode=original detached" }
            return "mode=original flow=\(self.flow) zoom=\(self.controller.view.scaleFactor) fit=\(self.controller.isAtFitScale()) contained=\(self.controller.canPageHorizontally()) selection=\(!(self.controller.view.currentSelection?.string ?? "").isEmpty)"
        }
        driver.canBegin = { [weak self] in
            guard let self else { return false }
            guard self.flow == .horizontal, self.controller.canPageHorizontally() else { return false }
            // A finger resting on text leaves a PDFKit selection behind, and refusing to
            // page until it clears is why real swipes stop working mid-session. A swipe
            // dismisses the selection instead of being silently discarded.
            if !(self.controller.view.currentSelection?.string ?? "").isEmpty {
                self.controller.view.clearSelection()
            }
            return true
        }
        driver.pageState = { [weak controller] in
            (controller?.currentPosition()?.pageIndex ?? 0, controller?.view.document?.pageCount ?? 0)
        }
        driver.preview = { [weak self] delta in self?.makePreview(delta: delta) }
        driver.commit = { [weak self] delta in
            self?.controller.goRelative(delta)
            self?.controller.view.layoutIfNeeded()
        }
        controller.onNavigate = { [weak driver] in driver?.cancel() }
    }

    required init?(coder: NSCoder) { fatalError("Use init(controller:)") }

    func update(flow: PageFlow, surround: ReaderSurround, scale: Double, reduceMotion: Bool) {
        if self.flow != flow { driver.cancel() }
        self.flow = flow
        self.surround = surround
        driver.reduceMotion = reduceMotion
        backgroundColor = UIColor(surround.color)
        controller.configure(flow: flow, surround: surround)
        // PDFZoomState ignores unchanged requests, including redraws caused by page/audio state.
        controller.applyReadingScale(scale)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.size != lastSize else { return }
        driver.cancel()
        lastSize = bounds.size
        controller.view.frame = bounds
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        controller.zoom.applyIfNeeded()
    }

    private func makePreview(delta: Int) -> UIView? {
        guard let document = controller.view.document,
              let current = controller.currentPosition()?.pageIndex,
              let page = document.page(at: current + delta) else { return nil }
        let preview = previewPage ?? PDFView()
        previewPage = preview
        preview.transform = .identity
        preview.frame = bounds
        preview.backgroundColor = UIColor(surround.color)
        preview.displayBox = .cropBox
        preview.displaysAsBook = false
        preview.displayMode = .singlePage
        preview.displaysPageBreaks = false
        preview.pageBreakMargins = .zero
        preview.autoScales = false
        if preview.document !== document { preview.document = document }
        preview.backgroundColor = UIColor(surround.color)
        preview.go(to: page)
        preview.layoutIfNeeded()
        let zoom = PDFZoomState(view: preview)
        zoom.request(Double(controller.zoom.multiplier))
        return preview
    }

    func detach() {
        driver.cancel()
        controller.onNavigate = nil
        controller.view.removeFromSuperview()
        previewPage?.document = nil
        previewPage = nil
    }
}
