import Foundation

public enum CodeSpeechMode: String, Codable, Sendable { case natural, literal }

public struct CodeSpeechNormalizer: Sendable {
    private let technical = TechnicalSpeechNormalizer()
    public init() {}

    public func normalize(_ input: String, mode: CodeSpeechMode = .natural,
                          dictionary: PronunciationDictionary = PronunciationDictionary()) -> String {
        mode == .literal ? literal(input, dictionary: dictionary) : natural(input, dictionary: dictionary)
    }

    private func natural(_ input: String, dictionary: PronunciationDictionary) -> String {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if let match = capture(#"^const\s*\[\s*([A-Za-z_$][A-Za-z0-9_$]*)\s*,\s*([A-Za-z_$][A-Za-z0-9_$]*)\s*\]\s*=\s*useState\s*\(\s*([^\)]+)\s*\)\s*;?$"#, in: text), match.count == 3 {
            return "Const. \(splitIdentifier(match[0])) and \(splitIdentifier(match[1])) equals use state, initialized to \(speakLiteral(match[2]))."
        }
        text = SpeechRegex.replace(#"\b(const|let|var)\b"#, in: text, with: "$1. ")
        text = SpeechRegex.replace(#"\[\s*([^,\]]+)\s*,\s*([^\]]+)\s*\]"#, in: text, with: "$1 and $2")
        text = SpeechRegex.replace(#"\(([^\)]*)\)"#, in: text, with: " $1 ")
        text = text.replacingOccurrences(of: ";", with: ". ")
            .replacingOccurrences(of: "{", with: " ")
            .replacingOccurrences(of: "}", with: " ")
            .replacingOccurrences(of: ",", with: ", ")
        text = technical.normalize(text, dictionary: dictionary)
        text = SpeechRegex.replace(#"\b([A-Za-z_$][A-Za-z0-9_$]*)\.([A-Za-z_$][A-Za-z0-9_$]*)\b"#, in: text, with: "$1 dot $2", options: [])
        return SpeechRegex.collapseWhitespace(text)
    }

    private func literal(_ input: String, dictionary: PronunciationDictionary) -> String {
        var text = technical.normalize(input, dictionary: dictionary)
        let replacements: [(String, String)] = [
            ("[", " open square bracket "), ("]", " close square bracket "),
            ("(", " open parenthesis "), (")", " close parenthesis "),
            ("{", " open brace "), ("}", " close brace "), (",", " comma "), (";", " semicolon ")
        ]
        for pair in replacements { text = text.replacingOccurrences(of: pair.0, with: pair.1) }
        return SpeechRegex.collapseWhitespace(text)
    }

    private func capture(_ pattern: String, in input: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = input as NSString
        guard let match = regex.firstMatch(in: input, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return (1..<match.numberOfRanges).compactMap { index in
            let range = match.range(at: index); return range.location == NSNotFound ? nil : ns.substring(with: range)
        }
    }

    private func splitIdentifier(_ value: String) -> String {
        let step = SpeechRegex.replace(#"([a-z0-9])([A-Z])"#, in: value, with: "$1 $2", options: [])
        return step.replacingOccurrences(of: "_", with: " ").lowercased()
    }

    private func speakLiteral(_ value: String) -> String {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean == "0" { return "zero" }
        if clean == "1" { return "one" }
        if clean == "null" { return "null" }
        return clean
    }
}
