import Foundation

public struct SourceMeaningSentence: Equatable, Sendable {
    public let text: String
    public let propositionID: String
    public let source: LearningSource
}

public struct SourceMeaningProjection: Equatable, Sendable {
    public var keyIdea: String?
    public var sentences: [SourceMeaningSentence]
    public var terms: [String]
    public var questions: [RealizedQuestion]
}

public struct SourceMeaningComposer: Sendable {
    public init() {}

    public func project(source: LearningSource, index: SemanticIndex?) -> SourceMeaningProjection {
        let fallback = SemanticCompiler().compile(DocumentAnalysis(documentID: source.documentID, fingerprint: "lens-selection-v3",
            algorithmVersion: 3, pages: [AnalyzedPage(pageIndex: source.pageIndex, normalizedText: source.sourceText,
                segments: [SourceSegment(pageIndex: source.pageIndex, kind: .paragraph, text: source.sourceText, sectionTitle: source.sectionTitle)])]))
        let available = (index?.propositions ?? []) + fallback.propositions
        let selection = normalized(source.sourceText)
        var seen = Set<String>()
        let claims = available.filter { p in
            guard p.isQuizTruth, p.evidence.documentID == source.documentID, p.evidence.pageIndex == source.pageIndex,
                  let claim = p.claim, selection.contains(normalized(p.evidence.sourceText)),
                  QuestionSelfContainment.validConcept(claim.subject) else { return false }
            return seen.insert(normalized(p.evidence.sourceText)).inserted
        }
        // Combine only a small cluster about the same subject. Other concepts remain terms.
        let primary = claims.first?.subjectID
        let group = claims.filter { $0.subjectID == primary }.prefix(3)
        let sentences = group.compactMap { p -> SourceMeaningSentence? in
            guard let c = p.claim else { return nil }
            let text: String
            if let tradeoff = c.tradeoff {
                text = tradeoff.meaning
            } else if c.intent == .define {
                let subject = c.subjectPhrase.prefix(1).uppercased() + String(c.subjectPhrase.dropFirst())
                text = "\(subject) means \(c.object)."
            } else if c.predicate.contains("differs from"), let reason = c.qualifier {
                text = "The important difference is \(reason)."
            } else {
                // Exact source wording is the safe realization for causal,
                // conditional, and contrastive claims; do not flip agent/beneficiary.
                text = p.evidence.sourceText
            }
            return SourceMeaningSentence(text: text, propositionID: p.id, source: p.evidence.learningSource)
        }
        var termsSeen = Set<String>()
        let terms = claims.compactMap { $0.claim?.subject }.filter { termsSeen.insert($0.lowercased()).inserted }
        let questions = claims.compactMap { $0.claim.flatMap { QuestionRealizer().realize($0) } }
        return SourceMeaningProjection(keyIdea: terms.first, sentences: sentences, terms: Array(terms.prefix(8)), questions: Array(questions.prefix(3)))
    }

    private func normalized(_ text: String) -> String {
        text.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
