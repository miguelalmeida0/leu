import SwiftUI
@MainActor
struct ReaderScreen: View {
    @State private var model: ReaderModel
    @StateObject private var explanation: ReaderExplanationCoordinator
    let thumbnails: PDFThumbnailService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    init(model: ReaderModel, thumbnails: PDFThumbnailService) {
        _model = State(initialValue: model)
        _explanation = StateObject(wrappedValue: ReaderExplanationCoordinator(reader: model))
        self.thumbnails = thumbnails
    }
    var body: some View {
        ZStack {
            ShelfTheme.background.ignoresSafeArea()
            content.clipped()
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            Group {
                if model.focusMode { ReaderFocusBar(model: model, close: close) }
                else { ReaderTopBar(model: model, close: close) }
            }
            .background(ShelfTheme.background.ignoresSafeArea(edges: .top))
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !model.focusMode && model.isLoaded {
                VStack(spacing: 0) {
                    ThoughtContinuationView(learning: model.learning, documentID: model.book.id)
                    ReaderBottomBar(model: model)
                }
            }
        }
        .overlay(alignment: .trailing) { regularWidthStudyInspector }
        .overlay(alignment: .trailing) {
            if model.isLoaded { MemoryMarginMarkers(reader: model, learning: model.learning) }
        }
        .animation(reduceMotion ? nil : ShelfMotion.gentle, value: model.showStudyDrawer)
        .task { await model.load(); model.restoreInitialLens(); explanation.runHarnessIfRequested() }
        .onAppear { StudyInteractionTrace.record("reader.appeared document=\(model.book.id)") }
        .onChange(of: model.pageIndex) { before, after in
            StudyInteractionTrace.record("reader.pageState mode=\(model.displayMode) before=\(before) after=\(after) label=Page \(after + 1) of \(model.book.pageCount)")
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { Task { _ = await model.flushPosition() } }
            UIApplication.shared.isIdleTimerDisabled = phase == .active && model.preferences.keepAwake
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            model.searchTask?.cancel()
            explanation.close()
        }
        .onChange(of: model.knowledge.pendingDestination) { _, destination in
            guard destination != nil else { return }
            closeForKnowledgeJump()
        }
        .sheet(item: $model.panel) { panel in
            switch panel {
            case .contents: ReaderContentsSheet(model: model, thumbnails: thumbnails)
            case .search: ReaderSearchSheet(model: model)
            case .notes: ReaderNotesSheet(model: model)
            case .settings: ReaderSettingsSheet(preferences: model.preferences)
            case .readingState: ReaderStateSheet(model: model)
            case .time: TimedReadingSheet(model: model)
            }
        }
        .sheet(isPresented: Binding(
            get: { model.showStudyDrawer && horizontalSizeClass != .regular },
            set: { if !$0 { model.showStudyDrawer = false } }
        )) {
            ReaderStudyDrawer(model: model)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $model.noteDraft) { NoteEditorSheet(model: model, draft: $0) }
        .sheet(item: $model.shareFile) { ShareSheet(file: $0) }
        .sheet(isPresented: $model.showLearningActions, onDismiss: {
            model.presentRequestedLens(); explanation.presentRequested()
        }) {
            LearningObjectActionSheet(reader: model, learning: model.learning, knowledge: model.knowledge,
                                      onExplainLikeTen: explanation.request)
        }
        .sheet(isPresented: $explanation.isPresented, onDismiss: { explanation.close() }) {
            if let packet = explanation.packet {
                ExplainLikeTenSheet(controller: explanation.controller, sourceLabel: packet.pageLabel,
                                    onClose: explanation.close)
            }
        }
        .sheet(isPresented: Binding(get: { model.lensSource != nil }, set: { if !$0 { model.lensSource = nil } })) {
            if let source = model.lensSource {
                UnderstandingLensSheet(reader: model, model: model.learning, source: source)
            }
        }
        .sheet(isPresented: $model.showVoiceSettings) { VoiceSettingsSheet(speech: model.speech) }
        .sheet(isPresented: $model.showKnowledgeSearch) { KnowledgeSearchSheet(knowledge: model.knowledge) }
        .sheet(isPresented: $model.blindPagePresented) { BlindPageSheet(model: model) }
        .leuDialog("Your change needs attention", isPresented: Binding(
            get: { model.errorMessage != nil && model.noteDraft == nil && model.panel == nil },
            set: { if !$0 { model.errorMessage = nil } })) {
                Button("OK") { model.errorMessage = nil }
            } message: { Text(model.errorMessage ?? "") }
        .background { UITestFrameProbe(identifier: "reader-screen") }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(model.isSaving)
    }
    @ViewBuilder
    private var content: some View {
        if let failure = model.loadFailure {
            VStack(spacing: 18) {
                Text("This PDF could not open.").font(.title2)
                Text(failure).multilineTextAlignment(.center)
                Button("Back to library", action: close).buttonStyle(ShelfButtonStyle(filled: true))
            }.padding(24)
        } else if model.displayMode == .read && model.isLoaded {
            readSurface
        } else {
            PDFReaderSurface(controller: model.controller,
                             flow: model.preferences.pageFlow,
                             surround: model.preferences.readerSurround,
                             readingScale: model.preferences.pdfZoomScale,
                             reduceMotion: reduceMotion)
                .background(UITestFrameProbe(identifier: "original-viewport-frame"))
                .accessibilityIdentifier("pdf-surface")
        }
    }
    @ViewBuilder
    private var readSurface: some View {
        if model.semanticLevel != .page {
            SemanticZoomSurface(model: model)
        } else if model.preferences.pageFlow == .vertical {
            ReadContinuousDocumentView(model: model)
        } else {
            ReadHorizontalPager(model: model, reduceMotion: reduceMotion,
                page: model.readablePage, textScale: model.preferences.readTextScale,
                activeSentence: model.speech.activeSentence ?? model.readingAnchor?.sentence)
        }
    }

    private var regularWidthStudyInspector: some View {
        Group {
            if model.showStudyDrawer && horizontalSizeClass == .regular {
                ZStack(alignment: .trailing) {
                    Color.black.opacity(0.48).ignoresSafeArea().onTapGesture {
                        withAnimation(ShelfMotion.chromeOut) { model.showStudyDrawer = false }
                    }
                    GeometryReader { proxy in
                        HStack(spacing: 0) {
                            Spacer(minLength: 0)
                            ReaderStudyDrawer(model: model)
                                .frame(width: min(proxy.size.width, 420))
                        }
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
                .zIndex(30)
            }
        }
    }
    private func close() {
        if model.initialKnowledgeTravel && model.knowledge.canNavigateBack && model.knowledge.pendingDestination == nil {
            model.knowledge.queueBackNavigation()
        }
        Task { if await model.close() { dismiss() } }
    }

    private func closeForKnowledgeJump() {
        Task { if await model.close() { dismiss() } }
    }
}
