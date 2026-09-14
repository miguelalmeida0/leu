import Foundation

public struct PassageReanchorer: Sendable {
    private let tokenizer = TechnicalTokenizer()
    public init() {}

    public func bestMatch(for old: KnowledgePassage, among candidates: [KnowledgePassage]) -> KnowledgePassage? {
        if let exact = candidates.first(where: { $0.contentFingerprint == old.contentFingerprint }) { return exact }
        var best: (KnowledgePassage, Double)?
        for candidate in candidates where candidate.documentID == old.documentID {
            let lexical = jaccard(old.normalizedText, candidate.normalizedText)
            let pageDistance = abs(candidate.pageIndex - old.pageIndex)
            let pageScore = max(0, 1 - Double(pageDistance) / 12)
            var context = 0.0
            if old.precedingContextFingerprint != nil && old.precedingContextFingerprint == candidate.precedingContextFingerprint { context += 0.45 }
            if old.followingContextFingerprint != nil && old.followingContextFingerprint == candidate.followingContextFingerprint { context += 0.45 }
            let score = lexical * 0.72 + pageScore * 0.18 + context
            if best == nil || score > best!.1 { best = (candidate, score) }
        }
        return (best?.1 ?? 0) >= 0.66 ? best?.0 : nil
    }

    private func jaccard(_ lhs: String, _ rhs: String) -> Double {
        let a = Set(tokenizer.tokens(in: lhs)), b = Set(tokenizer.tokens(in: rhs))
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        return Double(a.intersection(b).count) / Double(a.union(b).count)
    }
}
