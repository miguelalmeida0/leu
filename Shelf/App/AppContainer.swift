import SwiftUI
import ShelfCore

/// The single composition root. Feature views never construct repositories or persistence services.
@MainActor
final class AppContainer {
    let paths: AppPaths
    let repository: LibraryRepository
    let vault: FileDocumentVault
    let preferences: AppPreferences
    let thumbnails: PDFThumbnailService
    let library: LibraryModel
    let loader = PDFDocumentLoader()
    let pageSearch = PDFPageSearch()
    let exporter: PDFExportService
    let learningRepository: LearningRepository
    let learning: LearningModel
    let knowledgeRepository: KnowledgeRepository
    let knowledge: KnowledgeModel

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let testing = arguments.contains("--uitesting") ||
            ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        paths = AppPaths(isUITesting: testing)
        if testing && arguments.contains("--reset-library") {
            try? FileManager.default.removeItem(at: paths.root)
            UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "Shelf")
        }
        repository = LibraryRepository(persistence: JSONSnapshotStore(root: paths.root))
        vault = FileDocumentVault(root: paths.root)
        let indexes = FileTextIndexStore(root: paths.root)
        let inspector = PDFInspector()
        let importer = DocumentImportService(repository: repository, vault: vault, inspector: inspector, indexes: indexes)
        let incoming = IncomingFileService(temporary: paths.temporary)
        let backup = BackupService(repository: repository, vault: vault, temporaryDirectory: paths.temporary)
        let search = LibraryTextSearch(indexes: indexes)
        let rebuilder = IndexRebuilder(vault: vault, indexes: indexes, inspector: inspector, repository: repository)
        preferences = AppPreferences()
        thumbnails = PDFThumbnailService()
        exporter = PDFExportService(vault: vault, temporary: paths.temporary)
        learningRepository = LearningRepository(persistence: FileLearningSnapshotStore(root: paths.root))
        let learningIndexer = PDFLearningIndexer(extractor: PDFKitTextExtractor(
            checkpoints: FilePDFTextExtractionCheckpointStore(root: paths.root)
        ))
        library = LibraryModel(repository: repository, vault: vault, importer: importer,
            incoming: incoming, backup: backup, search: search, indexes: indexes,
            rebuilder: rebuilder, paths: paths, seedSamples: testing && !arguments.contains("--no-samples"))
        learning = LearningModel(repository: learningRepository, library: library,
            recordingsDirectory: paths.root.appendingPathComponent("Learning/Recordings", isDirectory: true),
            indexer: learningIndexer)
        knowledgeRepository = KnowledgeRepository(persistence: FileKnowledgeSnapshotStore(root: paths.root))
        knowledge = KnowledgeModel(repository: knowledgeRepository, learning: learning, library: library)
        learning.makeIntelligenceReader = { [weak self] source, returnLabel in
            guard let self, let book = library.snapshot.activeBooks.first(where: { $0.id == source.documentID }) else { return nil }
            let reader = ReaderModel(book: book, initialPage: source.pageIndex, repository: repository,
                url: vault.originalURL(for: book.id), loader: loader, search: pageSearch,
                exporter: exporter, preferences: preferences, learning: learning, knowledge: knowledge,
                initialSourceText: source.sourceText, sourceReturnLabel: returnLabel)
            return IntelligenceReaderRoute(reader: reader, thumbnails: thumbnails)
        }
    }

    func reader(for route: ReaderRoute) -> ReaderModel {
        ReaderModel(book: route.book, initialPage: route.pageIndex, repository: repository,
            url: vault.originalURL(for: route.book.id), loader: loader,
            search: pageSearch, exporter: exporter, preferences: preferences, learning: learning,
            knowledge: knowledge, initialSourceText: route.sourceText, initialKnowledgeTravel: route.knowledgeTravel, initialLensSource: route.restoreLens, sourceReturnLabel: route.sourceReturnLabel)
    }
}
