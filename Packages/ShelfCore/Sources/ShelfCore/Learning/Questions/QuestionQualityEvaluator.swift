import Foundation

/// Deterministic quality gate for generated questions. It never invents or rewrites source material.
public struct QuestionQualityEvaluator: Sendable {
    public init() {}

    public func score(_ question: LearningQuestion) -> Double {
        guard let correct = question.correctOption else { return 0 }
        let prompt = clean(question.prompt)
        let source = clean(question.source.sourceText)
        let options = question.options.map { clean($0.text) }
        guard !prompt.isEmpty, !source.isEmpty, options.count >= 3 else { return 0 }

        let normalized = options.map(normalize)
        let uniqueness = Set(normalized).count == normalized.count ? 1.0 : 0.0
        let correctCount = normalized.filter { $0 == normalize(correct.text) }.count
        let answerUniqueness = correctCount == 1 ? 1.0 : 0.0
        let sourceClarity = clarity(source)
        let completeness = sentenceCompleteness(source)
        let distractors = distractorQuality(options: options, correct: correct.text)
        let topicRelevance = question.topicIDs.isEmpty ? 0.72 : 1.0
        let lengthPenalty = max(0, source.count > 220 ? Double(source.count - 220) / 220.0 : 0)
        let ambiguityPenalty = beginsWithPronoun(source) ? 0.16 : 0

        let positive = sourceClarity * 0.22 + completeness * 0.16 + uniqueness * 0.16 +
            answerUniqueness * 0.18 + distractors * 0.18 + topicRelevance * 0.10
        return min(1, max(0, positive - min(0.22, lengthPenalty * 0.12) - ambiguityPenalty))
    }

    public func accepts(_ question: LearningQuestion, threshold: Double = 0.58) -> Bool {
        score(question) >= threshold
    }

    private func clarity(_ source: String) -> Double {
        guard source.count >= 18 else { return 0.25 }
        if source.count <= 190 { return 1.0 }
        if source.count <= 280 { return 0.82 }
        return 0.62
    }

    private func sentenceCompleteness(_ source: String) -> Double {
        let words = source.split(whereSeparator: { $0.isWhitespace })
        guard words.count >= 4 else { return 0.35 }
        let final = source.last
        let closes = final.map { ".?!:;".contains($0) } ?? false
        return closes ? 1.0 : 0.82
    }

    private func distractorQuality(options: [String], correct: String) -> Double {
        let distractors = options.filter { normalize($0) != normalize(correct) }
        guard distractors.count >= 2 else { return 0 }
        let correctLength = max(1, correct.count)
        let ratios = distractors.map { option in
            Double(min(correctLength, max(1, option.count))) / Double(max(correctLength, max(1, option.count)))
        }
        return ratios.reduce(0, +) / Double(ratios.count)
    }

    private func beginsWithPronoun(_ text: String) -> Bool {
        let first = normalize(text.split(separator: " ").first.map(String.init) ?? "")
        return ["it", "this", "that", "they", "these", "those", "he", "she"].contains(first)
    }

    private func clean(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalize(_ text: String) -> String {
        clean(text).folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }
}
