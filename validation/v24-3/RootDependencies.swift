import Foundation

// Portable adapters for testing extracted RootView method bodies, not SwiftUI rendering.
@MainActor @propertyWrapper final class RootTestState<Value> {
    var wrappedValue: Value
    init(wrappedValue: Value) { self.wrappedValue = wrappedValue }
}
enum ScenePhase { case active, inactive, background }
enum StudySurface { case landing, progress }
struct Session { let id = UUID(); var completedAt: Date? = nil }
struct LensOrigin: Equatable { let id: Int }
struct Book { let id: UUID; let fingerprint: String }
struct Snapshot { var activeBooks: [Book] = [] }
struct ReaderRoute {
    let documentID: UUID
    let pageIndex: Int
    let sourceText: String
    let knowledgeTravel: Bool
    let restoreLens: LensOrigin?
}
struct KnowledgeDestination {
    let documentID: UUID
    let pageIndex: Int
    let sourceText: String
    let restoreLens: LensOrigin?
}
@MainActor enum StudyInteractionTrace {
    static var events: [String] = []
    static func record(_ name: String) { events.append(name) }
}
@MainActor final class LibraryModel {
    var snapshot = Snapshot()
    var query = "query"
    var selectedCollectionID: UUID? = UUID()
    var selectedTag: String? = "tag"
    var passages = ["passage"]
    var readerRoute: ReaderRoute?
    var pendingBackupURL: URL?
    var errorMessage: String?
    func bootstrap() async { StudyInteractionTrace.record("library.bootstrap") }
    func restoreBackup(_ url: URL) async { StudyInteractionTrace.record("library.restore") }
    func readerClosed() { readerRoute = nil; StudyInteractionTrace.record("library.readerClosed") }
    func updateSearch() { StudyInteractionTrace.record("library.search") }
    func open(_ book: Book, page: Int, sourceText: String, knowledgeTravel: Bool, restoreLens: LensOrigin?) {
        readerRoute = ReaderRoute(documentID: book.id, pageIndex: page, sourceText: sourceText,
                                  knowledgeTravel: knowledgeTravel, restoreLens: restoreLens)
        StudyInteractionTrace.record("library.open")
    }
}
@MainActor final class LearningModel {
    var isReady = true
    var activeSession: Session?
    var writes = 0
    func bootstrap() async { StudyInteractionTrace.record("learning.bootstrap") }
    func syncLibrary() async { StudyInteractionTrace.record("learning.sync") }
    func persistStudyState() { writes += 1 }
}
@MainActor final class KnowledgeModel {
    var pendingDestination: KnowledgeDestination?
    var errorMessage: String?
    func bootstrap() async { StudyInteractionTrace.record("knowledge.bootstrap") }
    func syncLibrary() async { StudyInteractionTrace.record("knowledge.sync") }
    func consumeDestination() -> KnowledgeDestination? {
        let result = pendingDestination
        pendingDestination = nil
        return result
    }
}
@MainActor final class AppContainer {
    let library = LibraryModel()
    let learning = LearningModel()
    let knowledge = KnowledgeModel()
}
