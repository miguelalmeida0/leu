import Foundation
import ShelfCore
import LeuReasoningCore

@main struct TeachIntegration {
    static func main() async throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let out = root.appendingPathComponent("evidence/v29.1/after")
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        var analyses: [UUID: DocumentAnalysis] = [:], titles: [UUID: String] = [:]
        for name in ["javascript_midlevel_interview_mobile_mastery", "React Notes", "JavaScript Deep Dive", "System Design"] {
            let a = try decoder.decode(DocumentAnalysis.self, from: Data(contentsOf: root.appendingPathComponent("docs/v28/evidence/baseline/\(name)-analysis.json")))
            analyses[a.documentID] = a; titles[a.documentID] = name
        }
        let facts = analyses.values.flatMap { RelationalSourceFact.extract(analysis: $0, documentTitle: titles[$0.documentID]!) }
        var checks: [[String: Any]] = []
        func check(_ name: String, _ passed: Bool) { checks.append(["name": name, "passed": passed]); print("\(passed ? "PASS" : "FAIL") \(name)") }
        func feedback(_ value: ReasonedTeachFeedback) -> [String: Any] {
            ["captured": value.captured.map(\.learner), "worthAdding": value.worthAdding.map { $0.source.quote.text },
             "check": value.check.map { ["learner": $0.learner, "source": $0.source.quote.text] },
             "notEstablished": value.unsettled, "fullySupported": value.fullySupported]
        }
        struct Previous: Decodable { struct Case: Decodable { let id: Int; let learner, expected: String; let source: RelationalSourceFact }; let cases: [Case] }
        let previous = try decoder.decode(Previous.self, from: Data(contentsOf: root.appendingPathComponent("docs/v28/results-sprint/teach-paraphrase.json")))
        var comparisons: [[String: Any]] = []
        for item in previous.cases {
            let actual = TeachReasoningAdapter(sources: [item.source], analyses: analyses).compare(item.learner, analyses: analyses)
            let passed: Bool
            switch item.expected {
            case "SUPPORTED": passed = actual.fullySupported
            case "CONTRADICTED": passed = !actual.check.isEmpty && actual.captured.isEmpty
            case "OVERGENERALIZED", "INCOMPLETE": passed = !actual.worthAdding.isEmpty && !actual.fullySupported && actual.check.isEmpty
            default: passed = actual.captured.isEmpty && !actual.unsettled.isEmpty
            }
            comparisons.append(["id": item.id, "learner": item.learner, "previous": item.expected, "matchesPresentation": passed, "actual": feedback(actual), "source": item.source.quote.text])
        }
        try JSONSerialization.data(withJSONObject: comparisons, options: [.prettyPrinted, .sortedKeys]).write(to: out.appendingPathComponent("teach-43-comparison.json"))
        print("TEACH 43 presentation matches: \(comparisons.filter { $0["matchesPresentation"] as! Bool }.count)/43")
        check("All 43 existing Teach presentations remain correct", comparisons.count == 43 && comparisons.allSatisfy { $0["matchesPresentation"] as! Bool })
        let cleanup = facts.first { $0.title == "Effect cleanup" }!
        let http = facts.first { $0.title == "HTTP" }!
        let webhook = facts.first { $0.title == "Webhook" }!
        let adapter = TeachReasoningAdapter(sources: [cleanup], analyses: analyses)
        let concise = "Effect cleanup prevents duplicate listeners."
        let mixed = concise + " Effect cleanup creates encrypted backups."
        let a = adapter.compare(concise, analyses: analyses), b = adapter.compare(mixed, analyses: analyses)
        let h = TeachReasoningAdapter(sources: [http], analyses: analyses).compare("HTTP is a protocol.", analyses: analyses)
        let w = TeachReasoningAdapter(sources: [webhook], analyses: analyses).compare("A webhook prevents server outages.", analyses: analyses)
        check("Supported subset and missing detail stay separate", a.fullySupported && !a.worthAdding.isEmpty)
        check("Definition head is supported but incomplete", h.fullySupported && !h.worthAdding.isEmpty)
        check("Right-topic invention receives no support", w.captured.isEmpty && !w.unsettled.isEmpty && w.check.isEmpty)
        check("Mixed response flags only the unsupported clause", b.captured.count == 1 && b.unsettled == ["Effect cleanup creates encrypted backups."] && !b.fullySupported)
        var latency: [Double] = []
        for _ in 0..<20 { let start = Date(); _ = adapter.compare(mixed, analyses: analyses); latency.append(Date().timeIntervalSince(start)*1000) }
        let selected = cleanup.citation(in: analyses)!
        check("Exact source navigation remains bound", selected.passage == cleanup.passage && selected.isCurrent(in: analyses))
        let location = root.appendingPathComponent(".build/v291-history-\(UUID())")
        let store = FileLearningSnapshotStore(root: location)
        try store.save(LearningSnapshot(analyses: analyses))
        let repo = LearningRepository(persistence: store)
        var attempt = UnderstandingAttempt(source: selected); attempt.learnerExplanation = mixed
        try await repo.storeUnderstandingAttempt(attempt)
        let start = Date(); let reopened = try await LearningRepository(persistence: store).open()
        let reopenMs = Date().timeIntervalSince(start)*1000
        check("Mixed draft survives reopening without learned claims", reopened.understandingAttempts.first?.learnerExplanation == mixed && reopened.understandingAttempts.first?.supportedClaimIDs.isEmpty == true)
        attempt.learnerExplanation = concise; try await repo.storeUnderstandingAttempt(attempt)
        let edited = try await repo.snapshot()
        check("Edit reuses the same attempt identity", edited.understandingAttempts.count == 1 && edited.understandingAttempts.first?.id == attempt.id && edited.understandingAttempts.first?.learnerExplanation == concise)
        var stale = analyses; stale[cleanup.documentID]!.extractionVersion = 4
        check("Stale source cannot award support", adapter.compare(concise, analyses: stale).captured.isEmpty)
        // Replay the original authored cases without retaining obsolete truth
        // expectations. Every changed verdict carries its actual source below.
        struct Old: Decodable { let text, concept, verdict: String }
        let old = try decoder.decode([Old].self, from: Data(contentsOf: root.appendingPathComponent("evidence/v29.1/before/learner-cases.json")))
        let atoms = try decoder.decode([KnowledgeAtom].self, from: Data(contentsOf: root.appendingPathComponent("evidence/v29.1/before/atoms.json")))
        let documents = try decoder.decode([CanonicalDocument].self, from: Data(contentsOf: root.appendingPathComponent("evidence/v29.1/before/pdf-pages.json")))
        let certified = CertifiedReasoningIndex(documents: documents, sampledPages: Array(Set(atoms.compactMap(\.page))))
        let malformed = atoms.first { $0.subject == "Concurrent" && $0.relation == "requests" }!
        let repaired = certified.atoms.first { $0.canonicalSpan == malformed.canonicalSpan }!
        check("Canonical admission rejects the old malformed segmentation", !certified.admits(malformed) && certified.admits(repaired) && repaired.subject == "Concurrent requests" && repaired.object == "decisions from stale state")
        check("Repaired extraction preserves exact original source span", malformed.provenance.spans == repaired.provenance.spans && repaired.provenance.spans.allSatisfy { CanonicalSource.verifies($0, documents: documents) })
        try encoder.encode(["before": malformed, "after": repaired]).write(to: out.appendingPathComponent("exact-extraction.json"))
        let reviewed = old.map { item -> [String: Any] in
            let relevant = atoms.filter { SemanticIdentity.phrase($0.subject) == SemanticIdentity.phrase(item.concept) }
            let report = SourceBoundExplanationAligner().align(explanation: item.text, concept: item.concept, in: KnowledgeGraphBuilder().build(atoms: relevant))
            return ["learner": item.text, "before": item.verdict, "after": report.verdict.rawValue, "support": report.alignments.map { $0.verdict.rawValue }, "missingDetails": report.unaddressedAtomIDs.count, "findings": report.findings.map { $0.type.rawValue }, "source": relevant.map(\.canonicalSpan)]
        }
        try JSONSerialization.data(withJSONObject: reviewed, options: [.prettyPrinted, .sortedKeys]).write(to: out.appendingPathComponent("reviewed-32.json"))
        try JSONSerialization.data(withJSONObject: ["checks": checks, "concise": feedback(a), "mixed": feedback(b), "http": feedback(h), "webhook": feedback(w), "submitMs": latency, "reopenMs": reopenMs, "nativeUIExecuted": false], options: [.prettyPrinted, .sortedKeys]).write(to: out.appendingPathComponent("app-adapter-journey.json"))
        guard checks.allSatisfy({ $0["passed"] as! Bool }) else { exit(1) }
    }
}
