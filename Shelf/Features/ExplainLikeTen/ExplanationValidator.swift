import Foundation

/// Deterministic checks only. These verify structure, source identity, limits and a few
/// obvious inconsistencies. They do not and cannot prove the explanation is true, so
/// nothing here produces a confidence score or a "verified" badge.
struct ExplanationValidator {
    enum Failure: Equatable {
        case empty
        case tooShort(Int)
        case tooLong(Int)
        case unknownSpanID(String)
        case noSelectionReference
        case hedgeRemoved(String)
        case negationLost(String)
        case numberNotInSource(String)
        case looksLikeInstruction
        case containsMarkup
        case invalidStructure
        case invalidPreservedTerm
        case changedLiteral(String)

        var code: String {
            switch self {
            case .empty: return "empty"
            case .tooShort: return "tooShort"
            case .tooLong: return "tooLong"
            case .unknownSpanID: return "unknownSpanID"
            case .noSelectionReference: return "noSelectionReference"
            case .hedgeRemoved: return "hedgeRemoved"
            case .negationLost: return "negationLost"
            case .numberNotInSource: return "numberNotInSource"
            case .looksLikeInstruction: return "looksLikeInstruction"
            case .containsMarkup: return "containsMarkup"
            case .invalidStructure: return "invalidStructure"
            case .invalidPreservedTerm: return "invalidPreservedTerm"
            case .changedLiteral: return "changedLiteral"
            }
        }
    }

    /// Qualifiers whose loss changes meaning. If the source hedges and the explanation
    /// does not, that is a meaning reversal, not a simplification.
    private static let hedges = ["may", "might", "can", "could", "sometimes", "often",
                                 "usually", "typically", "generally", "in some cases"]
    private static let absolutes = ["always", "never", "all", "every", "guaranteed", "must"]
    private static let negations = ["not", "no", "cannot", "can't", "without", "neither",
                                    "unless", "except", "avoid", "prevent", "isn't", "aren't", "doesn't", "don't",
                                    "didn't", "won't", "wouldn't", "shouldn't", "couldn't", "mustn't", "wasn't", "weren't"]

