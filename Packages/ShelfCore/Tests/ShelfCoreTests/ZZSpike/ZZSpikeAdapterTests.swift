import XCTest
@testable import ShelfCore

// THROWAWAY — V37 capability spike only (branch `claude/v37-capability-spike`, never merged).

/// The harness on Linux, with synthetic readings only: the canonical criteria, each check, the
/// second-opinion rules, the Tier 0 fallbacks, the baselines and the scorer end to end.
final class ZZSpikeAdapterTests: XCTestCase {
    private typealias S = SpikeSynthetic

    private func canonical() throws -> (GeneralizationEvaluation.Fixture, SpikeCanonical.File) {
        let url = S.repository.appendingPathComponent("spikes/v37/cases/canonical.json")
        return (try S.fixture("canonical"), try JSONDecoder().decode(SpikeCanonical.File.self, from: Data(contentsOf: url)))
    }

    private func check(_ id: String, _ record: SpikeRecord, _ config: SpikeConfig) throws -> (SpikeAdapter.Outcome, [String]) {
        let (fixture, file) = try canonical()
        let item = try XCTUnwrap(fixture.cases.first { $0.id == id })
        let (outcome, spike) = try S.judge(item, set: "C", record: record, config: config)
        let criteria = try XCTUnwrap(file.cases.first { $0.id == id }?.passCriteria)
        return (outcome, SpikeCanonical.check(criteria, config: config, outcome: outcome, record: record, key: S.keys[spike.targetKey], spike: spike))
    }

    /// C1–C5 read the way a careful reader would: every configuration meets every §3.2 criterion.
    func testCanonicalCasesPassWithCarefulReadings() throws {
        for (id, record) in S.canonicalRecords().sorted(by: { $0.key < $1.key }) {
            for config in SpikeConfig.allCases {
                let (outcome, failed) = try check(id, record, config)
                XCTAssertEqual(failed, [], "\(config.rawValue) \(id): \(outcome.judged.state) asks=\(outcome.judged.asksProbe)")
                XCTAssertEqual(outcome.fallback, .none)
            }
        }
    }

    /// Careless readings fail the criteria they should.
    func testCanonicalCheckerRejectsWrongReadings() throws {
        let credited = S.record("C2", [S.label(1, S.authDefinition, "entails")], opinion: S.opinion([("credit", 1, "same")]))
        XCTAssertTrue(try check("C2", credited, .b).1.contains("reading"))
        let copyingAgreed = S.record("C4", [S.label(1, S.closureDefinition, "entails"), S.label(2, S.closureRetain, "contradicts", role: "reason", misconception: "m1")],
                                     links: [SpikeLink(reason: 2, conclusion: 1)],
                                     opinion: S.opinion([("credit", 1, "same"), ("contradiction", 2, "opposite"), ("reason", 2, "same")]))
        XCTAssertTrue(try check("C4", copyingAgreed, .d).1.contains("secondOpinion"))
        let unlinked = S.record("C4", [S.label(1, S.closureDefinition, "entails"), S.label(2, "none", "unrelated", role: "reason")])
        XCTAssertTrue(try check("C4", unlinked, .b).1.contains("link"))
        let fooled = S.record("C5", [S.label(1, "claim-ff95fc8d2fc5f02e", "entails")], opinion: S.opinion([("credit", 1, "same")]))
        let (_, failed) = try check("C5", fooled, .d)
        XCTAssertTrue(failed.contains("reading") && failed.contains("state"), "\(failed)")
    }

    /// Found while building the harness, recorded here and reported (nothing changed): the unchanged
    /// judge credits core claims only, so C3 read against Closure's supporting "retain access" claim —
    /// which §3.2 allows — is asked about, not credited; C1/C3 read as partial entailment reach only
    /// "fragile"; and C4 with a D verdict of "part" on the copying reason asks about Closure's purpose
    /// claim (the judge's how/why claim), not the access claim.
    func testCanonicalTensionsWithTheUnchangedJudge() throws {
        let supportingOnly = S.record("C3", [S.label(1, S.closureRetain, "entails")])
        let (supporting, failedSupporting) = try check("C3", supportingOnly, .b)
        XCTAssertEqual(supporting.judged.state, "fragile")
        XCTAssertTrue(failedSupporting.contains("state") && failedSupporting.contains("asksProbe"))
        let partial = S.record("C3", [S.label(1, S.closureDefinition, "partiallyEntails")])
        XCTAssertEqual(try check("C3", partial, .b).0.judged.state, "fragile")
        let part = S.record("C4", [S.label(1, S.closureDefinition, "entails"), S.label(2, S.closureRetain, "contradicts", role: "reason", misconception: "m1")],
                            links: [SpikeLink(reason: 2, conclusion: 1)],
                            opinion: S.opinion([("credit", 1, "same"), ("contradiction", 2, "opposite"), ("reason", 2, "part")]))
        let (asked, failed) = try check("C4", part, .d)
        XCTAssertEqual(asked.judged.state, "weakReasoning")
        XCTAssertTrue(asked.judged.asksProbe)
        XCTAssertEqual(asked.judged.probeClaims, ["claim-ea1f1e097d9c8eab"])
        XCTAssertEqual(failed, ["question"])
    }

