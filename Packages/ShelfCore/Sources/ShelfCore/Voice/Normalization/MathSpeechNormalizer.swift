import Foundation

public struct MathSpeechNormalizer: Sendable {
    public init() {}

    public func normalize(_ input: String) -> String {
        var text = input
        text = SpeechRegex.replace(#"O\s*\(\s*log\s+n\s*\)"#, in: text, with: "O of log n")
        text = SpeechRegex.replace(#"O\s*\(\s*n\s*[²2]\s*\)"#, in: text, with: "O of n squared")
        text = SpeechRegex.replace(#"O\s*\(\s*n\s*\^\s*2\s*\)"#, in: text, with: "O of n squared")
        text = SpeechRegex.replace(#"O\s*\(\s*n\s*\)"#, in: text, with: "O of n")
        text = SpeechRegex.replace(#"O\s*\(\s*1\s*\)"#, in: text, with: "O of one")
        text = text.replacingOccurrences(of: "n²", with: "n squared")
            .replacingOccurrences(of: "n^2", with: "n squared")
        return text
    }
}
