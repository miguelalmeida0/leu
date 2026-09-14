import Foundation

/// Real-PDF alignment has a stricter admission boundary than the prototype's
/// retrieval score. Similarity orders candidates; only predicate, argument,
/// polarity and guard checks can award support.
public struct SourceBoundExplanationAligner: Sendable {
    public init() {}

    public func align(explanation: String, concept: String?, in graph: KnowledgeGraph) -> ExplanationAlignmentReport {
        let clauses = TextScanning.sentences(in: explanation).flatMap { sentence -> [LearnerProposition] in
            for connector in [", and ", ", but ", "; ", " and ", " but "] {
                if let range = sentence.range(of: connector) {
                    let tail = String(sentence[range.upperBound...])
                    let probe = SourceSpan(documentID: "learner", page: 0, canonicalSpan: tail, sourceRole: .explanation)
                    let head = SourceSpan(documentID: "learner", page: 0, canonicalSpan: String(sentence[..<range.lowerBound]), sourceRole: .explanation)
                    if !PacketAtomExtractor().extractProse(probe).atoms.isEmpty && !PacketAtomExtractor().extractProse(head).atoms.isEmpty {
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
                if parsed.count > 1 { component.text = atom.statement + "." }
                return (component, Optional(atom))
            }
        }
        var results: [PropositionAlignment] = []
        var fullyCovered = Set<StableID>()
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
            let exactObject = equivalentPhrase(sourceObject, learnerObject)
            let objectsMatch = exactObject || (!source.isNegated && entails(sourceObject, learnerObject, definition: source.claimType == .definition, relation: source.relation))
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
            if !parsed.numbers.allSatisfy(source.numbers.contains) && relationMatches {
                add(.numericalMismatch, "The numerical claim differs from the source.")
            }
            if objectsMatch && relationMatches && !parsed.identifiers.allSatisfy(source.identifiers.contains) {
                add(.identifierMismatch, "A technical identifier differs from the source; case and spelling are part of its identity.")
            }
            if !objectsMatch || !relationMatches {
                if reverse == nil { add(.unsupportedAddition, "The source does not establish this predicate and object for \(source.subject).") }
            }
            // A reverse causal arrow, a missing guard, or an unmentioned effect
            // is not a proven falsehood. Only explicit opposite polarity of
            // the same assertion establishes a conflict here.
            let verdict: AlignmentVerdict = findings.contains { $0.type == .incorrectNegation } ? .contradicted : findings.isEmpty ? .supported : .notAddressed
            if verdict == .supported && exactObject { fullyCovered.insert(source.id) }
            results.append(.init(proposition: proposition, verdict: verdict, matchedAtomID: source.id,
                                 matchScore: objectsMatch && relationMatches ? 1 : 0, findings: findings,
                                 feedback: GroundedLine.fromAtom(source)))
        }
        return .init(alignments: results, unaddressedAtomIDs: graph.atoms.filter { !fullyCovered.contains($0.id) }.map(\.id), concept: concept)
    }

    /// Conservative, directional entailment, never a bag-of-words score.
    /// A distributive prevention list entails a member. A positive definition
    /// entails its bare nominal head. Neither rule works in reverse, through
    /// disjunction/negation, or for collective predicates such as "combines".
    private func entails(_ source: String, _ learner: String, definition: Bool, relation: String) -> Bool {
        let s = SemanticIdentity.phrase(source), l = SemanticIdentity.phrase(learner)
        guard !s.contains(" or "), !s.contains(" not "), !l.isEmpty else { return false }
        if relation == "prevents" {
            let members = source.replacingOccurrences(of: ", and ", with: ", ").replacingOccurrences(of: " and ", with: ", ").components(separatedBy: ", ")
            if members.count > 1 && members.contains(where: { equivalentPhrase($0, learner) }) { return true }
        }
        if definition && !l.contains(" ") {
            let head = s.components(separatedBy: " used ")[0].components(separatedBy: " for ")[0]
            let words = head.split(separator: " ")
            // A hyphenated classifier followed by a head noun supplies an
            // explicit subtype. Arbitrary adjective deletion is not licensed
            // (e.g. "fake diamond" does not entail "diamond").
            return words.count == 2 && words[0].contains("-") && words[1] == l
        }
        return false
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
