import Foundation
import Observation
import ShelfCore

/// Presentation state and application-service orchestration for the library. No SwiftUI rendering.
@MainActor @Observable
final class LibraryModel {
    let repository: LibraryRepository
    let vault: FileDocumentVault
    let importer: DocumentImportService
    let incoming: IncomingFileService
    let backup: BackupService
    let searchService: LibraryTextSearch
    let indexes: FileTextIndexStore
    let rebuilder: IndexRebuilder
    let paths: AppPaths
    let seedSamples: Bool

    var snapshot = LibrarySnapshot()
    var phase: LibraryPhase = .loading
    var selectedTab: ShelfTab = .library
    var selectedCollectionID: UUID?
    var selectedTag: String?
    var query = ""
    var sort: LibrarySort = .added
    var passages: [PassageMatch] = []
    var isSearching = false
    var isIndexing = false
    var importLabel: String?
    var operationLabel: String?
    var errorMessage: String?
    var notice: String?
    var readerRoute: ReaderRoute?
    var editingBook: Book?
    var shareFile: ShareFile?
    var pendingBackupURL: URL?
    var showCollections = false
    var showBackupImporter = false
    var recoveredMetadata = false
    @ObservationIgnored var queuedURLs: [URL] = []
    @ObservationIgnored var searchTask: Task<Void, Never>?
    @ObservationIgnored var noticeTask: Task<Void, Never>?
    @ObservationIgnored var isBootstrapping = false

    init(repository: LibraryRepository, vault: FileDocumentVault, importer: DocumentImportService,
         incoming: IncomingFileService, backup: BackupService, search: LibraryTextSearch,
         indexes: FileTextIndexStore, rebuilder: IndexRebuilder, paths: AppPaths, seedSamples: Bool) {
        self.repository = repository; self.vault = vault; self.importer = importer
        self.incoming = incoming; self.backup = backup; self.searchService = search
        self.indexes = indexes; self.rebuilder = rebuilder; self.paths = paths; self.seedSamples = seedSamples
    }

    var collections: [BookCollection] { snapshot.collections.sorted { $0.order < $1.order } }
    var filteredBooks: [Book] {
        LibraryQuery(section: selectedTab.section, text: query, collectionID: selectedCollectionID,
                     tag: selectedTag, sort: sort).apply(to: snapshot)
    }
    var allTags: [String] { Array(Set(snapshot.activeBooks.flatMap(\.tags))).sorted() }
    var trashedBooks: [Book] { snapshot.books.filter(\.isTrashed).sorted { ($0.trashedAt ?? .distantPast) > ($1.trashedAt ?? .distantPast) } }
    var busy: Bool { importLabel != nil || operationLabel != nil }
    var totalBytes: Int64 { snapshot.books.reduce(0) { $0 + $1.byteCount } }
    var studyMarks: [StudyAnnotation] {
        let active = Set(snapshot.activeBooks.map(\.id))
        return snapshot.annotations.filter { $0.kind.isStudyMarker && active.contains($0.bookID) }
            .sorted { $0.createdAt > $1.createdAt }
    }
    func originalURL(_ book: Book) -> URL { vault.originalURL(for: book.id) }

    func bootstrap() async {
        guard !isBootstrapping, phase != .ready else { return }
        isBootstrapping = true
        defer { isBootstrapping = false }
        do {
            try paths.prepare()
            snapshot = try await repository.open()
            recoveredMetadata = await repository.recoveredFromPrevious

            // Publish the persisted library immediately. Cleanup/index work must never
            // sit in the cold-launch critical path.
            phase = .ready

            if !seedSamples { try await purgeBundledSamplesIfPresent() }
            if seedSamples && !snapshot.didSeedSamples {
                try await SampleLibrarySeeder(repository: repository, importer: importer).seed()
            }
            try await reload()
            paths.clearOldTemporaryFiles()
            await drainImports()
            isIndexing = true
            let failures = await rebuilder.rebuildMissing()
            isIndexing = false
            try await reload()
            if failures > 0 { announce("Some PDFs are readable but could not be indexed. Use search inside the reader.") }
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func purgeBundledSamplesIfPresent() async throws {
        let existing = try await repository.snapshot().books.filter(\.isSample)
        guard !existing.isEmpty else { return }
        for book in existing {
            if !book.isTrashed { try await repository.trashBook(id: book.id) }
            try await repository.permanentlyDelete(id: book.id, vault: vault, indexes: indexes)
        }
        snapshot = try await repository.snapshot()
    }
    func reload() async throws { snapshot = try await repository.snapshot() }
    func open(_ book: Book, page: Int? = nil, sourceText: String? = nil, knowledgeTravel: Bool = false, restoreLens: LearningSource? = nil, sourceReturnLabel: String? = nil) {
        StudyInteractionTrace.record("reader.route.request document=\(book.id)")
        readerRoute = ReaderRoute(book: book, pageIndex: page, sourceText: sourceText, knowledgeTravel: knowledgeTravel, restoreLens: restoreLens, sourceReturnLabel: sourceReturnLabel)
    }
    func readerClosed() {
        Task { do { try await reload() } catch { errorMessage = error.localizedDescription } }
    }
    func announce(_ text: String) {
        noticeTask?.cancel()
        notice = text
        noticeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.notice = nil
        }
    }
    @discardableResult
    func perform(_ operation: () async throws -> Void) async -> Bool {
        do { try await operation(); try await reload(); return true }
        catch { errorMessage = error.localizedDescription; return false }
    }
}
