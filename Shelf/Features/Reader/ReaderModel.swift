import Foundation
import Observation
import ShelfCore
import UIKit
import PDFKit

/// Reader state and use cases. The controller owns PDFKit; the repository owns durable data.
@MainActor @Observable
final class ReaderModel {
    let book: Book
    let url: URL
    let preferences: AppPreferences
    let controller = PDFSessionController()
    let repository: LibraryRepository
    let loader: PDFDocumentLoader
    let searchService: PDFPageSearch
    let exporter: PDFExportService
    let recorder: ReadingPositionRecorder
    let initialPage: Int?
    let initialSourceText: String?
    let sourceReturnLabel: String?
    let readableExtractor = PDFReadablePageExtractor()
    let speech: ReaderSpeechController
    let anchorStore: ReadingAnchorStore
    let windowPlanner = ReadingWindowPlanner()
    let learning: LearningModel
    let knowledge: KnowledgeModel
    let initialKnowledgeTravel: Bool
    let initialLensSource: LearningSource?
    var pendingLensSource: LearningSource?
    var lensSource: LearningSource?

    var navigationRevision = 0
    @ObservationIgnored var readableCache: [Int: ReadablePage] = [:]
    @ObservationIgnored var documentFurniture: PDFDocumentFurniture?
    @ObservationIgnored var readableCacheOrder: [Int] = []
    var isLoaded = false
    var loadFailure: String?
    var pageIndex = 0
    var hasSelection = false
    var outline: [OutlineEntry] = []
    var annotations: [StudyAnnotation] = []
    var bookmarks: [PageBookmark] = []
    var panel: ReaderPanel?
    var noteDraft: NoteDraft?
    var shareFile: ShareFile?
    var errorMessage: String?
    var savedMessage: String?
    var focusMode = false
    var isSaving = false
    var searchText = ""
    var searchResults: [PassageMatch] = []
    var searchReturnPage: Int?
    var isSearching = false
    var undoStack: [AnnotationChange] = []
    var redoStack: [AnnotationChange] = []
    var displayMode: ReaderDisplayMode = .read
    var readablePage = ReadablePage(pageIndex: 0, blocks: [])
    var document: PDFDocument?
    var showStudyDrawer = false
    var readingAnchor: ReadingAnchor?
    var activeTimedPlan: TimedReadingPlan?
    var semanticLevel: SemanticZoomLevel = .page
    var showLearningActions = false
    var selectedReadSource: LearningSource?
    var showVoiceSettings = false
    var showKnowledgeSearch = false
    var blindPagePresented = false
    var blindPagePreviousIndex: Int?
    var blindPageDraft = ""
    var blindPagesSincePrompt = 0
    var blindPageSkips = 0
    @ObservationIgnored var blindLastPromptAt = Date()
    var isDetectingOutline = false
    @ObservationIgnored var searchTask: Task<Void, Never>?
    @ObservationIgnored var outlineTask: Task<Void, Never>?

    init(book: Book, initialPage: Int?, repository: LibraryRepository, url: URL,
         loader: PDFDocumentLoader, search: PDFPageSearch, exporter: PDFExportService,
         preferences: AppPreferences, learning: LearningModel, knowledge: KnowledgeModel,
         initialSourceText: String? = nil, initialKnowledgeTravel: Bool = false, initialLensSource: LearningSource? = nil, sourceReturnLabel: String? = nil) {
        self.book = book
        self.initialPage = initialPage
        self.initialSourceText = initialSourceText
        self.sourceReturnLabel = sourceReturnLabel
        self.repository = repository
        self.url = url
        self.loader = loader
        self.searchService = search
        self.exporter = exporter
        self.preferences = preferences
        self.learning = learning
        self.knowledge = knowledge
        self.initialKnowledgeTravel = initialKnowledgeTravel
        self.initialLensSource = initialLensSource
        self.speech = ReaderSpeechController(preferences: preferences, bookTitle: book.title)
        self.recorder = ReadingPositionRecorder(repository: repository, bookID: book.id)
        self.anchorStore = ReadingAnchorStore(bookID: book.id)
        self.readingAnchor = anchorStore.load()

        controller.onPosition = { [weak self] position in self?.receivePDFPosition(position) }
        controller.onSelection = { [weak self] selected in
            guard let self else { return }
            self.hasSelection = self.displayMode == .original && selected
        }
        controller.onUserZoom = { [weak self] ratio in
            guard let self, self.displayMode == .original else { return }
            self.preferences.pdfZoomScale = ratio
        }
        recorder.onError = { [weak self] message in self?.errorMessage = message }
        speech.onActiveSentence = { [weak self] sentence in self?.captureSpeechAnchor(sentence) }
        speech.onFinishedPage = { [weak self] in self?.handleSpeechFinishedPage() }
    }

    var pageNumber: Int { pageIndex + 1 }
    var isBookmarked: Bool { bookmarks.contains { $0.pageIndex == pageIndex } }
    var canUndo: Bool { !undoStack.isEmpty && !isSaving }
    var canRedo: Bool { !redoStack.isEmpty && !isSaving }

    var currentOutlineTitle: String? {
        sectionTitle(for: pageIndex)
    }

    func sectionTitle(for page: Int) -> String? {
        outline.last(where: { $0.pageIndex <= page && $0.source != .landmark })?.title
            ?? outline.last(where: { $0.pageIndex <= page })?.title
    }

