import XCTest
@testable import ShelfCore

final class EmotionalV24Tests: XCTestCase {
    func testOldConfidenceValuesMigrateToFourLevelModel() throws {
        let decoder = JSONDecoder()
        XCTAssertEqual(try decoder.decode(ConfidenceLevel.self, from: Data(#""low""#.utf8)), .guessing)
        XCTAssertEqual(try decoder.decode(ConfidenceLevel.self, from: Data(#""medium""#.utf8)), .fairlySure)
        XCTAssertEqual(try decoder.decode(ConfidenceLevel.self, from: Data(#""high""#.utf8)), .certain)
    }

    func testOldSnapshotDecodesWithV24Defaults() throws {
        let data = Data(#"{"schemaVersion":1,"analyses":[],"topics":[],"manualDocumentTopics":[],"learningObjects":[],"questions":[],"reviewStates":[],"attempts":[],"relationships":[],"trails":[],"masks":[],"recordings":[],"sessions":[],"timeline":[]}"#.utf8)
        let snapshot = try JSONDecoder().decode(LearningSnapshot.self, from: data)
        XCTAssertTrue(snapshot.semanticIndexes.isEmpty)
        XCTAssertTrue(snapshot.emotionalCheckIns.isEmpty)
        XCTAssertEqual(snapshot.emotionalCheckInPreference, .on)
    }

    func testEmotionalPolicyRespectsOffAndCooldown() {
        let id = UUID()
        let attempts = (0..<6).map { _ in LearningAttempt(learningObjectID: id, rating: .difficult, wasCorrect: false, confidence: .unsure) }
        let policy = EmotionalCheckInPolicy()
        XCTAssertFalse(policy.shouldOffer(preference: .off, attempts: attempts, lastCheckIn: nil))
        XCTAssertFalse(policy.shouldOffer(preference: .on, attempts: attempts, lastCheckIn: Date()))
        XCTAssertTrue(policy.shouldOffer(preference: .on, attempts: attempts, lastCheckIn: nil))
    }

    func testConfidentMissMakesCheckInEligibleWithoutInferringEmotion() {
        let id = UUID()
        let attempts = [
            LearningAttempt(learningObjectID: id, rating: .forgot, wasCorrect: false, confidence: .certain),
            LearningAttempt(learningObjectID: id, rating: .difficult, wasCorrect: true, confidence: .unsure),
            LearningAttempt(learningObjectID: id, rating: .difficult, wasCorrect: true, confidence: .fairlySure)
        ]
        XCTAssertTrue(EmotionalCheckInPolicy().shouldOffer(preference: .on, attempts: attempts, lastCheckIn: nil))
    }

    func testResumeContextPersistsAcrossRepositoryReopen() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let sessionID = UUID()
        let first = LearningRepository(persistence: FileLearningSnapshotStore(root: root))
        _ = try await first.open()
        try await first.saveResumeStudyContext(ResumeStudyContext(sessionID: sessionID, activityIndex: 3))
        let second = LearningRepository(persistence: FileLearningSnapshotStore(root: root))
        let restored = try await second.open()
        XCTAssertEqual(restored.resumeStudyContext?.sessionID, sessionID)
        XCTAssertEqual(restored.resumeStudyContext?.activityIndex, 3)
    }

    func testEmotionalHistoryIsLocalAndDeletableThroughRepository() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let repo = LearningRepository(persistence: FileLearningSnapshotStore(root: root))
        _ = try await repo.open()
        try await repo.recordEmotionalCheckIn(EmotionalCheckIn(feeling: .irritated))
        let recorded = try await repo.snapshot()
        XCTAssertEqual(recorded.emotionalCheckIns.count, 1)
        try await repo.deleteEmotionalCheckIns()
        let deleted = try await repo.snapshot()
        XCTAssertTrue(deleted.emotionalCheckIns.isEmpty)
    }

}
