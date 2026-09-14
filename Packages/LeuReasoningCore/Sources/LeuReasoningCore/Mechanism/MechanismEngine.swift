import Foundation

/// The five mechanism questions the engine can answer from the graph alone.
public enum MechanismQuestion: Codable, Equatable, Sendable {
    case why(String)
    case whatDoesThisEnable(String)
    case whatDependsOnThis(String)
    case whatThisRequires(String)
    case whatBreaksWithoutThis(String)
    case whatHappensNext(String)

    public var focusText: String {
        switch self {
        case .why(let text), .whatDoesThisEnable(let text), .whatDependsOnThis(let text),
             .whatThisRequires(let text), .whatBreaksWithoutThis(let text), .whatHappensNext(let text):
            return text
        }
    }

    /// Which relation kinds the traversal may follow, and in which direction.
    var traversal: (kinds: [RelationKind], forward: Bool, maxDepth: Int) {
        switch self {
        case .why:
            return ([.enables, .causes, .supports, .prevents, .explains, .reduces, .increases,
                     .creates, .makes, .keeps, .gives, .separates, .decouples, .replaces,
                     .catches, .derives, .balances, .trades, .models], true, 4)
        case .whatDoesThisEnable:
            return ([.enables, .supports], true, 2)
        case .whatHappensNext:
            return ([.causes, .consequenceOf], true, 3)
        case .whatDependsOnThis:
            return ([.requires, .prerequisiteOf], false, 2)
        case .whatThisRequires:
            return ([.requires, .prerequisiteOf], true, 2)
        case .whatBreaksWithoutThis:
            return ([.requires, .prerequisiteOf], false, 3)
        }
    }
}

/// One traversal step, fully attributed.
public struct MechanismStep: Codable, Equatable, Sendable {
    public var relationID: StableID
    public var kind: RelationKind
    public var fromLabel: String
    public var toLabel: String
    public var conditions: [ClaimCondition]
    public var provenance: Provenance
    public var qualifiers: [Qualifier]

    public init(relationID: StableID,
                kind: RelationKind,
                fromLabel: String,
                toLabel: String,
                conditions: [ClaimCondition],
                provenance: Provenance, qualifiers: [Qualifier] = []) {
        self.relationID = relationID
        self.kind = kind
        self.fromLabel = fromLabel
        self.toLabel = toLabel
        self.conditions = conditions
        self.provenance = provenance
        self.qualifiers = qualifiers
    }

    public var arrow: String { "\(fromLabel) —\(qualifiedRelation)→ \(toLabel)" }
    public var qualifiedRelation: String {
        let guards = qualifiers.map(\.text) + conditions.map { "\($0.isPositive ? "when" : "unless") \($0.text)" }
        return kind.rawValue + (guards.isEmpty ? "" : " [" + guards.joined(separator: "; ") + "]")
    }
}

/// A full path through the mechanism, plus its rendered narrative.
public struct MechanismPath: Codable, Equatable, Sendable {
    public var steps: [MechanismStep]
    public var admissibility: Admissibility
    public var provenance: Provenance

    public init(steps: [MechanismStep], admissibility: Admissibility, provenance: Provenance) {
        self.steps = steps
        self.admissibility = admissibility
        self.provenance = provenance
    }

    /// Rendered as source-grounded chain notation, never as free prose.
    public var narrative: String {
        guard let first = steps.first else { return "" }
        var line = first.fromLabel
        for step in steps { line += "\n  → \(step.qualifiedRelation): \(step.toLabel)" }
        return line
    }

    public var conditions: [ClaimCondition] {
        var all: [ClaimCondition] = []
        for step in steps {
            for condition in step.conditions where !all.contains(condition) { all.append(condition) }
        }
        return all
    }
}

public struct MechanismAnswer: Codable, Equatable, Sendable {
    public var question: MechanismQuestion
    public var focusLabel: String?
    public var paths: [MechanismPath]
    /// Set when the engine has nothing grounded to say. This is a first-class
    /// outcome, not an error: "your sources do not explain this" is a true and
    /// useful answer.
    public var unansweredReason: String?

    public init(question: MechanismQuestion,
                focusLabel: String?,
                paths: [MechanismPath],
                unansweredReason: String? = nil) {
        self.question = question
        self.focusLabel = focusLabel
        self.paths = paths
        self.unansweredReason = unansweredReason
    }

    public var isAnswered: Bool { !paths.isEmpty }
}

/// Bounded graph traversal. Every returned step is an edge that already exists
/// in the graph, so the engine cannot invent a bridge; multi-step paths are
/// marked `inferredValidated` because composing two source facts is Leu's
/// inference, not the document's sentence.
public struct MechanismEngine: Sendable {
    public var maxPaths: Int
    public var maxDepth: Int

    public init(maxPaths: Int = 6, maxDepth: Int = 4) {
        self.maxPaths = maxPaths
        self.maxDepth = maxDepth
    }

