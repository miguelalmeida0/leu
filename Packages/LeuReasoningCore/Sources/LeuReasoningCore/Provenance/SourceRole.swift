import Foundation

/// The communicative job a block of source text is doing.
///
/// Role matters because the same sentence means different things to the
/// reasoning engine depending on where it sits. "Keys must be stable" inside a
/// factual explanation is a claim about the world; the same words inside a
/// mnemonic are a memory aid, and inside interview advice they are a script.
public enum SourceRole: String, Codable, CaseIterable, Sendable {
    /// Compact factual explanation ("IN ONE BREATH" in the mobile-mastery layout).
    case compactExplanation
    /// Ordinary explanatory prose.
    case explanation
    /// Memory aid ("MAKE IT STICK"). Never a source of mechanism claims.
    case mnemonic
    /// Concrete illustration ("REAL EXAMPLE").
    case example
    /// Advice about how to present an idea ("SAY THIS IN THE INTERVIEW").
    case presentationAdvice
    /// Caution, pitfall or level-up note ("WATCH OUT", "LEVEL-UP").
    case caution
    /// Section label / heading. Structure, not content.
    case structure
    /// Running headers, footers, page numbers, branding.
    case furniture
    case unknown

    /// Roles whose sentences may produce first-class factual atoms.
    public var yieldsFactualClaims: Bool {
        switch self {
        case .compactExplanation, .explanation, .caution, .example: return true
        case .mnemonic, .presentationAdvice, .structure, .furniture, .unknown: return false
        }
    }

    /// Roles that may be quoted to a learner as an illustration.
    public var isIllustrative: Bool { self == .example }

    /// How much a claim from this role should be trusted as a *mechanism*
    /// statement rather than a paraphrase or a slogan.
    public var mechanismWeight: Double {
        switch self {
        case .compactExplanation: return 1.0
        case .explanation: return 0.95
        case .caution: return 0.85
        case .example: return 0.6
        default: return 0.0
        }
    }
}

/// A raw block of text handed to the classifier, with whatever layout signal
/// the extractor was able to recover. Every optional field is genuinely
/// optional: the classifier degrades to lexical + structural cues alone.
public struct SourceBlock: Codable, Equatable, Sendable {
    public var documentID: String
    public var page: Int
    public var indexOnPage: Int
    public var text: String
    /// Typography, when the PDF pipeline exposes it.
    public var fontSize: Double?
    public var isBold: Bool?
    public var isAllCaps: Bool?
    /// Normalised vertical position, 0 = top of page, 1 = bottom.
    public var verticalPosition: Double?

    public init(documentID: String,
                page: Int,
                indexOnPage: Int,
                text: String,
                fontSize: Double? = nil,
                isBold: Bool? = nil,
                isAllCaps: Bool? = nil,
                verticalPosition: Double? = nil) {
        self.documentID = documentID
        self.page = page
        self.indexOnPage = indexOnPage
        self.text = text
        self.fontSize = fontSize
        self.isBold = isBold
        self.isAllCaps = isAllCaps
        self.verticalPosition = verticalPosition
    }
}

public struct SourceRoleAssignment: Codable, Equatable, Sendable {
    public var block: SourceBlock
    public var role: SourceRole
    public var confidence: Double
    /// Human readable signals, so a role decision is never opaque.
    public var evidence: [String]
    /// The heading this block sits under, when one was found.
    public var governingHeading: String?

    public init(block: SourceBlock,
                role: SourceRole,
                confidence: Double,
                evidence: [String],
                governingHeading: String? = nil) {
        self.block = block
        self.role = role
        self.confidence = confidence
        self.evidence = evidence
        self.governingHeading = governingHeading
    }
}

/// Classifies blocks into roles from generalising signals rather than a
/// blacklist of literal heading strings.
///
/// Four signal families, applied in order:
///  1. repetition across pages (furniture),
///  2. typography / brevity / punctuation (structure),
///  3. lexical cue families on headings (which role a section carries),
///  4. inheritance from the governing heading, with a prose fallback.
public struct SourceRoleClassifier: Sendable {
    public init() {}

