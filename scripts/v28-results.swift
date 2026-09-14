import Foundation
@testable import ShelfCore

@main struct V28Results {
    static func main() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let out = root.appendingPathComponent("docs/v28/results-sprint")
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601
        let name = "javascript_midlevel_interview_mobile_mastery"
        let analysis = try decoder.decode(DocumentAnalysis.self, from: Data(contentsOf: root.appendingPathComponent("docs/v28/evidence/baseline/\(name)-analysis.json")))
        let pdf = try Data(contentsOf: root.appendingPathComponent("docs/v28/fixtures/\(name).pdf"))
        precondition(analysis.fingerprint == String(StableIdentity.hash64(pdf.base64EncodedString())))
        let sampleData = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("docs/v28/evidence/distributed-sample.json"))) as! [String: Any]
        let sample = Set(sampleData["pages"] as! [Int])
        var rows: [[String: Any]] = [], claims: [ContextualFactualClaim] = []
        for page in analysis.pages where sample.contains(page.pageIndex + 1) {
            let result = ContextualClaimComposer().compose(analysis: analysis, page: page)
            claims += result.claims
            rows.append(["page": page.pageIndex + 1, "title": result.card?.title ?? "unresolved",
                "factualBlock": result.card?.factualBlocks.map(\.text) ?? [], "claimCount": result.claims.count,
                "result": try JSONSerialization.jsonObject(with: encoder.encode(result)), "rejection": result.rejection ?? "none"])
        }
        let count = rows.filter { ($0["claimCount"] as! Int) > 0 }.count
        try JSONSerialization.data(withJSONObject: ["claimPages": count, "samplePages": rows.count, "pages": rows], options: [.prettyPrinted, .sortedKeys]).write(to: out.appendingPathComponent("claim-yield.json"))
        print("CLAIM PAGES: \(count)/\(rows.count)")
        for row in rows where (row["claimCount"] as! Int) == 0 { print("REJECTED", row) }
        guard count >= 30 else { exit(2) }
        let neighboringClaims = analysis.pages.flatMap { ContextualClaimComposer().compose(analysis: analysis, page: $0).claims }
        let compiler = QuestionV4Compiler()
        var questions: [QuestionV4] = [], rejections: [[String: Any]] = []
        for claim in claims {
            guard let question = compiler.compile(claim, neighbors: neighboringClaims) else {
                rejections.append(["page": claim.card.pageIndex + 1, "title": claim.card.title, "reason": "no_supported_adjacent_cognitive_transform_or_balanced_options"]); continue
            }
            if let reason = compiler.validate(question, claims: neighboringClaims, analyses: [analysis.documentID: analysis]) {
                rejections.append(["page": claim.card.pageIndex + 1, "title": claim.card.title, "reason": reason])
            } else { questions.append(question) }
        }
        try encoder.encode(questions).write(to: out.appendingPathComponent("questions.json"))
        try JSONSerialization.data(withJSONObject: ["questions": rejections], options: [.prettyPrinted, .sortedKeys]).write(to: out.appendingPathComponent("rejections.json"))
        print("QUESTIONS: \(questions.count)")
        guard questions.count >= 20 else { exit(3) }
        var analyses = [analysis.documentID: analysis], titles = [analysis.documentID: name]
        for name in ["React Notes", "System Design", "JavaScript Deep Dive"] {
            let item = try decoder.decode(DocumentAnalysis.self, from: Data(contentsOf: root.appendingPathComponent("docs/v28/evidence/baseline/\(name)-analysis.json")))
            let bytes = try Data(contentsOf: root.appendingPathComponent("Shelf/Resources/Samples/\(name).pdf"))
            precondition(item.fingerprint == String(StableIdentity.hash64(bytes.base64EncodedString())))
            analyses[item.documentID] = item; titles[item.documentID] = name
        }
        let connections = ConnectionResultsV2(analyses: analyses, titles: titles)
        try encoder.encode(connections.admitted).write(to: out.appendingPathComponent("connections.json"))
        try JSONSerialization.data(withJSONObject: ["questions": rejections, "connections": connections.rejected], options: [.prettyPrinted, .sortedKeys]).write(to: out.appendingPathComponent("rejections.json"))
        print("CONNECTIONS: \(connections.admitted.count)")
        guard connections.admitted.count >= 10 else { exit(4) }
        let allFacts = analyses.values.flatMap { RelationalSourceFact.extract(analysis: $0, documentTitle: titles[$0.documentID]!) }
        let sources: [String: RelationalSourceFact] = [
            "keys": allFacts.first { $0.documentTitle == "React Notes" && $0.pageIndex == 2 && $0.relations.contains { $0.subject == "react.stable-key" } }!,
            "retry": allFacts.first { $0.title == "Retry" }!,
            "unique": allFacts.first { $0.title == "Unique constraint" }!,
            "closure": allFacts.first { $0.documentTitle == "JavaScript Deep Dive" && $0.pageIndex == 2 }!,
            "immutable": allFacts.first { $0.title == "Immutability" }!
        ]
        struct Fixture: Codable { let family: String; let expected: String; let text: String }
        let fixtures = try decoder.decode([Fixture].self, from: Data(contentsOf: out.appendingPathComponent("teach-fixtures.json")))
        var teach: [[String: Any]] = []
        for (index, fixture) in fixtures.enumerated() {
            let source = sources[fixture.family]!
            let actual = TeachLeuV2.evaluate(fixture.text, source: source, analyses: analyses)
            let passed = actual.status.rawValue == fixture.expected
            teach.append(["id": index + 1, "learner": fixture.text, "expected": fixture.expected, "passed": passed,
                "source": try JSONSerialization.jsonObject(with: encoder.encode(source)),
                "actual": try JSONSerialization.jsonObject(with: encoder.encode(actual))])
            if !passed { print("TEACH FAIL \(index + 1): \(fixture.expected) -> \(actual.status.rawValue) [\(actual.reasonCode)]: \(fixture.text)") }
        }
        let teachPass = teach.filter { $0["passed"] as! Bool }.count
        try JSONSerialization.data(withJSONObject: ["passed": teachPass, "total": fixtures.count, "cases": teach], options: [.prettyPrinted, .sortedKeys]).write(to: out.appendingPathComponent("teach-paraphrase.json"))
        print("PARAPHRASE FIXTURES: \(teachPass)/\(fixtures.count)")
        guard teachPass == fixtures.count else { exit(5) }
        func mutated<T: Codable>(_ value: T, _ edit: (inout [String: Any]) -> Void) throws -> T {
            var object = try JSONSerialization.jsonObject(with: encoder.encode(value)) as! [String: Any]
            edit(&object)
            return try decoder.decode(T.self, from: JSONSerialization.data(withJSONObject: object))
        }
        var protections: [[String: Any]] = []
        func check(_ name: String, _ passes: Bool) {
            protections.append(["check": name, "passed": passes])
            if !passes { print("PROTECTION FAIL: \(name)") }
        }
        let q = questions.first!
        for (name, edit) in [
            ("wrong_answer_index", { (o: inout [String: Any]) in o["correctChoice"] = (q.correctChoice + 1) % 3 }),
            ("unsupported_prompt", { (o: inout [String: Any]) in o["prompt"] = "Why is this always safe?" }),
            ("unsupported_explanation", { (o: inout [String: Any]) in o["explanation"] = "This guarantees success." }),
            ("altered_option", { (o: inout [String: Any]) in var c = o["choices"] as! [[String: Any]]; c[0]["text"] = "Invented behavior"; o["choices"] = c }),
            ("mnemonic_option_role", { (o: inout [String: Any]) in var c = o["choices"] as! [[String: Any]]; c[0]["role"] = "mnemonic"; o["choices"] = c })
        ] {
            let forged: QuestionV4 = try mutated(q, edit)
            check(name, compiler.validate(forged, claims: neighboringClaims, analyses: analyses) != nil)
        }
        let connection = connections.admitted.first!
        let forgedProof: GroundedConnectionV2 = try mutated(connection) { $0["proofLevel"] = "SOURCE_EXPLICIT" }
        check("inferred_connection_cannot_claim_explicit", ConnectionAdmissionV2.validate(forgedProof, analyses: analyses) != nil)
        let forgedBridge: GroundedConnectionV2 = try mutated(connection) { o in var r = o["relationA"] as! [String: Any]; r["object"] = "unsupported.third-fact"; o["relationA"] = r }
        check("unsupported_bridge_rejected", ConnectionAdmissionV2.validate(forgedBridge, analyses: analyses) != nil)
        let stale: RelationalSourceFact = try mutated(sources["keys"]!) { $0["fingerprint"] = "obsolete" }
        check("stale_teach_source_rejected", TeachLeuV2.evaluate(fixtures[0].text, source: stale, analyses: analyses).reasonCode == "stale_source")
        let mnemonic: RelationalSourceFact = try mutated(sources["keys"]!) { $0["role"] = "mnemonic" }
        check("mnemonic_teach_source_rejected", !mnemonic.isCurrent(in: analyses))
        for text in [
            "Keys help React recognize the same item and encrypt private documents.",
            "A stable key helps React recognize the same item in 900 lists.",
            "Keys help React recognize the same item using magicCache().",
            "Keys help React recognize the same item and download the whole database.",
            "A closure retains access to its lexical environment and deletes the source file."
        ] {
            let source = sources[text.hasPrefix("A closure") ? "closure" : "keys"]!
            check("unsupported_addition: " + text, TeachLeuV2.evaluate(text, source: source, analyses: analyses).status != .supported)
        }
        try JSONSerialization.data(withJSONObject: protections, options: [.prettyPrinted, .sortedKeys]).write(to: out.appendingPathComponent("admission-protections.json"))
        print("ADMISSION PROTECTIONS: \(protections.filter { $0["passed"] as! Bool }.count)/\(protections.count)")
        guard protections.allSatisfy({ $0["passed"] as! Bool }) else { exit(6) }
    }
}
