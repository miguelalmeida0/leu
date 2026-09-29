import XCTest
@testable import ShelfCore

// THROWAWAY — V37 capability spike only (branch `test`, never merged into dev before a pass).

/// The four architecture risks, with synthetic readings (no model): claim families (1), partial
/// entailment (2), reason → conclusion composition (3) and misconception memory (4).
final class ZZSpikeRiskTests: XCTestCase {
    private typealias S = SpikeSynthetic

    private func judge(_ text: String, concept: String, _ labels: [SpikeSegmentLabel], links: [SpikeLink] = [],
                       opinion: SpikeSecondOpinionOutput? = nil, key: SpikeAnswerKey? = nil, _ config: SpikeConfig) throws -> SpikeAdapter.Outcome {
        let item = S.adHoc(text, concept: concept)
        return try S.judge(item, record: S.record(item.id, labels, links: links, opinion: opinion), key: key, config: config).0
    }

    // MARK: - Risk 1: claim families

    /// Every supporting claim of every development target joins a core claim of its own concept.
    func testEverySupportingClaimJoinsACoreClaimOfItsConcept() throws {
        var supporting = 0
        for item in try S.fixture("p-dev").cases {
            let target = try XCTUnwrap(GeneralizationEvaluation.input(for: item)).target
            let families = SpikeClaimFamily.families(target)
            let core = Set(target.rubric.filter { $0.role == .core }.map(\.id))
            for claim in target.supporting {
                supporting += 1
                XCTAssertTrue(core.contains(families[claim.id] ?? ""), "\(item.id): \(claim.id)")
            }
            for id in core { XCTAssertEqual(families[id], id) }
        }
        XCTAssertGreaterThan(supporting, 0)
    }

    /// C3 read against the supporting "retain access" claim is credited as the definition's family:
    /// the same judgement as the definition itself, in every configuration.
    func testSupportingClaimCreditCountsForItsFamily() throws {
        let item = try XCTUnwrap(try S.fixture("canonical").cases.first { $0.id == "C3" })
        for config in SpikeConfig.allCases {
            let viaSupporting = S.record("C3", [S.label(1, S.closureRetain, "entails")], opinion: S.check("correct"))
            let viaDefinition = S.record("C3", [S.label(1, S.closureDefinition, "entails")], opinion: S.check("correct"))
            let a = try S.judge(item, set: "C", record: viaSupporting, config: config).0
            let b = try S.judge(item, set: "C", record: viaDefinition, config: config).0
            XCTAssertEqual(SpikeScore.signature(a.judged), SpikeScore.signature(b.judged), "\(config.rawValue) fired \(a.checked?.fired ?? [])")
            XCTAssertTrue(a.judged.recordsCredit && !a.judged.asksProbe, config.rawValue)
            XCTAssertEqual(a.checked?.segments[0].familyID, S.closureDefinition)
            XCTAssertEqual(a.checked?.segments[0].claimID, S.closureRetain, "the claim named is kept")
        }
    }

    // MARK: - Risk 2: partial entailment

    /// Full, partial-but-meaningful, fragile and insufficient understanding come from family coverage and
    /// whether the essential idea is covered, never from "partially entails" alone.
    func testMasteryFollowsCoverageOfTheEssentialIdea() throws {
        let text = "It checks that the person is really who they claim to be; the system needs that before it grants access."
        let constraint = "claim-508e25d02094b377"
        func state(_ labels: [SpikeSegmentLabel], _ config: SpikeConfig = .b) throws -> String {
            try judge(text, concept: "Authentication", labels, opinion: S.check("correct"), config).judged.state
        }
        XCTAssertEqual(try state([S.label(1, S.authDefinition, "entails"), S.label(2, constraint, "entails")]), "understood")
        XCTAssertEqual(try state([S.label(1, S.authDefinition, "entails"), S.label(2)]), "mostlyUnderstood", "a non-essential idea left out")
        XCTAssertEqual(try state([S.label(1, S.authDefinition, "partiallyEntails"), S.label(2, constraint, "partiallyEntails")]), "fragile",
                       "partial pieces never add up to mastery")
        XCTAssertEqual(try state([S.label(1), S.label(2, constraint, "entails")]), "fragile", "the essential idea is missing")
        XCTAssertEqual(try state([S.label(1), S.label(2)]), "insufficient")
        let partial = try judge(text, concept: "Authentication", [S.label(1, S.authDefinition, "partiallyEntails"), S.label(2)],
                                opinion: S.check("correct"), .d)
        XCTAssertTrue(partial.checked!.fired.contains("V11"))
        XCTAssertTrue(partial.judged.asksProbe)
        XCTAssertFalse(partial.judged.recordsMastery)
    }

