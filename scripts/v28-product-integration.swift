import Foundation
@testable import ShelfCore

@main struct ProductIntegration {
    static func main() async throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let out = root.appendingPathComponent("docs/v28/productization")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        var analyses: [UUID: DocumentAnalysis] = [:], titles: [UUID: String] = [:]
        let mobile = "javascript_midlevel_interview_mobile_mastery"
        for name in [mobile, "React Notes", "JavaScript Deep Dive", "System Design"] {
            let a = try decoder.decode(DocumentAnalysis.self, from: Data(contentsOf: root.appendingPathComponent("docs/v28/evidence/baseline/\(name)-analysis.json")))
            analyses[a.documentID] = a; titles[a.documentID] = name
        }
        let primary = analyses.values.first { titles[$0.documentID] == mobile }!
        let react = analyses.values.first { titles[$0.documentID] == "React Notes" }!
        let index = V28ConnectionIndex(analyses: analyses, titles: titles)
        let anchor = index.facts.first { $0.documentID == react.documentID && $0.pageIndex == 2 && $0.relations.contains { $0.subject == "react.stable-key" } }!
        let selected = anchor.citation(in: analyses)!
        var results: [[String: Any]] = []
        func check(_ name: String, _ passed: Bool, _ detail: String) {
            results.append(["test": name, "passed": passed, "detail": detail]); print("\(passed ? "PASS" : "FAIL") \(name): \(detail)")
        }
        let start = Date()
        let bank = V4StudyBank.build(primary)
        let bankSeconds = Date().timeIntervalSince(start)
        print("BANK BUILT \(bank.count) in \(bankSeconds)s"); fflush(stdout)
        let store = FileLearningSnapshotStore(root: root.appendingPathComponent(".build/v28-product-library-\(UUID())"))
        try store.save(LearningSnapshot(analyses: analyses))
        let repository = LearningRepository(persistence: store)
        let saveStart = Date()
        try await repository.storeV4Questions(bank)
        let saveSeconds = Date().timeIntervalSince(saveStart)
        let reloadStart = Date()
        let reopened = try await LearningRepository(persistence: store).open()
        let reloadSeconds = Date().timeIntervalSince(reloadStart)
        let plan = ShelfStudySessionPlanner().plan(snapshot: reopened, topicID: nil, minutes: 5)
        let planned = plan.activities.compactMap { activity in reopened.questions.first { $0.id == activity.questionID } }
        var stripped = bank.first!; stripped.v4 = nil
        var edited = bank.first!; edited.prompt = "Why does this always succeed?"
        let proofProtected = FinalMCQAdmission.rejectionReason(stripped, analysis: primary) == "v4_missing_proof" &&
            FinalMCQAdmission.rejectionReason(edited, analysis: primary) == "v4_study_adapter_mismatch"
        let grammar = bank.first { $0.v4?.claim.card.title == "HttpOnly cookie" }?.prompt.hasPrefix("How does an HttpOnly cookie ") == true &&
            bank.first { $0.v4?.claim.card.title == "TypeScript" }?.prompt.contains("TypeScript catch many integration mistakes earlier and document contracts") == true &&
            bank.allSatisfy { !$0.prompt.contains(" and can ") && !$0.prompt.contains(", but adds") }
        let studyOK = bank.count >= 25 && reopened.questions.count == bank.count &&
            !planned.isEmpty && planned.allSatisfy { $0.v4 != nil && !$0.prompt.hasPrefix("According to") } &&
            bank.allSatisfy { $0.source.range != nil && $0.modelProvenance == nil } && proofProtected && grammar
        check("Study uses persisted V4 with clean copy", studyOK, "bank=\(bank.count); reloaded=\(reopened.questions.count); planned V4=\(planned.count)")
        if let question = planned.first { try encoder.encode(question).write(to: out.appendingPathComponent("study-question.json")) }

        let natural = "React needs a consistent ID so it knows it's still the same item after the list moves."
        let naturalResult = V28TeachPresentation.compare(natural, sources: [anchor], analyses: analyses)
        let retry = index.facts.first { $0.title == "Retry" }!
        let missing = V28TeachPresentation.compare("Retry every failed request.", sources: [retry], analyses: analyses)
        let contradiction = V28TeachPresentation.compare("Keys do not help React match an item to its earlier instance.", sources: [anchor], analyses: analyses)
        let unsupported = V28TeachPresentation.compare("Keys make rendering faster.", sources: [anchor], analyses: analyses)
        check("Teach presentation consumes V2 states", !naturalResult.captured.isEmpty && !missing.worthAdding.isEmpty && missing.check.isEmpty &&
            !contradiction.check.isEmpty && unsupported.captured.isEmpty && !unsupported.unsettled.isEmpty,
            "Natural paraphrase, missing condition, contradiction and unsupported effect routed separately")

