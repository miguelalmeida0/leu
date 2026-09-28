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

    /// A Leu that cannot read a model keeps it untouched, so changing what is stored without a new
    /// version would silently freeze the model on older installs. This pins what the real snapshot
    /// store writes — every key path with its JSON type, and every stored enum value — to the version.
    func testTheStoredShapeIsPinnedSoAChangeBumpsTheVersion() throws {
        let root = temporaryRoot()
        var snapshot = LearningSnapshot()
        snapshot.learnerModel = canonicalModel
        try FileLearningSnapshotStore(root: root).save(snapshot)
        let file = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("Learning/learning.json")))
        let stored = try XCTUnwrap((file as? [String: Any])?["learnerModel"] as? [String: Any])

        XCTAssertEqual(Set(stored.keys), ["version", "concepts", "misconceptions", "calibration", "recentProbes", "objective",
                                          "appliedEvidence", "evidenceWatermark"])
        XCTAssertNil(stored["appliedEvidenceIDs"], "the pre-release id list is never written")
        let applied = try XCTUnwrap(stored["appliedEvidence"] as? [[String: Any]])
        XCTAssertEqual(applied.map { Set($0.keys) }, [["id", "at"], ["id", "at"]], "each applied evidence is its id and its time")
        XCTAssertEqual(applied.map { $0["id"] as? String }, ["evidence-canonical-1", "evidence-canonical-2"])
        XCTAssertEqual(applied.map { $0["at"] as? String }, [Self.iso(day(1)), Self.iso(day(2))])
        XCTAssertEqual(stored["evidenceWatermark"] as? String, Self.iso(day(0)))
        XCTAssertEqual(stored["version"] as? Int, LearnerModelState.currentVersion)

        let version = LearnerModelState.currentVersion
        let pinned = try XCTUnwrap(Self.pinnedShapes[version], "version \(version) has no pinned shape: pin it before storing it")
        let shape = Self.shape(of: stored)
        XCTAssertEqual(Set(pinned).count, pinned.count)
        XCTAssertEqual(shape, Set(pinned), "stored shape changed without a new version — added: \(shape.subtracting(pinned).sorted()), " +
                       "removed: \(Set(pinned).subtracting(shape).sorted())")
        let reloaded = try FileLearningSnapshotStore(root: root).load().learnerModel
        XCTAssertEqual(reloaded, canonicalModel, "what is stored reads back as the same model")
        XCTAssertTrue(reloaded.isWritable)

        XCTAssertEqual(version, 1)
        XCTAssertEqual(ProbeOperation.allCases.map(\.rawValue), ["define", "recognizeDefinition", "purpose", "mechanism", "condition", "contrast",
                                                                "misconceptionCheck", "recognizeExample", "applyExample", "sourceQuestion"])
        XCTAssertEqual(MisconceptionKind.allCases.map(\.rawValue), ["contradiction", "reversal", "confusion", "overgeneralization"])
        XCTAssertEqual(MisconceptionStatus.allCases.map(\.rawValue), ["active", "resolving", "resolved"])
        XCTAssertEqual(ConfidenceLevel.allCases.map(\.rawValue), ["guessing", "unsure", "fairlySure", "certain"])
        for outcome in [EvidenceOutcome.correct, .partial, .incorrect] { XCTAssertEqual(outcome.rawValue, Self.pinned(outcome)) }
    }

    func testThePreReleaseEvidenceListWasNeverAReleasedSchema() throws {
        // V34 had not shipped when `appliedEvidenceIDs: [String]` became `appliedEvidence` and
        // `evidenceWatermark`, so version 1 as pinned above is the first released shape and no
        // production migration exists. A pre-release file still loads: a version-1 model reads
        // only its own keys, so the old list is ignored and never written back.
        let root = temporaryRoot()
        var snapshot = LearningSnapshot()
        snapshot.learnerModel = canonicalModel
        let store = FileLearningSnapshotStore(root: root)
        try store.save(snapshot)
        let url = root.appendingPathComponent("Learning/learning.json")
        var file = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        var model = try XCTUnwrap(file["learnerModel"] as? [String: Any])
        model.removeValue(forKey: "appliedEvidence")
        model.removeValue(forKey: "evidenceWatermark")
        model["appliedEvidenceIDs"] = ["evidence-pre-release"]
        file["learnerModel"] = model
        try JSONSerialization.data(withJSONObject: file).write(to: url)

        let loaded = try store.load()
        XCTAssertTrue(loaded.learnerModel.isWritable)
        XCTAssertEqual(loaded.learnerModel.concepts, canonicalModel.concepts)
        XCTAssertTrue(loaded.learnerModel.appliedEvidence.isEmpty)
        XCTAssertNil(loaded.learnerModel.evidenceWatermark)
        try store.save(loaded)
        let resaved = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        XCTAssertNil((resaved["learnerModel"] as? [String: Any])?["appliedEvidenceIDs"])
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

    /// The stored learner model of each released version, key path by key path with its JSON type
    /// (arrays as "[]", dates as ISO-8601 strings). A change to what is stored is a new version
    /// with a new entry here; a released entry never changes.
    static let pinnedShapes: [Int: [String]] = [
        1: [
            "version: number",
            "concepts: array",
            "concepts[].concept: object",
            "concepts[].concept.documentID: string",
            "concepts[].concept.concept: object",
            "concepts[].concept.concept.value: string",
            "concepts[].name: string",
            "concepts[].operations: array",
            "concepts[].operations[].operation: string",
            "concepts[].operations[].successWeight: number",
            "concepts[].operations[].failureWeight: number",
            "concepts[].operations[].attempts: number",
            "concepts[].operations[].lastEvidenceAt: string",
            "concepts[].operations[].lastSuccessAt: string",
            "concepts[].operations[].successDays: number",
            "concepts[].confidentErrors: number",
            "concepts[].lastConfidentErrorAt: string",
            "concepts[].firstSeenAt: string",
            "concepts[].lastSeenAt: string",
            "misconceptions: array",
            "misconceptions[].id: string",
            "misconceptions[].concept: object",
            "misconceptions[].concept.documentID: string",
            "misconceptions[].concept.concept: object",
            "misconceptions[].concept.concept.value: string",
            "misconceptions[].kind: string",
            "misconceptions[].claimID: string",
            "misconceptions[].relatedConcept: object",
            "misconceptions[].relatedConcept.value: string",
            "misconceptions[].learnerWording: string",
            "misconceptions[].occurrences: number",
            "misconceptions[].firstSeenAt: string",
            "misconceptions[].lastSeenAt: string",
            "misconceptions[].status: string",
            "misconceptions[].correctionDays: number",
            "misconceptions[].lastCorrectAt: string",
            "calibration: object",
            "calibration.bins: array",
            "calibration.bins[].confidence: string",
            "calibration.bins[].answered: number",
            "calibration.bins[].correct: number",
            "recentProbes: array",
            "recentProbes[].probeID: string",
            "recentProbes[].concept: object",
            "recentProbes[].concept.documentID: string",
            "recentProbes[].concept.concept: object",
            "recentProbes[].concept.concept.value: string",
            "recentProbes[].operation: string",
            "recentProbes[].askedAt: string",
            "recentProbes[].outcome: string",
            "objective: object",
            "objective.objective: object",
            "objective.objective.documentID: string",
            "objective.objective.concept: object",
            "objective.objective.concept.value: string",
            "objective.prerequisite: object",
            "objective.prerequisite.documentID: string",
            "objective.prerequisite.concept: object",
            "objective.prerequisite.concept.value: string",
            "objective.startedAt: string",
            "objective.detourAttempts: number",
            "appliedEvidence: array",
            "appliedEvidence[].id: string",
            "appliedEvidence[].at: string",
            "evidenceWatermark: string",
        ],
    ]

    /// One of everything the learner model stores, with every optional filled in.
    var canonicalModel: LearnerModelState {
        var calibration = CalibrationProfile()
        calibration.record(.certain, correct: false)
        calibration.record(.fairlySure, correct: true)
        var model = LearnerModelState(
            concepts: [ConceptMastery(concept: cache, name: "Cache",
                operations: [OperationMastery(operation: .define, successWeight: 1.5, failureWeight: 0.5, attempts: 2,
                                              lastEvidenceAt: day(2), lastSuccessAt: day(2), successDays: 2)],
                confidentErrors: 1, lastConfidentErrorAt: day(1), firstSeenAt: day(0), lastSeenAt: day(2))],
            misconceptions: [MisconceptionRecord(id: "misconception-canonical", concept: cache, kind: .confusion, claimID: "claim-canonical",
                relatedConcept: ConceptKey("Database index"), learnerWording: "A cache is an index", occurrences: 2,
                firstSeenAt: day(1), lastSeenAt: day(1), status: .resolving, correctionDays: 1, lastCorrectAt: day(2))],
            calibration: calibration,
            recentProbes: [ProbeRecord(probeID: "probe-canonical", concept: cache, operation: .contrast, askedAt: day(2), outcome: .correct)],
            objective: RemediationObjective(objective: cache, prerequisite: index, startedAt: day(1), detourAttempts: 1))
        model.appliedEvidence = [AppliedEvidence(id: "evidence-canonical-1", at: day(1)), AppliedEvidence(id: "evidence-canonical-2", at: day(2))]
        model.evidenceWatermark = day(0)
        return model
    }

    /// Every key path of a stored JSON value with the JSON type found there: its shape, not its values.
    private static func shape(of value: Any, at path: String = "") -> Set<String> {
        var entries: Set<String> = []
        if let object = value as? [String: Any] {
            for (key, child) in object {
                let childPath = path.isEmpty ? key : path + "." + key
                entries.insert(childPath + ": " + jsonType(child))
                entries.formUnion(shape(of: child, at: childPath))
            }
        } else if let array = value as? [Any] {
            for child in array {
                if child is [String: Any] || child is [Any] { entries.formUnion(shape(of: child, at: path + "[]")) }
                else { entries.insert(path + "[]: " + jsonType(child)) }
            }
        }
        return entries
    }

    private static func jsonType(_ value: Any) -> String {
        switch value {
        case is NSNull: return "null"
        case is String: return "string"
        case is [String: Any]: return "object"
        case is [Any]: return "array"
        default: return "number"
        }
    }

    /// Exhaustive on purpose: a new stored outcome stops this file compiling until it is pinned.
    private static func pinned(_ outcome: EvidenceOutcome) -> String {
        switch outcome {
        case .correct: return "correct"
        case .partial: return "partial"
        case .incorrect: return "incorrect"
        }
    }

    /// The store writes dates as ISO-8601.
    private static func iso(_ date: Date) -> String { ISO8601DateFormatter().string(from: date) }

    private func temporaryRoot() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
}
