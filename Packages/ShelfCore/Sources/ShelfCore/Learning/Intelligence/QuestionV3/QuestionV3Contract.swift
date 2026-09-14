import Foundation

public typealias QuestionV3Candidate = LearningModelCandidate

/// Reuses V2 canonical extraction, source-attested alternatives and model selection.
/// V3 controls the linguistic surface and independently readmits every candidate.
public struct QuestionV3Contract: Sendable {
    public init() {}
    public func compile(_ packet: LearningSourcePacket) -> QuestionRepresentability {
        guard packet.sourceIntegrityPassed == true, packet.extractionVersion == SourceExtractionVersion.current else {
            return QuestionRepresentability(status: .noRepresentableQuestion, meaningfulClaims: [], selectableClaims: [], questions: [])
        }
        let extracted = GroundedQuestionCompiler().compile(packet)
        var claims: [GroundedQuestionClaim] = [], questions: [LearningModelCandidate] = []
        for claim in extracted.meaningfulClaims {
            guard let stem = QuestionV3Stem.realize(claim) else { continue }
            // Counterstatements are exact, auditable polarity reversals of other
            // admissible assertions. They are answer options, NEVER admitted facts.
            // Same-claim negation puzzles are excluded. Every word of scope stays.
            let alternatives = extracted.meaningfulClaims.filter { $0.id != claim.id && $0.concept != claim.concept }
                .compactMap(QuestionV3Counterstatement.make)
            var admitted: LearningModelCandidate?
            if alternatives.count >= 2 {
                outer: for i in 0..<(alternatives.count - 1) {
                    for j in (i + 1)..<alternatives.count {
                        let options = [claim.canonicalAnswer, alternatives[i], alternatives[j]].sorted {
                            StableIdentity.hash64(claim.id + $0) < StableIdentity.hash64(claim.id + $1)
                        }
                        var proposal = LearningModelCandidate(prompt: stem, choices: options,
                            correctChoice: options.firstIndex(of: claim.canonicalAnswer)!, explanation: claim.evidence.text,
                            supportingQuote: claim.evidence.text, concept: claim.concept, skill: claim.cognitiveOperation)
                        proposal.selection = GroundedQuestionSelection(claimID: claim.id, cognitiveOperation: claim.cognitiveOperation)
                        if QuestionV3Validator.surfaceFailure(proposal) == nil { admitted = proposal; break outer }
                    }
                }
            }
            guard let question = admitted else { continue }
            guard QuestionV3Validator.surfaceFailure(question) == nil else { continue }
            let revised = GroundedQuestionClaim(id: claim.id, concept: claim.concept,
                cognitiveOperation: claim.cognitiveOperation, relation: claim.relation, predicate: claim.predicate,
                object: claim.object, qualifier: claim.qualifier, negated: claim.negated,
                documentID: claim.documentID, pageIndex: claim.pageIndex, evidence: claim.evidence, prompt: stem)
            claims.append(revised); questions.append(question)
        }
        return QuestionRepresentability(status: questions.isEmpty ? (extracted.meaningfulClaims.isEmpty ? .noRepresentableQuestion : .noDefensibleChoices) : .representable,
            meaningfulClaims: extracted.meaningfulClaims, selectableClaims: claims, questions: questions)
    }
}

/// Finite grammatical transforms. No model-authored distractor is accepted.
enum QuestionV3Counterstatement {
    static func make(_ claim: GroundedQuestionClaim) -> String? {
        let forms = ["helps": "does not help", "help": "do not help", "destroys": "does not destroy",
            "destroy": "do not destroy", "preserves": "does not preserve", "preserve": "do not preserve",
            "requires": "does not require", "require": "do not require", "causes": "does not cause",
            "returns": "does not return", "creates": "does not create", "reduces": "does not reduce",
            "prevents": "does not prevent", "limits": "does not limit", "can be": "cannot be",
            "should not": "should", "must not": "must", "cannot": "can"]
        let predicate = claim.predicate.replacingOccurrences(of: "also ", with: "")
        guard let reversed = forms[predicate] else { return nil }
        let source = CanonicalWhitespaceResolver.normalize(claim.evidence.text)
        let needle = " " + claim.predicate + " "
        guard source.components(separatedBy: needle).count == 2 else { return nil }
        return source.replacingOccurrences(of: needle,
            with: " " + (claim.predicate.hasPrefix("also ") ? "also " : "") + reversed + " ")
    }
}

