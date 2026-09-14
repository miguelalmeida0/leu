import Foundation

public enum SourcePassageMatcher {
    /// Match the entire passage on the already selected page. Layout whitespace
    /// can differ; punctuation/content cannot. Ambiguous matches fail closed.
    public static func range(of passage: String, in page: String) -> NSRange? {
        let needle = normalized(passage).text
        let haystack = normalized(page)
        guard needle.count >= 3 else { return nil }
        let ns = haystack.text as NSString
        let match = ns.range(of: needle)
        guard match.location != NSNotFound, match.length > 0 else { return nil }
        let tail = NSRange(location: NSMaxRange(match), length: ns.length - NSMaxRange(match))
        guard ns.range(of: needle, range: tail).location == NSNotFound,
              haystack.ranges.indices.contains(NSMaxRange(match) - 1) else { return nil }
        let first = haystack.ranges[match.location], last = haystack.ranges[NSMaxRange(match) - 1]
        return NSRange(location: first.location, length: NSMaxRange(last) - first.location)
    }

    private static func normalized(_ text: String) -> (text: String, ranges: [NSRange]) {
        var result = "", mapping: [NSRange] = []
        let ns = text as NSString
        var i = 0
        while i < ns.length {
            let range = ns.rangeOfComposedCharacterSequence(at: i)
            let character = ns.substring(with: range)
            i = NSMaxRange(range)
            if character.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || character == "\u{00AD}" { continue }
            let folded = character.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            result += folded
            mapping += Array(repeating: range, count: (folded as NSString).length)
        }
        return (result, mapping)
    }
}
