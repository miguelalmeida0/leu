import Foundation

public struct CardContext: Codable, Equatable, Sendable, Identifiable {
    public let documentID: UUID
    public let fingerprint: String
    public let extractionVersion: Int
    public let pageIndex: Int
    public let title: String
    public let titleSpan: CanonicalWhitespaceResolver.Span
    public let section: String?
    public let factualBlocks: [CanonicalWhitespaceResolver.Span]
    public let exampleBlocks: [CanonicalWhitespaceResolver.Span]
    public let excludedMnemonicBlocks: [CanonicalWhitespaceResolver.Span]
    public let excludedInterviewBlocks: [CanonicalWhitespaceResolver.Span]
    public let excludedAdviceBlocks: [CanonicalWhitespaceResolver.Span]
    public var id: String { "\(documentID)|\(fingerprint)|\(pageIndex)|\(titleSpan.range.location)" }

    public init?(analysis: DocumentAnalysis, page: AnalyzedPage) {
        guard analysis.extractionVersion == SourceExtractionVersion.current, page.spatialIntegrityPassed == true,
              let canonical = page.canonicalText, !canonical.contains("\u{FFFD}"),
              let marker = page.segments.firstIndex(where: { SourceRoleMap.headingRole($0.text) == .factualExplanation }), marker > 0,
              page.segments.filter({ SourceRoleMap.headingRole($0.text) == .factualExplanation }).count == 1 else { return nil }
        let roles = SourceRoleMap(canonicalText: canonical), ns = canonical as NSString
        guard let factualStart = roles.sections.first(where: { $0.role == .factualExplanation })?.range.location,
              let titleSpan = CanonicalWhitespaceResolver.resolve(page.segments[marker - 1].text,
                in: ns.substring(to: factualStart)) else { return nil }
        let title = CanonicalWhitespaceResolver.normalize(titleSpan.text)
        guard title.count >= 2, title.count <= 100, title.split(separator: " ").count <= 12,
              SourceRoleMap.headingRole(title) == nil, title.rangeOfCharacter(from: .letters) != nil,
              !title.contains(" / 310"), !title.contains("Explain it aloud") else { return nil }
        func blocks(_ role: IntelligenceSourceRole) -> [CanonicalWhitespaceResolver.Span] {
            roles.sections.filter { $0.role == role }.compactMap {
                CanonicalWhitespaceResolver.resolve(ns.substring(with: $0.range).trimmingCharacters(in: .whitespacesAndNewlines), in: canonical)
            }
        }
        let facts = blocks(.factualExplanation)
        guard !facts.isEmpty else { return nil }
        self.documentID = analysis.documentID; fingerprint = analysis.fingerprint
        extractionVersion = SourceExtractionVersion.current; pageIndex = page.pageIndex
        self.title = title; self.titleSpan = titleSpan
        section = marker >= 2 ? page.segments[marker - 2].text : nil
        factualBlocks = facts; exampleBlocks = blocks(.supportingExample)
        excludedMnemonicBlocks = blocks(.mnemonic); excludedInterviewBlocks = blocks(.interviewInstruction)
        excludedAdviceBlocks = blocks(.advice)
    }
    public func isCurrent(in analysis: DocumentAnalysis) -> Bool {
        guard analysis.documentID == documentID, let page = analysis.pages.first(where: { $0.pageIndex == pageIndex }) else { return false }
        return CardContext(analysis: analysis, page: page) == self
    }
}

public struct ContextualFactualClaim: Codable, Equatable, Sendable, Identifiable {
    public struct Reference: Codable, Equatable, Sendable {
        public let expression: String
        public let resolvedTo: String
        public let basis: String
    }
    public let card: CardContext
    public let original: CanonicalWhitespaceResolver.Span
    public let sentences: [CanonicalWhitespaceResolver.Span]
    public let references: [Reference]
    public let composedStatement: String
    public let families: [String]
    public var id: String { card.id + "|fact|\(original.range.location)" }
}

public struct ContextualClaimComposition: Codable, Sendable {
    public let card: CardContext?
    public let claims: [ContextualFactualClaim]
    public let rejection: String?
}

