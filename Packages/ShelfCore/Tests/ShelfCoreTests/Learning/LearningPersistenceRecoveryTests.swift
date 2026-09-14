import XCTest
@testable import ShelfCore

final class LearningPersistenceRecoveryTests: XCTestCase {
    func testCorruptCurrentRecoversPreviousLearningState() throws {
        let root = temporaryDirectory()
        let store = FileLearningSnapshotStore(root: root)
        let topic = LearningTopic(name: "React")
        try store.save(LearningSnapshot(topics: [topic]))
        try store.save(LearningSnapshot(topics: [topic, LearningTopic(name: "JavaScript")]))

        let current = root.appendingPathComponent("Learning/learning.json")
        try Data("{broken".utf8).write(to: current)
        let recovered = try store.load()
        XCTAssertEqual(recovered.topics, [topic])
    }

    func testBothCorruptLearningCheckpointsResetOnlyLearningIndex() throws {
        let root = temporaryDirectory()
        let directory = root.appendingPathComponent("Learning", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("broken-current".utf8).write(to: directory.appendingPathComponent("learning.json"))
        try Data("broken-previous".utf8).write(to: directory.appendingPathComponent("learning.previous.json"))

        let recovered = try FileLearningSnapshotStore(root: root).load()
        XCTAssertTrue(recovered.learningObjects.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("learning.json").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("learning.previous.json").path))
    }

    func testFutureLearningSchemaIsNotSilentlyDestroyed() throws {
        let root = temporaryDirectory()
        let directory = root.appendingPathComponent("Learning", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(LearningSnapshot(schemaVersion: 99))
        try data.write(to: directory.appendingPathComponent("learning.json"))

        XCTAssertThrowsError(try FileLearningSnapshotStore(root: root).load()) { error in
            guard case ShelfError.unsupportedVersion(99) = error else {
                return XCTFail("Expected unsupported learning schema, got \(error)")
            }
        }
    }

    private func temporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
}
