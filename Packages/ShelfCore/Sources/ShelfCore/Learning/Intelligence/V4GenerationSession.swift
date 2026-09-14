import Foundation

/// Unforgeable in the app module: only the generation actor constructs a batch,
/// after the unchanged independent source/role/contract admission checks pass.
public struct V4QuestionBatch: Sendable {
    public let questions: [LearningQuestion]
    public let pages: Set<Int>
    let documentID: UUID
    let sourceDigest: String
    fileprivate init(questions: [LearningQuestion], pages: Set<Int>, documentID: UUID, sourceDigest: String) {
        self.questions = questions; self.pages = pages; self.documentID = documentID; self.sourceDigest = sourceDigest
    }
}

public actor V4GenerationSession {
    private let analysis: DocumentAnalysis
    private let topics: Set<UUID>
    private var claims: [ContextualFactualClaim]?
    private var compiler: QuestionV4Compiler?
    private var sourceDigest: String?
    public init(analysis: DocumentAnalysis, topicIDs: Set<UUID> = []) { self.analysis = analysis; topics = topicIDs }

    public func batch(pages: [Int]) throws -> V4QuestionBatch {
        let started = DispatchTime.now().uptimeNanoseconds
        defer { IntelligencePerformance.record("question_generation", since: started, workCount: pages.count, cacheHit: false) }
        try Task.checkCancellation()
        if claims == nil {
            // Cross-card distractor selection needs the full factual inventory,
            // but question realization and durable checkpoints are page batches.
            let claimStart = DispatchTime.now().uptimeNanoseconds
            let composed = analysis.pages.flatMap { ContextualClaimComposer().compose(analysis: analysis, page: $0).claims }
            IntelligencePerformance.record("claim_generation", since: claimStart, workCount: composed.count)
            claims = composed; compiler = QuestionV4Compiler(claims: composed)
            sourceDigest = try ValidatedIntelligenceReceipt.source(analysis)
        }
        let selected = Set(pages), claims = claims!, compiler = compiler!
        let questions = try claims.filter { selected.contains($0.card.pageIndex) }.compactMap { claim -> LearningQuestion? in
            try Task.checkCancellation()
            guard let q = compiler.compile(claim, neighbors: claims),
                  compiler.validate(q, claims: claims, analyses: [analysis.documentID: analysis]) == nil else { return nil }
            return V4StudyBank.adapt(q, topicIDs: topics)
        }
        return V4QuestionBatch(questions: questions, pages: selected, documentID: analysis.documentID, sourceDigest: sourceDigest!)
    }

    public static func priorityPages(_ analysis: DocumentAnalysis, current: Int?) -> [Int] {
        guard let current else { return analysis.pages.map(\.pageIndex) }
        func sectionKey(_ page: AnalyzedPage) -> String? {
            guard let title = page.segments.first?.sectionTitle else { return nil }
            // Card numbers and typographic spacing are not section identity.
            let key = title.filter(\.isLetter).lowercased()
            return key.isEmpty ? nil : key
        }
        let section = analysis.pages.first { $0.pageIndex == current }.flatMap(sectionKey)
        return analysis.pages.sorted { a, b in
            func rank(_ page: AnalyzedPage) -> Int {
                if page.pageIndex == current { return 0 }
                if abs(page.pageIndex - current) <= 2 { return 1 }
                if let section, sectionKey(page) == section { return 2 }
                return 3
            }
            let x = rank(a), y = rank(b)
            return x == y ? abs(a.pageIndex - current) < abs(b.pageIndex - current) : x < y
        }.map(\.pageIndex)
    }
}
