import Foundation

public struct ProgressiveHintBuilder: Sendable {
    public init() {}

    public func hints(for question: LearningQuestion, topicName: String? = nil) -> [ProgressiveHint] {
        var result: [ProgressiveHint] = []
        if let section = question.source.sectionTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !section.isEmpty {
            result.append(ProgressiveHint(level: 1, text: section))
        } else if let topicName = topicName?.trimmingCharacters(in: .whitespacesAndNewlines), !topicName.isEmpty {
            result.append(ProgressiveHint(level: 1, text: topicName))
        } else {
            result.append(ProgressiveHint(level: 1, text: "Source page \(question.source.pageIndex + 1)"))
        }

        let sentence = firstSentence(question.source.sourceText)
        if !sentence.isEmpty {
            result.append(ProgressiveHint(level: 2, text: obscuringAnswer(in: sentence, question: question)))
        }
        let obscuredSource = obscuringAnswer(in: question.source.sourceText, question: question)
        if obscuredSource != question.source.sourceText || question.source.sourceText.count > sentence.count {
            result.append(ProgressiveHint(level: 3, text: obscuredSource))
        }
        return result
    }


    private func obscuringAnswer(in text: String, question: LearningQuestion) -> String {
        guard let correct = question.correctOption, text.localizedCaseInsensitiveContains(correct.text) else { return text }
        return text.replacingOccurrences(
            of: correct.text,
            with: String(repeating: "•", count: min(16, max(4, correct.text.count))),
            options: .caseInsensitive
        )
    }

    private func firstSentence(_ text: String) -> String {
        if let dot = text.firstIndex(of: ".") { return String(text[...dot]) }
        return String(text.prefix(180))
    }
}
