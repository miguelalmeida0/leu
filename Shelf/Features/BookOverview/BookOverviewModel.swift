import Foundation
import ShelfCore

/// One chapter of a book on the overview strip.
struct ChapterSpan: Identifiable, Equatable {
    let id: String
    let number: Int
    let title: String
    let pages: Range<Int>
    /// Share of the chapter's study material you hold, when Leu has any for it.
    let understood: Double?
    /// Share of the chapter's pages behind your reading position.
    let read: Double
    let isCurrent: Bool

    /// What the chapter's fill means, in words, so the strip never relies on colour alone.
    var caption: String {
        let prefix = isCurrent ? "reading now · " : ""
        if let understood {
            return understood >= 0.98 ? prefix + "understood" : prefix + "\(Int((understood * 100).rounded()))% understood"
        }
        if read >= 0.98 { return prefix + "read" }
        return read > 0 ? prefix + "\(Int((read * 100).rounded()))% read" : (isCurrent ? "reading now" : "")
    }

    var fill: Double { understood ?? read }
}

/// A section inside the current chapter.
struct SectionLine: Identifiable, Equatable {
    let id: String
    let title: String
    let page: Int
    let read: Bool
    let looseEnd: Bool
}

/// Builds the book overview (05) from the PDF outline, the reading position and what Leu
/// remembers. Pure, so it is tested directly.
enum BookOverviewModel {
    /// Top-level chapters with their page ranges. Without a usable outline the book is cut
    /// into even parts named by their pages, so the strip still tells the truth.
    static func chapters(outline: [OutlineEntry], pageCount: Int, currentPage: Int,
                         understanding: (Range<Int>) -> Double?) -> [ChapterSpan] {
        let pageCount = max(pageCount, 1)
        let structural = outline.filter { $0.source != .landmark && $0.pageIndex < pageCount }
        let top = structural.filter { $0.depth == (structural.map(\.depth).min() ?? 0) }
        var starts: [(String, Int)] = []
        for entry in top.sorted(by: { $0.pageIndex < $1.pageIndex }) where starts.last?.1 != entry.pageIndex {
            starts.append((entry.title, entry.pageIndex))
        }
        if starts.count < 2 {
            let parts = min(8, max(1, pageCount / 12))
            starts = (0..<parts).map { part in
                let first = part * pageCount / parts
                let last = (part + 1) * pageCount / parts
                return ("pp. \(first + 1)–\(last)", first)
            }
        }
        if let first = starts.first, first.1 > 0 { starts[0] = (first.0, 0) }
        return starts.enumerated().map { index, start in
            let end = index + 1 < starts.count ? starts[index + 1].1 : pageCount
            let range = start.1..<max(end, start.1 + 1)
            let behind = min(max(currentPage - range.lowerBound + 1, 0), range.count)
            return ChapterSpan(id: "\(index)-\(start.1)", number: index + 1, title: start.0, pages: range,
                               understood: understanding(range), read: Double(behind) / Double(range.count),
                               isCurrent: range.contains(currentPage))
        }
    }

    /// The sections of the chapter you are in, each marked read and flagged if a loose end
    /// (something fading or due) sits on its pages.
    static func sections(outline: [OutlineEntry], chapter: ChapterSpan, currentPage: Int,
                         looseEndPages: Set<Int>) -> [SectionLine] {
        let structural = outline.filter { $0.source != .landmark }
        let topDepth = structural.map(\.depth).min() ?? 0
        let inside = structural
            .filter { $0.depth > topDepth && chapter.pages.contains($0.pageIndex) }
            .sorted { $0.pageIndex < $1.pageIndex }
        return inside.enumerated().map { index, entry in
            let end = index + 1 < inside.count ? inside[index + 1].pageIndex : chapter.pages.upperBound
            let pages = entry.pageIndex..<max(end, entry.pageIndex + 1)
            return SectionLine(id: entry.id, title: entry.title, page: entry.pageIndex + 1,
                               read: entry.pageIndex < currentPage,
                               looseEnd: !looseEndPages.isDisjoint(with: Set(pages)))
        }
    }

    /// "about two fifths", "about half", "nearly all".
    static func fractionWords(_ value: Double) -> String {
        switch value {
        case ..<0.05: return "almost none"
        case ..<0.15: return "about a tenth"
        case ..<0.3: return "about a fifth"
        case ..<0.45: return "about two fifths"
        case ..<0.55: return "about half"
        case ..<0.7: return "about three fifths"
        case ..<0.9: return "most"
        default: return "nearly all"
        }
    }
}