    func validate(_ candidate: ExplanationCandidate, packet: ExplanationSourcePacket,
                  mode: ExplanationMode = .standard) -> [Failure] {
        var failures: [Failure] = []
        if candidate.needsContext {
            let reason = candidate.needsContextReason ?? ""
            guard candidate.blocks.isEmpty, candidate.preservedTerm == nil,
                  candidate.preservedTermMeaning == nil, !reason.isEmpty, reason.count <= 300 else { return [.invalidStructure] }
            return contentFailures(reason)
        }
        guard !candidate.blocks.isEmpty, candidate.blocks.allSatisfy({ !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { return [.empty] }
        if candidate.blocks.count > 5 || candidate.blocks.contains(where: { $0.text.count > 1400 }) || candidate.blocks.first?.kind != .plainMeaning ||
            candidate.blocks.filter({ $0.kind == .plainMeaning }).count != 1 ||
            candidate.blocks.filter({ $0.kind == .example }).count > 1 || candidate.needsContextReason != nil {
            failures.append(.invalidStructure)
        }
        if mode == .withExample && candidate.blocks.filter({ $0.kind == .example }).count != 1 {
            failures.append(.invalidStructure)
        }

        let wordCount = candidate.wordCount
        if wordCount < ExplanationSchema.minimumWords { failures.append(.tooShort(wordCount)) }
        if wordCount > ExplanationSchema.hardMaximumWords { failures.append(.tooLong(wordCount)) }

        let allowed = packet.allowedSpanIDs
        for block in candidate.blocks {
            if block.sourceSpanIDs.isEmpty || Set(block.sourceSpanIDs).count != block.sourceSpanIDs.count {
                failures.append(.invalidStructure)
            }
            for id in block.sourceSpanIDs where !allowed.contains(id) {
                failures.append(.unknownSpanID(id))
            }
        }
        if !candidate.blocks.contains(where: { $0.sourceSpanIDs.contains("s1") }) {
            failures.append(.noSelectionReference)
        }

        let source = packet.spans.map(\.text).joined(separator: " ").lowercased()
        let output = candidate.visibleText
        let lowered = output.lowercased()
        let sourceWords = words(source), outputWords = words(lowered)
        if let term = candidate.preservedTerm, let meaning = candidate.preservedTermMeaning {
            if term.isEmpty || term.count > 80 || meaning.isEmpty || meaning.count > 300 || !packet.spans.contains(where: { $0.text.contains(term) }) {
                failures.append(.invalidPreservedTerm)
            }
        } else if candidate.preservedTerm != nil || candidate.preservedTermMeaning != nil {
            failures.append(.invalidPreservedTerm)
        }

        // "may" must not become "always".
        let sourceHedges = Self.hedges.contains { sourceWords.contains($0) } || source.contains("in some cases")
        if sourceHedges {
            if !Self.hedges.contains(where: { outputWords.contains($0) }) && !lowered.contains("in some cases") { failures.append(.hedgeRemoved("uncertainty")) }
            for absolute in Self.absolutes where outputWords.contains(absolute) && !sourceWords.contains(absolute) {
                failures.append(.hedgeRemoved(absolute))
            }
        }
        // A negated source claim must stay negated somewhere in the output.
        let sourceNegations = Self.negations.filter { sourceWords.contains($0) }
        if !sourceNegations.isEmpty && !Self.negations.contains(where: { outputWords.contains($0) }) {
            failures.append(.negationLost(sourceNegations[0]))
        }
        // Numbers are a common invention point.
        let sourceNumbers = Set(numbers(in: source))
        for number in numbers(in: output) where !sourceNumbers.contains(number) {
            failures.append(.numberNotInSource(number))
        }
        for literal in protectedLiterals(packet.selectionText) where !output.contains(literal) {
            failures.append(.changedLiteral(literal))
        }
        failures += contentFailures(output)
        return failures
    }

    /// A short answer is worth showing; an over-long one, an unknown span, a lost
    /// negation or an invented number is not. Word count below the floor is advisory
    /// because an honest 70-word answer beats a padded 90-word one.
    func isDisplayable(_ failures: [Failure]) -> Bool {
        !failures.contains { failure in
            switch failure {
            case .tooShort: return false
            case .empty, .tooLong, .unknownSpanID, .noSelectionReference, .hedgeRemoved,
                 .negationLost, .numberNotInSource, .looksLikeInstruction, .containsMarkup,
                 .invalidStructure, .invalidPreservedTerm, .changedLiteral:
                return true
            }
        }
    }

    private func numbers(in text: String) -> [String] {
        matches(#"\b\d+(?:[.,]\d+)*(?:[eE][+-]?\d+)?\b"#, in: text)
    }

    private func words(_ text: String) -> Set<String> {
        Set(matches(#"[\p{L}]+(?:'[\p{L}]+)?"#, in: text.lowercased().replacingOccurrences(of: "’", with: "'")))
    }

    private func protectedLiterals(_ text: String) -> [String] {
        matches(#"\b[a-z][A-Za-z0-9]*[A-Z][A-Za-z0-9]*\b|\b[A-Za-z]\w*_\w+\b|\b[A-Za-z_$]\w*(?:\.[A-Za-z_$]\w*)+\b|O\([^\)\n]{1,60}\)|===|!==|=>|<=|>=|&&|\|\|"#, in: text)
    }

    private func contentFailures(_ text: String) -> [Failure] {
        let value = text.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
        var failures: [Failure] = []
        if ["ignore the above", "ignore previous instructions", "ignore all previous instructions", "system prompt"].contains(where: value.contains) {
            failures.append(.looksLikeInstruction)
        }
        if value.contains("<script") || value.contains("](http") || value.contains("```") { failures.append(.containsMarkup) }
        return failures
    }

    private func matches(_ pattern: String, in text: String) -> [String] {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let source = text as NSString
        return expression.matches(in: text, range: NSRange(location: 0, length: source.length)).map { source.substring(with: $0.range) }
    }
}
