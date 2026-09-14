import Foundation
import PDFKit

struct TimedReadingPlan: Identifiable, Equatable {
    let id = UUID()
    let requestedMinutes: Int
    let startPage: Int
    let endPage: Int
    let estimatedMinutes: Int
    let boundaryTitle: String?

    var pageCount: Int { max(1, endPage - startPage + 1) }
    var summary: String {
        let pages = startPage == endPage ? "p. \(startPage + 1)" : "pp. \(startPage + 1)–\(endPage + 1)"
        return "About \(estimatedMinutes) min · \(pages)"
    }
}

@MainActor
struct ReadingWindowPlanner {
    private let wordsPerMinute = 220

    func plan(document: PDFDocument, outline: [OutlineEntry], startPage: Int,
              startSentence: String? = nil, minutes: Int) -> TimedReadingPlan {
        let safeStart = min(max(startPage, 0), max(document.pageCount - 1, 0))
        let targetWords = max(120, minutes * wordsPerMinute)
        let lowerTarget = Int(Double(targetWords) * 0.68)
        let upperTarget = Int(Double(targetWords) * 1.35)
        var cumulativeWords = 0
        var candidates: [(page: Int, words: Int, title: String?, isBoundary: Bool)] = []

        for pageIndex in safeStart..<document.pageCount {
            let fullText = document.page(at: pageIndex)?.string ?? ""
            let readableText = pageIndex == safeStart ? textFromAnchor(fullText, sentence: startSentence) : fullText
            cumulativeWords += wordCount(readableText)
            let nextOutline = outline.first { $0.pageIndex == pageIndex + 1 && $0.isStructuralBoundary }
            let isBoundary = nextOutline != nil
            if cumulativeWords >= lowerTarget {
                candidates.append((pageIndex, cumulativeWords, nextOutline?.title, isBoundary))
            }
            if cumulativeWords >= upperTarget { break }
        }

        let best = candidates.min { lhs, rhs in
            score(lhs, target: targetWords) < score(rhs, target: targetWords)
        } ?? (safeStart, max(1, wordCount(textFromAnchor(document.page(at: safeStart)?.string ?? "", sentence: startSentence))), nil, false)

        let estimate = max(1, Int((Double(best.words) / Double(wordsPerMinute)).rounded()))
        return TimedReadingPlan(requestedMinutes: minutes, startPage: safeStart,
                                endPage: best.page, estimatedMinutes: estimate,
                                boundaryTitle: best.title)
    }

    private func textFromAnchor(_ text: String, sentence: String?) -> String {
        guard let sentence, !sentence.isEmpty,
              let range = text.range(of: sentence, options: [.caseInsensitive, .diacriticInsensitive]) else { return text }
        return String(text[range.lowerBound...])
    }

    private func score(_ candidate: (page: Int, words: Int, title: String?, isBoundary: Bool), target: Int) -> Double {
        let distance = abs(Double(candidate.words - target)) / Double(max(target, 1))
        return distance - (candidate.isBoundary ? 0.16 : 0)
    }

    private func wordCount(_ text: String) -> Int {
        text.split { $0.isWhitespace || $0.isNewline }.count
    }
}
