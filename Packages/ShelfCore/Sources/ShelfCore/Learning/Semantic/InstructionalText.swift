import Foundation

/// Front matter, study instructions and how-to-use-this-book pages address the
/// reader instead of asserting something about the subject. There is no derivable
/// answer behind "Do not memorize it word-for-word", so such text must never
/// become a recall prompt or quiz truth even though it parses as a clean sentence.
public enum InstructionalText {
    // Addressing the reader is not evidence of an instruction. Match study/UI
    // commands, including commands after a sentence boundary, not pronouns.
    private static let studyCommand = #"(?im)(?:^|[.!?]\s+)(?:please\s+)?(?:(?:do not|don't|never|always)\s+)?(?:memorize\b|(?:read|re-?read|review|skip)\s+(?:(?:this|the|following|next)\s+)?(?:section|page|chapter|book|passage)\b|(?:try\s+)?answer(?:ing)?\s+(?:before|the question|these questions)\b|(?:reconstruct|recall|explain|summarize)\s+(?:the|this)\s+(?:idea|definition|passage)\b|keep\s+(?:(?:the|this)\s+)?(?:following\s+)?structure\b|use\s+this\s+(?:page|book|section)\s+to\s+(?:study|learn|review)\b|(?:swipe|tap|scroll)\s+(?:to continue|to reveal|next|left|right)\b|how to (?:use|read|study) this (?:book|guide|manual)\b)"#
    private static let conditionalStudy = #"(?i)^if you cannot (?:explain|recall|reconstruct)\b.+\b(?:reread|re-read|review|try again)\b"#

    public static func isReaderInstruction(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.range(of: studyCommand, options: .regularExpression) != nil ||
            trimmed.range(of: conditionalStudy, options: .regularExpression) != nil
    }

    public static func isSectionLabel(_ text: String) -> Bool {
        let letters = text.filter(\.isLetter).uppercased()
        return ["INONEBREATH", "MAKEITSTICK", "REALEXAMPLE"].contains(letters)
    }

    public static func isStudyFurniture(_ text: String) -> Bool {
        isSectionLabel(text) || isReaderInstruction(text) || isMemoryContent(text)
    }
    public static func excludesFromStudy(_ segment: SourceSegment) -> Bool {
        isStudyFurniture(segment.text) || isReaderInstruction(segment.sectionTitle ?? "") ||
            (segment.sectionTitle ?? "").filter(\.isLetter).uppercased() == "MAKEITSTICK" ||
            isMemoryHook(subject: segment.text, sentence: segment.text)
    }
    public static func isMemoryContent(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).range(of: #"^(?:MEMORY|MAKE IT STICK)(?:\s|:|$)"#, options: .regularExpression) != nil
    }
    public static func isReaderGuidePage(_ text: String) -> Bool {
        text.components(separatedBy: .newlines).filter { !$0.isEmpty }.prefix(3).contains {
            $0.range(of: #"(?i)^how to (?:use|read|study) this (?:manual|book|guide)\b|^use this like an interview\b"#, options: .regularExpression) != nil
        }
    }

    /// A memory hook states a resemblance, not a property. "One person viewed
    /// through two windows is still the same person" defines nothing recoverable,
    /// so a definition question built on it has no answer a reader could reason to.
    private static let analogySubject = #"(?i)\b(?:viewed|seen|looked at|written|placed|shown|pictured|imagined|drawn|held|treated|thought of)\s+(?:through|as|in|on|by|with|from|like|at)\b"#
    private static let analogyMarker = #"(?i)\b(?:is|are)\s+(?:just\s+)?like\b|\bthink of (?:it|this|them) as\b|\bimagine\b"#

    public static func isMemoryHook(subject: String, sentence: String) -> Bool {
        if subject.range(of: analogySubject, options: .regularExpression) != nil { return true }
        return sentence.range(of: analogyMarker, options: .regularExpression) != nil
    }
}