    // MARK: - Risk 3: reason → conclusion composition

    func testMarkersFixWhichSegmentIsTheReason() {
        let cases: [(String, [(Int, Int)])] = [
            ("Caches are fast because they keep data in memory.", [(2, 1)]),
            ("Since the data sits in memory, reads are fast.", [(1, 2)]),
            ("The data sits in memory, so reads are fast.", [(1, 2)]),
            ("The data sits in memory so reads are fast.", [(1, 2)]),
            ("The data sits in memory, therefore reads are fast.", [(1, 2)]),
            ("The data sits in memory, therefore means reads are fast.", [(1, 2)]),
            ("The data sits in memory, which means reads are fast.", [(1, 2)]),
            ("The data sits in memory. That's why reads are fast.", [(1, 2)]),
            ("The data sits in memory. As a result, reads are fast.", [(1, 2)]),
            ("The data sits in memory, thus reads are fast.", [(1, 2)]),
            ("The data sits in memory; hence reads are fast.", [(1, 2)]),
            ("The data sits in memory, which stores recent results.", []),
            ("The server works so that clients wait less.", [])
        ]
        for (text, expected) in cases {
            let segments = SpikeSegmenter.segments(text)
            let links = SpikeSegmenter.links(segments, text: text).map { [$0.reason, $0.conclusion] }
            XCTAssertEqual(links, expected.map { [$0.0, $0.1] }, "\(text) → \(segments)")
        }
    }

    /// A true premise used to support a false conclusion earns nothing, whatever marker joins them: the
    /// answer is one wrong idea (committed, or asked as a misconception check), never partial credit.
    func testATruePremiseForAFalseConclusionEarnsNoCredit() throws {
        let key = S.keys["Mobile Mastery|JWT"]
        for marker in [", so", " so", ", therefore", ", which means", ". That's why", ". As a result,", ", thus", "; hence"] {
            let text = "JWTs are signed\(marker) nobody can read them."
            let segments = SpikeSegmenter.segments(text)
            XCTAssertEqual(segments.count, 2, text)
            let labels = [S.label(1, S.jwtDefinition, "entails"), S.label(2, S.jwtNotEncrypted, "contradicts", misconception: "m1")]
            for config in SpikeConfig.allCases {
                let outcome = try judge(text, concept: "JWT", labels, links: [SpikeLink(reason: 1, conclusion: 2)],
                                        opinion: S.check("mistaken", locate: (2, S.jwtNotEncrypted, "wrongIdea")), key: key, config)
                XCTAssertFalse(outcome.judged.recordsCredit, "\(config.rawValue) \(text)")
                XCTAssertFalse(outcome.judged.recordsMastery, "\(config.rawValue) \(text)")
                XCTAssertEqual(outcome.checked?.segments[0].premiseOf, 2, "\(config.rawValue) \(text)")
                let asked = outcome.judged.asksProbe && (outcome.assessment?.judgement.question?.between.contains(.misconception) ?? false)
                XCTAssertTrue(outcome.judged.state == "misconception" || asked, "\(config.rawValue) \(text): \(outcome.judged.state)")
            }
        }
        // "Since" introduces the premise first: the same composition.
        let since = "Since JWTs are signed, nobody can read them."
        let outcome = try judge(since, concept: "JWT", [S.label(1, S.jwtDefinition, "entails"), S.label(2, S.jwtNotEncrypted, "contradicts")],
                                opinion: S.check("mistaken", locate: (2, S.jwtNotEncrypted, "wrongIdea")), key: key, .d)
        XCTAssertFalse(outcome.judged.recordsCredit)
    }

    // MARK: - Risk 4: misconception memory

