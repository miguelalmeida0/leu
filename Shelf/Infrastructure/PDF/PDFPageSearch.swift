import PDFKit
import ShelfCore

/// Full current-document search, independent of the bounded library index.
actor PDFPageSearch {
    func search(url: URL, query: String, bookID: UUID) throws -> [PassageMatch] {
        guard query.count >= 2, let document = PDFDocument(url: url) else { return [] }
        var matches: [PassageMatch] = []

        for pageIndex in 0..<document.pageCount {
            try Task.checkCancellation()
            let text = autoreleasepool { (document.page(at: pageIndex)?.string ?? "") as NSString }
            var range = NSRange(location: 0, length: text.length)

            while range.length > 0 {
                let match = text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive], range: range)
                guard match.location != NSNotFound else { break }

                let excerptRange = wordBoundedExcerptRange(in: text, around: match)
                let excerpt = text.substring(with: excerptRange)
                    .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                matches.append(PassageMatch(
                    bookID: bookID,
                    pageIndex: pageIndex,
                    excerpt: excerpt,
                    location: match.location,
                    length: match.length
                ))

                if matches.count >= 200 { return matches }
                let next = NSMaxRange(match)
                range = NSRange(location: next, length: text.length - next)
            }
        }
        return matches
    }

    private func wordBoundedExcerptRange(in text: NSString, around match: NSRange) -> NSRange {
        var start = max(0, match.location - 64)
        var end = min(text.length, NSMaxRange(match) + 128)

        while start > 0 {
            let scalar = text.substring(with: NSRange(location: start, length: 1))
            if scalar.rangeOfCharacter(from: .whitespacesAndNewlines) != nil { start += 1; break }
            start -= 1
            if match.location - start > 96 { break }
        }

        while end < text.length {
            let scalar = text.substring(with: NSRange(location: end, length: 1))
            if scalar.rangeOfCharacter(from: .whitespacesAndNewlines) != nil { break }
            end += 1
            if end - NSMaxRange(match) > 170 { break }
        }

        return NSRange(location: start, length: max(0, end - start))
    }
}
