import Foundation

/// One page's canonical text prepared once for many exact look-ups. Resolution semantics
/// match `CanonicalWhitespaceResolver` (whitespace-only equivalence, ambiguous matches fail),
/// without re-normalising the page for every sentence.
struct CanonicalPageIndex {
    let canonical: String
    private let normalized: NSString
    private let origins: [NSRange]
    private let dehyphenated: DehyphenatedIndex

    init(_ canonical: String) {
        self.canonical = canonical
        dehyphenated = DehyphenatedIndex(canonical)
        var normalized = "", origins: [NSRange] = [], pending: NSRange?, offset = 0
        for character in canonical {
            let width = String(character).utf16.count
            defer { offset += width }
            if character.isWhitespace {
                pending = pending.map { NSRange(location: $0.location, length: offset + width - $0.location) }
                    ?? NSRange(location: offset, length: width)
                continue
            }
            if !normalized.isEmpty, let gap = pending { normalized += " "; origins.append(gap) }
            pending = nil
            normalized.append(character)
            origins.append(contentsOf: repeatElement(NSRange(location: offset, length: width), count: width))
        }
        self.normalized = normalized as NSString
        self.origins = origins
    }

    /// The unique canonical span for `text`, or nil when absent or ambiguous. When a line-break
    /// hyphen is the only difference ("fixed-\nlength" vs "fixed-length"), the match is retried
    /// with hyphens ignored; the returned evidence is still the exact canonical substring.
    func span(_ text: String, documentID: UUID, pageIndex: Int) -> SourceSpan? {
        let needle = CanonicalWhitespaceResolver.normalize(text)
        guard !needle.isEmpty else { return nil }
        let first = normalized.range(of: needle, options: .literal)
        guard first.location != NSNotFound else {
            return dehyphenated.range(of: text).flatMap { range in
                SourceSpan(documentID: documentID, pageIndex: pageIndex,
                           range: SourceTextRange(location: range.location, length: range.length),
                           text: (canonical as NSString).substring(with: range))
            }
        }
        let next = first.location + 1
        if next < normalized.length, normalized.range(of: needle, options: .literal,
            range: NSRange(location: next, length: normalized.length - next)).location != NSNotFound { return nil }
        return make(first, documentID: documentID, pageIndex: pageIndex)
    }

    /// A heading is its own line (or a title wrapped over consecutive lines); recurring words
    /// elsewhere on the page do not make it ambiguous. The first line-anchored occurrence wins.
    func headingSpan(_ heading: String, documentID: UUID, pageIndex: Int) -> SourceSpan? {
        let target = CanonicalWhitespaceResolver.normalize(heading)
        let ns = canonical as NSString
        if let unique = span(heading, documentID: documentID, pageIndex: pageIndex) { return unique }
        var cursor = 0
        while cursor < ns.length {
            let line = ns.lineRange(for: NSRange(location: cursor, length: 0))
            let text = ns.substring(with: line)
            if CanonicalWhitespaceResolver.normalize(text) == target {
                let leading = text.prefix { $0.isWhitespace }.utf16.count
                let length = text.trimmingCharacters(in: .whitespacesAndNewlines).utf16.count
                let range = SourceTextRange(location: line.location + leading, length: length)
                return SourceSpan(documentID: documentID, pageIndex: pageIndex, range: range,
                                  text: ns.substring(with: NSRange(location: range.location, length: range.length)))
            }
            // A wrapped title: this line starts the heading and the next line completes it.
            let trimmed = CanonicalWhitespaceResolver.normalize(text)
            if !trimmed.isEmpty, target.hasPrefix(trimmed + " "), NSMaxRange(line) < ns.length {
                let next = ns.lineRange(for: NSRange(location: NSMaxRange(line), length: 0))
                let joined = CanonicalWhitespaceResolver.normalize(ns.substring(with: NSRange(location: line.location, length: NSMaxRange(next) - line.location)))
                if joined == target {
                    let leading = text.prefix { $0.isWhitespace }.utf16.count
                    let body = ns.substring(with: NSRange(location: line.location + leading, length: NSMaxRange(next) - line.location - leading))
                    let length = body.trimmingCharacters(in: .whitespacesAndNewlines).utf16.count
                    let range = SourceTextRange(location: line.location + leading, length: length)
                    return SourceSpan(documentID: documentID, pageIndex: pageIndex, range: range,
                                      text: ns.substring(with: NSRange(location: range.location, length: range.length)))
                }
            }
            cursor = NSMaxRange(line)
        }
        return nil
    }