    // MARK: - Checks (each only downgrades; B trusts the reading fully)

    private func run(_ text: String, concept: String, _ labels: [SpikeSegmentLabel], links: [SpikeLink] = [],
                     opinion: SpikeSecondOpinionOutput? = nil, key: SpikeAnswerKey? = nil, _ config: SpikeConfig) throws -> SpikeAdapter.Outcome {
        let item = S.adHoc(text, concept: concept)
        return try S.judge(item, record: S.record(item.id, labels, links: links, opinion: opinion), key: key, config: config).0
    }

    func testV1RejectsStructurallyInvalidReadingsInEveryConfiguration() throws {
        let text = "It checks that the person is really who they claim to be."
        let invalid: [[SpikeSegmentLabel]] = [
            [S.label(1, S.authDefinition, "entails"), S.label(2, S.authDefinition, "entails")],
            [S.label(2, S.authDefinition, "entails")],
            [S.label(1, "claim-unknown", "entails")],
            [S.label(1, S.authDefinition, "contradicts", misconception: "m9")],
            [S.label(1, S.authDefinition, "agrees")]
        ]
        let item = S.adHoc(text, concept: "Authentication")
        let input = try XCTUnwrap(GeneralizationEvaluation.input(for: item))
        let tier0 = GeneralizationEvaluation.v35(input, text)
        for labels in invalid {
            for config in SpikeConfig.allCases {
                let outcome = try run(text, concept: "Authentication", labels, config)
                XCTAssertEqual(outcome.fallback, .invalidReading)
                XCTAssertTrue(outcome.fallback.isFailure)
                XCTAssertEqual(SpikeScore.signature(outcome.judged), SpikeScore.signature(tier0))
            }
        }
    }

    func testFailedCallsFallBackToTier0AndEmptyAnswersAreNotFailures() throws {
        let (fixture, _) = try canonical()
        let c1 = fixture.cases[0]
        XCTAssertEqual(try S.judge(c1, record: S.record("C1", [], status: "timeout"), config: .b).0.fallback, .readingFailed)
        XCTAssertEqual(try S.judge(c1, record: nil, config: .c).0.fallback, .missingRecord)
        let opinionTimedOut = S.record("C1", [S.label(1, S.authDefinition, "entails")], opinion: nil, opinionStatus: "timeout")
        XCTAssertEqual(try S.judge(c1, record: opinionTimedOut, config: .d).0.fallback, .opinionFailed)
        XCTAssertEqual(try S.judge(c1, record: opinionTimedOut, config: .c).0.fallback, .none, "B and C never need the second opinion")
        let empty = try S.judge(S.adHoc("Fast.", concept: "Cache"), record: nil, config: .d).0
        XCTAssertEqual(empty.fallback, .empty)
        XCTAssertFalse(empty.fallback.isFailure)
    }

    func testV2DropsCreditOnHedgeOrFiller() throws {
        let labels = [S.label(1, S.authDefinition, "entails", role: "filler")]
        let text = "Basically it checks who you really are."
        XCTAssertEqual(try run(text, concept: "Authentication", labels, .b).judged.state, "mostlyUnderstood")
        let checked = try run(text, concept: "Authentication", labels, .c)
        XCTAssertTrue(checked.checked!.fired.contains("V2"))
        XCTAssertEqual(checked.judged.state, "insufficient")
    }

    func testV3NegationMismatchMakesCreditTentative() throws {
        let labels = [S.label(1, S.authDefinition, "entails")]
        let text = "Authentication does not verify identity."
        let trusted = try run(text, concept: "Authentication", labels, .b)
        XCTAssertTrue(trusted.judged.recordsMastery, "B trusts the reading, even when it misses a negation")
        let checked = try run(text, concept: "Authentication", labels, .c)
        XCTAssertTrue(checked.checked!.fired.contains("V3"))
        XCTAssertTrue(checked.judged.asksProbe)
        XCTAssertFalse(checked.judged.recordsMastery)
    }

