import Foundation
import ShelfCore

@main struct SourceExcerptChecks {
    static func main() throws {
        let quote = "The café flag is green."
        let first = "First record: " + quote + " This is an archived example."
        let selected = "Second record 🟢: " + quote + " This is the currently selected record."
        let full = first + "\n\n" + selected
        let document = UUID()
        var page = AnalyzedPage(pageIndex: 2, normalizedText: full,
            segments: [.init(pageIndex: 2, kind: .paragraph, text: full)])
        page.canonicalText = full; page.spatialIntegrityPassed = true
        var analysis = DocumentAnalysis(documentID: document, fingerprint: "excerpt-fixture", algorithmVersion: 5, pages: [page])
        analysis.extractionVersion = SourceExtractionVersion.current
        let source = IntelligenceSource(source: .init(documentID: document, pageIndex: 2, sourceText: selected), analysis: analysis)!
        let analyses = [document: analysis]
        let excerpt = source.exactExcerpt(quote, in: analyses)
        let expected = (full as NSString).range(of: quote, options: [.literal, .backwards])
        var checks: [[String: Any]] = [
            ["name": "Repeated quote resolves within the selected second passage", "passed": excerpt?.range == SourceTextRange(location: expected.location, length: expected.length)],
            ["name": "Unicode excerpt retains exact text, document and page", "passed": excerpt?.sourceText.utf16.elementsEqual(quote.utf16) == true && excerpt?.documentID == document && excerpt?.pageIndex == 2],
            ["name": "Quote elsewhere on the page cannot escape the selected passage", "passed": source.exactExcerpt("First record", in: analyses) == nil],
            ["name": "Empty quote cannot create a zero-length route", "passed": source.exactExcerpt("", in: analyses) == nil],
            ["name": "Missing document cannot produce a route", "passed": source.exactExcerpt(quote, in: [:]) == nil]
        ]
        checks.append(["name": "Reader range validates against the original PDF text layer", "passed": excerpt?.range?.exactMatch(in: full, quote: quote) == expected])
        checks.append(["name": "Changed PDF offsets refuse highlighting rather than finding another occurrence", "passed": excerpt?.range?.exactMatch(in: "Changed prefix " + full, quote: quote) == nil])
        checks.append(["name": "Out-of-bounds PDF range is rejected without overflow", "passed": SourceTextRange(location: Int.max, length: 1).exactMatch(in: full, quote: quote) == nil])
        analysis.fingerprint = "changed"
        checks.append(["name": "Stale source cannot produce a route", "passed": source.exactExcerpt(quote, in: [document: analysis]) == nil])
        let output = CommandLine.arguments.count > 1 ? URL(fileURLWithPath: CommandLine.arguments[1]) : URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("docs/qwen-local/source-excerpt-final-checks.json")
        guard !FileManager.default.fileExists(atPath: output.path) else { fatalError("Preserve existing evidence") }
        try JSONSerialization.data(withJSONObject: ["checks": checks, "scope": "Host source-range binding; rendered PDF highlight remains PENDING"], options: [.prettyPrinted, .sortedKeys]).write(to: output)
        if checks.contains(where: { $0["passed"] as? Bool != true }) { exit(1) }
    }
}
