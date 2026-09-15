import Foundation
import ShelfCore

@main struct DraftChecks {
    static func main() async throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let output = CommandLine.arguments.count > 1 ? URL(fileURLWithPath: CommandLine.arguments[1]) : root.appendingPathComponent("docs/qwen-local/draft-persistence.json")
        guard !FileManager.default.fileExists(atPath: output.path) else { fatalError("Preserve existing evidence") }
        let document = UUID()
        let text = "The cleanup removes the previous listener before the effect runs again. This prevents duplicate listeners."
        var page = AnalyzedPage(pageIndex: 0, normalizedText: text,
            segments: [.init(pageIndex: 0, kind: .paragraph, text: text, sectionTitle: "Cleanup")])
        page.canonicalText = text; page.spatialIntegrityPassed = true
        var analysis = DocumentAnalysis(documentID: document, fingerprint: "draft-fixture", algorithmVersion: 5, pages: [page])
        analysis.extractionVersion = SourceExtractionVersion.current
        let source = IntelligenceSource(source: .init(documentID: document, pageIndex: 0, sourceText: text), analysis: analysis)!
        let location = root.appendingPathComponent(".qwen-local/draft-check-\(UUID())")
        let store = FileLearningSnapshotStore(root: location)
        try store.save(LearningSnapshot(analyses: [document: analysis]))
        let repository = LearningRepository(persistence: store)
        let original = String(repeating: "My draft contains café and 🟢, with spaces and line breaks.\n", count: 180)
            + "The FINAL clause must survive even when inference refuses this length."
        var attempt = UnderstandingAttempt(source: source, learnerExplanation: original)
        try await repository.storeUnderstandingAttempt(attempt)
        let reopened = try await LearningRepository(persistence: store).open()
        var checks: [[String: Any]] = [
            ["name": "Oversized Unicode draft reopens byte-for-byte including the final clause", "passed": reopened.understandingAttempts.first?.learnerExplanation.utf8.elementsEqual(original.utf8) == true],
            ["name": "Saving an unresolved draft creates no support or taught event", "passed": reopened.understandingAttempts.first?.supportedClaimIDs.isEmpty == true && reopened.understandingEvents.isEmpty]
        ]
        attempt.learnerExplanation = "The edited draft keeps the same identity."
        try await repository.storeUnderstandingAttempt(attempt)
        let edited = try await LearningRepository(persistence: store).open()
        checks.append(["name": "Edit replaces only the same attempt", "passed": edited.understandingAttempts.count == 1 && edited.understandingAttempts.first?.id == attempt.id && edited.understandingAttempts.first?.learnerExplanation == attempt.learnerExplanation])
        var stale = edited
        stale.analyses[document]!.fingerprint = "changed-source"
        try store.save(stale)
        do {
            try await LearningRepository(persistence: store).storeUnderstandingAttempt(attempt)
            checks.append(["name": "Stale source remains rejected", "passed": false])
        } catch {
            checks.append(["name": "Stale source remains rejected", "passed": true])
        }
        let afterRejected = try store.load()
        checks.append(["name": "Rejected stale write preserves the saved attempt", "passed": afterRejected.understandingAttempts == edited.understandingAttempts])
        let report: [String: Any] = ["checks": checks, "draft_utf8_bytes": original.utf8.count,
            "scope": "Actual file persistence and repository reopen; no rendered UI, termination signal, or phone test"]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: output)
        if checks.contains(where: { $0["passed"] as? Bool != true }) { exit(1) }
    }
}