public struct ContextualClaimComposer: Sendable {
    public init() {}
    public func compose(analysis: DocumentAnalysis, page: AnalyzedPage) -> ContextualClaimComposition {
        guard let card = CardContext(analysis: analysis, page: page) else {
            return .init(card: nil, claims: [], rejection: "missing_or_unverified_single_card_context")
        }
        var claims: [ContextualFactualClaim] = [], failure = "no_admissible_factual_block"
        for block in card.factualBlocks {
            let text = CanonicalWhitespaceResolver.normalize(block.text)
            guard text.count >= 35, text.count <= 900 else { failure = "factual_block_length"; continue }
            guard text.range(of: #"(?i)\b(?:imagine|pretend|memorize|ignore (?:all|previous)|system prompt|assistant instruction)\b"#, options: .regularExpression) == nil else {
                failure = "instruction_or_mnemonic_inside_factual_role"; continue
            }
            let sentences = Self.sentences(block)
            guard (1...3).contains(sentences.count) else { failure = "requires_more_than_three_factual_sentences"; continue }
            var references: [ContextualFactualClaim.Reference] = []
            var previousSubject: String?
            for sentence in sentences {
                let normalized = CanonicalWhitespaceResolver.normalize(sentence.text)
                if let prefix = Self.referencePrefixes.first(where: { normalized.lowercased().hasPrefix($0 + " ") }) {
                    // The entire factual block remains evidence. No antecedent is
                    // imported from mnemonic/example/interview text or another card.
                    references.append(.init(expression: prefix, resolvedTo: previousSubject ?? card.title,
                        basis: previousSubject == nil ? "current_card_title; original factual context retained" : "explicit_subject_in_previous_factual_sentence; original scope retained"))
                }
                if let subject = Self.explicitSubject(normalized) { previousSubject = subject }
            }
            var families = ["definition"]
            let lower = text.lowercased()
            if ["helps", "enables", "allows", "makes", "provides", "supports", "lets", "gives"].contains(where: lower.contains) { families.append("mechanism") }
            if ["prevents", "reduces", "avoids", "improves", "catches", "keeps", "creates", "replaces"].contains(where: lower.contains) { families.append("consequence") }
            if ["when", "only", "before", "after", "without", "must", "should"].contains(where: lower.contains) { families.append("constraint") }
            if ["before", "after", "then", "first-in-first-out"].contains(where: lower.contains) { families.append("sequence") }
            if ["trade", "but ", "cost", "complexity"].contains(where: lower.contains) { families.append("tradeoff") }
            if ["bug", "unpredictable", "neither", "failure", "race"].contains(where: lower.contains) { families.append("failureMode") }
            claims.append(.init(card: card, original: block, sentences: sentences, references: references,
                composedStatement: Self.attach(title: card.title, text: text), families: families))
        }
        return .init(card: card, claims: claims, rejection: claims.isEmpty ? failure : nil)
    }
    private static let referencePrefixes = ["that approach", "this pattern", "the operation", "the constraint", "the index", "the request", "the component", "it", "this", "they", "these"]
    private static func attach(title: String, text: String) -> String {
        // Finite fragment completion; the actual citation remains the unedited
        // title and factual block. A colon keeps already explicit subjects intact.
        let transformations = ["Intentionally duplicate": "intentionally duplicates", "Verifies that": "verifies that", "Guarantees that": "guarantees that",
            "Constrain or support": "constrains or supports", "Move shared state": "moves shared state"]
        for (prefix, replacement) in transformations where text.hasPrefix(prefix) {
            return title + " " + replacement + text.dropFirst(prefix.count)
        }
        return title + ": " + text
    }
    private static func explicitSubject(_ sentence: String) -> String? {
        // Main-clause subjects only: a noun inside a relative/conditional clause
        // is not allowed to steal the next sentence's antecedent.
        let pattern = #"^(.{1,100}?) (?:should|must|can|may|is|are|defines|define|requests|request|reduces|reduce|creates|create|returns|return|keeps|keep|prevents|prevent)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: sentence, range: NSRange(sentence.startIndex..., in: sentence)) else { return nil }
        let subject = (sentence as NSString).substring(with: match.range(at: 1))
        guard !referencePrefixes.contains(subject.lowercased()),
              subject.range(of: #"(?i)\b(?:that|which|whose|where|when|if|because|before|after)\b"#, options: .regularExpression) == nil else { return nil }
        return subject
    }
    static func sentences(_ block: CanonicalWhitespaceResolver.Span) -> [CanonicalWhitespaceResolver.Span] {
        // Only sentence-ending punctuation followed by whitespace. API dots,
        // decimals, abbreviations without a boundary and operators stay intact.
        let text = block.text as NSString
        let regex = try! NSRegularExpression(pattern: #"[.!?](?=\s+[A-Z]|\s*$)"#)
        let ends = regex.matches(in: block.text, range: NSRange(location: 0, length: text.length)).map { NSMaxRange($0.range) }
        var result: [CanonicalWhitespaceResolver.Span] = [], start = 0
        for end in ends + [text.length] where end > start {
            let piece = text.substring(with: NSRange(location: start, length: end - start))
            let trimmed = piece.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                let local = (piece as NSString).range(of: trimmed)
                result.append(.init(range: .init(location: block.range.location + start + local.location, length: local.length), text: trimmed))
            }
            start = end
        }
        return result
    }
}