    func testV4AntonymMakesCreditTentative() throws {
        let definition = "claim-6189944de72947c"
        let labels = [S.label(1, definition, "entails")]
        let text = "A cache is a slower storage layer that keeps results you can reuse later."
        XCTAssertFalse(try run(text, concept: "Cache", labels, .b).judged.asksProbe)
        let checked = try run(text, concept: "Cache", labels, .c)
        XCTAssertTrue(checked.checked!.fired.contains("V4"), "\(checked.checked!.fired)")
        XCTAssertTrue(checked.judged.asksProbe)
    }

    func testV5AbsoluteAgainstQualifiedClaimMakesCreditTentative() throws {
        let labels = [S.label(1, "claim-f7d36955ca232d94", "entails")]
        let text = "An access token is a credential for API requests that always has a short lifetime."
        let checked = try run(text, concept: "Access token", labels, .c)
        XCTAssertTrue(checked.checked!.fired.contains("V5"), "\(checked.checked!.fired)")
        XCTAssertTrue(checked.judged.asksProbe)
    }

    func testV7VagueOrShortCreditIsTentative() throws {
        let labels = [S.label(1, S.authDefinition, "entails", specificity: "vague")]
        let checked = try run("It is about identity.", concept: "Authentication", labels, .c)
        XCTAssertTrue(checked.checked!.fired.contains("V7"))
        XCTAssertTrue(checked.judged.asksProbe)
    }

    func testV8DropsLinksWithoutMarkerOrReasonRole() throws {
        let text = "The inner function can still access the outer variable. JavaScript copies all outer variables into it."
        let labels = [S.label(1, S.closureDefinition, "entails"), S.label(2, S.closureRetain, "contradicts", misconception: "m1")]
        let links = [SpikeLink(reason: 2, conclusion: 1)]
        XCTAssertEqual(try run(text, concept: "Closure", labels, links: links, key: S.keys["Mobile Mastery|Closure"], .b).judged.state, "weakReasoning")
        let checked = try run(text, concept: "Closure", labels, links: links, key: S.keys["Mobile Mastery|Closure"], .c)
        XCTAssertTrue(checked.checked!.fired.contains("V8"))
        XCTAssertEqual(checked.judged.state, "misconception", "without the link the copying claim is a stated wrong idea")
    }

    func testV9UngroundedContradictionIsDoubtful() throws {
        let labels = [S.label(1, S.authDefinition, "contradicts")]
        let text = "Authentication means painting the walls blue."
        let trusted = try run(text, concept: "Authentication", labels, .b)
        XCTAssertEqual(trusted.judged.state, "misconception")
        XCTAssertFalse(trusted.judged.asksProbe)
        let checked = try run(text, concept: "Authentication", labels, .c)
        XCTAssertTrue(checked.checked!.fired.contains("V9"))
        XCTAssertTrue(checked.judged.asksProbe)
        XCTAssertFalse(checked.judged.recordsMisconception)
    }

    // MARK: - Second opinion (D)

    func testSecondOpinionKeepsOnlyWhatItAgreesWith() throws {
        let text = "It checks that the person is really who they claim to be."
        let credit = [S.label(1, S.authDefinition, "entails")]
        func d(_ labels: [SpikeSegmentLabel], _ verdicts: [(String, Int, String)], _ text: String, _ concept: String = "Authentication") throws -> SpikeAdapter.Outcome {
            try run(text, concept: concept, labels, opinion: S.opinion(verdicts), .d)
        }
        XCTAssertFalse(try d(credit, [("credit", 1, "same")], text).judged.asksProbe)
        XCTAssertTrue(try d(credit, [("credit", 1, "different")], text).judged.asksProbe)
        XCTAssertTrue(try d(credit, [], text).judged.asksProbe, "an unchecked credit is asked about")
        let opposite = try d(credit, [("credit", 1, "opposite")], text)
        XCTAssertTrue(opposite.judged.asksProbe)
        XCTAssertFalse(opposite.judged.recordsMastery)
        let denial = [S.label(1, S.authDefinition, "contradicts", polarity: "negated")]
        XCTAssertTrue(try d(denial, [("contradiction", 1, "same")], "Authentication does not verify identity.").judged.asksProbe)
        let confusion = [S.label(1, "none", "contradicts", describes: "Authorization")]
        let mixedUp = "Authentication decides what an authenticated user is allowed to do."
        let firm = try d(confusion, [("confusion", 1, "same")], mixedUp)
        XCTAssertEqual(firm.judged.state, "misconception")
        XCTAssertTrue(firm.judged.recordsMisconception)
        let doubtful = try d(confusion, [("confusion", 1, "different")], mixedUp)
        XCTAssertTrue(doubtful.judged.asksProbe)
        XCTAssertEqual(doubtful.judged.probeConcept, ConceptKey("Authorization"))
    }

