import Combine
import Foundation
import ShelfCore

/// Owns this reader's presentation and request lifetime, not the reader's text.
@MainActor final class ReaderExplanationCoordinator: ObservableObject {
    @Published var isPresented = false
    @Published private(set) var packet: ExplanationSourcePacket?
    let controller: ExplanationController
    private let reader: ReaderModel
    private var pending: ExplanationSourcePacket?
    private var didRunHarness = false

    init(reader: ReaderModel) {
        self.reader = reader
        controller = ExplainLikeTenFeature.live(provider: reader.learning.intelligenceProvider,
                                                cache: reader.learning.explanationCache)
    }

    func request(_ source: LearningSource) {
        guard source.documentID == reader.book.id,
              reader.readablePage(at: source.pageIndex).sourceIntegrityPassed,
              let canonical = reader.document?.page(at: source.pageIndex)?.string else {
            reader.savedMessage = "This passage could not be read cleanly enough to explain."
            return
        }
        let blocks = reader.readablePage(at: source.pageIndex).blocks
        let selected = blocks.firstIndex { SourcePassageMatcher.range(of: source.sourceText, in: $0.text) != nil }
        let preceding = selected.flatMap { $0 > 0 ? blocks[$0 - 1].text : nil }
        let following = selected.flatMap { $0 + 1 < blocks.count ? blocks[$0 + 1].text : nil }
        guard let built = ExplanationPacketBuilder().packet(selection: source,
            pageLabel: "\(reader.book.title) · p. \(source.pageIndex + 1)", fingerprint: reader.book.fingerprint,
            extractionVersion: PDFKitTextExtractor.extractionVersion, canonicalPage: canonical,
            heading: source.sectionTitle, preceding: preceding, following: following,
            language: "en") else {
            reader.savedMessage = "Select a complete, readable passage of 40–2,400 characters."
            return
        }
        pending = built
        reader.showLearningActions = false
    }

    func presentRequested() {
        guard let pending else { return }
        self.pending = nil
        packet = pending
        controller.start(packet: pending)
        isPresented = true
    }

    func close() {
        controller.reset()
        packet = nil
        pending = nil
        isPresented = false
    }

    func runHarnessIfRequested() {
        guard ExplainLikeTenHarness.isEnabled, !didRunHarness,
              let source = reader.currentLearningSource() else { return }
        didRunHarness = true
        request(source)
        presentRequested()
    }
}
