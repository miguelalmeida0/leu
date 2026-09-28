import Foundation

/// What a chosen wrong option reveals. Built only from grounded claims and concept names:
/// when the option cannot be traced to the source, nothing is claimed about it.
public struct DistractorAnalysis: Equatable, Sendable {
    public let kind: MisconceptionKind?
    public let relatedConcept: ConceptKey?
    public let claimID: String?
    /// One sentence for the answer feedback, from fixed templates and source words.
    public let explanation: String?

    public static let untraced = DistractorAnalysis(kind: nil, relatedConcept: nil, claimID: nil, explanation: nil)

    public static func analyze(question: LearningQuestion, selected: QuestionOption, tested: ConceptReference?,
                               in knowledge: ConceptKnowledgeBase) -> DistractorAnalysis {
        // A duplicate of the correct answer (a malformed question) reveals nothing about the learner.
        let answer = question.correctOption.map { CanonicalWhitespaceResolver.normalize($0.text).lowercased() }
        guard selected.id != question.correctOptionID, CanonicalWhitespaceResolver.normalize(selected.text).lowercased() != answer else { return .untraced }
        let testedName = tested.map { PromptRealizer.inline($0.name) } ?? "this idea"
        let document = question.source.documentID
        // The option is another concept's name.
        let named = ConceptKey(selected.text)
        let expected = tested?.id.concept ?? question.correctOption.map { ConceptKey($0.text) }
        if !named.isEmpty, named != expected, let entry = knowledge.concept(named), entry.documentID == document {
            let definition = knowledge.definition(of: named)
            let explanation = definition.map { "“\(entry.name)” is a different idea in your source: \(Self.quote($0.evidence.text))" }
            return DistractorAnalysis(kind: .confusion, relatedConcept: named, claimID: definition?.id, explanation: explanation)
        }
        // The option restates (or reverses) a grounded claim.
        let option = LexicalProfile(selected.text)
        let content = option.terms.filter { $0.weight == 1 }
        guard content.count >= 2 else { return .untraced }
        let pool = knowledge.claims.filter { $0.evidence.documentID == document }
        let matches = pool.compactMap { claim -> (LearningClaim, Double)? in
            let profile = LexicalProfile(claim.statement)
            let shared = content.filter { profile.match($0) >= 0.85 }.count
            let share = Double(shared) / Double(content.count)
            return share >= 0.75 ? (claim, share) : nil
        }
        guard let (claim, _) = matches.max(by: { ($0.1, -$0.0.evidence.range.location) < ($1.1, -$1.0.evidence.range.location) }) else { return .untraced }
        let owner = claim.topic ?? claim.concept
        let reversed = option.isNegative != (LexicalProfile(claim.statement).isNegative)
        if reversed {
            return DistractorAnalysis(kind: .contradiction, relatedConcept: owner == tested?.id.concept ? nil : owner, claimID: claim.id,
                                      explanation: claim.citation("says the opposite"))
        }
        if let tested, owner != tested.id.concept {
            let otherName = knowledge.concept(owner)?.name ?? claim.conceptName
            return DistractorAnalysis(kind: .confusion, relatedConcept: owner, claimID: claim.id,
                                      explanation: "That describes \(PromptRealizer.inline(otherName)), not \(testedName).")
        }
        return .untraced
    }

    static func quote(_ text: String) -> String { "“" + InterventionPlanner.quote(text) + "”" }
}
