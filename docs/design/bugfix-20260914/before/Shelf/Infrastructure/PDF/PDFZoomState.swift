import PDFKit

/// Fits the actual crop box to a laid-out viewport. A SwiftUI redraw is not a zoom command.
@MainActor
final class PDFZoomState {
    private weak var view: PDFView?
    private weak var lastPage: PDFPage?
    private var lastSize = CGSize.zero
    private var lastMode: PDFDisplayMode?
    private var appliedRequest: CGFloat = -1
    private(set) var isApplying = false
    private(set) var multiplier: CGFloat = 1
    private(set) var fitScale: CGFloat = 0
    var onUserZoom: ((Double) -> Void)?

    init(view: PDFView) { self.view = view }

    func request(_ value: Double) {
        guard value.isFinite else { return }
        multiplier = CGFloat(min(max(value, 0.75), 3))
        applyIfNeeded()
    }

    func applyIfNeeded() {
        guard !isApplying, let view, let page = view.currentPage,
              view.bounds.width > 1, view.bounds.height > 1 else { return }
        let changed = lastPage !== page || lastSize != view.bounds.size || lastMode != view.displayMode
        guard changed || abs(appliedRequest - multiplier) > 0.001 else { return }
        let size = rotatedSize(page, box: view.displayBox)
        guard size.width > 0, size.height > 0 else { return }
        let pageFit = min(max(view.bounds.width - 12, 1) / size.width,
                          max(view.bounds.height - 12, 1) / size.height)
        // Keep PDFKit's native continuous-scroll fit behavior in vertical Original mode.
        let nativeFit = view.displayMode == .singlePageContinuous ? view.scaleFactorForSizeToFit : 0
        let fit = nativeFit > 0 ? nativeFit : pageFit
        guard fit.isFinite, fit > 0 else { return }
        isApplying = true
        defer { isApplying = false }
        fitScale = fit
        lastPage = page
        lastSize = view.bounds.size
        lastMode = view.displayMode
        appliedRequest = multiplier
        view.autoScales = false
        view.minScaleFactor = fit * 0.75
        view.maxScaleFactor = fit * 3
        let target = fit * multiplier
        if abs(view.scaleFactor - target) > 0.001 { view.scaleFactor = target }
    }

    func observedScaleChange() {
        guard !isApplying, let view, lastPage === view.currentPage,
              lastSize == view.bounds.size, fitScale > 0 else { return }
        let ratio = min(max(view.scaleFactor / fitScale, 0.75), 3)
        guard abs(ratio - multiplier) > 0.003 else { return }
        multiplier = ratio
        appliedRequest = ratio
        onUserZoom?(Double(ratio))
    }

    var atFit: Bool {
        guard let view, fitScale > 0 else { return false }
        return view.scaleFactor <= fitScale * 1.025
    }

    func widthMultiplier() -> CGFloat? {
        guard let view, let page = view.currentPage, fitScale > 0 else { return nil }
        let size = rotatedSize(page, box: view.displayBox)
        return size.width > 0 ? (view.bounds.width - 12) / size.width / fitScale : nil
    }

    private func rotatedSize(_ page: PDFPage, box: PDFDisplayBox) -> CGSize {
        let rect = page.bounds(for: box)
        return abs(page.rotation) % 180 == 90
            ? CGSize(width: rect.height, height: rect.width) : rect.size
    }
}

@MainActor
final class ShelfPDFView: PDFView {
    var onViewportLayout: (() -> Void)?
    override func layoutSubviews() {
        super.layoutSubviews()
        onViewportLayout?()
    }
}
