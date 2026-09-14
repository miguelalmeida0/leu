import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct RootView: View {
    let container: AppContainer
    @Environment(\.scenePhase) private var scenePhase
    @State private var didRestoreStudyOnLaunch = false
    @State private var primaryArea: PrimaryArea = .shelf
    @State private var studySurface: StudySurface = .landing

    // Opaque subexpressions bound inference without adding a new state owner or container.
    var body: some View {
        backupPresentation
            .leuDialog("Leu needs your attention", isPresented: libraryErrorPresented) {
                Button("OK") { container.library.errorMessage = nil }
            } message: { Text(container.library.errorMessage ?? "") }
    }

    private var rootContent: some View {
        VStack(spacing: 0) {
            phaseContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .clipped()
                .background { UITestFrameProbe(identifier: "root-content-viewport") }
            bottomChrome
        }
        .background(ShelfTheme.background.ignoresSafeArea())
        .foregroundStyle(ShelfTheme.text)
    }

    private var phaseContent: some View {
        ZStack {
            switch container.library.phase {
            case .failed(let message):
                EmptyLibraryState(symbol: "externaldrive.badge.exclamationmark",
                    title: "Your library needs attention.", message: message, actionTitle: "Try again") {
                        Task { await retryBootstrap() }
                    }
            case .loading:
                ProgressView().tint(ShelfTheme.accent).accessibilityLabel("Opening Leu")
            case .ready:
                primaryContent(container.library)
            }
        }
    }

    private var bottomChrome: some View {
        VStack(spacing: 0) {
            if let notice = container.library.notice {
                NoticeBar(text: notice) { container.library.notice = nil }
            }
            if let notice = container.learning.notice {
                NoticeBar(text: notice) { container.learning.notice = nil }
            }
            PrimaryTabBar(selection: $primaryArea)
        }
        .background(ShelfTheme.background)
        .background { UITestFrameProbe(identifier: "root-bottom-chrome-frame") }
    }

    private var lifecycleContent: some View {
        rootContent
            .task { await bootstrapOnLaunch() }
            .onChange(of: scenePhase) { _, phase in scenePhaseChanged(phase) }
            .onChange(of: container.library.selectedTab) { _, _ in resetLibraryScope(container.library) }
            .onChange(of: activeBookVersions) { _, _ in
                Task { await synchronizeLibraryIndexes() }
            }
            .onChange(of: primaryArea) { _, area in primaryAreaChanged(area) }
            .onChange(of: container.learning.activeSession?.id) { _, sessionID in
                activeSessionChanged(sessionID)
            }
            .onChange(of: container.knowledge.pendingDestination) { _, destination in
                knowledgeDestinationChanged(destination)
            }
    }

    private var readerAndSheetPresentation: some View {
        @Bindable var model = container.library
        return lifecycleContent
            .fullScreenCover(item: $model.readerRoute, onDismiss: { readerDidDismiss() }) { route in
                ReaderScreen(model: container.reader(for: route), thumbnails: container.thumbnails)
            }
            .sheet(item: $model.editingBook) { book in BookDetailsSheet(book: book, model: model) }
            .sheet(isPresented: $model.showCollections) { CollectionsSheet(model: model) }
            .sheet(item: $model.shareFile) { file in ShareSheet(file: file) }
    }

    private var backupPresentation: some View {
        @Bindable var model = container.library
        return readerAndSheetPresentation
            .fileImporter(isPresented: $model.showBackupImporter, allowedContentTypes: [.shelfBackup, .data],
                          allowsMultipleSelection: false) { (result: Result<[URL], Error>) in
                backupImportCompleted(result)
            }
            .leuDialog("Restore this backup?", isPresented: backupConfirmationPresented,
                                titleVisibility: .visible, presenting: model.pendingBackupURL) { url in
                Button("Merge into my library") { mergeBackup(url) }
                Button("Cancel", role: .cancel) { model.pendingBackupURL = nil }
            } message: { _ in
                Text("Existing PDFs and edits are preserved. New documents and notes are added. Every PDF is checked before changes are committed.")
            }
    }

    private var activeBookVersions: [String] {
        container.library.snapshot.activeBooks.map { book -> String in
            "\(book.id.uuidString)|\(book.fingerprint)"
        }
    }

    private var backupConfirmationPresented: Binding<Bool> {
        Binding(get: { container.library.pendingBackupURL != nil },
                set: { if !$0 { container.library.pendingBackupURL = nil } })
    }

    private var libraryErrorPresented: Binding<Bool> {
        Binding(get: {
            let model = container.library
            return model.errorMessage != nil && model.editingBook == nil && !model.showCollections
        }, set: { if !$0 { container.library.errorMessage = nil } })
    }

    @ViewBuilder
    private func primaryContent(_ model: LibraryModel) -> some View {
        switch primaryArea {
        case .shelf:
            shelfContent(model)
        case .learn:
            switch studySurface {
            case .landing:
                LearnTodayScreen(model: container.learning, knowledge: container.knowledge) {
                    StudyInteractionTrace.record("route.progress.requested")
                    studySurface = .progress
                }
            case .progress:
                LearningStateSheet(model: container.learning) {
                    StudyInteractionTrace.record("route.progress.done")
                    studySurface = .landing
                }
            }
        case .trails:
            TrailsScreen(model: container.learning, knowledge: container.knowledge)
        }
    }

    @ViewBuilder
    private func shelfContent(_ model: LibraryModel) -> some View {
        switch model.selectedTab {
        case .library, .favorites, .recents:
            LibraryScreen(model: model, preferences: container.preferences, thumbnails: container.thumbnails,
                          knowledge: container.knowledge)
        case .tags:
            TagsScreen(model: model)
        case .settings:
            SettingsScreen(model: model, preferences: container.preferences, knowledge: container.knowledge, learning: container.learning)
        }
    }

    // Lifecycle work is typechecked independently of SwiftUI's generic modifier chain.
    private func bootstrapOnLaunch() async {
        await container.library.bootstrap()
        await retainExplanationSources()
        await container.learning.bootstrap()
        restoreStudyOnLaunchIfNeeded()
        await container.knowledge.bootstrap()
    }

    private func restoreStudyOnLaunchIfNeeded() {
        guard container.learning.isReady, !didRestoreStudyOnLaunch else { return }
        didRestoreStudyOnLaunch = true
        guard let session = container.learning.activeSession, session.completedAt == nil else { return }
        primaryArea = .learn
        studySurface = .landing
        StudyInteractionTrace.record("route.study.restored")
    }

    private func retryBootstrap() async {
        await container.library.bootstrap()
        await retainExplanationSources()
        await container.learning.bootstrap()
        await container.knowledge.bootstrap()
    }

    private func synchronizeLibraryIndexes() async {
        await retainExplanationSources()
        await container.learning.syncLibrary()
        await container.knowledge.syncLibrary()
    }

    private func retainExplanationSources() async {
        guard case .ready = container.library.phase else { return }
        await container.learning.explanationCache.retainDocuments(Set(container.library.snapshot.activeBooks.map(\.id)))
    }

    private func scenePhaseChanged(_ phase: ScenePhase) {
        if phase != .active && container.learning.activeSession != nil {
            container.learning.persistStudyState()
        }
    }

    private func primaryAreaChanged(_ area: PrimaryArea) {
        if area != .learn { studySurface = .landing }
        if area == .learn || area == .trails {
            Task { await synchronizeLibraryIndexes() }
        }
    }

    private func activeSessionChanged(_ sessionID: UUID?) {
        // A recall launched from Progress must reveal the session, not remain behind Progress.
        guard sessionID != nil, primaryArea == .learn else { return }
        StudyInteractionTrace.record("route.session.requested")
        studySurface = .landing
    }

    private func knowledgeDestinationChanged(_ destination: KnowledgeDestination?) {
        guard destination != nil, container.library.readerRoute == nil else { return }
        openKnowledgeDestination(container.library)
    }

    private func readerDidDismiss() {
        let model = container.library
        model.readerClosed()
        if container.knowledge.pendingDestination != nil {
            DispatchQueue.main.async { openKnowledgeDestination(model) }
        }
    }

    private func backupImportCompleted(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls): container.library.pendingBackupURL = urls.first
        case .failure(let error): container.library.errorMessage = error.localizedDescription
        }
    }

    private func mergeBackup(_ url: URL) {
        Task {
            await container.library.restoreBackup(url)
            await synchronizeLibraryIndexes()
        }
        container.library.pendingBackupURL = nil
    }

    private func openKnowledgeDestination(_ model: LibraryModel) {
        guard let destination = container.knowledge.consumeDestination() else { return }
        guard let book = model.snapshot.activeBooks.first(where: { $0.id == destination.documentID }) else {
            container.knowledge.errorMessage = "That source PDF is not currently available on this iPhone."
            return
        }
        model.open(book, page: destination.pageIndex, sourceText: destination.sourceText,
                   knowledgeTravel: true, restoreLens: destination.restoreLens)
    }

    private func resetLibraryScope(_ model: LibraryModel) {
        model.query = ""; model.selectedCollectionID = nil; model.selectedTag = nil; model.passages = []
        model.updateSearch()
    }
}

private enum StudySurface {
    case landing
    case progress
}

extension UTType {
    static let shelfBackup = UTType(exportedAs: "app.shelf.backup", conformingTo: .data)
}
