import Foundation

public enum ProbeFormat: Codable, Equatable, Hashable, Sendable {
    /// Answered in the learner's own words and compared with the rubric claims.
    case open
    /// Pick one option. Options are concept names from the same document.
    case choice(options: [String], answerIndex: Int)

    public var isChoice: Bool { if case .choice = self { return true } else { return false } }
}

/// One grounded question about one concept. Every prompt is template text plus source words;
/// every answer is justified by claims whose exact spans are carried with the probe.
public struct LearningProbe: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let id: String
    public let concept: LearnerConceptID
    public let conceptName: String
    public let operation: ProbeOperation
    public let prompt: String
    public let format: ProbeFormat
    /// Claims that answer an open probe, or justify a choice probe's answer.
    public let rubricClaimIDs: [String]
    /// Exact source spans the answer can be checked against.
    public let evidence: [SourceSpan]
    /// The other concept a contrast or confusion probe is about.
    public let relatedConcept: ConceptKey?
    /// The source example a transfer probe is built on.
    public let excerpt: SourceSpan?

    init(concept: LearnerConceptID, conceptName: String, operation: ProbeOperation, prompt: String, format: ProbeFormat,
         rubric: [LearningClaim], evidence: [SourceSpan]? = nil, relatedConcept: ConceptKey? = nil, excerpt: SourceSpan? = nil) {
        self.concept = concept; self.conceptName = conceptName; self.operation = operation
        self.prompt = CanonicalWhitespaceResolver.normalize(prompt); self.format = format
        rubricClaimIDs = rubric.map(\.id); self.evidence = evidence ?? rubric.map(\.evidence)
        self.relatedConcept = relatedConcept; self.excerpt = excerpt
        id = "probe-" + String(StableIdentity.hash64("\(concept)|\(operation.rawValue)|\(self.prompt)|\(rubricClaimIDs.joined(separator: ","))"), radix: 16)
    }

    /// A choice probe as a question for the existing question card. Never persisted in the
    /// question bank: it is rebuilt from the probe whenever it is needed.
    public var question: LearningQuestion? {
        guard case .choice(let options, let answerIndex) = format, options.indices.contains(answerIndex), let anchor = evidence.first else { return nil }
        let choices = options.map { QuestionOption(id: StableIdentity.uuid(id + "|" + $0), text: $0) }
        return LearningQuestion(id: StableIdentity.uuid(id), stableKey: "probe|" + id, kind: .termMatching, prompt: prompt,
                                options: choices, correctOptionID: choices[answerIndex].id, source: anchor.learningSource,
                                qualityScore: 0.8, generatedAt: Date(timeIntervalSinceReferenceDate: 0),
                                semanticFingerprint: id, propositionID: rubricClaimIDs.first,
                                semanticOperator: Self.operatorPrefix + operation.rawValue)
    }

    static let operatorPrefix = "probe."

    /// What to show once the learner has answered: the probe's own source sentences, which answer
    /// it. The passage a recall card was planned from may be only a heading on the same page.
    public var answerText: String { evidence.map { CanonicalWhitespaceResolver.normalize($0.text) }.joined(separator: "\n\n") }
    public var answerSource: LearningSource? { evidence.first?.learningSource }

    public var level: Int { operation.level }
}

public extension DiagnosisTarget {
    /// What an answer to an open probe is compared against: the probe's rubric claims, with the
    /// concept's neighbours kept as competitors so confusions are still recognised.
    static func probe(_ probe: LearningProbe, in base: ConceptKnowledgeBase) -> DiagnosisTarget? {
        let card = DiagnosisTarget.concept(probe.concept.concept, in: base)
        let pool = (card?.allClaims ?? []) + base.claims(teaching: probe.concept.concept, roles: [.core, .supporting])
        let rubric = probe.rubricClaimIDs.compactMap { id in pool.first { $0.id == id } ?? base.claims.first { $0.id == id } }
        guard !rubric.isEmpty else { return nil }
        let ids = Set(rubric.map(\.id))
        return DiagnosisTarget(concept: probe.concept.concept, conceptName: probe.conceptName, rubric: rubric,
                               supporting: (card?.supporting ?? []).filter { !ids.contains($0.id) },
                               competitors: (card?.competitors ?? []).filter { !ids.contains($0.id) }, names: card?.names ?? [:])
    }
}