    /// Cue families. These are *seeds* for a lexical family, matched by token
    /// overlap and stemming, so unseen heading wordings ("in a nutshell",
    /// "memory hook", "common traps") still land in the right family.
    static let cueFamilies: [(role: SourceRole, cues: [String])] = [
        (.compactExplanation, ["breath", "nutshell", "essence", "short", "summary", "core", "gist", "brief", "one", "line"]),
        (.mnemonic, ["stick", "remember", "memory", "mnemonic", "hook", "trick", "recall", "chant"]),
        (.example, ["example", "real", "case", "scenario", "practice", "sample", "walkthrough", "demo", "story"]),
        (.presentationAdvice, ["say", "interview", "answer", "pitch", "script", "tell", "phrase", "respond", "wording"]),
        (.caution, ["watch", "caution", "careful", "gotcha", "pitfall", "trap", "mistake", "level", "up", "warning", "avoid"])
    ]

    public func classify(blocks: [SourceBlock]) -> [SourceRoleAssignment] {
        let repeated = repeatedTexts(in: blocks)
        let typicalFontSize = medianFontSize(in: blocks)

        var assignments: [SourceRoleAssignment] = []
        var currentHeading: (text: String, role: SourceRole)?
        var currentPage = blocks.first?.page

        for block in blocks.sorted(by: SourceRoleClassifier.readingOrder) {
            if block.page != currentPage {
                currentPage = block.page
                // A heading keeps governing across a page break only when the
                // next page does not open with its own heading; resolved below.
            }
            let normalized = SourceRoleClassifier.normalize(block.text)

            if repeated.contains(normalized) || isPageFurniture(block) {
                assignments.append(SourceRoleAssignment(block: block,
                                                        role: .furniture,
                                                        confidence: 0.9,
                                                        evidence: repeated.contains(normalized)
                                                            ? ["identical text repeats across pages"]
                                                            : ["page-edge position with page-number shape"]))
                continue
            }

            if let headingEvidence = headingSignals(block, typicalFontSize: typicalFontSize) {
                let family = lexicalFamily(for: block.text)
                currentHeading = (block.text, family?.role ?? .explanation)
                var evidence = headingEvidence
                if let family {
                    evidence.append("heading vocabulary matches \(family.role.rawValue) family (\(family.matched.joined(separator: ", ")))")
                }
                assignments.append(SourceRoleAssignment(block: block,
                                                        role: .structure,
                                                        confidence: min(1.0, 0.6 + 0.1 * Double(evidence.count)),
                                                        evidence: evidence,
                                                        governingHeading: nil))
                continue
            }

            // Body block: inherit from the governing heading, unless the block
            // itself carries a strong inline cue.
            if let inline = inlineFamily(for: block.text) {
                assignments.append(SourceRoleAssignment(block: block,
                                                        role: inline.role,
                                                        confidence: 0.7,
                                                        evidence: ["inline cue (\(inline.matched.joined(separator: ", ")))"],
                                                        governingHeading: currentHeading?.text))
                continue
            }

            if let heading = currentHeading {
                assignments.append(SourceRoleAssignment(block: block,
                                                        role: heading.role,
                                                        confidence: 0.8,
                                                        evidence: ["inherits role from heading \"\(heading.text)\""],
                                                        governingHeading: heading.text))
            } else {
                assignments.append(SourceRoleAssignment(block: block,
                                                        role: .explanation,
                                                        confidence: 0.5,
                                                        evidence: ["prose fallback: no governing heading"],
                                                        governingHeading: nil))
            }
        }
        return assignments
    }

    // MARK: - Signals

    static func readingOrder(_ lhs: SourceBlock, _ rhs: SourceBlock) -> Bool {
        if lhs.page != rhs.page { return lhs.page < rhs.page }
        return lhs.indexOnPage < rhs.indexOnPage
    }

    /// Text that appears on three or more pages in the same position band is
    /// furniture regardless of what it says.
    func repeatedTexts(in blocks: [SourceBlock]) -> Set<String> {
        var pagesByText: [String: Set<Int>] = [:]
        for block in blocks {
            let key = SourceRoleClassifier.normalize(block.text)
            guard !key.isEmpty, key.count < 90 else { continue }
            pagesByText[key, default: []].insert(block.page)
        }
        let distinctPages = Set(blocks.map(\.page)).count
        let threshold = distinctPages >= 3 ? 3 : max(2, distinctPages)
        return Set(pagesByText.filter { $0.value.count >= threshold }.keys)
    }

