import Foundation
import LeuReasoningCore

struct Challenge: Codable { let id, source, learner: String; let support: [String]; let coverage, why: String }
struct Outcome: Codable { let id: String; let report: ExplanationAlignmentReport; let supportCorrect: Bool; let coverage: String; let coverageCorrect: Bool; let falseApprovals: Int }
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let cases = try JSONDecoder().decode([Challenge].self, from: Data(contentsOf: root.appendingPathComponent("evidence/v29.1/challenge.json")))
let outcomes = cases.map { item -> Outcome in
    let atoms = PacketAtomExtractor().extractProse(.init(documentID: "challenge", page: 1, canonicalSpan: item.source, sourceRole: .explanation)).atoms
    let graph = KnowledgeGraphBuilder().build(atoms: atoms)
    let report = SourceBoundExplanationAligner().align(explanation: item.learner, concept: nil, in: graph)
    // BEFORE's only available coverage signal was unaddressed atoms. This is
    // deliberately reported as-is; the new API replaces it after the repair.
    let coverage = report.unaddressedAtomIDs.isEmpty ? "complete" : "incomplete"
    let actual = report.alignments.map { $0.verdict.rawValue }
    let falseApprovals = actual.enumerated().filter { $0.element == "supported" && (item.support.indices.contains($0.offset) ? item.support[$0.offset] != "supported" : true) }.count
    return Outcome(id: item.id, report: report, supportCorrect: actual == item.support, coverage: coverage, coverageCorrect: coverage == item.coverage, falseApprovals: falseApprovals)
}
let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
try encoder.encode(outcomes).write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
print("support \(outcomes.filter(\.supportCorrect).count)/\(outcomes.count); coverage \(outcomes.filter(\.coverageCorrect).count)/\(outcomes.count); false approvals \(outcomes.map(\.falseApprovals).reduce(0,+))")
