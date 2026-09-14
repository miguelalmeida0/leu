import XCTest
import ShelfCore

final class SourceIntegrityMigrationTests: XCTestCase {
    func testV3CorruptionCannotEnterAPlanWhileMigrationIsPending() {
        let id = UUID()
        let damaged = ["Reac Note", "Key describ identit", "Stat i snapsho"]
        let objects = damaged.enumerated().map { index, text in
            LearningObject(type: .passage, source: LearningSource(documentID: id, pageIndex: index,
                sourceText: text), title: text, origin: .documentAnalysis)
        }
        var analysis = DocumentAnalysis(documentID: id, fingerprint: "unchanged", algorithmVersion: 2, pages: [])
        analysis.extractionVersion = 3
        let snapshot = LearningSnapshot(analyses: [id: analysis], learningObjects: objects)
        XCTAssertTrue(snapshot.studyObjects.isEmpty)
        let plan = ShelfStudySessionPlanner().plan(snapshot: snapshot, topicID: nil, minutes: 5, now: Date())
        XCTAssertFalse(plan.activities.contains { activity in objects.contains { $0.id == activity.learningObjectID } })
    }
    func testOldDerivedObjectsAreRetainedForHistoryButNotPlanned() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = FileLearningSnapshotStore(root: root)
        try await verifyMigration(store: store)
    }

    func testMigrationInMemoryRetainsUserContentAndReviewState() async throws {
        try await verifyMigration(store: MigrationMemoryStore())
    }

    private func verifyMigration(store: any LearningSnapshotPersistence) async throws {
        let id = UUID()
        let old = LearningObject(type: .passage, source: LearningSource(documentID: id, pageIndex: 0,
            sourceText: "Miss ng charact rs"), title: "Old", origin: .documentAnalysis)
        let authored = LearningObject(type: .recall, source: old.source, title: "My note", origin: .userAuthored)
        var snapshot = LearningSnapshot(learningObjects: [old, authored])
        snapshot.reviewStates[old.id] = ReviewState(learningObjectID: old.id)
        let questionID = UUID()
        snapshot.attempts = [LearningAttempt(learningObjectID: old.id, questionID: questionID,
            rating: .difficult, wasCorrect: false, confidence: .certain)]
        snapshot.confidenceRecords = [ConfidenceRecord(questionID: questionID, propositionID: nil,
            confidence: .certain, wasCorrect: false)]
        try store.save(snapshot)
        // FileLearningSnapshotStore's existing ISO-8601 format stores whole
        // seconds. Verify that boundary before migration, then compare exact
        // durable values; no global Equatable or production format change.
        let durableBefore = try store.load()
        let durableAuthored = try XCTUnwrap(durableBefore.learningObjects.first { $0.id == authored.id })
        HistoryFieldDiff.printPairs("serialization.authored", authored, durableAuthored)
        HistoryFieldDiff.printPairs("serialization.attempts", snapshot.attempts, durableBefore.attempts)
        HistoryFieldDiff.printPairs("serialization.confidence", snapshot.confidenceRecords, durableBefore.confidenceRecords)
        var expectedAuthored = authored
        var expectedAttempts = snapshot.attempts
        var expectedConfidence = snapshot.confidenceRecords
        if store is FileLearningSnapshotStore {
            expectedAuthored.createdAt = wholeSecond(expectedAuthored.createdAt)
            for i in expectedAttempts.indices { expectedAttempts[i].occurredAt = wholeSecond(expectedAttempts[i].occurredAt) }
            for i in expectedConfidence.indices { expectedConfidence[i].occurredAt = wholeSecond(expectedConfidence[i].occurredAt) }
        }
        XCTAssertEqual(durableAuthored, expectedAuthored)
        XCTAssertEqual(durableBefore.attempts, expectedAttempts)
        XCTAssertEqual(durableBefore.confidenceRecords, expectedConfidence)
        let repository = LearningRepository(persistence: store)
        var analysis = DocumentAnalysis(documentID: id, fingerprint: "pdf-unchanged", algorithmVersion: 2,
            pages: [AnalyzedPage(pageIndex: 0, normalizedText: "Complete source words.", segments: [
                SourceSegment(pageIndex: 0, kind: .paragraph, text: "Complete source words.", importance: 0.8)])])
        analysis.extractionVersion = SourceExtractionVersion.current
        analysis.pages[0].canonicalText = "Complete source words."
        try await repository.upsertAnalysis(analysis, topics: [], questions: [])
        let saved = try store.load()
        HistoryFieldDiff.printPairs("migration.authored", durableAuthored, saved.learningObjects.first { $0.id == authored.id } as Any)
        HistoryFieldDiff.printPairs("migration.attempts", durableBefore.attempts, saved.attempts)
        HistoryFieldDiff.printPairs("migration.confidence", durableBefore.confidenceRecords, saved.confidenceRecords)
        XCTAssertEqual(saved.learningObjects.first { $0.id == old.id }?.sourceIsStale, true)
        XCTAssertEqual(saved.learningObjects.first { $0.id == authored.id }, durableAuthored)
        XCTAssertNotNil(saved.reviewStates[old.id])
        XCTAssertEqual(saved.reviewStates[old.id], durableBefore.reviewStates[old.id])
        XCTAssertEqual(saved.attempts, durableBefore.attempts)
        XCTAssertEqual(saved.confidenceRecords, durableBefore.confidenceRecords)
        XCTAssertFalse(saved.studyObjects.contains { $0.id == old.id })
        let plan = ShelfStudySessionPlanner().plan(snapshot: saved, topicID: nil, minutes: 5, now: Date())
        XCTAssertFalse(plan.activities.contains { $0.learningObjectID == old.id })
        for activity in plan.activities {
            guard let object = saved.learningObjects.first(where: { $0.id == activity.learningObjectID }) else { continue }
            XCTAssertFalse(object.source.sourceText.contains("Miss ng charact rs"))
        }
    }

    private func wholeSecond(_ date: Date) -> Date {
        Date(timeIntervalSinceReferenceDate: floor(date.timeIntervalSinceReferenceDate))
    }

    func testOldExtractionCannotProduceModelContext() {
        let text = String(repeating: "An intact source sentence. ", count: 5)
        var page = AnalyzedPage(pageIndex: 0, normalizedText: text, segments: [])
        page.canonicalText = text
        var analysis = DocumentAnalysis(documentID: UUID(), fingerprint: "file", algorithmVersion: 2, pages: [page])
        analysis.extractionVersion = 3
        XCTAssertNil(LearningSourcePacket(analysis: analysis, page: page))
        analysis.extractionVersion = SourceExtractionVersion.current
        XCTAssertNotNil(LearningSourcePacket(analysis: analysis, page: page))
    }
}

