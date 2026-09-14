import SwiftUI

/// Native arbitration keeps horizontal paging separate from each page's vertical reading scroll.
@MainActor
struct ReadHorizontalPager: UIViewControllerRepresentable {
    let model: ReaderModel
    var reduceMotion = false
    // Observed arguments ensure SwiftUI calls update when content/typography changes.
    let page: ReadablePage
    let textScale: Double
    let activeSentence: String?

    func makeUIViewController(context: Context) -> ReadPagerController { ReadPagerController(model: model) }
    func updateUIViewController(_ controller: ReadPagerController, context: Context) {
        controller.driver.reduceMotion = reduceMotion
        controller.refresh(page: page, scale: textScale, sentence: activeSentence)
    }
    static func dismantleUIViewController(_ controller: ReadPagerController, coordinator: ()) { controller.driver.cancel() }
}

@MainActor
final class ReadPagerController: UIViewController {
    let model: ReaderModel
    let driver = ReaderPageTurnDriver()
    private let host: UIHostingController<ReadablePageView>
    private var previewHost: UIHostingController<ReadablePageView>?
    private var displayedPage = -1
    private var displayedScale: Double = -1
    private var lastSize = CGSize.zero

    init(model: ReaderModel) {
        self.model = model
        host = UIHostingController(rootView: ReadablePageView(page: model.readablePage,
            textScale: model.preferences.readTextScale, activeSentence: model.speech.activeSentence,
            surround: model.preferences.readerSurround,
            onLearnBlock: { [weak model] block in model?.selectReadBlock(block, pageIndex: model?.pageIndex ?? 0) }))
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("Use init(model:)") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.clipsToBounds = true
        view.backgroundColor = UIColor(model.preferences.readerSurround.readingBackground)
        view.accessibilityIdentifier = "read-paged-viewport"
        view.accessibilityContainerType = .semanticGroup
        view.accessibilityLabel = "Reading area"
        view.shouldGroupAccessibilityChildren = true
        addChild(host)
        view.addSubview(host.view)
        host.didMove(toParent: self)
        host.view.backgroundColor = UIColor(model.preferences.readerSurround.readingBackground)
        driver.install(viewport: view, content: host.view)
        driver.diagnosticContext = { "mode=read zoom=not-applicable selection=not-applicable" }
        driver.canBegin = { [weak self] in self?.model.panel == nil && self?.model.showStudyDrawer == false }
        driver.pageState = { [weak self] in (self?.model.pageIndex ?? 0, self?.model.book.pageCount ?? 0) }
        driver.preview = { [weak self] delta in self?.makePreview(delta: delta) }
        driver.commit = { [weak self] delta in
            guard let self else { return }
            self.model.go(to: self.model.pageIndex + delta)
            self.refresh(page: self.model.readablePage, scale: self.model.preferences.readTextScale,
                         sentence: self.model.speech.activeSentence)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard lastSize != view.bounds.size else { return }
        driver.cancel()
        lastSize = view.bounds.size
        host.view.frame = view.bounds
    }

    func refresh(page: ReadablePage, scale: Double, sentence: String?) {
        loadViewIfNeeded()
        view.backgroundColor = UIColor(model.preferences.readerSurround.readingBackground)
        host.view.backgroundColor = UIColor(model.preferences.readerSurround.readingBackground)
        if displayedPage != page.pageIndex || displayedScale != scale { driver.cancel() }
        displayedPage = page.pageIndex
        displayedScale = scale
        host.rootView = ReadablePageView(page: page, textScale: scale, activeSentence: sentence,
            surround: model.preferences.readerSurround,
            onLearnBlock: { [weak model] block in model?.selectReadBlock(block, pageIndex: page.pageIndex) })
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
    }

    private func makePreview(delta: Int) -> UIView? {
        let target = model.pageIndex + delta
        guard (0..<model.book.pageCount).contains(target) else { return nil }
        if let previous = previewHost {
            previous.willMove(toParent: nil)
            previous.view.removeFromSuperview()
            previous.removeFromParent()
        }
        let preview = UIHostingController(rootView: ReadablePageView(page: model.readablePage(at: target),
            textScale: model.preferences.readTextScale, activeSentence: nil, scrollEnabled: false,
            surround: model.preferences.readerSurround, onLearnBlock: nil))
        previewHost = preview
        addChild(preview)
        preview.view.frame = view.bounds
        preview.view.backgroundColor = UIColor(ShelfTheme.paper)
        view.addSubview(preview.view)
        preview.didMove(toParent: self)
        preview.view.setNeedsLayout()
        preview.view.layoutIfNeeded()
        return preview.view
    }
}
