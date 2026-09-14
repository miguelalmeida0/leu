import Foundation
import PDFKit

/// Presentation-only evidence from repeated text at repeated page-edge geometry.
/// Never edits canonical text, PDF bytes, source ranges, or learning provenance.
struct PDFDocumentFurniture {
    private struct Occurrence {
        let page: Int
        let key: String
        let rect: CGRect
    }
    private let patterns: [Occurrence]

    init(document: PDFDocument) {
        let count = min(8, document.pageCount)
        guard count >= 3 else { patterns = []; return }
        var occurrences: [Occurrence] = []
        for index in 0..<count {
            guard let page = document.page(at: index), let text = page.string else { continue }
            let source = text as NSString
            var cursor = 0
            while cursor < source.length {
                var end = 0, contentEnd = 0
                source.getLineStart(nil, end: &end, contentsEnd: &contentEnd, for: NSRange(location: cursor, length: 0))
                let range = NSRange(location: cursor, length: contentEnd - cursor)
                let line = source.substring(with: range)
                if let selection = page.selection(for: range), selection.string == line,
                   let occurrence = Self.occurrence(text: line, rect: selection.bounds(for: page),
                       pageBounds: page.bounds(for: .cropBox), page: index) {
                    occurrences.append(occurrence)
                }
                guard end > cursor else { break }; cursor = end
            }
        }
        patterns = Dictionary(grouping: occurrences, by: \.key).values.compactMap { group in
            guard Set(group.map(\.page)).count >= max(3, Int(ceil(Double(count) * 0.75))),
                  let first = group.first, group.allSatisfy({ Self.samePlacement($0.rect, first.rect) }) else { return nil }
            return first
        }
    }

    func contains(_ line: PDFSpatialLine, pageBounds: CGRect) -> Bool {
        guard let candidate = Self.occurrence(text: line.text, rect: line.bounds, pageBounds: pageBounds, page: -1) else { return false }
        return patterns.contains { $0.key == candidate.key && Self.samePlacement($0.rect, candidate.rect) }
    }

    private static func occurrence(text: String, rect: CGRect, pageBounds: CGRect, page: Int) -> Occurrence? {
        guard pageBounds.width > 0, pageBounds.height > 0, !rect.isNull, !rect.isInfinite,
              rect.width > 0, rect.height > 0 else { return nil }
        let normalized = CGRect(x: (rect.minX - pageBounds.minX) / pageBounds.width,
            y: (rect.minY - pageBounds.minY) / pageBounds.height,
            width: rect.width / pageBounds.width, height: rect.height / pageBounds.height)
        let top = normalized.minY >= 0.90
        guard top || normalized.maxY <= 0.08, normalized.height <= 0.028,
              text.count <= 110, text.filter(\.isLetter).count >= 5,
              !text.contains("{"), !text.contains("}"), !text.contains(";") else { return nil }
        let key = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            .replacingOccurrences(of: #"\p{N}+"#, with: "#", options: .regularExpression)
        return Occurrence(page: page, key: "\(top ? "top" : "bottom")|\(key)", rect: normalized)
    }

    private static func samePlacement(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) <= 0.015 && abs(a.minY - b.minY) <= 0.008 &&
            abs(a.width - b.width) <= 0.05 && abs(a.height - b.height) <= 0.004
    }
}