        let found = index.connections(from: selected, analyses: analyses)
        let roundTrip = found.allSatisfy { c in
            guard let a = c.sourceA.citation(in: analyses), let b = c.sourceB.citation(in: analyses) else { return false }
            return a.passage == c.sourceA.passage && b.passage == c.sourceB.passage && a.isCurrent(in: analyses) && b.isCurrent(in: analyses)
        }
        let collision = found.first!
        let reverseSource = collision.sourceB.citation(in: analyses)!
        let reverse = index.connections(from: reverseSource, analyses: analyses)
        check("Connections retain both exact source routes", !found.isEmpty && roundTrip && reverse.contains { $0.id == collision.id }, "\(found.count) forward; \(reverse.count) reverse; both document/page/ranges rebind")
        check("Collision ranks a real two-source bridge", collision.relationship == "mechanism" && collision.sourceB.title == "Reconciliation" &&
            collision.sourceA.documentID != collision.sourceB.documentID && ConnectionAdmissionV2.validate(collision, analyses: analyses) == nil,
            "\(collision.sourceA.documentTitle) p.\(collision.sourceA.pageIndex+1) + \(collision.sourceB.title) p.\(collision.sourceB.pageIndex+1)")
        try encoder.encode(collision).write(to: out.appendingPathComponent("collision.json"))

        let explanation = "Stable keys let React recognize the same item after reordering. Reconciliation compares the previous and next trees, using element type and keys to keep or replace component instances."
        let linked = V28TeachPresentation.compare(explanation, sources: [collision.sourceA, collision.sourceB], analyses: analyses, connection: collision)
        let partial = V28TeachPresentation.compare(natural, sources: [collision.sourceA, collision.sourceB], analyses: analyses, connection: collision)
        let invented = V28TeachPresentation.compare(explanation + " Keys encrypt the database.", sources: [collision.sourceA, collision.sourceB], analyses: analyses, connection: collision)
        let numeric = V28TeachPresentation.compare(explanation.replacingOccurrences(of: "component instances", with: "900 component instances"),
            sources: [collision.sourceA, collision.sourceB], analyses: analyses, connection: collision)
        check("Teach Connection requires both sources", linked.connected && Set(linked.captured.map { $0.source.id }).count == 2 &&
            !partial.connected && !invented.connected && !invented.unsettled.isEmpty && !numeric.connected && !numeric.unsettled.isEmpty,
            "linked=\(linked.connected); supported sources=\(Set(linked.captured.map { $0.source.id }).count); unknown clauses=\(linked.unsettled)")
        try JSONSerialization.data(withJSONObject: ["learner": explanation, "connected": linked.connected,
            "captured": linked.captured.map { ["clause": $0.learner, "document": $0.source.documentTitle, "page": String($0.source.pageIndex+1), "explanation": $0.assessment.explanation] },
            "unsettled": linked.unsettled], options: [.prettyPrinted, .sortedKeys]).write(to: out.appendingPathComponent("teach-connection.json"))

        if let definition = index.activity(from: selected, analyses: analyses) {
            var stable = KeyIdentityPrediction(), position = KeyIdentityPrediction()
            var refusedEarly = false
            do { try stable.reveal(definition: definition, analyses: analyses) } catch { refusedEarly = true }
            stable.predict(.followsItem); try stable.reveal(definition: definition, analyses: analyses)
            try position.choose(.positions, definition: definition); position.predict(.staysAtPosition)
            try position.reveal(definition: definition, analyses: analyses)
            check("What Changes If predicts before deterministic transition", refusedEarly && index.activity(from: reverseSource, analyses: analyses)?.source == definition.source && stable.state.order == ["C", "A", "B"] &&
                stable.state.rowState == [0, 7, 0] && position.state.rowState == [7, 0, 0],
                "stable state=\(stable.state.rowState); index state=\(position.state.rowState); same row order=\(stable.state.order)")
            try encoder.encode(definition).write(to: out.appendingPathComponent("what-changes-if-source.json"))
        } else { check("What Changes If predicts before deterministic transition", false, "Actual React p.3 activity prerequisites were not admitted") }

        let explanations = ExplainFromLibrary.results(source: selected, index: index, analyses: analyses)
        check("Library explanation retains provenance", explanations.contains { $0.kind == .explanation } &&
            explanations.contains { $0.kind == .related } && explanations.allSatisfy { $0.isCurrent(in: analyses) && $0.passage.range != nil },
            explanations.map { "\($0.kind.rawValue): \($0.source.documentTitle) p.\($0.passage.pageIndex+1)" }.joined(separator: "; "))
        try JSONSerialization.data(withJSONObject: ["passed": results.filter { $0["passed"] as! Bool }.count, "total": results.count,
            "tests": results, "bankBuildSeconds": bankSeconds, "bankSaveSeconds": saveSeconds, "bankReloadSeconds": reloadSeconds,
            "totalSeconds": Date().timeIntervalSince(start)], options: [.prettyPrinted, .sortedKeys]).write(to: out.appendingPathComponent("integration-results.json"))
        guard results.count == 7, results.allSatisfy({ $0["passed"] as! Bool }) else { exit(1) }
    }
}
