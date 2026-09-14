import Foundation

/// Deterministic, high-confidence transformations for common TypeScript type syntax.
/// It intentionally handles only shapes whose spoken meaning is unambiguous.
public struct TypeScriptSpeechNormalizer: Sendable {
    public init() {}

    public func normalize(_ input: String) -> String {
        var text = input
        text = SpeechRegex.replace(#"\bPromise\s*<\s*([A-Za-z_$][A-Za-z0-9_$]*)\s*\[\s*\]\s*>"#,
                                   in: text, with: "Promise of an array of $1 objects", options: [])
        text = SpeechRegex.replace(#"\bArray\s*<\s*([A-Za-z_$][A-Za-z0-9_$]*)\s*>"#,
                                   in: text, with: "array of $1", options: [])
        text = SpeechRegex.replace(#"\bPromise\s*<\s*([A-Za-z_$][A-Za-z0-9_$]*)\s*>"#,
                                   in: text, with: "Promise of $1", options: [])
        text = SpeechRegex.replace(#"\b([A-Za-z_$][A-Za-z0-9_$]*)\s*\[\s*\]"#,
                                   in: text, with: "array of $1", options: [])
        return text
    }
}
