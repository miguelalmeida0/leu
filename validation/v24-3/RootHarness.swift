import Foundation

@main struct RootHarness {
    @MainActor static var checks = 0
    @MainActor static func require(_ condition: Bool, _ name: String) throws {
        guard condition else { throw Failure.assertion(name) }
        checks += 1
        print("PASS: " + name)
    }
    @MainActor static func probe() -> RootLogicProbe {
        StudyInteractionTrace.events = []
        return RootLogicProbe()
    }
    // Wait for bounded, scheduled callbacks without invoking their bodies from the test.
    @MainActor static func waitForEvent(_ name: String) async throws {
        for _ in 0..<10_000 {
            if StudyInteractionTrace.events.contains(name) { return }
            await Task.yield()
        }
        throw Failure.assertion("Scheduled callback did not complete: " + name)
    }
    @MainActor static func main() async throws {
        try await launchChecks()
        try await routingChecks()
        try await sourceChecks()
        try await backupChecks()
        print("PASS: \(checks) extracted RootView lifecycle checks; platform adapters, not Apple UI certification")
    }
    @MainActor static func launchChecks() async throws {
        let resumed = probe()
        resumed.container.learning.activeSession = Session()
        await resumed.bootstrapOnLaunch()
        try require(StudyInteractionTrace.events == ["library.bootstrap", "learning.bootstrap",
            "route.study.restored", "knowledge.bootstrap"], "bootstrap and recovery preserve execution order")
        try require(resumed.primaryArea == .learn && resumed.studySurface == .landing,
                    "unfinished Study restores directly")
        resumed.primaryArea = .shelf
        resumed.restoreStudyOnLaunchIfNeeded()
        try require(resumed.primaryArea == .shelf, "recovery does not override a later manual navigation")
        let empty = probe()
        await empty.bootstrapOnLaunch()
        try require(empty.primaryArea == .shelf && empty.didRestoreStudyOnLaunch, "no session stays in Library")
        let finished = probe()
        finished.container.learning.activeSession = Session(completedAt: Date())
        await finished.bootstrapOnLaunch()
        try require(finished.primaryArea == .shelf, "completed sessions do not reopen as unfinished")
        let waiting = probe()
        waiting.container.learning.isReady = false
        waiting.container.learning.activeSession = Session()
        waiting.restoreStudyOnLaunchIfNeeded()
        try require(!waiting.didRestoreStudyOnLaunch && waiting.primaryArea == .shelf,
                    "recovery waits for Learning readiness")
        waiting.container.learning.isReady = true
        waiting.restoreStudyOnLaunchIfNeeded()
        try require(waiting.primaryArea == .learn, "ready recovery can still run after an unready attempt")
        let retry = probe()
        await retry.retryBootstrap()
        try require(StudyInteractionTrace.events == ["library.bootstrap", "learning.bootstrap", "knowledge.bootstrap"],
                    "retry retains original bootstrap order")
        StudyInteractionTrace.events = []
        await retry.synchronizeLibraryIndexes()
        try require(StudyInteractionTrace.events == ["learning.sync", "knowledge.sync"], "index synchronization is ordered")
    }
    @MainActor static func routingChecks() async throws {
        let current = probe()
        current.container.learning.activeSession = Session()
        current.scenePhaseChanged(.active)
        try require(current.container.learning.writes == 0, "active scene does not request a checkpoint")
        current.scenePhaseChanged(.inactive); current.scenePhaseChanged(.background)
        try require(current.container.learning.writes == 2, "inactive and background request checkpoints")
        current.container.learning.activeSession = nil
        current.scenePhaseChanged(.background)
        try require(current.container.learning.writes == 2, "no session means no checkpoint request")
        current.primaryArea = .learn; current.studySurface = .progress
        current.activeSessionChanged(nil)
        try require(current.studySurface == .progress, "nil session changes do not dismiss Progress")
        current.activeSessionChanged(UUID())
        try require(current.studySurface == .landing && StudyInteractionTrace.events.contains("route.session.requested"),
                    "recall from Progress reveals the Study session")
        current.primaryArea = .shelf; current.studySurface = .progress
        current.activeSessionChanged(UUID())
        try require(current.studySurface == .progress && current.primaryArea == .shelf,
                    "session changes do not steal a different tab")
        StudyInteractionTrace.events = []
        current.primaryAreaChanged(.shelf)
        try require(current.studySurface == .landing && StudyInteractionTrace.events.isEmpty,
                    "leaving Study resets only its internal surface")
        current.primaryAreaChanged(.trails)
        try await waitForEvent("knowledge.sync")
        try require(StudyInteractionTrace.events == ["learning.sync", "knowledge.sync"], "Trails refreshes both indexes")
        StudyInteractionTrace.events = []; current.primaryArea = .learn
        current.primaryAreaChanged(.learn)
        try await waitForEvent("knowledge.sync")
        try require(StudyInteractionTrace.events == ["learning.sync", "knowledge.sync"], "Study refreshes both indexes")
    }
    @MainActor static func sourceChecks() async throws {
        let current = probe(), book = Book(id: UUID(), fingerprint: "sha")
        let destination = KnowledgeDestination(documentID: book.id, pageIndex: 7, sourceText: "Source",
                                               restoreLens: LensOrigin(id: 42))
        current.container.library.snapshot.activeBooks = [book]
        current.container.knowledge.pendingDestination = destination
        current.knowledgeDestinationChanged(nil)
        try require(current.container.knowledge.pendingDestination != nil, "nil destination is ignored")
        current.knowledgeDestinationChanged(destination)
        let route = current.container.library.readerRoute
        try require(route?.documentID == book.id && route?.pageIndex == 7 && route?.sourceText == "Source" &&
                    route?.restoreLens == LensOrigin(id: 42) && route?.knowledgeTravel == true,
                    "source navigation retains document, page, excerpt and Lens origin")
        current.container.knowledge.pendingDestination = destination
        current.knowledgeDestinationChanged(destination)
        try require(current.container.knowledge.pendingDestination != nil, "a presented Reader defers another destination")
        StudyInteractionTrace.events = []
        current.readerDidDismiss()
        try await waitForEvent("library.open")
        try require(StudyInteractionTrace.events == ["library.readerClosed", "library.open"],
                    "dismissal closes the old Reader before opening the queued source")
        current.container.library.readerRoute = nil
        current.container.library.snapshot.activeBooks = []
        current.container.knowledge.pendingDestination = destination
        current.knowledgeDestinationChanged(destination)
        try require(current.container.library.readerRoute == nil && current.container.knowledge.errorMessage != nil,
                    "unavailable source produces an error, not a route")
        current.container.library.snapshot.activeBooks = [book]
        try require(current.activeBookVersions == ["\(book.id.uuidString)|sha"], "typed book identity includes its fingerprint")
    }
    @MainActor static func backupChecks() async throws {
        let current = probe(), first = URL(fileURLWithPath: "/first"), second = URL(fileURLWithPath: "/second")
        current.backupImportCompleted(.success([first, second]))
        try require(current.container.library.pendingBackupURL == first, "file selection keeps the first URL")
        current.backupImportCompleted(.success([]))
        try require(current.container.library.pendingBackupURL == nil, "empty file selection clears confirmation")
        current.backupImportCompleted(.failure(Failure.assertion("import")))
        try require(current.container.library.errorMessage != nil, "import errors remain visible")
        current.container.library.pendingBackupURL = first
        current.mergeBackup(first)
        try require(current.container.library.pendingBackupURL == nil, "merge immediately clears the confirmation")
        try await waitForEvent("knowledge.sync")
        try require(StudyInteractionTrace.events == ["library.restore", "learning.sync", "knowledge.sync"],
                    "merge refreshes indexes only after restore")
        current.resetLibraryScope(current.container.library)
        let model = current.container.library
        try require(model.query.isEmpty && model.selectedCollectionID == nil && model.selectedTag == nil &&
                    model.passages.isEmpty && StudyInteractionTrace.events.last == "library.search",
                    "library scope reset clears filters and refreshes search")
    }
}
private enum Failure: Error { case assertion(String) }
