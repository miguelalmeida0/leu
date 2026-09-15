import Foundation

public extension IntelligenceSource {
    /// Bind inside the selected passage first. A duplicate elsewhere on the page
    /// must not redirect a model citation to a different occurrence.
    func exactExcerpt(_ quote: String, in analyses: [UUID: DocumentAnalysis]) -> LearningSource? {
        guard !quote.isEmpty, isCurrent(in: analyses), let base = passage.range else { return nil }
        let local = (passage.sourceText as NSString).range(of: quote, options: .literal)
        guard local.location != NSNotFound, NSMaxRange(local) <= base.length else { return nil }
        let resolved = NSRange(location: base.location + local.location, length: local.length)
        let page = packet.sourceText as NSString
        guard NSMaxRange(resolved) <= page.length,
              page.substring(with: resolved).utf16.elementsEqual(quote.utf16) else { return nil }
        return LearningSource(documentID: packet.documentID, pageIndex: packet.pageIndex,
            sourceText: quote, range: .init(location: resolved.location, length: resolved.length),
            sectionTitle: passage.sectionTitle)
    }
}

public extension SourceTextRange {
    /// Validate again against the actual PDF text layer before a strict route
    /// highlights anything. A changed offset never falls back to another quote.
    func exactMatch(in pageText: String, quote: String) -> NSRange? {
        let page = pageText as NSString
        guard location >= 0, length > 0, length <= page.length,
              location <= page.length - length else { return nil }
        let range = NSRange(location: location, length: length)
        guard page.substring(with: range).utf16.elementsEqual(quote.utf16) else { return nil }
        return range
    }
}
