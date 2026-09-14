import Foundation

/// Small, deterministic text utilities shared by extraction and alignment.
/// Deliberately dependency-free: no NLTagger, no locale-specific behaviour, so
/// results are byte-identical on device, in CI and in fixtures.
public enum TextScanning {

    // MARK: - Sentences

    /// Splits prose into sentences without breaking on abbreviations,
    /// decimals, or code-ish tokens like `Cache-Control: max-age=60.`
    public static func sentences(in text: String) -> [String] {
        var sentences: [String] = []
        var current = ""
        let characters = Array(text)
        var index = 0
        while index < characters.count {
            let character = characters[index]
            current.append(character)
            if character == "." || character == "!" || character == "?" {
                let next = index + 1 < characters.count ? characters[index + 1] : " "
                let previous = index > 0 ? characters[index - 1] : " "
                let decimal = previous.isNumber && next.isNumber
                let abbreviation = character == "." && isAbbreviationBoundary(current)
                if !decimal && !abbreviation && (next == " " || next == "\n" || index + 1 == characters.count) {
                    sentences.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                    current = ""
                }
            }
            index += 1
        }
        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { sentences.append(tail) }
        return sentences.filter { !$0.isEmpty }
    }

    static let abbreviations: Set<String> = ["e.g.", "i.e.", "etc.", "vs.", "fig.", "no.", "approx."]

    static func isAbbreviationBoundary(_ buffer: String) -> Bool {
        let lowered = buffer.lowercased()
        return abbreviations.contains { lowered.hasSuffix($0) }
    }

    // MARK: - Tokens

    public static func words(_ text: String) -> [String] {
        text.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" })
            .map { String($0).trimmingCharacters(in: CharacterSet(charactersIn: ",;:()\"")) }
            .filter { !$0.isEmpty }
    }

    /// Lowercased, punctuation-stripped tokens used for comparison.
    public static func normalizedTokens(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_")).inverted)
            .filter { !$0.isEmpty }
    }

    /// Content tokens: normalised, stop-worded and stemmed. Used wherever two
    /// phrasings must match without requiring identical vocabulary.
    ///
    /// The trailing length filter drops leftover single letters (stray
    /// fragments of stemming or punctuation splitting), but a single-digit
    /// number is real content, not noise — "3 attempts" and "5 attempts"
    /// must not collapse into the same token set, or every comparison built
    /// on this function (equivalence, clustering, overlap scoring) goes
    /// blind to the one thing that actually distinguishes them.
    public static func contentTokens(_ text: String) -> [String] {
        normalizedTokens(text)
            .filter { !stopWords.contains($0) }
            .map { SourceRoleClassifier.stem($0) }
            .filter { $0.count > 1 || $0.allSatisfy(\.isNumber) }
    }

    public static let stopWords: Set<String> = [
        "a", "an", "the", "of", "to", "in", "on", "at", "for", "and", "or", "is", "are", "be", "been",
        "was", "were", "it", "its", "this", "that", "these", "those", "as", "by", "with", "from",
        "into", "than", "then", "so", "such", "we", "you", "your", "our", "their", "they", "he",
        "she", "will", "would", "can", "could", "do", "does", "did", "has", "have", "had", "but",
        "if", "when", "which", "what", "there", "here", "about", "each", "any", "all", "also"
    ]

    /// Jaccard overlap over content tokens. Deterministic, cheap, and good
    /// enough to tell "reuses previously fetched data" from "refetches data".
    public static func overlap(_ lhs: String, _ rhs: String) -> Double {
        let left = Set(contentTokens(lhs))
        let right = Set(contentTokens(rhs))
        guard !left.isEmpty, !right.isEmpty else { return 0 }
        let intersection = left.intersection(right).count
        let union = left.union(right).count
        return Double(intersection) / Double(union)
    }

    /// Asymmetric coverage: how much of `needle` appears in `haystack`.
    public static func coverage(of needle: String, in haystack: String) -> Double {
        let left = Set(contentTokens(needle))
        guard !left.isEmpty else { return 0 }
        let right = Set(contentTokens(haystack))
        return Double(left.intersection(right).count) / Double(left.count)
    }

    // MARK: - Structured fragments

    public static func numbers(in text: String) -> [NumericFact] {
        var facts: [NumericFact] = []
        let words = TextScanning.words(text)
        for (index, word) in words.enumerated() {
            let cleaned = word.trimmingCharacters(in: CharacterSet(charactersIn: ".,"))
            guard let value = Double(cleaned.replacingOccurrences(of: "%", with: "")),
                  cleaned.rangeOfCharacter(from: .decimalDigits) != nil else { continue }
            let previousOne = index > 0 ? words[index - 1].lowercased() : ""
            let previousTwo = index > 1 ? words[index - 2].lowercased() : ""
            var comparator = NumericFact.Comparator.exactly
            if previousOne == "least" && previousTwo == "at" { comparator = .atLeast }
            else if previousOne == "most" && previousTwo == "at" { comparator = .atMost }
            else if previousOne == "up" || previousTwo == "up" { comparator = .atMost }
            else if previousOne == "about" || previousOne == "around" || previousOne == "roughly" { comparator = .approximately }
            else if previousOne == "over" || previousOne == "more" { comparator = .atLeast }
            var unit: String?
            if cleaned.hasSuffix("%") { unit = "%" }
            else if index + 1 < words.count, words[index + 1].count <= 12,
                     words[index + 1].rangeOfCharacter(from: .decimalDigits) == nil {
                unit = words[index + 1].trimmingCharacters(in: CharacterSet(charactersIn: ".,"))
            }
            facts.append(NumericFact(comparator: comparator, value: value, unit: unit, rawText: cleaned))
        }
        return facts
    }

    public static func identifiers(in text: String) -> [SourceIdentifier] {
        var found: [SourceIdentifier] = []
        for raw in words(text) {
            let token = raw.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))
            guard !token.isEmpty else { continue }
            if token.hasPrefix("`") && token.hasSuffix("`") && token.count > 2 {
                append(&found, SourceIdentifier(kind: .apiSymbol, text: String(token.dropFirst().dropLast())))
                continue
            }
            if token.count == 3, let code = Int(token), (100..<600).contains(code) {
                append(&found, SourceIdentifier(kind: .httpStatus, text: token))
                continue
            }
            if token.contains("-"), token.split(separator: "-").allSatisfy({ $0.first?.isUppercase == true }) {
                append(&found, SourceIdentifier(kind: .header, text: token))
                continue
            }
            if isCamelCase(token) {
                append(&found, SourceIdentifier(kind: .apiSymbol, text: token))
                continue
            }
            if token.hasSuffix("()") {
                append(&found, SourceIdentifier(kind: .apiSymbol, text: token))
            }
        }
        return found
    }

    static func append(_ list: inout [SourceIdentifier], _ identifier: SourceIdentifier) {
        if !list.contains(identifier) { list.append(identifier) }
    }

    static func isCamelCase(_ token: String) -> Bool {
        guard token.count > 2, let first = token.first, first.isLowercase else { return false }
        var sawUpper = false
        for character in token.dropFirst() {
            if character.isUppercase { sawUpper = true }
            if !character.isLetter && !character.isNumber { return false }
        }
        return sawUpper
    }

    /// Concept slugs: normalised noun-ish phrases used as graph keys.
    public static func conceptSlug(_ text: String) -> String {
        contentTokens(text).prefix(4).joined(separator: "-")
    }
}