    private func make(_ match: NSRange, documentID: UUID, pageIndex: Int) -> SourceSpan? {
        let start = origins[match.location].location
        let last = origins[NSMaxRange(match) - 1]
        let range = NSRange(location: start, length: NSMaxRange(last) - start)
        let original = (canonical as NSString).substring(with: range)
        return SourceSpan(documentID: documentID, pageIndex: pageIndex,
                          range: SourceTextRange(location: range.location, length: range.length), text: original)
    }
}

/// Normalised text with hyphens removed and whitespace dropped around line-break hyphens,
/// mapped back to canonical UTF-16 ranges. Used only as a fallback look-up.
private struct DehyphenatedIndex {
    let text: NSString
    let origins: [NSRange]

    init(_ canonical: String) {
        var output = "", origins: [NSRange] = [], offset = 0, pendingSpace: NSRange?, afterHyphen = false
        for character in canonical {
            let width = String(character).utf16.count
            defer { offset += width }
            if character == "-" { afterHyphen = true; pendingSpace = nil; continue }
            if character.isWhitespace {
                if afterHyphen { continue }
                pendingSpace = pendingSpace.map { NSRange(location: $0.location, length: offset + width - $0.location) }
                    ?? NSRange(location: offset, length: width)
                continue
            }
            if !output.isEmpty, let gap = pendingSpace { output += " "; origins.append(gap) }
            pendingSpace = nil; afterHyphen = false
            output.append(character)
            origins.append(contentsOf: repeatElement(NSRange(location: offset, length: width), count: width))
        }
        text = output as NSString; self.origins = origins
    }

    static func needle(_ value: String) -> String {
        CanonicalWhitespaceResolver.normalize(value.replacingOccurrences(of: #"-\s+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "-", with: ""))
    }

    func range(of value: String) -> NSRange? {
        let needle = Self.needle(value)
        guard !needle.isEmpty else { return nil }
        let first = text.range(of: needle, options: .literal)
        guard first.location != NSNotFound else { return nil }
        let next = first.location + 1
        if next < text.length, text.range(of: needle, options: .literal,
            range: NSRange(location: next, length: text.length - next)).location != NSNotFound { return nil }
        let start = origins[first.location].location, last = origins[NSMaxRange(first) - 1]
        return NSRange(location: start, length: NSMaxRange(last) - start)
    }
}

/// Sentence splitting for claim compilation. Unlike the V2 splitter, "?" or "!" only ends a
/// sentence before a capitalised word, so "appended to a URL after ? to alter" stays whole,
/// and "e.g." / "vs." never split.
enum ClaimSentenceSplitter {
    static func sentences(_ text: String) -> [String] {
        let characters = Array(text)
        var sentences: [String] = [], current = ""
        var index = 0
        while index < characters.count {
            let character = characters[index]
            current.append(character)
            if ".;!?".contains(character) {
                var next = index + 1
                while next < characters.count, characters[next] == " " || characters[next] == "\n" { next += 1 }
                let atEnd = next >= characters.count
                let followedBySpace = index + 1 < characters.count && characters[index + 1].isWhitespace
                let nextStartsSentence = !atEnd && (characters[next].isUppercase || "\"“(".contains(characters[next]))
                let abbreviation = current.lowercased().hasSuffix("e.g.") || current.lowercased().hasSuffix("i.e.") ||
                    current.lowercased().hasSuffix(" vs.") || current.lowercased().hasSuffix("etc.") && !nextStartsSentence
                let boundary = character == ";" ? (followedBySpace || atEnd) :
                    (atEnd || (followedBySpace && nextStartsSentence && !abbreviation))
                if boundary {
                    let sentence = current.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !sentence.isEmpty { sentences.append(sentence) }
                    current = ""
                }
            }
            index += 1
        }
        let rest = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !rest.isEmpty { sentences.append(rest) }
        return sentences
    }
}
