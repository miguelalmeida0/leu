import XCTest
@testable import ShelfCore

/// Storing the learner model: legacy, unreadable and future models, and the pinned shape.
extension LearnerModelTests {
    func testLegacySnapshotsDecodeWithAnEmptyLearnerModel() throws {
        let legacy = try JSONEncoder().encode(LearningSnapshot())
        var object = try JSONSerialization.jsonObject(with: legacy) as! [String: Any]
        object.removeValue(forKey: "learnerModel")
        let decoded = try JSONDecoder().decode(LearningSnapshot.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertTrue(decoded.learnerModel.isEmpty)
    }

    func testACorruptLearnerModelNeverMakesTheSnapshotUnreadable() throws {
        var snapshot = LearningSnapshot(lensUsage: ["kept": 3])
        snapshot.learnerModel = model([evidence(.correct, at: day(0))])
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as! [String: Any]
        object["learnerModel"] = ["version": 1, "concepts": "not a list"]
        let decoded = try JSONDecoder().decode(LearningSnapshot.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(decoded.lensUsage, ["kept": 3])
        XCTAssertTrue(decoded.learnerModel.isEmpty)
        XCTAssertFalse(decoded.learnerModel.isWritable, "what cannot be read cannot be rebuilt either: it is kept, not replaced")
        let saved = try JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded)) as! [String: Any]
        XCTAssertEqual(saved["learnerModel"] as? NSDictionary, ["version": 1, "concepts": "not a list"] as NSDictionary)
    }

    func testAnyUnreadableLearnerModelSurvivesLoadAndSaveVerbatim() throws {
        let base = try JSONSerialization.jsonObject(with: JSONEncoder().encode(LearningSnapshot(lensUsage: ["kept": 3]))) as! [String: Any]
        let unreadable: [(String, Any)] = [
            ("malformed field", ["version": 1, "concepts": "not a list"]),
            ("malformed version", ["version": "one", "concepts": []]),
            ("future version", ["version": 7, "concepts": [["shape": "unknown"]], "futureField": ["nested": [1, 2.5]]]),
            ("string", "corrupt"),
            ("array", [1, 2, 3]),
            ("number", 42),
        ]
        for (label, value) in unreadable {
            var object = base
            object["learnerModel"] = value
            let decoded = try JSONDecoder().decode(LearningSnapshot.self, from: JSONSerialization.data(withJSONObject: object))
            XCTAssertEqual(decoded.lensUsage, ["kept": 3], label)
            XCTAssertFalse(decoded.learnerModel.isWritable, "\(label): kept, never replaced by a writable empty model")
            var model = decoded.learnerModel
            XCTAssertFalse(LearnerModelReducer().apply(evidence(.correct, at: day(0)), to: &model), label)
            let saved = try JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded)) as! [String: Any]
            XCTAssertEqual(saved["learnerModel"].map { [$0] as NSArray }, [value] as NSArray, "\(label) survives the save verbatim")
        }
        for (label, legacy) in [("missing", nil), ("null", NSNull())] as [(String, Any?)] {
            var object = base
            object["learnerModel"] = legacy
            let decoded = try JSONDecoder().decode(LearningSnapshot.self, from: JSONSerialization.data(withJSONObject: object))
            XCTAssertTrue(decoded.learnerModel.isEmpty, label)
            XCTAssertTrue(decoded.learnerModel.isWritable, "\(label): a legacy snapshot starts an empty, writable model")
            var model = decoded.learnerModel
            XCTAssertTrue(LearnerModelReducer().apply(evidence(.correct, at: day(0)), to: &model), label)
        }
    }

    func testTheStoredShapeIsPinnedSoAChangeBumpsTheVersion() {
        // A Leu that cannot read a model keeps it untouched. Changing a stored case without a new
        // version would silently freeze the model on older installs: change these together.
        XCTAssertEqual(LearnerModelState.currentVersion, 1)
        XCTAssertEqual(ProbeOperation.allCases.map(\.rawValue), ["define", "recognizeDefinition", "purpose", "mechanism", "condition", "contrast",
                                                                "misconceptionCheck", "recognizeExample", "applyExample", "sourceQuestion"])
        XCTAssertEqual(MisconceptionKind.allCases.map(\.rawValue), ["contradiction", "reversal", "confusion", "overgeneralization"])
        XCTAssertEqual(MisconceptionStatus.allCases.map(\.rawValue), ["active", "resolving", "resolved"])
        XCTAssertEqual(ConfidenceLevel.allCases.map(\.rawValue), ["guessing", "unsure", "fairlySure", "certain"])
    }

    func testAFutureLearnerModelIsPreservedAndNeverRewritten() throws {
        let future = #"{"version": 7, "concepts": [{"shape": "unknown"}], "futureField": {"nested": [1, 2.5, true, null, "x"]}}"#
        var state = try JSONDecoder().decode(LearnerModelState.self, from: Data(future.utf8))
        XCTAssertFalse(state.isWritable)
        XCTAssertFalse(LearnerModelReducer().apply(evidence(.correct, at: day(0)), to: &state))
        let reencoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as! NSDictionary
        let original = try JSONSerialization.jsonObject(with: Data(future.utf8)) as! NSDictionary
        XCTAssertEqual(reencoded, original)
    }
}