    /// C5's wrong idea concerns a supporting claim: it is stored against that claim (and its family),
    /// survives a save and a later session, is offered for a transfer test, and is reconfirmed or repaired.
    func testMisconceptionOnASupportingClaimPersistsAcrossSessions() throws {
        let item = try XCTUnwrap(try S.fixture("canonical").cases.first { $0.id == "C5" })
        let input = try XCTUnwrap(GeneralizationEvaluation.input(for: item))
        let key = S.keys["Mobile Mastery|JWT"]
        let (outcome, _) = try S.judge(item, set: "C", record: S.canonicalRecords()["C5"], config: .b)
        XCTAssertEqual(outcome.judged.state, "misconception")
        var memory = SpikeMisconceptionMemory()
        let day1 = Date(timeIntervalSince1970: 1_800_000_000)
        let written = memory.observe(outcome, answerID: "C5", documentID: input.documentID.uuidString, target: input.target, key: key, at: day1)
        XCTAssertEqual(written.count, 1)
        let record = try XCTUnwrap(memory.records.first)
        XCTAssertEqual(record.claimID, S.jwtNotEncrypted)
        XCTAssertEqual(record.claimRole, "supporting")
        XCTAssertEqual(record.familyID, S.jwtDefinition)
        XCTAssertEqual(record.concept, input.target.concept?.value)
        XCTAssertEqual(record.mistakeID, "m1")
        XCTAssertTrue(record.misconception.contains("nobody can read"))
        XCTAssertEqual(record.evidence.first?.learnerText, "so nobody can read them.")
        XCTAssertEqual(record.detectedVersion, SpikeMisconceptionMemory.version)
        XCTAssertEqual(record.repair, .open)
        XCTAssertGreaterThan(record.confidence, 0.5)

        // A later session: load from disk, test the idea in a new context.
        var later = try SpikeMisconceptionMemory.decoded(try memory.encoded())
        XCTAssertEqual(later, memory)
        let targets = later.transferTargets(documentID: record.documentID, concept: record.concept)
        XCTAssertEqual(targets.map(\.claimID), [S.jwtNotEncrypted])
        later.markProbed(record.id)
        XCTAssertEqual(later.records[0].repair, .probed)

        // Held again → reconfirmed and more certain; then stated correctly → repaired.
        let again = try judge("Signed tokens are secret, so a JWT hides its payload.", concept: "JWT",
                              [S.label(1, S.jwtDefinition, "entails"), S.label(2, S.jwtNotEncrypted, "contradicts", misconception: "m1")],
                              links: [SpikeLink(reason: 1, conclusion: 2)], key: key, .b)
        later.observe(again, answerID: "T1", documentID: record.documentID, target: input.target, key: key, at: day1.addingTimeInterval(86_400))
        XCTAssertEqual(later.records[0].reconfirmations.map(\.outcome), [.stillHeld])
        XCTAssertEqual(later.records[0].evidence.count, 2)
        XCTAssertGreaterThan(later.records[0].confidence, record.confidence)
        let fixed = try judge("A JWT is a compact signed token that carries claims as header, payload and signature.", concept: "JWT",
                              [S.label(1, S.jwtDefinition, "entails")], opinion: S.check("correct"), key: key, .d)
        XCTAssertTrue(fixed.judged.recordsCredit)
        later.observe(fixed, answerID: "T2", documentID: record.documentID, target: input.target, key: key, at: day1.addingTimeInterval(172_800))
        XCTAssertEqual(later.records[0].repair, .repaired)
        XCTAssertEqual(later.records[0].reconfirmations.map(\.outcome), [.stillHeld, .corrected])
        XCTAssertTrue(later.transferTargets(documentID: record.documentID, concept: record.concept).isEmpty)
    }

    /// Nothing asked about is stored: a doubtful wrong idea waits for its answer.
    func testADoubtfulMisconceptionIsNotStored() throws {
        let item = try XCTUnwrap(try S.fixture("canonical").cases.first { $0.id == "C5" })
        let input = try XCTUnwrap(GeneralizationEvaluation.input(for: item))
        let doubtful = S.record("C5", [S.label(1, S.jwtDefinition, "entails"), S.label(2, S.jwtNotEncrypted, "contradicts")],
                                links: [SpikeLink(reason: 1, conclusion: 2)], opinion: S.check("mistaken", locate: (0, nil, "none")))
        let (outcome, _) = try S.judge(item, set: "C", record: doubtful, config: .d)
        XCTAssertTrue(outcome.judged.asksProbe)
        var memory = SpikeMisconceptionMemory()
        XCTAssertEqual(memory.observe(outcome, answerID: "C5", documentID: "d", target: input.target, key: nil, at: Date()), [])
    }
}
