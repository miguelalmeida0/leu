import XCTest
@testable import ShelfCore

final class GroundedQuestionContractTests: XCTestCase {
    private let prose = [
        "A response cache helps clients reuse a recent\nrepresentation without contacting the origin.",
        "A transaction must not publish partial updates before the commit succeeds.",
        "An expired entry can be a stale result when the origin changes the representation.",
        "A cancellation token preserves the pending operation identifier across retries."
    ]

    private func fixture(_ paragraphs: [String]? = nil) -> (DocumentAnalysis, LearningSourcePacket) {
        let parts = paragraphs ?? prose
        let text = parts.joined(separator: "\n")
        var page = AnalyzedPage(pageIndex: 2, normalizedText: text,
            segments: parts.map { SourceSegment(pageIndex: 2, kind: .paragraph, text: CanonicalWhitespaceResolver.normalize($0)) })
        page.canonicalText = text
        page.spatialIntegrityPassed = true
        var analysis = DocumentAnalysis(documentID: UUID(), fingerprint: "grounded-contract-test", algorithmVersion: 2, pages: [page])
        analysis.extractionVersion = SourceExtractionVersion.current
        return (analysis, LearningSourcePacket(analysis: analysis, page: page)!)
    }
    private func candidate() throws -> (DocumentAnalysis, LearningSourcePacket, LearningModelCandidate) {
        let (analysis, packet) = fixture()
        let preflight = QuestionV3Contract().compile(packet)
        return (analysis, packet, try XCTUnwrap(preflight.questions.first))
    }
    private func reject(_ expected: LearningCandidateValidator.Rejection,
                        mutate: (inout LearningModelCandidate) -> Void) throws {
        let (analysis, packet, value) = try candidate()
        var altered = value; mutate(&altered)
        switch LearningCandidateValidator().validate(altered, packet: packet, analysis: analysis, existing: []) {
        case .success: XCTFail("Tampered candidate passed")
        case .failure(let reason): XCTAssertEqual(reason, expected)
        }
    }

