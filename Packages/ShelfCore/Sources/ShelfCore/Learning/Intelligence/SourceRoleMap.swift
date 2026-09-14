import Foundation

public enum IntelligenceSourceRole: String, Codable, Sendable {
    case factualExplanation, supportingExample, mnemonic, interviewInstruction, advice, heading, unclassified
    public var admitsCanonicalFact: Bool { self == .factualExplanation || self == .unclassified }
}

/// Classification never edits canonical text. Tracked lettering is normalized
/// only to recognize a closed set of section headings, not arbitrary prose/code.
public struct SourceRoleMap: Sendable {
    public struct Section: Equatable, Sendable {
        public let role: IntelligenceSourceRole
        public let range: NSRange
    }
    public let sections: [Section]
    public init(canonicalText: String) {
        let ns = canonicalText as NSString
        var sections: [Section] = [], cursor = 0, start = 0
        var role: IntelligenceSourceRole = .unclassified
        while cursor < ns.length {
            let lineRange = ns.lineRange(for: NSRange(location: cursor, length: 0))
            let line = ns.substring(with: lineRange).trimmingCharacters(in: .whitespacesAndNewlines)
            if let next = Self.headingRole(line) {
                if lineRange.location > start {
                    sections.append(.init(role: role, range: NSRange(location: start, length: lineRange.location - start)))
                }
                sections.append(.init(role: .heading, range: lineRange))
                start = NSMaxRange(lineRange); role = next
            }
            cursor = NSMaxRange(lineRange)
        }
        if start < ns.length { sections.append(.init(role: role, range: NSRange(location: start, length: ns.length - start))) }
        self.sections = sections
    }
    public func role(for range: NSRange) -> IntelligenceSourceRole? {
        guard range.location >= 0, range.length > 0 else { return nil }
        return sections.first { NSIntersectionRange($0.range, range) == range }?.role
    }
    public static func headingRole(_ text: String) -> IntelligenceSourceRole? {
        let letters = text.uppercased().filter { $0.isLetter }
        switch letters {
        case "INONEBREATH": return .factualExplanation
        case "MAKEITSTICK": return .mnemonic
        case "REALEXAMPLE": return .supportingExample
        case "SAYTHISINTHEINTERVIEW", "SAYTHISININTERVIEW": return .interviewInstruction
        case "WATCHLEVELUP", "WATCH", "LEVELUP": return .advice
        default: return nil
        }
    }
}
