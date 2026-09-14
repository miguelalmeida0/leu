import XCTest
import CryptoKit
@testable import ShelfCore

final class V28PersistenceTests: XCTestCase {
    func root() throws -> URL {
        let base = ProcessInfo.processInfo.environment["V28_TEST_ROOT"].map { URL(fileURLWithPath: $0) } ?? FileManager.default.temporaryDirectory
        let root = base.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }; return root
    }
    func path(_ root: URL, _ name: String = "learning.json") -> URL { root.appendingPathComponent("Learning/" + name) }
    func state(_ name: String) -> LearningSnapshot { LearningSnapshot(topics: [.init(name: name)]) }
    func testFirstWriteReloadsExactly() throws {
        let root = try root(), value = state("identity")
        try FileLearningSnapshotStore(root: root).save(value)
        XCTAssertEqual(try FileLearningSnapshotStore(root: root).load(), value)
    }
    func testSecondWriteReplacesCurrentAndRetainsPrevious() throws {
        let root = try root(), a = state("before"), b = state("after"), store = FileLearningSnapshotStore(root: root)
        try store.save(a); let first = try Data(contentsOf: path(root)); try store.save(b)
        XCTAssertEqual(try store.load(), b)
        XCTAssertEqual(try Data(contentsOf: path(root, "learning.previous.json")), first)
    }
    func testReadDoesNotChangeChecksum() throws {
        let root = try root(), store = FileLearningSnapshotStore(root: root)
        try store.save(state("checksum")); let before = SHA256.hash(data: try Data(contentsOf: path(root)))
        _ = try store.load()
        XCTAssertEqual(SHA256.hash(data: try Data(contentsOf: path(root))), before)
    }
    func testInterruptedLegacyNextDoesNotReplaceCommittedState() throws {
        let root = try root(), store = FileLearningSnapshotStore(root: root), value = state("committed")
        try store.save(value); try Data("{partial".utf8).write(to: path(root, "learning.next.json"))
        XCTAssertEqual(try store.load(), value)
    }
    func testInterruptedUniqueStageIsNotPublished() throws {
        let root = try root(), store = FileLearningSnapshotStore(root: root), value = state("committed")
        try store.save(value); try Data("{partial".utf8).write(to: path(root, ".learning-next-interrupted.json"))
        XCTAssertEqual(try store.load(), value)
    }
    func testFirstUncommittedStageDoesNotCreateHistory() throws {
        let root = try root(), store = FileLearningSnapshotStore(root: root)
        _ = try store.load(); try Data("{}".utf8).write(to: path(root, "learning.next.json"))
        XCTAssertEqual(try store.load(), LearningSnapshot())
    }
    func testCorruptionRecoversPreviousWithoutPromotingNext() throws {
        let root = try root(), store = FileLearningSnapshotStore(root: root), first = state("first")
        try store.save(first); try store.save(state("second"))
        try Data("broken".utf8).write(to: path(root)); try Data("{}".utf8).write(to: path(root, "learning.next.json"))
        XCTAssertEqual(try store.load(), first)
    }
    func testMissingCurrentRecoversPrevious() throws {
        let root = try root(), store = FileLearningSnapshotStore(root: root), first = state("first")
        try store.save(first); try store.save(state("second")); try FileManager.default.removeItem(at: path(root))
        XCTAssertEqual(try store.load(), first)
    }
    func testCorruptCurrentCannotOverwriteGoodBackupOnSave() throws {
        let root = try root(), store = FileLearningSnapshotStore(root: root)
        try store.save(state("first")); try store.save(state("second"))
        let backup = try Data(contentsOf: path(root, "learning.previous.json"))
        try Data("broken".utf8).write(to: path(root))
        XCTAssertThrowsError(try store.save(state("third")))
        XCTAssertEqual(try Data(contentsOf: path(root, "learning.previous.json")), backup)
    }
    func testFutureSchemaCannotBeOverwritten() throws {
        let root = try root(), store = FileLearningSnapshotStore(root: root)
        try store.save(LearningSnapshot(schemaVersion: 99)); let bytes = try Data(contentsOf: path(root))
        XCTAssertThrowsError(try store.load()); XCTAssertThrowsError(try store.save(state("replacement")))
        XCTAssertEqual(try Data(contentsOf: path(root)), bytes)
    }
    func testUnicodeAndCodeSurviveRepeatedWrites() throws {
        let root = try root(), store = FileLearningSnapshotStore(root: root)
        let value = state("🧠 Não: Promise.all(x) !== 12; 用户")
        for _ in 0..<3 { try store.save(value); XCTAssertEqual(try store.load(), value) }
    }
    func testFailedBackupReplacementLeavesCurrentUntouched() throws {
        let root = try root(), store = FileLearningSnapshotStore(root: root)
        try store.save(state("first")); let first = try Data(contentsOf: path(root))
        try FileManager.default.createDirectory(at: path(root, "learning.previous.json"), withIntermediateDirectories: true)
        XCTAssertThrowsError(try store.save(state("second")))
        XCTAssertEqual(try Data(contentsOf: path(root)), first)
    }
    func testSuccessfulSaveLeavesNoOwnStagingFiles() throws {
        let root = try root(), store = FileLearningSnapshotStore(root: root)
        try store.save(state("one")); try store.save(state("two"))
        let files = try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("Learning").path)
        XCTAssertEqual(Set(files), ["learning.json", "learning.previous.json"])
    }
    func testRecoveryCanBeSavedAndReloadedAgain() throws {
        let root = try root(), store = FileLearningSnapshotStore(root: root), value = state("durable")
        try store.save(value); try store.save(state("later")); try Data("broken".utf8).write(to: path(root))
        let recovered = try store.load(); try store.save(recovered)
        XCTAssertEqual(try FileLearningSnapshotStore(root: root).load(), value)
    }
    func testLegacySnapshotReceivesEmptyUnderstandingCollections() throws {
        let root = try root(), store = FileLearningSnapshotStore(root: root)
        _ = try store.load(); try Data("{\"schemaVersion\":1}".utf8).write(to: path(root))
        let value = try store.load(); XCTAssertTrue(value.understandingAttempts.isEmpty); XCTAssertTrue(value.understandingEvents.isEmpty)
        try store.save(value); XCTAssertEqual(try store.load(), value)
    }
}