/// Print every stored field, including nil optionals, and subsecond Date values
/// that XCTest's normal description hides. Pure diagnostics, not equality logic.
enum HistoryFieldDiff {
    static func printPairs(_ label: String, _ before: Any, _ after: Any) {
        let left = fields(before), right = fields(after)
        for field in Set(left.keys).union(right.keys).sorted() {
            let a = left[field] ?? "<missing>", b = right[field] ?? "<missing>"
            print("HISTORY_FIELD \(label).\(field) before=\(a) after=\(b) \(a == b ? "SAME" : "DIFF")")
        }
    }
    private static func fields(_ value: Any, path: String = "") -> [String: String] {
        if let date = value as? Date { return [path: String(format: "%.17f", date.timeIntervalSinceReferenceDate)] }
        if let id = value as? UUID { return [path: id.uuidString] }
        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .optional {
            return mirror.children.first.map { fields($0.value, path: path) } ?? [path: "nil"]
        }
        if mirror.children.isEmpty || mirror.displayStyle == .enum { return [path: String(reflecting: value)] }
        var output: [String: String] = [:]
        for (index, child) in mirror.children.enumerated() {
            let key = child.label ?? "[\(index)]"
            output.merge(fields(child.value, path: path.isEmpty ? key : path + "." + key)) { _, new in new }
        }
        return output
    }
}

/// Mock persistence is reported separately from the real file-store test.
private final class MigrationMemoryStore: LearningSnapshotPersistence, @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()
    func load() throws -> LearningSnapshot {
        lock.lock(); defer { lock.unlock() }
        return data.isEmpty ? LearningSnapshot() : try JSONDecoder().decode(LearningSnapshot.self, from: data)
    }
    func save(_ snapshot: LearningSnapshot) throws {
        lock.lock(); defer { lock.unlock() }
        data = try JSONEncoder().encode(snapshot)
    }
}
