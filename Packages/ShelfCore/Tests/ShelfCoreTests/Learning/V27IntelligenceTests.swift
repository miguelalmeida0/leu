import XCTest
@testable import ShelfCore

final class V27IntelligenceTests: XCTestCase {
    let react = [
        "A stable key helps React match an item to its previous instance within a list of siblings.",
        "Reordering should not make one item inherit the local state of another.",
        "An array index can be a poor key when items move, are inserted or removed.",
        "A freshly generated random key also destroys continuity between renders."
    ]
    func fixture(_ parts: [String], verified: Bool? = true, version: Int = SourceExtractionVersion.current,
                 id: UUID = UUID()) -> DocumentAnalysis {
        let text = parts.joined(separator: "\n")
        var page = AnalyzedPage(pageIndex: 2, normalizedText: text,
            segments: parts.map { SourceSegment(pageIndex: 2, kind: .paragraph, text: $0) })
        page.canonicalText = text; page.spatialIntegrityPassed = verified
        var analysis = DocumentAnalysis(documentID: id, fingerprint: String(StableIdentity.hash64(text)), algorithmVersion: 2, pages: [page])
        analysis.extractionVersion = version
        return analysis
    }
    func source(_ analysis: DocumentAnalysis) throws -> IntelligenceSource {
        try XCTUnwrap(IntelligenceSource(source: LearningSource(documentID: analysis.documentID, pageIndex: 2,
            sourceText: analysis.pages[0].canonicalText!), analysis: analysis))
    }
    func testFortyEightTechnicalSourceCasesRetainCanonicalClaimsAndIndependentlyAdmit() throws {
        let subjects = ["A transaction", "A response cache", "A counting semaphore", "A retry budget",
            "A cancellation token", "A database lock", "A release marker", "A worker queue"]
        let relations = ["preserves the pending operation identifier across retries",
            "limits pending Promise.all requests to 12 concurrent operations",
            "helps clients reuse a recent representation without contacting the origin",
            "prevents concurrent writes when the transaction is active",
            "must not publish partial updates before the commit succeeds",
            "can be a stale result when the origin changes the representation"]
        var cases = 0
        for subject in subjects { for relation in relations {
            let statement = subject + " " + relation + "."
            let analysis = fixture([statement] + react)
            let packet = try XCTUnwrap(LearningSourcePacket(analysis: analysis, page: analysis.pages[0]))
            let result = QuestionV3Contract().compile(packet)
            XCTAssertTrue(result.meaningfulClaims.contains { $0.evidence.text == statement }, statement)
            XCTAssertFalse(result.questions.isEmpty, statement)
            for candidate in result.questions {
                XCTAssertNil(QuestionV3Validator.surfaceFailure(candidate), candidate.prompt)
                XCTAssertTrue(QuestionV3Validator.accepts(candidate, packet: packet))
                let accepted = try LearningCandidateValidator().validate(candidate, packet: packet, analysis: analysis, existing: []).get()
                XCTAssertTrue(analysis.pages[0].canonicalText!.contains(accepted.source.sourceText))
                XCTAssertEqual(accepted.modelProvenance?.schemaVersion, 3)
            }
            cases += 1
        } }
        XCTAssertEqual(cases, 48)
    }
    func testNoHeadingsMnemonicInstructionsOrCodeAsClaims() throws {
        for excluded in ["MAKE IT STICK: a stable key helps React preserve an item in a list.",
            "IN ONE BREATH: a stable key helps React preserve an item in a list.",
            "Practice: a stable key helps React preserve an item in a list.",
            "Explain why a stable key helps React preserve an item in a list.",
            "Chapter 3 — Keys describe identity", "items.map(item => <Row key={item.id} />)"] {
            let analysis = fixture([excluded] + react)
            let packet = try XCTUnwrap(LearningSourcePacket(analysis: analysis, page: analysis.pages[0]))
            XCTAssertFalse(QuestionV3Contract().compile(packet).questions.contains { $0.supportingQuote.contains(excluded) }, excluded)
        }
    }
    func testIndependentAdmissionRejectsChangedQualifierNumberNegationAndIdentifier() throws {
        let analysis = fixture(["A counting semaphore limits pending Promise.all requests to 12 concurrent operations."] + react)
        let packet = try XCTUnwrap(LearningSourcePacket(analysis: analysis, page: analysis.pages[0]))
        let original = try XCTUnwrap(QuestionV3Contract().compile(packet).questions.first)
        for extra in [" Always.", " Never.", " 13 operations.", " Promise.any."] {
            var changed = original; changed.choices[changed.correctChoice] += extra
            XCTAssertFalse(QuestionV3Validator.accepts(changed, packet: packet))
            XCTAssertThrowsError(try LearningCandidateValidator().validate(changed, packet: packet, analysis: analysis, existing: []).get())
        }
    }
    func testMalformedGenericAndUnbalancedOptionsAreRejected() throws {
        let analysis = fixture(react), packet = try source(analysis).packet
        let valid = try XCTUnwrap(QuestionV3Contract().compile(packet).questions.first)
        for stem in ["What is a stable key?", "What does a stable key do?", "Which statement is true?", "What does A key helps React do?", "Why? Why?"] {
            var changed = valid; changed.prompt = stem
            XCTAssertNotNil(QuestionV3Validator.surfaceFailure(changed), stem)
        }
        var long = valid; long.choices[0] = String(repeating: "oversized choice ", count: 50)
        XCTAssertNotNil(QuestionV3Validator.surfaceFailure(long))
        var duplicate = valid; duplicate.choices[0] = duplicate.choices[1]
        XCTAssertNotNil(QuestionV3Validator.surfaceFailure(duplicate))
    }
    func testReactMechanismHasDeterminerAndDeterministicProvenanceDoesNotClaimInference() throws {
        let analysis = fixture(react), packet = try source(analysis).packet
        let mechanism = try XCTUnwrap(QuestionV3Contract().compile(packet).questions.first { $0.skill == "mechanism" })
        XCTAssertEqual(mechanism.prompt, "Which effect explains the role of a stable key?")
        XCTAssertNil(QuestionV3Validator.surfaceFailure(mechanism))
        let accepted = try LearningCandidateValidator().validate(mechanism, packet: packet, analysis: analysis,
            existing: [], backend: "deterministic-v3").get()
        XCTAssertEqual(accepted.modelProvenance?.modelInferencePerformed, false)
        XCTAssertEqual(accepted.modelProvenance?.availability, .available) // named deterministic backend
        XCTAssertFalse(accepted.modelProvenance!.generationConfiguration.contains("greedy"))
        XCTAssertFalse(accepted.stableKey.contains("apple-on-device"))
        var missing = mechanism; missing.prompt = "Which effect explains the role of stable key?"
        XCTAssertEqual(QuestionV3Validator.surfaceFailure(missing), "missing_subject_article")
    }
    func testDegradedAndUnknownIntegrityContributeZeroCapabilities() throws {
        for verified: Bool? in [false, nil] {
            let analysis = fixture(react, verified: verified)
            XCTAssertNil(IntelligenceSource(source: LearningSource(documentID: analysis.documentID, pageIndex: 2,
                sourceText: analysis.pages[0].canonicalText!), analysis: analysis))
            if let packet = LearningSourcePacket(analysis: analysis, page: analysis.pages[0]) {
                XCTAssertTrue(QuestionV3Contract().compile(packet).questions.isEmpty)
            }
            XCTAssertTrue(GroundedConnectionIndex(analyses: [analysis.documentID: analysis]).connections(from: try source(fixture(react))).isEmpty)
        }
    }
    func testTeachCorrectPartialConflictingAndUnsettled() throws {
        let citation = try source(fixture(react))
        let exact = TeachLeuValidator.evaluate(react[0], source: citation)
        XCTAssertEqual(exact.supported.count, 1); XCTAssertTrue(exact.supported[0].complete)
        let partial = TeachLeuValidator.evaluate("Keys tell React which item is which when a list changes.", source: citation)
        XCTAssertEqual(partial.supported.count, 1); XCTAssertFalse(partial.supported[0].complete)
        XCTAssertFalse(partial.omitted.isEmpty)
        let conflict = TeachLeuValidator.evaluate(react[1].replacingOccurrences(of: " not ", with: " "), source: citation)
        XCTAssertEqual(conflict.challenged.count, 1)
        for claim in ["Keys encrypt all private documents.", "React is always faster than every other framework.",
            "Keys tell React which item is which when a list changes, and random keys are always safe."] {
            let result = TeachLeuValidator.evaluate(claim, source: citation)
            XCTAssertTrue(result.supported.isEmpty); XCTAssertEqual(result.unsettled, [claim])
        }
    }
    func testModelSuggestionCannotProveInventedLearnerClaim() throws {
        let analysis = fixture(react), citation = try source(analysis)
        let result = TeachLeuValidator.evaluate("Keys encrypt files.", source: citation,
            proposals: [.init(learnerClaimID: "learner-0", sourceClaimID: citation.claims[0].id)])
        XCTAssertTrue(result.supported.isEmpty); XCTAssertTrue(result.challenged.isEmpty)
        XCTAssertTrue(TeachLeuValidator.isValid(result, explanation: "Keys encrypt files.", analyses: [analysis.documentID: analysis]))
    }
    func testPersistedV3QuestionIsIndependentlyReadmitted() throws {
        let analysis = fixture(react), packet = try source(analysis).packet
        let candidate = try XCTUnwrap(QuestionV3Contract().compile(packet).questions.first)
        let question = try LearningCandidateValidator().validate(candidate, packet: packet, analysis: analysis,
            existing: [], backend: "deterministic-v3").get()
        XCTAssertNil(FinalMCQAdmission.rejectionReason(question, analysis: analysis))
        var altered = question; altered.prompt = "Which statement is true about every programming language?"
        XCTAssertEqual(FinalMCQAdmission.rejectionReason(altered, analysis: analysis), "v3_persisted_contract_mismatch")
        altered = question; altered.source.range = SourceTextRange(location: 0, length: 80)
        XCTAssertEqual(FinalMCQAdmission.rejectionReason(altered, analysis: analysis), "v3_persisted_contract_mismatch")
        var forgedPacket = packet; forgedPacket.sourceIntegrityPassed = true
        var degraded = analysis; degraded.pages[0].spatialIntegrityPassed = nil
        XCTAssertThrowsError(try LearningCandidateValidator().validate(candidate, packet: forgedPacket,
            analysis: degraded, existing: []).get())
    }
    func testConnectionsRequireExplicitRelationInBothSources() throws {
        let a = fixture(["A database lock prevents concurrent writes when the transaction is active."] + react)
        let b = fixture(["A table lock prevents concurrent writes when the transaction is active."] + react.prefix(2))
        let current = try source(a), connected = try source(b)
        let matches = GroundedConnectionIndex(analyses: [a.documentID: a, b.documentID: b]).connections(from: current)
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches.first?.current.packet.documentID, a.documentID)
        XCTAssertEqual(matches.first?.connected.packet.documentID, b.documentID)
        XCTAssertTrue(matches.allSatisfy { ConnectionValidator.admits($0.currentClaim, $0.connectedClaim, current: current, connected: connected) })
        let unrelated = fixture(["A database lock preserves the transaction identifier across retries."] + react.prefix(1))
        XCTAssertTrue(GroundedConnectionIndex(analyses: [unrelated.documentID: unrelated]).connections(from: current).isEmpty)
        let duplicate = fixture(a.pages[0].segments.map(\.text))
        XCTAssertTrue(GroundedConnectionIndex(analyses: [duplicate.documentID: duplicate]).connections(from: current).isEmpty)
    }
    func testStableKeysActivityIdentityAndProgressAreDeterministic() throws {
        let analysis = fixture(react), definition = try XCTUnwrap(ActivityValidator.definition(for: source(analysis)))
        XCTAssertEqual(definition.contract, .stableKeys)
        var stable = ActivityState(); try stable.apply(.reorder, definition: definition)
        XCTAssertEqual(stable.order, ["C", "A", "B"]); XCTAssertEqual(stable.rowState, [0, 7, 0])
        var positional = ActivityState(); try positional.apply(.chooseKeys(.positions), definition: definition)
        try positional.apply(.reorder, definition: definition)
        XCTAssertEqual(positional.order, stable.order); XCTAssertEqual(positional.rowState, [7, 0, 0])
        XCTAssertThrowsError(try positional.apply(.edit("unknown"), definition: definition))
        XCTAssertThrowsError(try positional.apply(.reuse, definition: definition))
        XCTAssertTrue(ActivityValidator.accepts(definition, analyses: [analysis.documentID: analysis]))
    }
    func testCacheLabUsesActualCacheClaimWithoutHTTPAssumptions() throws {
        let analysis = fixture(["A cache avoids repeating work, but introduces a second representation that can become stale.",
            "PDF thumbnails are derived data. Original documents and private annotations are not disposable caches."])
        let definition = try XCTUnwrap(ActivityValidator.definition(for: source(analysis)))
        XCTAssertEqual(definition.contract, .cachedCopy)
        var state = ActivityState()
        try state.apply(.reuse, definition: definition); XCTAssertEqual(state.cached, 1); XCTAssertEqual(state.computations, 1)
        try state.apply(.changeOriginal, definition: definition); try state.apply(.reuse, definition: definition)
        XCTAssertEqual(state.cached, 1); XCTAssertEqual(state.original, 2); XCTAssertEqual(state.computations, 1)
        try state.apply(.recompute, definition: definition); XCTAssertEqual(state.cached, 2); XCTAssertEqual(state.computations, 2)
        XCTAssertThrowsError(try state.apply(.reorder, definition: definition))
        XCTAssertNil(ActivityValidator.definition(for: try source(fixture([react[0], react[3]]))))
    }
    func testUnderstandingMemoryRoundTripAndSourceRebind() throws {
        let analysis = fixture(react), citation = try source(analysis)
        var attempt = UnderstandingAttempt(source: citation, learnerExplanation: react[0], createdAt: Date(timeIntervalSince1970: 1_700_000_000))
        attempt.result = TeachLeuValidator.evaluate(react[0], source: citation)
        var snapshot = LearningSnapshot(); snapshot.analyses[analysis.documentID] = analysis
        snapshot.understandingAttempts = [attempt]
        snapshot.understandingEvents = [.init(kind: .taughtConcept, source: citation, occurredAt: attempt.createdAt)]
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let restored = try decoder.decode(LearningSnapshot.self, from: encoder.encode(snapshot))
        XCTAssertEqual(restored.understandingAttempts, [attempt]); XCTAssertEqual(restored.understandingEvents, snapshot.understandingEvents)
        XCTAssertEqual(UnderstandingTimeline.thought(documentID: analysis.documentID, attempts: restored.understandingAttempts, analyses: restored.analyses), attempt)
        let changed = fixture(react + ["A retry budget limits repeated operations after the deadline."], id: analysis.documentID)
        XCTAssertFalse(citation.isCurrent(in: [changed.documentID: changed]))
        XCTAssertNil(UnderstandingTimeline.thought(documentID: analysis.documentID, attempts: restored.understandingAttempts, analyses: [changed.documentID: changed]))
        XCTAssertEqual(restored.understandingAttempts[0].learnerExplanation, react[0])
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: encoder.encode(snapshot)) as? [String: Any])
        legacy.removeValue(forKey: "understandingAttempts"); legacy.removeValue(forKey: "understandingEvents")
        let migrated = try decoder.decode(LearningSnapshot.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertTrue(migrated.understandingAttempts.isEmpty); XCTAssertTrue(migrated.understandingEvents.isEmpty)
    }
    func testActualRepositoryPersistsThoughtAndRejectsStaleWriteWithoutLosingHistory() async throws {
        let base = ProcessInfo.processInfo.environment["V27_TEST_ROOT"].map { URL(fileURLWithPath: $0) } ?? FileManager.default.temporaryDirectory
        let root = base.appendingPathComponent("v27-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = FileLearningSnapshotStore(root: root), repository = LearningRepository(persistence: store)
        let analysis = fixture(react), citation = try source(analysis)
        try await repository.upsertAnalysis(analysis, topics: [], questions: [])
        var attempt = UnderstandingAttempt(source: citation, learnerExplanation: react[0], createdAt: Date(timeIntervalSince1970: 1_700_000_000))
        attempt.result = TeachLeuValidator.evaluate(react[0], source: citation)
        try await repository.storeUnderstandingAttempt(attempt)
        try await repository.storeUnderstandingEvent(.init(kind: .taughtConcept, source: citation, occurredAt: attempt.createdAt))
        let reopened = try await LearningRepository(persistence: store).open()
        XCTAssertEqual(reopened.understandingAttempts, [attempt]); XCTAssertEqual(reopened.understandingEvents.count, 1)
        var changed = analysis; changed.extractionVersion = SourceExtractionVersion.current - 1
        try await repository.upsertAnalysis(changed, topics: [], questions: [])
        do { try await repository.storeUnderstandingAttempt(attempt); XCTFail("Stale result persisted") }
        catch LearningIntelligenceError.sourceIntegrityFailed {} catch { XCTFail("Unexpected error: \(error)") }
        let migrated = try await LearningRepository(persistence: store).open()
        XCTAssertEqual(migrated.understandingAttempts, [attempt]); XCTAssertEqual(migrated.understandingEvents.count, 1)
        XCTAssertNil(UnderstandingTimeline.thought(documentID: analysis.documentID, attempts: migrated.understandingAttempts, analyses: migrated.analyses))
    }
}
