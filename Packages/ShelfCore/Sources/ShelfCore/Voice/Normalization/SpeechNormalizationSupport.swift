import Foundation

enum SpeechRegex {
    static func replace(_ pattern: String, in input: String, with template: String,
                        options: NSRegularExpression.Options = [.caseInsensitive]) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return input }
        let range = NSRange(input.startIndex..<input.endIndex, in: input)
        return regex.stringByReplacingMatches(in: input, range: range, withTemplate: template)
    }

    static func escapedBoundaryReplace(_ literal: String, in input: String, with replacement: String) -> String {
        let escaped = NSRegularExpression.escapedPattern(for: literal)
        let pattern = #"(?<![A-Za-z0-9_$])"# + escaped + #"(?![A-Za-z0-9_$])"#
        return replace(pattern, in: input, with: NSRegularExpression.escapedTemplate(for: replacement), options: [.caseInsensitive])
    }

    static func collapseWhitespace(_ input: String) -> String {
        replace(#"[ \t]+"#, in: input, with: " ", options: [])
            .replacingOccurrences(of: " \n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