    // MARK: - Baselines and the scorer

    func testTier0AndBaselineOnTheDevelopmentSet() throws {
        let fixture = try S.fixture("p-dev")
        for (name, predictor) in [("A0", GeneralizationEvaluation.v35), ("A", GeneralizationEvaluation.v36)] {
            let report = GeneralizationEvaluation.evaluate(fixture, predictor, metamorphic: false)
            XCTAssertEqual(report.cases, 80)
            XCTAssertEqual(report.unavailable, 0)
            print("SPIKE|P|\(name)|\(report)")
        }
    }

    /// SPIKE_SPEC §3.4: A reproduces the recorded V36 sealed36 totals, and A0 the recorded V35 ones.
    func testSealed36BaselinesReproduceTheRecordedTotals() throws {
        let fixture = try XCTUnwrap(GeneralizationEvaluation.fixture("sealed36"))
        let a = GeneralizationEvaluation.evaluate(fixture, GeneralizationEvaluation.v36, metamorphic: false)
        let a0 = GeneralizationEvaluation.evaluate(fixture, GeneralizationEvaluation.v35, metamorphic: false)
        for (report, coarse, falseMastery, harmful, probes) in [(a, 51, 10, 23, 114), (a0, 52, 11, 25, 113)] {
            XCTAssertEqual(Int((report.coarseRate * 100).rounded()), coarse)
            XCTAssertEqual(report.falseMastery, falseMastery)
            XCTAssertEqual(report.goldNotPositive, 104)
            XCTAssertEqual(report.harmfulWrites, harmful)
            XCTAssertEqual(report.probes, probes)
        }
        print("SPIKE|S36|totals only|A coarse \(a.coarseRight)/\(a.cases) falseMastery \(a.falseMastery)/\(a.goldNotPositive) harmful \(a.harmfulWrites) probes \(a.probes)"
              + " | A0 coarse \(a0.coarseRight)/\(a0.cases) falseMastery \(a0.falseMastery)/\(a0.goldNotPositive) harmful \(a0.harmfulWrites) probes \(a0.probes)")
    }

    func testScorerEndToEndOnASyntheticCanonicalRun() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("spike-score-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let lines = try S.canonicalRecords().values.map { String(decoding: try JSONEncoder().encode($0), as: UTF8.self) }
        try lines.joined(separator: "\n").write(to: directory.appendingPathComponent("C.jsonl"), atomically: true, encoding: .utf8)
        try JSONEncoder().encode(SpikeAnswerKeyFile(keys: S.keys)).write(to: directory.appendingPathComponent("keys.json"))
        let env = ["LEU_SPIKE_SCORE_CASES": S.repository.appendingPathComponent("spikes/v37/cases/canonical.json").path,
                   "LEU_SPIKE_SCORE_SET": "C", "LEU_SPIKE_SCORE_LABEL": "C-synthetic",
                   "LEU_SPIKE_SCORE_READINGS": directory.appendingPathComponent("C.jsonl").path,
                   "LEU_SPIKE_SCORE_KEYS": directory.appendingPathComponent("keys.json").path,
                   "LEU_SPIKE_SCORE_OUT": directory.appendingPathComponent("C.score.json").path]
        let result = try XCTUnwrap(try ZZSpikeScoreRun.score(env))
        let canonical = try XCTUnwrap(result["canonical"] as? [String: Any])
        for config in ["B", "C", "D"] { XCTAssertEqual((canonical[config] as? [String: Any])?["passed"] as? Int, 5, config) }
        let failures = try XCTUnwrap(result["failures"] as? [String: Int])
        XCTAssertEqual(failures["schemaError"], 0); XCTAssertEqual(failures["missing"], 0)
        XCTAssertEqual((result["perCase"] as? [String: Any])?.count, 5, "A0, A, B, C, D")
        XCTAssertEqual((result["latency"] as? [Any])?.count, 5)
        XCTAssertThrowsError(try ZZSpikeScoreRun.score(env.merging(["LEU_SPIKE_SCORE_BLIND": "1"]) { $1 }), "blind output outside blind/ is refused")
    }
}
