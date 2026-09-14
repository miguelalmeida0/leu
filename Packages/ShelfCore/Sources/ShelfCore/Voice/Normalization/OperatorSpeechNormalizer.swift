import Foundation

public struct OperatorSpeechNormalizer: Sendable {
    public init() {}

    public func normalize(_ input: String) -> String {
        var text = input
        text = SpeechRegex.replace(#"===\s+performs\s+strict\s+equality"#, in: text,
                                   with: "the strict equality operator performs strict equality")
        text = SpeechRegex.replace(#"!==\s+performs\s+strict\s+inequality"#, in: text,
                                   with: "the strict inequality operator performs strict inequality")
        let replacements: [(String, String)] = [
            (#"!=="#, " strictly does not equal "), (#"==="# , " strictly equals "),
            (#">="# , " greater than or equal to "), (#"<="# , " less than or equal to "),
            (#"!="# , " does not equal "), (#"=="#, " equals "),
            (#"&&"#, " and "), (#"\|\|"#, " or "), (#"=>"#, " arrow "),
            (#"\+\+"#, " increment "), (#"--"#, " decrement ")
        ]
        for (pattern, replacement) in replacements { text = SpeechRegex.replace(pattern, in: text, with: replacement, options: []) }
        text = SpeechRegex.replace(#"(?<![<])>(?![=>])"#, in: text, with: " greater than ", options: [])
        text = SpeechRegex.replace(#"(?<![>])<(?![=<])"#, in: text, with: " less than ", options: [])
        text = SpeechRegex.replace(#"!\s*([A-Za-z_$][A-Za-z0-9_$]*)"#, in: text, with: "not $1", options: [])
        return SpeechRegex.collapseWhitespace(text)
    }
}
