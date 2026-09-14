import Foundation

public struct TechnicalTokenizer: Sendable {
    public static let genericTerms: Set<String> = [
        "system", "data", "function", "component", "application", "process", "value",
        "information", "object", "method", "result", "type", "code", "user", "page"
    ]

    private static let stopWords: Set<String> = [
        "the", "a", "an", "and", "or", "but", "if", "then", "than", "to", "of", "in", "on",
        "for", "from", "with", "without", "is", "are", "was", "were", "be", "been", "being",
        "this", "that", "these", "those", "it", "its", "as", "at", "by", "into", "when", "while",
        "which", "who", "where", "what", "how", "can", "could", "should", "would", "will", "may"
    ]

    private static let tokenRegex: NSRegularExpression = {
        let pattern = #"O\([^\n\)]{1,24}\)|C\+\+|C#|\.NET|[A-Za-z]+/[0-9]+|[A-Za-z_$][A-Za-z0-9_$]*(?:\.[A-Za-z_$][A-Za-z0-9_$]*)+(?:\(\))?|[A-Za-z][A-Za-z0-9]*(?:-[A-Za-z0-9]+)+|[A-Za-z_$][A-Za-z0-9_$]*|[0-9]+(?:\.[0-9]+)?"#
        return try! NSRegularExpression(pattern: pattern)
    }()

    public init() {}

    public func tokens(in text: String) -> [String] {
        let ns = text as NSString
        let matches = Self.tokenRegex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        var result: [String] = []
        result.reserveCapacity(matches.count * 2)
        for match in matches {
            let raw = ns.substring(with: match.range)
            let normalized = normalize(raw)
            guard !normalized.isEmpty else { continue }
            result.append(normalized)
            if normalized.contains(".") && !normalized.hasPrefix(".") {
                result.append(contentsOf: normalized.split(separator: ".").map(String.init).filter { !$0.isEmpty })
            }
        }
        return result.filter { !Self.stopWords.contains($0) }
    }

    public func termCounts(in text: String) -> [String: Int] {
        Dictionary(tokens(in: text).map { ($0, 1) }, uniquingKeysWith: +)
    }

    public func phraseCounts(in text: String) -> [String: Int] {
        let sequence = tokens(in: text).filter { token in
            token.count > 1 && !Self.genericTerms.contains(token)
        }
        guard sequence.count >= 2 else { return [:] }
        var counts: [String: Int] = [:]
        for index in sequence.indices {
            if index + 1 < sequence.count {
                counts[sequence[index] + " " + sequence[index + 1], default: 0] += 1
            }
            if index + 2 < sequence.count {
                counts[sequence[index] + " " + sequence[index + 1] + " " + sequence[index + 2], default: 0] += 1
            }
        }
        return counts
    }

    public func normalize(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if value.hasSuffix("()") { value.removeLast(2) }
        if value.hasPrefix("o(") { return value.replacingOccurrences(of: " ", with: "") }
        if value.contains(".") || value.contains("/") || value.contains("+") || value.contains("#") || value.contains("-") {
            return value
        }
        return stem(value)
    }

    private func stem(_ token: String) -> String {
        guard token.count > 4 else { return token }
        if token.hasSuffix("ies"), token.count > 5 { return String(token.dropLast(3)) + "y" }
        if token.hasSuffix("ing"), token.count > 6 {
            var base = String(token.dropLast(3))
            if base.count >= 3, base.last == base.dropLast().last { base.removeLast() }
            if base.hasSuffix("at") || base.hasSuffix("iz") { base += "e" }
            return base
        }
        if token.hasSuffix("ed"), token.count > 5 {
            var base = String(token.dropLast(2))
            if base.hasSuffix("at") || base.hasSuffix("iz") { base += "e" }
            return base
        }
        if token.hasSuffix("es"), token.count > 5 { return String(token.dropLast(2)) }
        if token.hasSuffix("s"), token.count > 4, !token.hasSuffix("ss") { return String(token.dropLast()) }
        return token
    }
}