    public func answer(_ question: MechanismQuestion, in graph: KnowledgeGraph) -> MechanismAnswer {
        guard let focus = graph.resolveNode(question.focusText) else {
            return MechanismAnswer(question: question,
                                   focusLabel: nil,
                                   paths: [],
                                   unansweredReason: "No source in this library talks about \"\(question.focusText)\".")
        }
        let plan = question.traversal
        let depth = min(plan.maxDepth, maxDepth)
        var paths = traverse(from: focus.id,
                             in: graph,
                             kinds: plan.kinds,
                             forward: plan.forward,
                             maxDepth: depth)

        if case .whatBreaksWithoutThis = question {
            paths = extendWithFailureModes(paths, focus: focus, in: graph)
        }
        if case .why = question {
            // A definition alone answers "what is it", not "why it matters".
            paths = paths.filter { $0.steps.contains { $0.kind != .explains } }
        }

        paths = Array(paths.prefix(maxPaths))
        if paths.isEmpty {
            return MechanismAnswer(question: question,
                                   focusLabel: focus.label,
                                   paths: [],
                                   unansweredReason: "Your sources mention \"\(focus.label)\" but do not state \(explanationNoun(question)).")
        }
        return MechanismAnswer(question: question, focusLabel: focus.label, paths: paths,
                               unansweredReason: paths.contains { $0.steps.count >= depth }
                                 ? "Traversal stopped at its configured depth; further steps were not evaluated."
                                 : "Source does not establish a further step beyond these admitted edges.")
    }

    func explanationNoun(_ question: MechanismQuestion) -> String {
        switch question {
        case .why: return "why it matters"
        case .whatDoesThisEnable: return "what it enables"
        case .whatDependsOnThis: return "what depends on it"
        case .whatThisRequires: return "what it requires"
        case .whatBreaksWithoutThis: return "what breaks without it"
        case .whatHappensNext: return "what happens next"
        }
    }

    /// Depth-first, deterministic (relations are visited in id order), cycle
    /// free, and capped. Paths are emitted longest-first so the most explanatory
    /// chain surfaces before its own prefix.
    func traverse(from start: StableID,
                  in graph: KnowledgeGraph,
                  kinds: [RelationKind],
                  forward: Bool,
                  maxDepth: Int) -> [MechanismPath] {
        var results: [MechanismPath] = []
        var stack: [(node: StableID, steps: [MechanismStep], visited: Set<String>)] = [
            (start, [], [start.rawValue])
        ]
        while let current = stack.popLast() {
            guard current.steps.count < maxDepth else {
                appendPath(&results, steps: current.steps)
                continue
            }
            let edges = (forward ? graph.outgoing(from: current.node) : graph.incoming(to: current.node))
                .filter { kinds.contains($0.kind) }
                .sorted { $0.id.rawValue < $1.id.rawValue }
            if edges.isEmpty {
                appendPath(&results, steps: current.steps)
                continue
            }
            var extended = false
            for edge in edges {
                let nextID = forward ? edge.object.id : edge.subject.id
                guard !current.visited.contains(nextID.rawValue) else { continue }
                guard let fromNode = graph.node(forward ? edge.subject.id : edge.object.id),
                      let toNode = graph.node(nextID) else { continue }
                let step = MechanismStep(relationID: edge.id,
                                         kind: edge.kind,
                                         fromLabel: forward ? fromNode.label : toNode.label,
                                         toLabel: forward ? toNode.label : fromNode.label,
                                         conditions: edge.conditions,
                                         provenance: edge.provenance, qualifiers: edge.qualifiers)
                var visited = current.visited
                visited.insert(nextID.rawValue)
                stack.append((nextID, current.steps + [step], visited))
                extended = true
            }
            if !extended { appendPath(&results, steps: current.steps) }
        }
        return results.sorted { lhs, rhs in
            if lhs.steps.count != rhs.steps.count { return lhs.steps.count > rhs.steps.count }
            return lhs.narrative < rhs.narrative
        }
    }

    func appendPath(_ results: inout [MechanismPath], steps: [MechanismStep]) {
        guard !steps.isEmpty else { return }
        let admissibility: Admissibility = steps.count == 1 ? .sourceSupported : .inferredValidated
        let provenance: Provenance
        if steps.count == 1 {
            provenance = steps[0].provenance
        } else {
            provenance = Provenance.inferred(from: steps.map(\.provenance),
                                             ids: steps.map(\.relationID),
                                             rule: .causalComposition)
        }
        let path = MechanismPath(steps: steps, admissibility: admissibility, provenance: provenance)
        // Drop a path that is merely a prefix of one already collected.
        if results.contains(where: { $0.steps.count > steps.count && Array($0.steps.prefix(steps.count)) == steps }) {
            return
        }
        results.removeAll { candidate in
            candidate.steps.count < steps.count && Array(steps.prefix(candidate.steps.count)) == candidate.steps
        }
        if !results.contains(where: { $0.steps == steps }) { results.append(path) }
    }

    /// "What breaks without X" is the contrapositive of a stated requirement,
    /// extended by any failure-mode atom that names the dependent.
    func extendWithFailureModes(_ paths: [MechanismPath],
                                focus: KnowledgeNode,
                                in graph: KnowledgeGraph) -> [MechanismPath] {
        var extended = paths
        for path in paths {
            guard let last = path.steps.last else { continue }
            let dependent = last.toLabel
            for atom in graph.atoms where atom.claimType == .failureMode || atom.claimType == .consequence {
                guard TextScanning.coverage(of: dependent, in: atom.subject) >= 0.6 else { continue }
                guard let kind = RelationKind(rawValue: atom.relation) else { continue }
                let step = MechanismStep(relationID: atom.id,
                                         kind: kind,
                                         fromLabel: atom.subject,
                                         toLabel: atom.object,
                                         conditions: atom.conditions,
                                         provenance: atom.provenance)
                let steps = path.steps + [step]
                let provenance = Provenance.inferred(from: steps.map(\.provenance),
                                                     ids: steps.map(\.relationID),
                                                     rule: .contrapositiveOfRequirement)
                let candidate = MechanismPath(steps: steps,
                                              admissibility: .inferredValidated,
                                              provenance: provenance)
                if !extended.contains(where: { $0.steps == steps }) { extended.append(candidate) }
            }
        }
        return extended.sorted { $0.steps.count > $1.steps.count }
    }
}