    func medianFontSize(in blocks: [SourceBlock]) -> Double? {
        let sizes = blocks.compactMap(\.fontSize).sorted()
        guard !sizes.isEmpty else { return nil }
        return sizes[sizes.count / 2]
    }

    func isPageFurniture(_ block: SourceBlock) -> Bool {
        let trimmed = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        let looksLikePageNumber = trimmed.count <= 12
            && trimmed.rangeOfCharacter(from: CharacterSet.decimalDigits) != nil
            && trimmed.rangeOfCharacter(from: CharacterSet.letters.subtracting(CharacterSet(charactersIn: "Ppage"))) == nil
        if let position = block.verticalPosition, position > 0.93 || position < 0.05 {
            return looksLikePageNumber || (trimmed.count <= 40 && trimmed.hasSuffix("\u{2022}"))
        }
        return looksLikePageNumber && trimmed.count <= 4
    }

    /// Heading detection from shape, not from a known-strings list.
    func headingSignals(_ block: SourceBlock, typicalFontSize: Double?) -> [String]? {
        let trimmed = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var evidence: [String] = []
        let wordCount = trimmed.split(separator: " ").count

        if let size = block.fontSize, let typical = typicalFontSize, size > typical * 1.12 {
            evidence.append("font size \(size) exceeds body size \(typical)")
        }
        if block.isBold == true { evidence.append("bold") }
        let isCaps = block.isAllCaps ?? (trimmed == trimmed.uppercased() && trimmed.rangeOfCharacter(from: .letters) != nil)
        if isCaps && wordCount <= 8 { evidence.append("all caps, \(wordCount) words") }
        if wordCount <= 8 && !trimmed.hasSuffix(".") && !trimmed.hasSuffix("?") { evidence.append("short, unpunctuated line") }

        // Require at least two independent signals so that a short sentence in
        // body prose is not promoted to a heading.
        return evidence.count >= 2 ? evidence : nil
    }

    struct FamilyMatch { var role: SourceRole; var matched: [String] }

    func lexicalFamily(for text: String) -> FamilyMatch? {
        let tokens = SourceRoleClassifier.tokens(text)
        guard !tokens.isEmpty else { return nil }
        var best: FamilyMatch?
        var bestScore = 0
        for family in SourceRoleClassifier.cueFamilies {
            let matched = family.cues.filter { cue in
                tokens.contains { SourceRoleClassifier.sharesStem($0, cue) }
            }
            if matched.count > bestScore {
                bestScore = matched.count
                best = FamilyMatch(role: family.role, matched: matched)
            }
        }
        return bestScore > 0 ? best : nil
    }

    /// Inline cues are only honoured when the block opens with them, so that a
    /// passing mention of "for example" inside an explanation does not reclassify
    /// the whole paragraph.
    func inlineFamily(for text: String) -> FamilyMatch? {
        let prefix = text.split(separator: " ").prefix(4).joined(separator: " ")
        guard let match = lexicalFamily(for: prefix) else { return nil }
        return match.matched.count >= 1 && (match.role == .example || match.role == .caution) ? match : nil
    }

    static func normalize(_ text: String) -> String {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    static func tokens(_ text: String) -> [String] {
        normalize(text).split(separator: " ").map(String.init)
    }

    /// Cheap suffix-tolerant comparison: "examples" ~ "example", "traps" ~ "trap".
    static func sharesStem(_ lhs: String, _ rhs: String) -> Bool {
        if lhs == rhs { return true }
        let a = stem(lhs), b = stem(rhs)
        return a == b && a.count >= 3
    }

    static func stem(_ word: String) -> String {
        var value = word
        for suffix in ["ing", "ies", "es", "s", "ed"] where value.count > suffix.count + 2 && value.hasSuffix(suffix) {
            value = String(value.dropLast(suffix.count))
            break
        }
        return value
    }
}
