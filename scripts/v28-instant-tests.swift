import Foundation
@testable import ShelfCore

@main struct InstantTests {
    static func main() async throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let out = root.appendingPathComponent("docs/v28.1/performance")
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        var analyses: [UUID: DocumentAnalysis] = [:], titles: [UUID: String] = [:]
        for name in ["javascript_midlevel_interview_mobile_mastery", "React Notes", "JavaScript Deep Dive", "System Design"] {
            let a = try decoder.decode(DocumentAnalysis.self, from: Data(contentsOf: root.appendingPathComponent("docs/v28/evidence/baseline/\(name)-analysis.json")))
            analyses[a.documentID] = a; titles[a.documentID] = name
        }
        let primary = analyses.values.first { $0.pages.count == 345 }!
        var tests: [[String: Any]] = []
        func check(_ name: String, _ pass: Bool) {
            tests.append(["name": name, "pass": pass]); print("\(pass ? "PASS" : "FAIL") \(name)"); fflush(stdout)
        }
        let location = root.appendingPathComponent(".build/v28-instant-tests-\(UUID())")
        let store = FileLearningSnapshotStore(root: location)
        let durableTime = Date(timeIntervalSinceReferenceDate: 810_000_000)
        let historyObject = LearningObject(type: .passage, source: .init(documentID: primary.documentID, pageIndex: 40, sourceText: "My own learning note"), title: "My note", createdAt: durableTime, origin: .userAuthored)
        let historyQuestionID = UUID()
        let attempt = LearningAttempt(learningObjectID: historyObject.id, questionID: historyQuestionID, occurredAt: durableTime, rating: .difficult, wasCorrect: false, confidence: .certain, responseTime: 4.125, hintCount: 1)
        let confidence = ConfidenceRecord(questionID: historyQuestionID, propositionID: "history", confidence: .certain, wasCorrect: false, occurredAt: durableTime)
        try store.save(LearningSnapshot(analyses: analyses, learningObjects: [historyObject], attempts: [attempt], confidenceRecords: [confidence]))
        let repo = LearningRepository(persistence: store)
        let priority = V4GenerationSession.priorityPages(primary, current: 40)
        check("Current page then nearby pages", priority.first == 40 && Set(priority.prefix(5)) == Set(38...42))
        let session = V4GenerationSession(analysis: primary)
        var checkpoints: [[String: Any]] = []
        let started = Date()
        let first = try await session.batch(pages: Array(priority.prefix(12)))
        var start = Date(); try await repo.storeV4Batch(first)
        checkpoints.append(["pages": 12, "questions": first.questions.count, "generationToVisibleMs": Date().timeIntervalSince(started)*1000, "saveMs": Date().timeIntervalSince(start)*1000])
        let partial = try await LearningRepository(persistence: FileLearningSnapshotStore(root: location)).open()
        check("Useful questions durably visible before all pages finish", !partial.questions.isEmpty && partial.completedV4Pages(documentID: primary.documentID).count == 12)
        let remaining = priority.filter { !partial.completedV4Pages(documentID: primary.documentID).contains($0) }
        let resumed = V4GenerationSession(analysis: primary)
        for offset in stride(from: 0, to: remaining.count, by: 24) {
            let batch = try await resumed.batch(pages: Array(remaining[offset..<min(offset+24, remaining.count)]))
            start = Date(); try await repo.storeV4Batch(batch)
            checkpoints.append(["pages": batch.pages.count, "questions": batch.questions.count, "saveMs": Date().timeIntervalSince(start)*1000])
        }
        let complete = try await repo.snapshot()
        check("Resumed bank has 90 questions and all pages checkpointed", complete.questions.count == 90 && complete.completedV4Pages(documentID: primary.documentID).count == 345)
        let old = try decoder.decode([LearningQuestion].self, from: Data(contentsOf: out.appendingPathComponent("baseline-questions.json")))
        let oldProofs = Dictionary(uniqueKeysWithValues: old.map { ($0.id, $0.v4) })
        check("All 90 full proofs match baseline including choices and order", complete.questions.allSatisfy { oldProofs[$0.id] == $0.v4 })
        let opened = try await LearningRepository(persistence: FileLearningSnapshotStore(root: location)).open()
        check("Reopen needs zero generation pages", Set(primary.pages.map(\.pageIndex)).subtracting(opened.completedV4Pages(documentID: primary.documentID)).isEmpty)
        check("Warm migration uses receipt without reconstructed claims", IntelligencePerformance.samples().last(where: { $0.stage == "validated_snapshot_lookup" })?.workCount == 0)
        let selectedTopics: Set<UUID> = [UUID(), UUID()]
        try await repo.setManualTopics(documentID: primary.documentID, topicIDs: selectedTopics)
        let retagged = try await LearningRepository(persistence: FileLearningSnapshotStore(root: location)).open()
        check("Learner topic changes preserve generation completion", retagged.completedV4Pages(documentID: primary.documentID).count == 345 && retagged.questions.allSatisfy { $0.topicIDs == selectedTopics })
        var edited = complete
        edited.questions[0].prompt = "Why does this always work?"
        DerivedExtractionMigration.apply(to: &edited)
        check("Edited question invalidates receipt and is rejected", !edited.questions.contains { $0.id == complete.questions[0].id } && edited.completedV4Pages(documentID: primary.documentID).isEmpty)
        var stale = complete
        stale.analyses[primary.documentID]!.extractionVersion = 4
        DerivedExtractionMigration.apply(to: &stale)
        check("Extraction downgrade invalidates questions and completion", stale.questions.isEmpty && stale.completedV4Pages(documentID: primary.documentID).isEmpty)
        var changed = complete
        changed.analyses[primary.documentID]!.fingerprint += "-changed"
        DerivedExtractionMigration.apply(to: &changed)
        check("Fingerprint change invalidates questions", changed.questions.isEmpty)
        var sourceEdit = complete
        let q = sourceEdit.questions[0]
        let pageOffset = sourceEdit.analyses[primary.documentID]!.pages.firstIndex { $0.pageIndex == q.source.pageIndex }!
        sourceEdit.analyses[primary.documentID]!.pages[pageOffset].canonicalText = "Changed source under the same fingerprint"
        DerivedExtractionMigration.apply(to: &sourceEdit)
        check("Same-fingerprint source edit cannot reuse admission", !sourceEdit.questions.contains { $0.id == q.id })
        var upgraded = complete
        let receiptEncoder = JSONEncoder()
        var receiptJSON = try JSONSerialization.jsonObject(with: receiptEncoder.encode(upgraded.v4Receipts[primary.documentID]!)) as! [String: Any]
        receiptJSON["contract"] = 999
        upgraded.v4Receipts[primary.documentID] = try JSONDecoder().decode(ValidatedIntelligenceReceipt.self, from: JSONSerialization.data(withJSONObject: receiptJSON))
        DerivedExtractionMigration.apply(to: &upgraded)
        check("Changed question contract requires fresh admission", upgraded.questions.count == 90 && upgraded.completedV4Pages(documentID: primary.documentID).isEmpty)
        var contract = complete
        contract.v4Receipts.removeAll()
        DerivedExtractionMigration.apply(to: &contract)
        check("Legacy snapshot revalidates once without losing accepted questions", contract.questions.count == 90 && !contract.v4Receipts.isEmpty)
        check("Migration preserves learner records exactly", stale.attempts == [attempt] && stale.confidenceRecords == [confidence] && stale.learningObjects.contains(historyObject) && stale.reviewStates == complete.reviewStates)
        // The actor rejects a valid batch bound to a different analysis version.
        let differentStore = FileLearningSnapshotStore(root: location.appendingPathComponent("changed"))
        try differentStore.save(LearningSnapshot(analyses: changed.analyses))
        var rejected = false
        do { try await LearningRepository(persistence: differentStore).storeV4Batch(first) } catch { rejected = true }
        check("Stale in-flight batch cannot install", rejected)
        let cache = LibraryIntelligenceCache(root: location)
        let uncached = V28ConnectionIndex(analyses: analyses, titles: titles)
        let anchor = uncached.facts.first { titles[$0.documentID] == "React Notes" && $0.pageIndex == 2 && $0.relations.contains { $0.subject == "react.stable-key" } }!
        let source = anchor.citation(in: analyses)!
        let cold = try await cache.retrieve(source: source, analyses: analyses, titles: titles)
        let cacheWriteError = await cache.lastPersistenceError
        check("Derived cache writes actually persist", cacheWriteError == nil)
        var lookups: [Double] = [], availability: [Double] = []
        for _ in 0..<20 {
            start = Date(); _ = try await cache.retrieve(source: source, analyses: analyses, titles: titles); lookups.append(Date().timeIntervalSince(start)*1000)
            start = Date(); _ = try await cache.sources(for: source, analyses: analyses, titles: titles); availability.append(Date().timeIntervalSince(start)*1000)
        }
        start = Date()
        let diskSources = try await LibraryIntelligenceCache(root: location).sources(for: source, analyses: analyses, titles: titles)
        let coldAvailability = Date().timeIntervalSince(start)*1000
        check("Reopened reader tools load current shard under 100ms", !diskSources.isEmpty && coldAvailability < 100)
        let disk = try await LibraryIntelligenceCache(root: location).retrieve(source: source, analyses: analyses, titles: titles)
        check("Reopened capability snapshot performs no source-role work", IntelligencePerformance.samples().last(where: { $0.stage == "reader_snapshot" })?.cacheHit == true)
        let snapshotLookups = IntelligencePerformance.samples().filter { $0.stage == "connection_snapshot" }.suffix(analyses.count)
        check("Fresh actor reads persisted facts without role reconstruction", snapshotLookups.count == analyses.count && snapshotLookups.allSatisfy { $0.cacheHit && $0.workCount == 0 })
        check("Persistent connections preserve exact admitted pair orientation", !cold.connections.isEmpty && cold.connections == disk.connections && cold.connections == uncached.connections(from: source, analyses: analyses))
        let cacheFiles = try FileManager.default.contentsOfDirectory(at: location.appendingPathComponent("Intelligence-v28.1"), includingPropertiesForKeys: nil)
        let capFile = cacheFiles.first { $0.lastPathComponent.hasPrefix("cap-") }!
        var corrupt = try JSONSerialization.jsonObject(with: Data(contentsOf: capFile)) as! [String: Any]
        var payload = corrupt["payload"] as! [String: Any]; payload["canTeach"] = false; corrupt["payload"] = payload
        try JSONSerialization.data(withJSONObject: corrupt).write(to: capFile)
        let repairedCache = try await LibraryIntelligenceCache(root: location).retrieve(source: source, analyses: analyses, titles: titles)
        check("Corrupt cached payload is recomputed rather than accepted", repairedCache.canTeach && repairedCache.connections == cold.connections && IntelligencePerformance.samples().last(where: { $0.stage == "reader_snapshot" })?.cacheHit == false)
        let removedID = cold.connections.first!.related(to: source).documentID
        var removed = analyses; removed.removeValue(forKey: removedID)
        let afterRemoval = try await cache.retrieve(source: source, analyses: removed, titles: titles)
        check("Removed document disappears from cached results", afterRemoval.connections.allSatisfy { $0.sourceA.documentID != removedID && $0.sourceB.documentID != removedID })
        check("Warm connection p50 below 150ms", lookups.sorted()[10] < 150)
        check("Warm reader capability availability below 100ms", availability.max()! < 100)
        try JSONSerialization.data(withJSONObject: ["tests": tests, "passed": tests.filter { $0["pass"] as! Bool }.count,
            "total": tests.count, "checkpoints": checkpoints, "warmConnectionMs": lookups, "readerAvailabilityMs": availability, "reopenedReaderAvailabilityMs": coldAvailability], options: [.prettyPrinted, .sortedKeys]).write(to: out.appendingPathComponent("incremental-and-cache-tests.json"))
        guard tests.allSatisfy({ $0["pass"] as! Bool }) else { exit(1) }
    }
}
