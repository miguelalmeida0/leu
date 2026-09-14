import Foundation

/// Conservative source-selection admission. Free factual paraphrases are rejected;
/// lexical checks are not represented as general semantic entailment verification.
public struct LearningCandidateValidator: Sendable {
    public init() {}
    public func validate(_ c: LearningModelCandidate, packet: LearningSourcePacket,
                         analysis: DocumentAnalysis, existing: [LearningQuestion]) -> Result<LearningQuestion, Rejection> {
        guard analysis.documentID == packet.documentID, analysis.fingerprint == packet.fingerprint,
              analysis.extractionVersion == packet.extractionVersion,
              let page = analysis.pages.first(where: { $0.pageIndex == packet.pageIndex }),
              page.canonicalText == packet.sourceText,
              packet.range.location == 0, packet.range.length == packet.sourceText.utf16.count else { return .failure(.wrongSource) }
        let ns = packet.sourceText as NSString
        let quoteRange = ns.range(of: c.supportingQuote)
        guard c.supportingQuote.count >= 30, quoteRange.location != NSNotFound,
              c.supportingQuote.utf16.count <= 800 else { return .failure(.fabricatedQuote) }
        guard c.choices.count >= 3, c.choices.count <= 4, c.choices.indices.contains(c.correctChoice),
              Set(c.choices.map(normalize)).count == c.choices.count else { return .failure(.duplicateOrInvalidChoices) }
        let answer = c.choices[c.correctChoice]
        guard answer.count >= 12, c.supportingQuote.contains(answer),
              c.choices.filter({ c.supportingQuote.contains($0) }).count == 1 else { return .failure(.ambiguousAnswer) }
        // Each competing answer must be an attested statement, so the model cannot
        // manufacture false technical facts. Wider misconception formats need review.
        guard c.choices.allSatisfy({ $0.count >= 12 && packet.sourceText.contains($0) }),
              QuestionOptionQuality.rejectionReason(prompt: c.prompt, answer: answer,
                alternatives: c.choices.enumerated().filter { $0.offset != c.correctChoice }.map(\.element)) == nil else {
            return .failure(.unsupportedChoices)
        }
        guard !c.explanation.isEmpty, c.supportingQuote.contains(c.explanation) else { return .failure(.unsupportedExplanation) }
        guard c.prompt.count >= 30, c.prompt.count <= 240, c.prompt.hasSuffix("?"),
              !c.prompt.localizedCaseInsensitiveContains(answer),
              !c.concept.isEmpty, packet.sourceText.localizedCaseInsensitiveContains(c.concept),
              c.prompt.localizedCaseInsensitiveContains(c.concept),
              QuestionSelfContainment.rejectionReason(prompt: c.prompt, answer: answer, concept: c.concept) == nil else {
            return .failure(.weakQuestion)
        }
        // Do not auto-accept an arbitrary model question merely because it cites
        // a real quote. It must ask for the supported subject/relation in that quote.
        let semantic = SemanticCompiler().compile(analysis)
        let supported = semantic.propositions.contains { p in
            guard p.isQuizTruth, let claim = p.claim,
                  c.supportingQuote.contains(p.evidence.sourceText),
                  let realization = QuestionRealizer().realize(claim) else { return false }
            return normalize(realization.answer) == normalize(answer) &&
                normalize(realization.prompt) == normalize(c.prompt)
        }
        guard supported else { return .failure(.semanticReviewRequired) }
        guard !existing.contains(where: { normalize($0.prompt) == normalize(c.prompt) }) else { return .failure(.duplicateQuestion) }
        let key = packet.cacheKey + "|" + normalize(c.prompt)
        let options = c.choices.map { QuestionOption(id: StableIdentity.uuid(key + $0), text: $0) }
        var question = LearningQuestion(id: StableIdentity.uuid(key), stableKey: key, kind: .semanticRelationship,
            prompt: c.prompt, options: options, correctOptionID: options[c.correctChoice].id,
            source: LearningSource(documentID: packet.documentID, pageIndex: packet.pageIndex,
                sourceText: c.supportingQuote, range: SourceTextRange(location: quoteRange.location, length: quoteRange.length),
                sectionTitle: packet.sectionTitle), qualityScore: 0.8)
        question.modelProvenance = LearningGenerationProvenance(packet: packet, backend: "apple-on-device", explanation: c.explanation)
        return .success(question)
    }
    public enum Rejection: String, Error, Codable, Sendable {
        case wrongSource, fabricatedQuote, duplicateOrInvalidChoices, ambiguousAnswer, unsupportedChoices
        case unsupportedExplanation, weakQuestion, duplicateQuestion, semanticReviewRequired
    }
    private func normalize(_ value: String) -> String { value.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ") }
}
