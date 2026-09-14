import Foundation

/// Surface cues cannot prove distractor truth, but must not disclose the answer.
enum QuestionOptionQuality {
    static func comparable(_ candidate: String, to answer: String) -> Bool {
        let a = answer.split(whereSeparator: \.isWhitespace).count
        let b = candidate.split(whereSeparator: \.isWhitespace).count
        return min(a, b) > 0 && Double(max(a, b)) / Double(min(a, b)) <= 2.5
    }

    static func rejectionReason(prompt: String, answer: String, alternatives: [String]) -> String? {
        let lengths = ([answer] + alternatives).map { $0.split(whereSeparator: \.isWhitespace).count }
        guard let shortest = lengths.min(), let longest = lengths.max(), shortest > 0,
              Double(longest) / Double(shortest) <= 2.5 else { return "option length reveals answer" }
        let query = words(prompt)
        let correctOverlap = query.intersection(words(answer)).count
        let otherOverlap = alternatives.map { query.intersection(words($0)).count }.max() ?? 0
        if correctOverlap >= 2 && correctOverlap >= otherOverlap + 2 { return "unique lexical echo" }
        return nil
    }

    private static func words(_ text: String) -> Set<String> {
        let filler: Set<String> = ["a", "an", "the", "of", "in", "on", "for", "to", "by", "with", "and", "or", "but",
            "is", "are", "does", "do", "what", "which", "how", "when", "why", "if", "from", "at", "as", "it"]
        return Set(text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)).subtracting(filler)
    }
}
