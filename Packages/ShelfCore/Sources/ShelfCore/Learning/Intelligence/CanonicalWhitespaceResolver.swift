import Foundation

/// Whitespace is the only equivalence: case, punctuation, operators and numbers stay exact.
/// Each normalized UTF-16 unit maps back to its complete original canonical range.
public enum CanonicalWhitespaceResolver {
    public struct Span: Codable, Equatable, Sendable {
        public var range: SourceTextRange
        public var text: String
    }

    public static func normalize(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    public static func resolve(_ text: String, in canonical: String) -> Span? {
        let needle = normalize(text)
        guard !needle.isEmpty else { return nil }
        var normalized = ""
        var origins: [NSRange] = []
        var pendingWhitespace: NSRange?
        var offset = 0
        for character in canonical {
            let string = String(character)
            let width = string.utf16.count
            defer { offset += width }
            if character.isWhitespace {
                if let pending = pendingWhitespace {
                    pendingWhitespace = NSRange(location: pending.location, length: offset + width - pending.location)
                } else { pendingWhitespace = NSRange(location: offset, length: width) }
                continue
            }
            if !normalized.isEmpty, let pending = pendingWhitespace {
                normalized += " "; origins.append(pending)
            }
            pendingWhitespace = nil
            normalized += string
            origins.append(contentsOf: Array(repeating: NSRange(location: offset, length: width), count: width))
        }
        let ns = normalized as NSString
        let first = ns.range(of: needle, options: .literal)
        guard first.location != NSNotFound else { return nil }
        // Overlapping occurrences are ambiguous too. Never choose the first match silently.
        let next = first.location + 1
        if next < ns.length, ns.range(of: needle, options: .literal,
            range: NSRange(location: next, length: ns.length - next)).location != NSNotFound { return nil }
        let start = origins[first.location].location
        let last = origins[NSMaxRange(first) - 1]
        let range = NSRange(location: start, length: NSMaxRange(last) - start)
        let original = (canonical as NSString).substring(with: range)
        guard normalize(original) == needle else { return nil }
        return Span(range: SourceTextRange(location: range.location, length: range.length), text: original)
    }
}
