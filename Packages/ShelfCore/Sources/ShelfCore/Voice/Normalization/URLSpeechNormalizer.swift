import Foundation

public struct URLSpeechNormalizer: Sendable {
    public init() {}

    public func normalize(_ input: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"https?://[^\s<>]+"#, options: [.caseInsensitive]) else { return input }
        let ns = input as NSString
        let matches = regex.matches(in: input, range: NSRange(location: 0, length: ns.length)).reversed()
        var output = input
        for match in matches {
            let token = ns.substring(with: match.range)
            let spoken = speak(token)
            if let range = Range(match.range, in: output) { output.replaceSubrange(range, with: spoken) }
        }
        return output
    }

    private func speak(_ url: String) -> String {
        var value = url
        var prefix = ""
        if value.lowercased().hasPrefix("https://") { prefix = "H T T P S "; value.removeFirst(8) }
        else if value.lowercased().hasPrefix("http://") { prefix = "H T T P "; value.removeFirst(7) }
        value = value.replacingOccurrences(of: ".", with: " dot ")
            .replacingOccurrences(of: "/", with: " slash ")
            .replacingOccurrences(of: ":", with: " colon ")
            .replacingOccurrences(of: "?", with: " question mark ")
            .replacingOccurrences(of: "&", with: " and ")
            .replacingOccurrences(of: "=", with: " equals ")
        return prefix + SpeechRegex.collapseWhitespace(value)
    }
}