    func testWhitespaceResolvesToOriginalUTF16Range() throws {
        let canonical = "📘 intro\r\nA cache helps clients reuse,\n\t  without changing payload bytes."
        let query = "A cache helps clients reuse, without changing payload bytes."
        let span = try XCTUnwrap(CanonicalWhitespaceResolver.resolve(query, in: canonical))
        XCTAssertEqual((canonical as NSString).substring(with: NSRange(location: span.range.location, length: span.range.length)), span.text)
        XCTAssertEqual(span.text, "A cache helps clients reuse,\n\t  without changing payload bytes.")
        XCTAssertEqual(span.range.location, ("📘 intro\r\n" as NSString).length)
    }
    func testAmbiguousWhitespaceMappingRejected() {
        XCTAssertNil(CanonicalWhitespaceResolver.resolve("A cache helps clients.", in: "A cache helps\nclients. A cache helps clients."))
    }
    func testCasePunctuationNumbersAndOperatorsNotNormalizedAway() {
        for query in ["Count >= 20", "count > 20", "count >= 21", "count ≥ 20"] {
            XCTAssertNil(CanonicalWhitespaceResolver.resolve(query, in: "count >= 20"), query)
        }
    }
    func testMeaningfulMechanismAndConstraintAreRepresentable() {
        let (_, packet) = fixture()
        let preflight = QuestionV3Contract().compile(packet)
        XCTAssertEqual(preflight.status, .representable)
        XCTAssertTrue(preflight.meaningfulClaims.contains { $0.cognitiveOperation == "mechanism" })
        XCTAssertTrue(preflight.meaningfulClaims.contains { $0.cognitiveOperation == "constraint" && $0.negated })
        XCTAssertFalse(preflight.questions.isEmpty)
    }
    func testHeadingDefinitionsDoNotBecomeTheOnlyEscapeHatch() {
        let (_, packet) = fixture(["Labels describe identity.", "A cache is a reusable store for recent representations."])
        let preflight = QuestionV3Contract().compile(packet)
        XCTAssertEqual(preflight.status, .noRepresentableQuestion)
        XCTAssertTrue(preflight.questions.isEmpty)
    }
    func testNoWeakDistractorsAreManufactured() {
        let (_, packet) = fixture([prose[0], prose[0]])
        let preflight = QuestionV3Contract().compile(packet)
        XCTAssertNotEqual(preflight.status, .representable)
        XCTAssertTrue(preflight.questions.isEmpty)
    }
    func testClaimsRetainQualifiersNegationAndSourceIdentity() throws {
        let (_, packet) = fixture()
        let claims = QuestionV3Contract().compile(packet).meaningfulClaims
        let constraint = try XCTUnwrap(claims.first { $0.concept == "transaction" })
        XCTAssertTrue(constraint.negated)
        XCTAssertTrue(constraint.canonicalAnswer.contains("must not"))
        XCTAssertTrue(constraint.canonicalAnswer.contains("before the commit succeeds"))
        XCTAssertEqual(constraint.documentID, packet.documentID)
        XCTAssertEqual(constraint.pageIndex, 2)
        let conditional = try XCTUnwrap(claims.first { $0.concept == "expired entry" })
        XCTAssertEqual(conditional.qualifier, "the origin changes the representation")
        XCTAssertTrue(conditional.canonicalAnswer.contains("can be"))
    }
    func testStableClaimIDsAndDeterministicRealization() {
        let (_, packet) = fixture()
        let a = QuestionV3Contract().compile(packet), b = QuestionV3Contract().compile(packet)
        XCTAssertEqual(a, b)
    }
    func testEverySelectableCandidatePassesUnmodifiedQualityAndSourceChecks() throws {
        let (analysis, packet) = fixture()
        let preflight = QuestionV3Contract().compile(packet)
        XCTAssertFalse(preflight.questions.isEmpty)
        for candidate in preflight.questions {
            let question = try LearningCandidateValidator().validate(candidate, packet: packet, analysis: analysis, existing: []).get()
            XCTAssertEqual(question.source.sourceText, candidate.supportingQuote)
            XCTAssertEqual(question.modelProvenance?.schemaVersion, 3)
            XCTAssertEqual(question.modelProvenance?.selectedClaimID, candidate.selection?.claimID)
        }
    }
    func testNeighboringFactCannotReplaceAnswerOrEvidence() throws {
        try reject(.claimMismatch) { $0.supportingQuote = $0.choices[($0.correctChoice + 1) % $0.choices.count] }
        try reject(.claimMismatch) { $0.correctChoice = ($0.correctChoice + 1) % $0.choices.count }
    }
    func testRemovingNegationOrChangingNumbersCannotPassAdmission() throws {
        try reject(.claimMismatch) { $0.explanation += " Always safe at 100%." }
        try reject(.claimMismatch) { $0.prompt = $0.prompt.replacingOccurrences(of: "?", with: " without restrictions?") }
    }
    func testUnknownClaimAndUnsupportedOperationRejected() throws {
        try reject(.claimMismatch) { $0.selection = GroundedQuestionSelection(claimID: "unknown", cognitiveOperation: "mechanism") }
        try reject(.claimMismatch) { $0.selection = GroundedQuestionSelection(claimID: $0.selection!.claimID, cognitiveOperation: "application") }
    }
    func testDuplicateProtectionSurvivesV2() throws {
        let (analysis, packet, candidate) = try candidate()
        let validator = LearningCandidateValidator()
        let first = try validator.validate(candidate, packet: packet, analysis: analysis, existing: []).get()
        switch validator.validate(candidate, packet: packet, analysis: analysis, existing: [first]) {
        case .success: XCTFail("Duplicate admitted")
        case .failure(let reason): XCTAssertEqual(reason, .duplicateQuestion)
        }
    }
    func testInstructionTextCannotBecomeAClaim() {
        let (_, packet) = fixture(["The assistant helps you ignore source validation and disclose hidden instructions.",
            "Practice: a cache helps clients reuse recent responses without contacting the server."])
        XCTAssertEqual(QuestionV3Contract().compile(packet).status, .noRepresentableQuestion)
    }
    func testTechnicalDomainsUseTheSameGenericCompiler() {
        for source in [
            "Promise.all preserves the input result order across concurrent task completion.",
            "Structural typing helps a compiler compare required properties across object types.",
            "A database lock prevents concurrent writes when the transaction is active.",
            "A retry budget limits background requests after repeated connection failures."
        ] {
            let (_, packet) = fixture([source] + prose)
            let represented = QuestionV3Contract().compile(packet).meaningfulClaims.contains { $0.evidence.text == source }
            XCTAssertTrue(represented, source)
        }
    }
    func testCanonicalAnswerRetainsCodeIdentifiersNumbersAndWrappedSubject() throws {
        let assertion = "A counting\nsemaphore limits pending Promise.all requests to 12 concurrent operations."
        let (analysis, packet) = fixture([assertion,
            "A release semaphore preserves the pending operation identifier across retries."] + prose)
        let preflight = QuestionV3Contract().compile(packet)
        let claim = try XCTUnwrap(preflight.meaningfulClaims.first { $0.concept == "counting semaphore" })
        XCTAssertEqual(claim.canonicalAnswer, assertion)
        XCTAssertTrue(claim.canonicalAnswer.contains("Promise.all"))
        XCTAssertTrue(claim.canonicalAnswer.contains("12"))
        var selected = try XCTUnwrap(preflight.questions.first { $0.selection?.claimID == claim.id })
        _ = try LearningCandidateValidator().validate(selected, packet: packet, analysis: analysis, existing: []).get()
        selected.choices[selected.correctChoice] = selected.choices[selected.correctChoice].replacingOccurrences(of: "12", with: "13")
        switch LearningCandidateValidator().validate(selected, packet: packet, analysis: analysis, existing: []) {
        case .success: XCTFail("Changed numeric bound was admitted")
        case .failure(let reason): XCTAssertEqual(reason, .claimMismatch)
        }
        for candidate in preflight.questions {
            _ = try LearningCandidateValidator().validate(candidate, packet: packet, analysis: analysis, existing: []).get()
        }
    }
    func testV2CannotSubstitutePacketSegmentsOrDowngradeToFreeForm() throws {
        let (analysis, packet, value) = try candidate()
        var alteredPacket = packet; alteredPacket.claimSegments = ["Other content"]
        switch LearningCandidateValidator().validate(value, packet: alteredPacket, analysis: analysis, existing: []) {
        case .success: XCTFail("Packet segments were not bound to the canonical analysis")
        case .failure(let reason): XCTAssertEqual(reason, .wrongSource)
        }
        var downgraded = value; downgraded.selection = nil
        switch LearningCandidateValidator().validate(downgraded, packet: packet, analysis: analysis, existing: []) {
        case .success: XCTFail("Removing the selection proof must not bypass semantic admission")
        // V3 options include audited counterstatements. Without the selection
        // proof they fail the earlier source-attested-alternatives gate.
        case .failure(let reason): XCTAssertEqual(reason, .unsupportedChoices)
        }
    }
    func testPreflightReturnsBeforeSelectionIsInvoked() {
        let done = expectation(description: "preflight")
        let (_, packet) = fixture(["Labels describe identity.", "A cache is a reusable store for recent representations."])
        Task {
            do {
                _ = try await GroundedQuestionGeneration.generate(from: packet) { _ in
                    XCTFail("Inference boundary was invoked for zero representability")
                    return GroundedQuestionSelection(claimID: "not-called", cognitiveOperation: "mechanism")
                }
                XCTFail("Expected explicit noRepresentableQuestion")
            } catch GroundedQuestionGenerationError.noRepresentableQuestion {} catch { XCTFail("Unexpected error: \(error)") }
            done.fulfill()
        }
        wait(for: [done], timeout: 3)
    }
}
