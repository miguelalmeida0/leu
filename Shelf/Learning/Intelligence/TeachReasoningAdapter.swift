import Foundation
import ShelfCore
import LeuReasoningCore

struct ReasonedTeachPoint: Sendable {
    let learner: String
    let explanation: String
    let source: RelationalSourceFact
}
struct ReasonedTeachFeedback: Sendable {
    var captured: [ReasonedTeachPoint] = []
    var worthAdding: [ReasonedTeachPoint] = []
    var check: [ReasonedTeachPoint] = []
    var unsettled: [String] = []
    var fullySupported: Bool { !captured.isEmpty && check.isEmpty && unsettled.isEmpty }
}

/// A selected-passage value prepared off the UI executor. Uses the existing
/// extraction-bound fact cache, never PDFKit, library-wide extraction or a model.
/// It is not persisted as a second source of truth.
struct TeachReasoningAdapter: Sendable {
    let sources: [RelationalSourceFact]
    private let graph: KnowledgeGraph
    private let sourceByAtom: [StableID: RelationalSourceFact]

    init(sources: [RelationalSourceFact], analyses: [UUID: DocumentAnalysis]) {
        self.sources = sources.filter { $0.isCurrent(in: analyses) }
        var atoms: [KnowledgeAtom] = [], bindings: [StableID: RelationalSourceFact] = [:]
        for fact in self.sources {
            let body = SourceSpan(documentID: fact.documentID.uuidString, page: fact.pageIndex + 1,
                canonicalSpan: fact.quote.text, characterOffset: fact.quote.range.location,
                sourceRole: .explanation, extractionVersion: String(fact.extractionVersion))
            let extracted: [KnowledgeAtom]
            if let title = fact.titleSpan, fact.role == "primary_factual" {
                let heading = SourceSpan(documentID: fact.documentID.uuidString, page: fact.pageIndex + 1,
                    canonicalSpan: title.text, characterOffset: title.range.location,
                    sourceRole: .structure, extractionVersion: String(fact.extractionVersion))
                extracted = PacketAtomExtractor().extract(.init(title: fact.title, titleSpan: heading, body: body)).atoms
            } else { extracted = PacketAtomExtractor().extractProse(body).atoms }
            for atom in extracted {
                // Extraction returns exact substrings; never bind generated
                // wording or a neighboring card as the quotation.
                guard let quote = atom.canonicalSpan, fact.quote.text.contains(quote) else { continue }
                atoms.append(atom); bindings[atom.id] = fact
            }
        }
        graph = KnowledgeGraphBuilder().build(atoms: atoms); sourceByAtom = bindings
    }
    var canTeach: Bool { !sources.isEmpty }

    func compare(_ text: String, analyses: [UUID: DocumentAnalysis]) -> ReasonedTeachFeedback {
        guard sources.allSatisfy({ $0.isCurrent(in: analyses) }) else {
            return .init(unsettled: ["This source changed. Reopen it to compare your explanation."])
        }
        // If this grammar cannot represent the source at all, preserve the
        // existing complete bounded contract rather than fragmenting away the
        // context it validates. Unknown families still return no support.
        if graph.atoms.isEmpty {
            let prior = V28TeachPresentation.compare(text, sources: sources, analyses: analyses)
            return .init(captured: prior.captured.map { .init(learner: $0.learner, explanation: $0.assessment.explanation, source: $0.source) },
                worthAdding: prior.worthAdding.map { .init(learner: $0.learner, explanation: $0.assessment.explanation, source: $0.source) },
                check: prior.check.map { .init(learner: $0.learner, explanation: $0.assessment.explanation, source: $0.source) }, unsettled: prior.unsettled)
        }
        let report = SourceBoundExplanationAligner().align(explanation: text, concept: nil, in: graph)
        var result = ReasonedTeachFeedback()
        var coveredByExistingContract = Set<String>()
        for alignment in report.alignments {
            let clause = alignment.proposition.text
            let fact = alignment.matchedAtomID.flatMap { sourceByAtom[$0] }
            if alignment.verdict == .supported, let fact {
                result.captured.append(.init(learner: clause, explanation: "Your source supports this idea.", source: fact))
            } else if alignment.verdict == .contradicted, let fact {
                result.check.append(.init(learner: clause, explanation: "This reverses what the passage states.", source: fact))
            } else {
                // Retain V28.1's independently validated, bounded natural-
                // language contracts. They are not a lexical fallback: each
                // still requires its predicate, scope and identifier checks.
                // They cannot override a demonstrated polarity conflict.
                let prior = V28TeachPresentation.compare(clause, sources: sources, analyses: analyses)
                if !prior.captured.isEmpty && prior.check.isEmpty && prior.unsettled.isEmpty {
                    for point in prior.captured {
                        result.captured.append(.init(learner: point.learner, explanation: point.assessment.explanation, source: point.source))
                        coveredByExistingContract.insert(point.source.id)
                    }
                    for point in prior.worthAdding {
                        result.worthAdding.append(.init(learner: "", explanation: point.assessment.missingConditions.joined(separator: "; "), source: point.source))
                    }
                } else if !prior.check.isEmpty {
                    for point in prior.check {
                        result.check.append(.init(learner: point.learner, explanation: point.assessment.explanation, source: point.source))
                    }
                } else {
                    result.unsettled.append(clause)
                    for point in prior.worthAdding {
                        result.worthAdding.append(.init(learner: "", explanation: point.assessment.explanation, source: point.source))
                    }
                    if let fact, alignment.findings.contains(where: { [.missingCondition, .scopeTooBroad].contains($0.type) }) {
                        result.worthAdding.append(.init(learner: "", explanation: "Keep the condition or limit stated in this passage.", source: fact))
                    }
                }
            }
        }
        // Coverage is independent: a supported subset still leaves the rest
        // of the quoted idea worth adding. Unsupported clauses never count.
        for id in report.unaddressedAtomIDs {
            guard let fact = sourceByAtom[id], !coveredByExistingContract.contains(fact.id),
                  !result.worthAdding.contains(where: { $0.source.id == fact.id }) else { continue }
            result.worthAdding.append(.init(learner: "", explanation: "There is more detail in this part of your source.", source: fact))
        }
        return result
    }
}
