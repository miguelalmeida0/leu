import XCTest
import SwiftUI
import ShelfCore
@testable import Shelf

/// Exercises the production state owner and source route with disposable repositories.
@MainActor
final class RecallSessionStateTests: XCTestCase {
    private func makeModel() async throws -> (LearningModel, FileLearningSnapshotStore) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let libraryRepository = LibraryRepository(persistence: JSONSnapshotStore(root: root))
        let vault = FileDocumentVault(root: root)
        let indexes = FileTextIndexStore(root: root)
        let inspector = PDFInspector()
        let library = LibraryModel(repository: libraryRepository, vault: vault,
            importer: DocumentImportService(repository: libraryRepository, vault: vault, inspector: inspector, indexes: indexes),
            incoming: IncomingFileService(temporary: root),
            backup: BackupService(repository: libraryRepository, vault: vault, temporaryDirectory: root),
            search: LibraryTextSearch(indexes: indexes), indexes: indexes,
            rebuilder: IndexRebuilder(vault: vault, indexes: indexes, inspector: inspector, repository: libraryRepository),
            paths: AppPaths(isUITesting: true), seedSamples: false)
        let book = Book(title: "Recall source", originalFilename: "source.pdf", fingerprint: "recall-state-test", pageCount: 4, byteCount: 1)
        library.snapshot.books = [book]
        let objects = [2, 3].map { page in
            LearningObject(type: .recall,
                source: LearningSource(documentID: book.id, pageIndex: page, sourceText: "Source passage \(page).", sectionTitle: "Section \(page)"),
                title: "Section \(page)")
        }
        let store = FileLearningSnapshotStore(root: root)
        try store.save(LearningSnapshot(learningObjects: objects))
        let repository = LearningRepository(persistence: store)
        let model = LearningModel(repository: repository, library: library, recordingsDirectory: root.appendingPathComponent("Recordings"))
        model.snapshot = try await repository.open()
        model.startActiveRecall()
        await model.studySaveTask?.value
        XCTAssertNil(model.studySaveError)
        return (model, store)
    }

    func testDraftSurvivesExactSourceRouteAndCardReconstruction() async throws {
        let (model, _) = try await makeModel()
        let source = try XCTUnwrap(model.currentObject?.source)
        let sessionID = model.activeSession?.id
        model.recallDraft = "My answer, including a second\nline."
        model.openSource(source)
        XCTAssertEqual(model.library.readerRoute?.book.id, source.documentID)
        XCTAssertEqual(model.library.readerRoute?.pageIndex, source.pageIndex)
        XCTAssertEqual(model.library.readerRoute?.sourceText, source.sourceText)
        model.library.readerRoute = nil
        let reconstructed = UIHostingController(rootView: RecallCardView(model: model))
        reconstructed.loadViewIfNeeded()
        XCTAssertEqual(model.recallDraft, "My answer, including a second\nline.")
        XCTAssertEqual(model.activeSession?.id, sessionID)
        XCTAssertEqual(model.activityIndex, 0)
        XCTAssertTrue(model.snapshot.attempts.isEmpty)
    }

    func testUnknownSurvivesSourceRouteAndCardReconstructionWithoutAssessment() async throws {
        let (model, store) = try await makeModel()
        model.recallMarkedUnknown = true
        model.openSource(try XCTUnwrap(model.currentObject?.source))
        model.library.readerRoute = nil
        let reconstructed = UIHostingController(rootView: RecallCardView(model: model))
        reconstructed.loadViewIfNeeded()
        XCTAssertTrue(model.recallMarkedUnknown)
        XCTAssertTrue(model.snapshot.attempts.isEmpty)
        XCTAssertTrue(try store.load().attempts.isEmpty)
        XCTAssertTrue(model.snapshot.confidenceRecords.isEmpty)
    }

    func testAdvanceResetsBothInputsWithoutRelyingOnAViewCallback() async throws {
        let (model, _) = try await makeModel()
        let first = model.currentObject?.id
        model.recallDraft = "Transient answer"
        model.recallMarkedUnknown = true
        model.advance()
        await model.studySaveTask?.value
        XCTAssertNotEqual(model.currentObject?.id, first)
        XCTAssertEqual(model.activityIndex, 1)
        XCTAssertEqual(model.recallDraft, "")
        XCTAssertFalse(model.recallMarkedUnknown)
        XCTAssertTrue(model.snapshot.attempts.isEmpty)
    }

    func testEndAndNewSessionClearRecallInput() async throws {
        let (model, _) = try await makeModel()
        model.recallDraft = "Ended session"
        model.recallMarkedUnknown = true
        model.endSession()
        await model.studySaveTask?.value
        XCTAssertEqual(model.recallDraft, "")
        XCTAssertFalse(model.recallMarkedUnknown)
        model.startActiveRecall()
        await model.studySaveTask?.value
        model.recallDraft = "Replaced session"
        model.recallMarkedUnknown = true
        model.startActiveRecall()
        await model.studySaveTask?.value
        XCTAssertEqual(model.recallDraft, "")
        XCTAssertFalse(model.recallMarkedUnknown)
    }

    func testCheckpointExcludesDraftAndUnknownAndCreatesNoAttempt() async throws {
        let (model, store) = try await makeModel()
        let before = try store.load()
        model.recallDraft = "PRIVATE-TRANSIENT-RECALL-TEXT"
        model.recallMarkedUnknown = true
        model.persistStudyState()
        await model.studySaveTask?.value
        let saved = try store.load()
        XCTAssertEqual(saved.attempts, before.attempts)
        XCTAssertEqual(saved.confidenceRecords, before.confidenceRecords)
        XCTAssertEqual(saved.reviewStates, before.reviewStates)
        let json = String(decoding: try JSONEncoder().encode(saved), as: UTF8.self)
        XCTAssertFalse(json.contains("PRIVATE-TRANSIENT-RECALL-TEXT"))
        XCTAssertFalse(json.contains("recallDraft"))
        XCTAssertFalse(json.contains("recallMarkedUnknown"))
        XCTAssertEqual(model.recallDraft, "PRIVATE-TRANSIENT-RECALL-TEXT")
        XCTAssertTrue(model.recallMarkedUnknown)
    }

    func testOnlyExplicitRatingCreatesAnAttemptAndDoesNotGradeOpenRecall() async throws {
        let (model, store) = try await makeModel()
        model.recallDraft = "An unevaluated answer"
        model.recallMarkedUnknown = true
        XCTAssertTrue(try store.load().attempts.isEmpty)
        await model.rateCurrent(.forgot)
        await model.studySaveTask?.value
        let attempts = try store.load().attempts
        XCTAssertEqual(attempts.count, 1)
        XCTAssertEqual(attempts.first?.rating, .forgot)
        XCTAssertNil(attempts.first?.wasCorrect)
        XCTAssertNil(attempts.first?.confidence)
        XCTAssertEqual(model.recallDraft, "")
        XCTAssertFalse(model.recallMarkedUnknown)
    }
}
