import XCTest
@testable import ShelfCore

/// THROWAWAY — V37 capability spike only (branch `claude/v37-capability-spike`, never merged).
/// Exports the concept and passage catalogue the spike's case authors write against, built from
/// the same knowledge bases and `DiagnosisTarget`s the generalization harness scores with, so
/// every credit and misconception anchor an author copies is a sentence the harness can find.
/// Runs only when `LEU_SPIKE_CATALOG` names the output file.
final class ZZSpikeCatalog: XCTestCase {
    func testExportCatalog() throws {
        guard let output = ProcessInfo.processInfo.environment["LEU_SPIKE_CATALOG"] else { return }
        var concepts: [[String: Any]] = []
        var passages: [[String: Any]] = []
        for document in LearningCorpus.documents.map(\.title).sorted() {
            let base = try XCTUnwrap(LearningCorpus.knowledge[document])
            var keys = Set<String>()
            for entry in base.concepts where keys.insert(entry.key.value).inserted {
                guard let target = DiagnosisTarget.concept(entry.key, in: base) else { continue }
                let card = base.concept(entry.key) ?? entry
                let neighbours = target.names.keys.filter { $0 != entry.key }
                    .map { base.concept($0)?.name ?? $0.value }.sorted()
                let partner = base.contrasts(of: entry.key).first.map { base.concept($0)?.name ?? $0.value } ?? "-"
                concepts.append([
                    "concept": target.conceptName ?? card.name,
                    "key": entry.key.value,
                    "document": document,
                    "page": card.pageIndex,
                    "section": card.section ?? "",
                    "examples": card.examples.map(\.text),
                    "neighbours": neighbours,
                    "contrastPartner": partner,
                    "rubric": target.rubric.map { ["id": $0.id, "kind": $0.kind.rawValue, "text": $0.evidence.text] },
                    "supporting": target.supporting.map(\.evidence.text),
                    "supportingIDs": target.supporting.map(\.id),
                ])
            }
            let analysis = LearningCorpus.analysis(document)
            for page in analysis.pages.indices where analysis.pages[page].canonicalText != nil {
                // A page that resolves to one concept card is that concept's target, not a passage.
                guard let target = DiagnosisTarget.passage(DiagnosisEvaluation.pageSource(document, page), in: base),
                      target.concept == nil else { continue }
                passages.append([
                    "document": document,
                    "page": page,
                    "pageText": analysis.pages[page].canonicalText ?? "",
                    "rubric": target.rubric.map { ["id": $0.id, "kind": $0.kind.rawValue, "text": $0.evidence.text] },
                    "supporting": target.supporting.map(\.evidence.text),
                    "supportingIDs": target.supporting.map(\.id),
                ])
            }
        }
        let catalog: [String: Any] = ["concepts": concepts, "passages": passages]
        let data = try JSONSerialization.data(withJSONObject: catalog, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: URL(fileURLWithPath: output))
        print("SPIKE-CATALOG concepts=\(concepts.count) passages=\(passages.count) -> \(output)")
    }
}
