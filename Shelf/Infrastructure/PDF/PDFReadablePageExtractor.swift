import Foundation
import PDFKit

struct PDFReadablePageExtractor {
    func extract(document: PDFDocument, pageIndex: Int, diagnostics: Bool = false,
                 furniture: PDFDocumentFurniture? = nil) -> ReadablePage {
        guard let page = document.page(at: pageIndex) else { return ReadablePage(pageIndex: pageIndex, blocks: []) }
        var tracing = diagnostics
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "--pdf-diagnostics-page"), args.indices.contains(i + 1), Int(args[i + 1]) == pageIndex + 1 {
            tracing = true
        }
        tracing = tracing || ProcessInfo.processInfo.environment["LEU_PDF_DIAGNOSTICS"] == "1"
        #endif
        let glyphs = PDFSpatialTextExtractor().glyphs(from: page)
        let canonical = page.string ?? ""
        let mapped = glyphs.sorted { $0.sourceIndex < $1.sourceIndex }.map(\.text).joined()
        guard canonical.filter({ !$0.isWhitespace }) == mapped.filter({ !$0.isWhitespace }) else {
            // Lossless reader fallback. This page is excluded from intelligence;
            // a model must never guess the missing source characters.
            return extract(text: canonical, pageIndex: pageIndex)
        }
        let lines = PDFLineGrouper().lines(from: glyphs, pageWidth: page.bounds(for: .cropBox).width, diagnostics: tracing)
        let contentLines = lines.filter { furniture?.contains($0, pageBounds: page.bounds(for: .cropBox)) != true }
        let classified = PDFBlockClassifier().classify(contentLines)
        var result = PDFTextReconstructor().reconstruct(classified, pageIndex: pageIndex, pageHeight: page.bounds(for: .cropBox).height)
        result.sourceIntegrityPassed = !canonical.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        #if DEBUG
        if tracing {
            print("[leu-pdf] page=\(pageIndex + 1) source=\(page.string ?? "") attributedAligned=\(page.string == page.attributedString?.string)")
            print("[leu-pdf] glyphs=\(glyphs.map { "\($0.sourceIndex):\($0.text):\($0.bounds):font=\($0.fontSize)" })")
            print("[leu-pdf] lines=\(lines.map { "\($0.bounds):\($0.text)" })")
            print("[leu-pdf] blocks=\(classified.map { "\($0.kind):\($0.line.text)" })")
            print("[leu-pdf] output=\(result.blocks.map(\.text))")
        }
        #endif
        return result
    }

    /// Plain text has no geometry. Preserve its information rather than inventing
    /// missing word boundaries. Real PDF extraction always takes the spatial path.
    func extract(text: String, pageIndex: Int) -> ReadablePage {
        let blocks = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { ReadableBlock(kind: .paragraph, text: $0) }
        return ReadablePage(pageIndex: pageIndex, blocks: blocks)
    }
}
