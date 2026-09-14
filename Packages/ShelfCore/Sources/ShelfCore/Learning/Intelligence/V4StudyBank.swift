import Foundation

/// Adapts the admitted V4 bank to the existing durable Study question contract.
/// The complete V4 proof is retained; display copy never changes its citation.
public enum V4StudyBank {
    public static func build(_ analysis: DocumentAnalysis, topicIDs: Set<UUID> = []) -> [LearningQuestion] {
        let claims = analysis.pages.flatMap { ContextualClaimComposer().compose(analysis: analysis, page: $0).claims }
        let compiler = QuestionV4Compiler(claims: claims)
        return claims.compactMap { claim in
            guard let q = compiler.compile(claim, neighbors: claims),
                  compiler.validate(q, claims: claims, analyses: [analysis.documentID: analysis]) == nil else { return nil }
            return adapt(q, topicIDs: topicIDs)
        }
    }
    public static func displayPrompt(_ prompt: String) -> String {
        let prefix = "According to the source, "
        guard prompt.hasPrefix(prefix) else { return prompt }
        let body = String(prompt.dropFirst(prefix.count))
        return body.prefix(1).uppercased() + body.dropFirst()
    }
    public static func adapt(_ q: QuestionV4, topicIDs: Set<UUID> = [], generatedAt: Date = Date()) -> LearningQuestion {
        let options = q.choices.map { QuestionOption(id: StableIdentity.uuid(q.id + "|option|" + $0.sourceClaimID), text: $0.text) }
        var question = LearningQuestion(id: StableIdentity.uuid(q.id), stableKey: q.id, kind: .semanticRelationship,
            prompt: displayPrompt(q.prompt), options: options, correctOptionID: options[q.correctChoice].id,
            source: LearningSource(documentID: q.claim.card.documentID, pageIndex: q.claim.card.pageIndex,
                sourceText: q.claim.original.text, range: q.claim.original.range, sectionTitle: q.claim.card.title),
            topicIDs: topicIDs, qualityScore: 0.9, generatedAt: generatedAt,
            semanticFingerprint: q.claim.card.fingerprint, propositionID: q.claim.id, semanticOperator: q.operation)
        question.v4 = q
        return question
    }
    public static func rejection(_ question: LearningQuestion, analysis: DocumentAnalysis) -> String? {
        V4StudyAdmission(analysis: analysis).rejection(question)
    }
}

/// Transaction-local cache of independently reconstructed current claims.
/// Callers cannot supply claims or retain this across an analysis change.
struct V4StudyAdmission {
    private let analysis: DocumentAnalysis
    private let claims: [ContextualFactualClaim]
    private let compiler: QuestionV4Compiler
    init(analysis: DocumentAnalysis) {
        self.analysis = analysis
        claims = analysis.pages.flatMap { ContextualClaimComposer().compose(analysis: analysis, page: $0).claims }
        compiler = QuestionV4Compiler(claims: claims)
    }
    func rejection(_ question: LearningQuestion) -> String? {
        guard let q = question.v4 else { return "missing_v4_proof" }
        if let failure = compiler.validate(q, claims: claims, analyses: [analysis.documentID: analysis]) { return failure }
        guard question == V4StudyBank.adapt(q, topicIDs: question.topicIDs, generatedAt: question.generatedAt) else { return "v4_study_adapter_mismatch" }
        return nil
    }
}
