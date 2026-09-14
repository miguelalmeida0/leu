import Foundation
import LeuReasoningCore

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let out = root.appendingPathComponent("evidence/v29-real-reasoning")
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
func write<T: Encodable>(_ value: T, _ name: String) throws { try encoder.encode(value).write(to: out.appendingPathComponent(name + ".json")) }
let docs = try JSONDecoder().decode([CanonicalDocument].self, from: Data(contentsOf: out.appendingPathComponent("pdf-pages.json")))
let mobile = docs[0]
let cards = mobile.pages.compactMap { CanonicalSource.card(in: $0, documentID: mobile.id) }
let sample = (0..<40).map { cards[Int((Double($0) * Double(cards.count - 1) / 39).rounded())] }
let start = Date()
let results = sample.map { PacketAtomExtractor().extract($0) }
let atoms = results.flatMap(\.atoms)
try write(results.map { ["page": String($0.packet.body.page), "title": $0.packet.title, "atoms": String($0.atoms.count), "sampling": "rounded evenly spaced indices over all IN ONE BREATH concept cards", "pdfSHA256": mobile.sha256] }, "sample-pages")
try write(atoms, "atoms")
try write(results, "packets")
print("PAGES \(results.filter { !$0.atoms.isEmpty }.count)/40 ATOMS \(atoms.count) extractionMS \(Date().timeIntervalSince(start) * 1000)")
for r in results { print("p\(r.packet.body.page) \(r.packet.title): " + r.atoms.map { "[\($0.subject) → \($0.relation) → \($0.object)]" }.joined(separator: " | ")); if !r.unresolved.isEmpty {print("UNRESOLVED " + r.unresolved.joined(separator: " | "))} }
precondition(atoms.allSatisfy { $0.provenance.spans.allSatisfy { CanonicalSource.verifies($0, documents: docs) } })
let indexStart = Date()
let index = CertifiedReasoningIndex(documents: docs, sampledPages: sample.map { $0.body.page })
print("INDEX \(index.atoms.count) atoms \(index.graph.relations.count) relations \(index.inferred.count) inferred \(index.crossDocument.count) crossDoc MS \(Date().timeIntervalSince(indexStart)*1000)")
try write(index.atoms, "library-atoms")
try write(index.graph.relations, "relations")
try write(index.crossDocument, "cross-document")
var crossCandidates: [[String: String]] = []
for definition in index.atoms where definition.claimType == .definition && definition.provenance.spans.contains(where: { $0.sourceRole == .structure }) {
    for use in index.atoms where use.sourceDocumentID != definition.sourceDocumentID {
        let term = SemanticIdentity.phrase(definition.subject)
        let text = " " + SemanticIdentity.phrase(use.canonicalSpan ?? "") + " "
        let admitted = index.crossDocument.first { Set($0.supportingAtoms) == Set([definition.id, use.id]) }
        guard admitted != nil || (term.count >= 4 && (text.contains(" " + term + " ") || text.contains(" " + term + "s "))) else { continue }
        crossCandidates.append(["definitionAtom": definition.id.rawValue, "useAtom": use.id.rawValue,
                                "term": definition.subject, "status": admitted == nil ? "UNRESOLVED" : "INFERRED_VALIDATED",
                                "rule": admitted?.provenance.rule.rawValue ?? "none",
                                "reason": admitted == nil ? "A lexical reference alone does not establish a unique technical sense." : "The source definition supplies bounded context for the explicitly referenced technical term; no whole-claim equivalence is inferred."])
    }
}
try write(crossCandidates, "cross-document-candidates")
try write(index.rejected, "rejections")
let chains = sample.map { MechanismEngine().answer(.why($0.title), in: index.graph) }
try write(chains, "mechanism-chains")
let changes: [KnowledgeChange] = [
    .removed("Effect cleanup"), .removed("State machine"), .removed("Event bubbling"),
    .removed("Message queue"), .removed("Docker"), .removed("Webhook"), .removed("Tree shaking"),
    .removed("Refresh token"), .removed("Distributed cache"), .conditionFalse("props are stable"),
    .removed("HTTP"), .removed("JSON"), .propertyLost(subject: "Effect cleanup", property: "wireless"),
    .replaced("State machine", with: "an unspecified alternative"), .conditionFalse("props are shallowly equal")
]
let counterfactuals = changes.map { CounterfactualEngine().evaluate($0, in: index.graph) }
try write(counterfactuals, "counterfactuals")
print("MECHANISMS \(chains.filter { !$0.paths.isEmpty }.count) multi \(chains.filter { $0.paths.contains { $0.steps.count >= 2 } }.count)")
struct LearnerCase: Codable { var category: String; var concept: String; var text: String; var verdict: AlignmentVerdict; var finding: MisconceptionType? }
struct LearnerResult: Codable { var input: LearnerCase; var actual: ExplanationAlignmentReport; var passed: Bool }
let cases = try JSONDecoder().decode([LearnerCase].self, from: Data(contentsOf: out.appendingPathComponent("learner-cases.json")))
let learner = cases.map { item -> LearnerResult in
    let actual = ExplanationAligner().align(explanation: item.text, concept: item.concept, in: index.graph)
    let passed = actual.verdict == item.verdict && (item.finding == nil || actual.findings.contains { $0.type == item.finding })
    return LearnerResult(input: item, actual: actual, passed: passed)
}
try write(learner, "learner-alignment")
print("LEARNER \(learner.filter(\.passed).count)/\(learner.count)")
for result in learner where !result.passed { print("LEARNER FAIL \(result.input.category) \(result.input.text) actual \(result.actual.verdict) findings \(result.actual.findings.map { $0.type.rawValue })") }
var synthesisPairs = index.crossDocument.compactMap { relation -> (KnowledgeAtom, KnowledgeAtom)? in
    guard let a = index.graph.atom(relation.subject.id), let b = index.graph.atom(relation.object.id) else { return nil }
    return (a,b)
}
let external = index.atoms.filter { $0.sourceDocumentID != mobile.id }
for (a,b) in zip(atoms.prefix(5), external.suffix(5)) { synthesisPairs.append((a,b)) }
let syntheses = synthesisPairs.prefix(15).map { MultiSourceSynthesizer().compare($0.0, $0.1, in: index) }
try write(syntheses, "synthesis")
let plans = learner.map { QuestionPlanner().plan(concept: $0.input.concept, in: index.graph, alignment: $0.actual) }
try write(plans, "question-plans")
let strategies = learner.map { ExplanationStrategySelector().select(concept: $0.input.concept, in: index.graph, alignment: $0.actual) }
try write(strategies, "explanation-strategies")
let time = Date(timeIntervalSince1970: 1_000)
let state = UnderstandingStateProjector().project(events: [
    .openedRelatedSource(documentID: mobile.id, concept: "React.memo", at: time),
    .evaluatedExplanation(concept: "React.memo", text: cases[10].text, alignment: learner[10].actual, at: time.addingTimeInterval(1)),
    .changedExplanation(concept: "React.memo", previous: cases[10].text, updated: cases[7].text, at: time.addingTimeInterval(2)),
    .evaluatedExplanation(concept: "React.memo", text: cases[7].text, alignment: learner[7].actual, at: time.addingTimeInterval(3))
], extractionVersion: "leu.pdf-packet.1")
try write(state, "understanding-state")
struct Timing: Codable { var count: Int; var p50MS: Double; var p95MS: Double; var maxMS: Double }
func measure(_ count: Int = 31, _ f: () -> Void) -> Timing {
    var samples: [Double] = []
    for _ in 0..<count { let t = Date(); f(); samples.append(Date().timeIntervalSince(t) * 1000) }
    samples.sort()
    return Timing(count: count, p50MS: samples[count / 2], p95MS: samples[min(count-1,Int(Double(count)*0.95))], maxMS: samples.last!)
}
let perf: [String: Timing] = [
 "atomExtraction40Pages": measure { _ = sample.map { PacketAtomExtractor().extract($0) } },
 "graphConstruction": measure { _ = KnowledgeGraphBuilder().build(atoms: index.atoms) },
 "relationAdmission": measure(7) { _ = GraphValidator().validate(atoms: index.atoms, relations: index.graph.relations) },
 "mechanismQuery": measure { _ = MechanismEngine().answer(.why("Effect cleanup"), in: index.graph) },
 "learnerAlignment": measure { _ = ExplanationAligner().align(explanation: cases[7].text, concept: cases[7].concept, in: index.graph) },
 "counterfactualQuery": measure { _ = CounterfactualEngine().evaluate(.removed("Effect cleanup"), in: index.graph) },
 "multiSourceSynthesis": measure { _ = MultiSourceSynthesizer().compare(synthesisPairs[0].0, synthesisPairs[0].1, in: index) }
]
try write(perf, "performance")
let unsupportedBridges = chains.flatMap(\.paths).flatMap(\.steps).filter { step in
    guard let edge = index.graph.relation(step.relationID) else { return true }
    return !index.admits(edge) || edge.kind != step.kind || edge.provenance != step.provenance || !step.provenance.isComplete
}.count
let inventedConsequences = counterfactuals.flatMap(\.consequences).filter { result in
    result.polarity == .failureFollows || result.viaChain.links.compactMap(\.viaRelation).contains { index.graph.relation($0) == nil }
}.count
let unsupportedSynthesis = syntheses.flatMap(\.statements).filter { line in
    !line.provenance.spans.allSatisfy { CanonicalSource.verifies($0, documents: docs) } || line.atomIDs.isEmpty
}.count
let failures = learner.filter { !$0.passed }.count
var audit: [String: Int] = [:]
audit["samplePagesWithAtoms"] = results.filter { !$0.atoms.isEmpty }.count
audit["sampleAtoms"] = atoms.count
audit["sourceRelations"] = index.graph.relations.filter(\.isSourceSupported).count
audit["definitionSubstitutions"] = index.inferred.count
audit["crossDocumentRelations"] = index.crossDocument.count
audit["mechanismAnswers"] = chains.filter { !$0.paths.isEmpty }.count
audit["multiStepAnswers"] = chains.filter { $0.paths.contains { $0.steps.count > 1 } }.count
audit["counterfactualScenarios"] = counterfactuals.count
audit["learnerCases"] = learner.count
audit["learnerFailures"] = failures
audit["synthesisCases"] = syntheses.count
audit["unsupportedBridges"] = unsupportedBridges
audit["inventedConsequences"] = inventedConsequences
audit["unsupportedSynthesis"] = unsupportedSynthesis
audit["manufacturedContrasts"] = syntheses.filter { $0.kind == .disagreement }.count
try write(audit, "audit")
print("AUDIT", audit)
precondition(audit["samplePagesWithAtoms"]! >= 32 && atoms.count >= 60 && index.inferred.count >= 5 && index.crossDocument.count >= 10)
precondition(audit["multiStepAnswers"]! >= 5 && syntheses.count >= 15 && failures == 0)
precondition(unsupportedBridges == 0 && inventedConsequences == 0 && unsupportedSynthesis == 0)
precondition(["mechanismQuery", "learnerAlignment", "counterfactualQuery"].allSatisfy { perf[$0]!.p50MS < 100 })
