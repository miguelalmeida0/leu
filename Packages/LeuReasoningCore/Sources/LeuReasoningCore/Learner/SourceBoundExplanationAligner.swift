import Foundation

/// Real-PDF alignment has a stricter admission boundary than the prototype's
/// retrieval score. Similarity orders candidates; only predicate, argument,
/// polarity and guard checks can award support.
public struct SourceBoundExplanationAligner: Sendable {
    public init() {}

    public func align(explanation: String, concept: String?, in graph: KnowledgeGraph) -> ExplanationAlignmentReport {
        let clauses = TextScanning.sentences(in: explanation).flatMap { sentence -> [LearnerProposition] in
            for connector in [", and ", ", but ", "; "] {
                if let range = sentence.range(of: connector) {
                    let tail = String(sentence[range.upperBound...])
                    let probe = SourceSpan(documentID: "learner", page: 0, canonicalSpan: tail, sourceRole: .explanation)
                    if !PacketAtomExtractor().extractProse(probe).atoms.isEmpty {
                        return [String(sentence[..<range.lowerBound]), tail].map { PropositionSplitter().parse($0) }
                    }
                }
            }
            // "listeners, subscriptions, and leaks" is a coordinated object,
            // not a second learner proposition.
            return [PropositionSplitter().parse(sentence)]
        }
        let parsedClauses: [(LearnerProposition, KnowledgeAtom?)] = clauses.flatMap { proposition -> [(LearnerProposition, KnowledgeAtom?)] in
            let span = SourceSpan(documentID: "learner", page: 0, canonicalSpan: activeVoice(proposition.text), sourceRole: .explanation)
            let parsed = PacketAtomExtractor().extractProse(span).atoms
            if parsed.isEmpty { return [(proposition, nil)] }
            return parsed.map { atom in
                var component = proposition
                component.id = StableID(namespace: "prop", components: [proposition.text, atom.subject, atom.relation, atom.object])
                return (component, Optional(atom))
            }
        }
        var results: [PropositionAlignment] = []
        for (proposition, candidate) in parsedClauses {
            guard let parsed = candidate else {
                results.append(.init(proposition: proposition, verdict: .notAddressed, matchedAtomID: nil, matchScore: 0, findings: [], feedback: nil))
                continue
            }
            let sameSubject = graph.atoms.filter { equivalentPhrase($0.subject, parsed.subject) }
            let reverse = graph.atoms.first { $0.relation == parsed.relation && equivalentPhrase($0.subject, parsed.object) && equivalentPhrase($0.object, parsed.subject) }
            let candidates = sameSubject.sorted {
                let a = ($0.relation == parsed.relation ? 2.0 : 0) + TextScanning.overlap($0.object, parsed.object)
                let b = ($1.relation == parsed.relation ? 2.0 : 0) + TextScanning.overlap($1.object, parsed.object)
                return a == b ? $0.id.rawValue < $1.id.rawValue : a > b
            }
            guard let source = reverse ?? candidates.first else {
                results.append(.init(proposition: proposition, verdict: .notAddressed, matchedAtomID: nil, matchScore: 0, findings: [], feedback: nil))
                continue
            }
            var findings: [MisconceptionFinding] = []
            func add(_ type: MisconceptionType, _ detail: String) {
                findings.append(.init(type: type, propositionID: proposition.id, atomID: source.id,
                                      detail: detail, feedback: detail, provenance: source.provenance))
            }
            let sourceObject = coreObject(source.object), learnerObject = coreObject(parsed.object)
            let objectsMatch = equivalentPhrase(sourceObject, learnerObject)
            let relationMatches = source.relation == parsed.relation
            if reverse != nil { add(.reversedCauseEffect, "The source states this relationship in the opposite direction.") }
            if objectsMatch && relationMatches && source.isNegated != parsed.isNegated { add(.incorrectNegation, "The learner reversed the source's stated polarity.") }
            if objectsMatch && relationMatches {
                for condition in source.conditions where !parsed.conditions.contains(where: { $0.isPositive == condition.isPositive && equivalentPhrase($0.text, condition.text) }) {
                    add(.missingCondition, "The source restricts this claim: \(condition.isPositive ? "when" : "unless") \(condition.text).")
                }
            }
            let guardLoss = source.qualifiers.contains { !parsed.qualifiers.contains($0) }
            if proposition.quantifier == .universal && (guardLoss || !source.conditions.isEmpty) {
                add(.scopeTooBroad, "The universal claim exceeds the source's modality or condition.")
            } else if objectsMatch && relationMatches && guardLoss {
                add(.missingCondition, "The source's limiting modality or scope was omitted.")
            }
            if source.numbers != parsed.numbers && relationMatches && TextScanning.overlap(sourceObject, learnerObject) > 0.5 {
                add(.numericalMismatch, "The numerical claim differs from the source.")
            }
            if objectsMatch && relationMatches && source.identifiers != parsed.identifiers {
                add(.identifierMismatch, "A technical identifier differs from the source; case and spelling are part of its identity.")
            }
            if !objectsMatch || !relationMatches {
                if reverse == nil { add(.unsupportedAddition, "The source does not establish this predicate and object for \(source.subject).") }
            }
            let verdict: AlignmentVerdict = findings.contains { $0.type.isContradiction } ? .contradicted : findings.isEmpty ? .supported : .partiallySupported
            results.append(.init(proposition: proposition, verdict: verdict, matchedAtomID: source.id,
                                 matchScore: objectsMatch && relationMatches ? 1 : 0, findings: findings,
                                 feedback: GroundedLine.fromAtom(source)))
        }
        let touched = Set(results.compactMap(\.matchedAtomID))
        return .init(alignments: results, unaddressedAtomIDs: graph.atoms.filter { !touched.contains($0.id) && $0.carriesMechanism }.map(\.id), concept: concept)
    }

    private func coreObject(_ value: String) -> String {
        var core = Decomposition(sentence: value).mainClause
        if core.lowercased().hasPrefix("not ") { core = String(core.dropFirst(4)) }
        return core
    }

    private func equivalentPhrase(_ a: String, _ b: String) -> Bool {
        SemanticIdentity.phrase(a) == SemanticIdentity.phrase(b)
    }

    private func activeVoice(_ sentence: String) -> String {
        // Bounded passive grammar, with the same modality retained. No free
        // paraphrasing: the two argument spans are merely exchanged.
        for (passive, active) in [("prevented", "prevents"), ("enabled", "enables"), ("supported", "supports"), ("created", "creates"), ("reduced", "reduces"), ("replaced", "replaces")] {
            for copula in [" is ", " are "] {
                if let middle = sentence.range(of: copula + passive + " by ", options: .caseInsensitive) {
                    let object = String(sentence[..<middle.lowerBound])
                    let subject = String(sentence[middle.upperBound...]).trimmingCharacters(in: CharacterSet(charactersIn: ". "))
                    return subject + " " + active + " " + object + "."
                }
            }
        }
        return sentence
    }
}
