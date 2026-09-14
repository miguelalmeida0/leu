import Foundation

/// Protocol/version/status forms that sound poor when generic operator rules see them first.
public struct NetworkingSpeechNormalizer: Sendable {
    public init() {}

    public func normalize(_ input: String) -> String {
        var text = input
        text = SpeechRegex.replace(#"\bHTTP/([123])(?:\.([01]))?\b"#, in: text, with: "H T T P $1 $2", options: [.caseInsensitive])
        text = SpeechRegex.replace(#"\bHTTPS\s+404\b"#, in: text, with: "H T T P S four oh four")
        text = SpeechRegex.replace(#"\bHTTP\s+404\b"#, in: text, with: "H T T P four oh four")
        text = SpeechRegex.replace(#"\bHTTP\s+401\b"#, in: text, with: "H T T P four oh one")
        text = SpeechRegex.replace(#"\bHTTP\s+403\b"#, in: text, with: "H T T P four oh three")
        text = SpeechRegex.replace(#"\bHTTP\s+500\b"#, in: text, with: "H T T P five hundred")
        text = SpeechRegex.replace(#"\bHTTP\s+502\b"#, in: text, with: "H T T P five oh two")
        text = SpeechRegex.replace(#"\bHTTP\s+503\b"#, in: text, with: "H T T P five oh three")
        return SpeechRegex.collapseWhitespace(text)
    }
}