enum QuestionV3Stem {
    static func realize(_ claim: GroundedQuestionClaim) -> String? {
        let concept = claim.concept
        let canonical = CanonicalWhitespaceResolver.normalize(claim.evidence.text)
        guard let predicateRange = canonical.range(of: " " + claim.predicate + " ") else { return nil }
        let sourceSubject = String(canonical[..<predicateRange.lowerBound])
        var subject = GeneralClaimExtractor.inline(sourceSubject)
        if !subject.contains(" "), subject.lowercased().hasSuffix("ing") { subject = subject.lowercased() }
        let original = claim.prompt.replacingOccurrences(of: "to " + concept + "?", with: "to " + subject + "?")
        // These forms ask for an explicit relation; factual scope stays in the
        // complete source-bound options, never in model-authored premises.
        switch claim.cognitiveOperation {
        case "mechanism":
            if claim.predicate == "helps" || claim.predicate == "help" {
                return "Which effect explains the role of \(subject)?"
            }
            if original.hasPrefix("How ") { return original }
            return "Which mechanism describes the role of \(subject)?"
        case "consequence": return "What consequence is associated with \(subject)?"
        case "constraint":
            if original.hasPrefix("Under what condition") || original.hasPrefix("Which restriction") { return original }
            return "Which constraint governs the use of \(subject)?"
        case "cause", "distinguish", "sequence", "prerequisite", "application", "debugging", "tradeoff": return original
        default: return nil
        }
    }
}

public enum QuestionV3Validator {
    public static func surfaceFailure(_ question: LearningModelCandidate) -> String? {
        let stem = question.prompt
        guard stem.filter({ $0 == "?" }).count == 1, stem.hasSuffix("?"), (30...240).contains(stem.count),
              stem.first?.isUppercase == true else { return "malformed_stem" }
        if stem.range(of: #"(?i)^what (?:is|are)\b|^what (?:does|do) .+ do\?|^which statement is true|\b(?:does|do) .+ (?:does|is|has|happens|means|causes|returns|creates|reduces)\b|\b(?:of|from|does|do) (?-i:A|An|The)\b"#, options: .regularExpression) != nil { return "generic_or_malformed_stem" }
        let noun = NSRegularExpression.escapedPattern(for: question.concept)
        if question.supportingQuote.range(of: "(?i)^(?:a|an|the) " + noun + "\\b", options: .regularExpression) != nil,
           stem.range(of: "(?i)\\b(?:of|for|from|using|with) " + noun + "\\b", options: .regularExpression) != nil {
            return "missing_subject_article"
        }
        guard question.choices.indices.contains(question.correctChoice), (3...4).contains(question.choices.count) else { return "invalid_choices" }
        let surfaces = [stem, question.supportingQuote] + question.choices
        for text in surfaces {
            if InstructionalText.isMemoryContent(text) || InstructionalText.isMemoryHook(subject: text, sentence: text) { return "mnemonic_leakage" }
            if InstructionalText.isReaderInstruction(text) { return "instruction_leakage" }
            if text.range(of: #"(?i)MAKE\s*IT\s*STICK|IN\s*ONE\s*BREATH|\bchapter\s+\d|___|\[insert"#, options: .regularExpression) != nil { return "furniture_leakage" }
        }
        let counts = question.choices.map { $0.split(whereSeparator: \.isWhitespace).count }
        guard let lo = counts.min(), let hi = counts.max(), lo >= 5, hi <= 48,
              Double(hi) / Double(lo) <= 1.85 else { return "option_length_imbalance" }
        let normalized = question.choices.map { Set(tokens($0)) }
        for i in normalized.indices {
            for j in normalized.indices where j > i {
                let similarity = Double(normalized[i].intersection(normalized[j]).count) / Double(max(1, normalized[i].union(normalized[j]).count))
                if similarity > 0.82 { return "semantic_duplicate_options" }
            }
        }
        return QuestionOptionQuality.rejectionReason(prompt: stem, answer: question.choices[question.correctChoice],
            alternatives: question.choices.enumerated().filter { $0.offset != question.correctChoice }.map(\.element))
    }
    public static func accepts(_ candidate: LearningModelCandidate, packet: LearningSourcePacket) -> Bool {
        surfaceFailure(candidate) == nil && QuestionV3Contract().compile(packet).questions.contains(candidate)
    }
    public static func persistedFailure(_ question: LearningQuestion, analysis: DocumentAnalysis) -> String? {
        guard let provenance = question.modelProvenance, provenance.schemaVersion == 3,
              let page = analysis.pages.first(where: { $0.pageIndex == question.source.pageIndex }),
              let current = LearningSourcePacket(analysis: analysis, page: page), current == provenance.packet,
              let expected = QuestionV3Contract().compile(current).questions.first(where: {
                  $0.selection?.claimID == provenance.selectedClaimID && $0.selection?.cognitiveOperation == provenance.cognitiveOperation
              }), question.prompt == expected.prompt, question.options.map(\.text) == expected.choices,
              question.correctOption?.text == expected.choices[expected.correctChoice],
              question.source.sourceText == expected.supportingQuote,
              provenance.explanation == expected.explanation,
              let range = question.source.range,
              range == CanonicalWhitespaceResolver.resolve(expected.supportingQuote, in: current.sourceText)?.range else {
            return "v3_persisted_contract_mismatch"
        }
        return nil
    }
    private static func tokens(_ text: String) -> [String] {
        text.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
    }
}