    var semanticOutlineEntries: [OutlineEntry] {
        let structural = outline.filter { $0.source != .landmark }
        switch semanticLevel {
        case .book:
            let top = structural.filter { $0.depth == 0 }
            return Array((top.isEmpty ? structural : top).prefix(36))
        case .chapter:
            guard !structural.isEmpty else { return [] }
            let current = structural.lastIndex(where: { $0.pageIndex <= pageIndex }) ?? 0
            let lower = max(0, current - 5)
            let upper = min(structural.count, current + 7)
            return Array(structural[lower..<upper])
        default:
            return []
        }
    }

    func load() async {
        guard !isLoaded else { return }
        do {
            let loaded = try await loader.load(url: url)
            document = loaded.document
            try await refreshMarks()
            outline = loaded.outline
            var position = book.position
            if let initialPage { position = ReadingPosition(pageIndex: initialPage) }
            pageIndex = position.clamped(toPageCount: book.pageCount).pageIndex
            controller.install(loaded.document, marks: annotations, position: position)
            controller.applyReadingScale(preferences.pdfZoomScale)
            refreshReadablePage()
            try await repository.recordOpened(bookID: book.id)
            isLoaded = true
            if let source = initialSourceText, !source.isEmpty {
                restoreSourceHighlight(source)
                if initialKnowledgeTravel { playHaptic(.sourceRevealed) }
            }
            UIApplication.shared.isIdleTimerDisabled = preferences.keepAwake
            if outline.isEmpty { beginOutlineDetection() }
        } catch {
            loadFailure = error.localizedDescription
        }
    }

    private func beginOutlineDetection() {
        outlineTask?.cancel()
        isDetectingOutline = true
        let sourceURL = url
        outlineTask = Task { [weak self] in
            guard let self else { return }
            do {
                let detected = try await loader.detectOutline(url: sourceURL)
                try Task.checkCancellation()
                outline = detected
            } catch is CancellationError {
                // Closing the reader owns cancellation.
            } catch {
                // Navigation inference is optional; the PDF remains fully readable without it.
            }
            isDetectingOutline = false
        }
    }

    func setDisplayMode(_ mode: ReaderDisplayMode) {
        selectedReadSource = nil
        if mode == .original {
            // Synchronize the hidden PDF before it becomes the authoritative reading surface.
            controller.go(to: pageIndex)
            controller.applyReadingScale(preferences.pdfZoomScale)
        }
        displayMode = mode
        if mode == .original {
            semanticLevel = .page
            let sentence = readingAnchor?.pageIndex == pageIndex ? readingAnchor?.sentence : nil
            controller.showSpeechHighlight(sentence, pageIndex: pageIndex)
        } else {
            // Read mode has no native PDF text selection surface. Clear PDFKit selection so a
            // hidden/stale selection can never become a passage mark on the wrong page.
            controller.clearSelection()
            hasSelection = false
            if speech.activeSentence == nil { controller.clearSpeechHighlight() }
        }
        refreshReadablePage()
    }

    func refreshReadablePage() {
        guard document != nil else { return }
        readablePage = readablePage(at: pageIndex)
    }


    func refreshMarks() async throws {
        let snapshot = try await repository.snapshot()
        annotations = snapshot.annotations.filter { $0.bookID == book.id }.sorted { $0.createdAt > $1.createdAt }
        bookmarks = snapshot.bookmarks.filter { $0.bookID == book.id }.sorted { $0.pageIndex < $1.pageIndex }
        controller.synchronize(annotations)
    }


    func toggleBookmark() async {
        do {
            let added = try await repository.toggleBookmark(bookID: book.id, pageIndex: pageIndex)
            try await refreshMarks()
            savedMessage = added ? "Bookmark saved" : "Bookmark removed"
            playHaptic(.mark)
        } catch { errorMessage = error.localizedDescription }
    }

    @discardableResult
    func flushPosition() async -> Bool {
        if displayMode == .original, let position = controller.currentPosition() {
            recorder.schedule(position)
        } else {
            recorder.schedule(ReadingPosition(pageIndex: pageIndex, scaleRatio: preferences.pdfZoomScale))
        }
        do { try await recorder.flush(); return true }
        catch { errorMessage = error.localizedDescription; return false }
    }

    func close() async -> Bool {
        speech.stop()
        controller.clearSpeechHighlight()
        let saved = await flushPosition()
        if saved {
            searchTask?.cancel()
            outlineTask?.cancel()
            UIApplication.shared.isIdleTimerDisabled = false
        }
        return saved
    }

    func export(annotated: Bool) async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do { shareFile = ShareFile(url: try await exporter.export(book: book, annotations: annotations, annotated: annotated)) }
        catch { errorMessage = error.localizedDescription }
    }

    func playHaptic(_ event: ShelfHaptics.Event) {
        ShelfHaptics.shared.play(event, enabled: preferences.hapticsEnabled,
                                 intensityScale: preferences.hapticIntensity)
    }

    private func captureSpeechAnchor(_ sentence: String?) {
        controller.showSpeechHighlight(sentence, pageIndex: pageIndex)
        guard let sentence, !sentence.isEmpty else { return }
        let anchor = ReadingAnchor(pageIndex: pageIndex, sentence: sentence)
        readingAnchor = anchor
        anchorStore.save(anchor)
    }

    func updateReadingAnchorForPageChange(_ page: Int) {
        let anchor = ReadingAnchor(pageIndex: page, sentence: nil)
        readingAnchor = anchor
        anchorStore.save(anchor)
    }

    private func handleSpeechFinishedPage() {
        guard let plan = activeTimedPlan else { return }
        if pageIndex < plan.endPage {
            go(to: pageIndex + 1)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) { [weak self] in
                self?.toggleSpeech()
            }
        } else {
            activeTimedPlan = nil
            playHaptic(.bookFinished)
            savedMessage = "Reading window complete"
        }
    }
}
