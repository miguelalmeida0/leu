import Foundation

public enum V28EvidenceLevel: String, Sendable { case sourceSupported = "SOURCE_SUPPORTED", inferredValidated = "INFERRED_VALIDATED" }

public extension GroundedConnectionV2 {
    func related(to reading: IntelligenceSource) -> RelationalSourceFact {
        sourceA.documentID == reading.packet.documentID ? sourceB : sourceA
    }
}

public extension RelationalSourceFact {
    var passage: LearningSource {
        LearningSource(documentID: documentID, pageIndex: pageIndex, sourceText: quote.text, range: quote.range, sectionTitle: title)
    }
    func citation(in analyses: [UUID: DocumentAnalysis]) -> IntelligenceSource? {
        guard isCurrent(in: analyses), let analysis = analyses[documentID] else { return nil }
        return IntelligenceSource(source: passage, analysis: analysis)
    }
}

/// Contextual ranking is downstream of unchanged two-source admission.
public struct V28ConnectionIndex: Sendable {
    public let facts: [RelationalSourceFact]
    public init(analyses: [UUID: DocumentAnalysis], titles: [UUID: String]) {
        facts = analyses.values.flatMap { RelationalSourceFact.extract(analysis: $0, documentTitle: titles[$0.documentID] ?? "Source") }
    }
    init(facts: [RelationalSourceFact]) { self.facts = facts }
    public func anchors(for source: IntelligenceSource) -> [RelationalSourceFact] {
        guard let range = source.passage.range else { return [] }
        return facts.filter {
            $0.documentID == source.packet.documentID && $0.pageIndex == source.packet.pageIndex &&
            $0.fingerprint == source.packet.fingerprint &&
            max(range.location, $0.quote.range.location) < min(range.location + range.length, $0.quote.range.location + $0.quote.range.length)
        }
    }
    public func connections(from source: IntelligenceSource, analyses: [UUID: DocumentAnalysis]) -> [GroundedConnectionV2] {
        let started = DispatchTime.now().uptimeNanoseconds
        defer { IntelligencePerformance.record("connection_query", since: started, workCount: facts.count) }
        guard source.isCurrent(in: analyses) else { return [] }
        var found: [GroundedConnectionV2] = [], seen = Set<String>()
        for a in anchors(for: source) {
            for b in facts where a.documentID != b.documentID {
                guard let c = ConnectionAdmissionV2.admit(a, b) ?? ConnectionAdmissionV2.admit(b, a), ConnectionAdmissionV2.validate(c, analyses: analyses) == nil,
                      seen.insert(c.id).inserted else { continue }
                found.append(c)
            }
        }
        return found.sorted {
            let a = Self.rank($0), b = Self.rank($1)
            return a == b ? $0.id < $1.id : a > b
        }
    }
    private static func rank(_ c: GroundedConnectionV2) -> Int {
        // The current passage is already mandatory. A validated bridge adds a
        // different concept; restating the same mechanism follows it.
        c.relationship == "mechanism" ? 100 : 50
    }
    public func activity(from source: IntelligenceSource, analyses: [UUID: DocumentAnalysis]) -> ActivityDefinition? {
        activity(from: source, analyses: analyses, connections: connections(from: source, analyses: analyses))
    }
    func activity(from source: IntelligenceSource, analyses: [UUID: DocumentAnalysis], connections: [GroundedConnectionV2]) -> ActivityDefinition? {
        guard source.isCurrent(in: analyses), !anchors(for: source).isEmpty else { return nil }
        let sources = [source] + connections.compactMap { $0.related(to: source).citation(in: analyses) }
        for citation in sources {
            guard let analysis = analyses[citation.packet.documentID],
                  let full = IntelligenceSource(source: .init(documentID: citation.packet.documentID,
                    pageIndex: citation.packet.pageIndex, sourceText: citation.packet.sourceText), analysis: analysis) else { continue }
            if let definition = ActivityValidator.definition(for: full) { return definition }
        }
        return nil
    }
}

public struct TeachSourcePoint: Equatable, Sendable {
    public let learner: String
    public let source: RelationalSourceFact
    public let assessment: TeachSemanticAssessment
}
public struct TeachSourceFeedback: Equatable, Sendable {
    public var captured: [TeachSourcePoint] = []
    public var worthAdding: [TeachSourcePoint] = []
    public var check: [TeachSourcePoint] = []
    public var unsettled: [String] = []
    public var connected = false
}

/// Shared by Teach Leu and Teach this connection. Each clause keeps the exact
/// source that supports it. Matching one clause never approves an unknown one.
public enum V28TeachPresentation {
    public static func compare(_ text: String, sources: [RelationalSourceFact], analyses: [UUID: DocumentAnalysis],
                               connection: GroundedConnectionV2? = nil) -> TeachSourceFeedback {
        let started = DispatchTime.now().uptimeNanoseconds
        defer { IntelligencePerformance.record("teach_analysis", since: started, workCount: sources.count) }
        let current = sources.filter { $0.isCurrent(in: analyses) }
        var result = TeachSourceFeedback(), used = Set<String>()
        for clause in LearnerClaim.split(text) {
            let candidates = current.map { source -> TeachSourcePoint in
                var assessment = TeachLeuV2.evaluate(clause.text, source: source, analyses: analyses)
                if assessment.family == nil || assessment.reasonCode == "unsettled_relation" {
                    if let bridge = connection, ConnectionAdmissionV2.validate(bridge, analyses: analyses) == nil,
                       let comparison = reconciliation(clause.text, source: source) { assessment = comparison }
                }
                return TeachSourcePoint(learner: clause.text, source: source, assessment: assessment)
            }
            let supported = candidates.filter { $0.assessment.status == .supported }
            if !supported.isEmpty {
                result.captured += supported
                for p in supported { used.insert(p.source.id); if !p.assessment.missingConditions.isEmpty { result.worthAdding.append(p) } }
            } else if let point = candidates.first(where: { $0.assessment.status == .contradicted }) {
                result.check.append(point)
            } else if let point = candidates.first(where: { $0.assessment.status == .overgeneralized || $0.assessment.status == .incomplete }) {
                result.worthAdding.append(point)
            } else { result.unsettled.append(clause.text) }
        }
        if let connection, ConnectionAdmissionV2.validate(connection, analyses: analyses) == nil {
            result.connected = used.contains(connection.sourceA.id) && used.contains(connection.sourceB.id) && result.check.isEmpty && result.unsettled.isEmpty
        }
        return result
    }
    private static func reconciliation(_ learner: String, source: RelationalSourceFact) -> TeachSemanticAssessment? {
        guard source.relations.contains(where: { $0.relation == "governs-with-type-and-keys" }) else { return nil }
        let text = CanonicalWhitespaceResolver.normalize(learner).lowercased()
        func result(_ status: TeachSemanticAssessment.Status, _ code: String, _ message: String, _ missing: [String] = []) -> TeachSemanticAssessment {
            .init(status: status, family: "react.reconciliation", reasonCode: code, explanation: message,
                missingConditions: missing, complete: status == .supported, backend: "deterministic-two-source-comparison")
        }
        if text.contains("always preserve") || text.contains("always keep") || text.contains("keys alone") || text.contains("regardless of type") {
            return result(.overgeneralized, "missing_element_type_condition", "This source makes instance preservation or replacement depend on both element type and keys.", ["element type and keys", "preservation or replacement"])
        }
        guard text.contains("reconciliation") || text.contains("compares") else { return nil }
        let protected = ProtectedSemanticTokens(learner), evidence = ProtectedSemanticTokens(source.quote.text)
        guard protected.numbers.isSubset(of: evidence.numbers), protected.operators.isSubset(of: evidence.operators),
              protected.identifiers.isSubset(of: evidence.identifiers) else {
            return result(.unsupported, "unbound_reconciliation_detail", "This passage does not establish the added numeric or code detail.")
        }
        // This one product slice admits a bounded paraphrase of the actual
        // comparison packet. Unknown effects and reversed conditions stay open.
        let allowed = Set(("react reconciliation compares comparing comparison previous next old new element elements trees tree using uses based on both type types and key keys decide decides deciding whether how to keep keeps preserve preserves preserving replace replaces replacing or component components instances instance mounted ui update updates process the a is its with it of this determines identity correspondence").split(separator: " ").map(String.init))
        let words = Set(text.split { !$0.isLetter }.map(String.init))
        guard words.isSubset(of: allowed), text.contains("type"), text.contains("keys"),
              text.contains("instance"), text.contains("replace"),
              text.contains("preserv") || text.contains("keep") else { return nil }
        return result(.supported, "instance_decision_captured", "You connected comparison with keeping or replacing component instances, retaining element type and keys.")
    }
}

public struct LibraryExplanationItem: Identifiable, Equatable, Codable, Sendable {
    public enum Kind: String, Codable, Sendable { case explanation = "CLEAREST EXPLANATION", example = "A USEFUL EXAMPLE", related = "RELATED IDEA" }
    public let kind: Kind
    public let source: RelationalSourceFact
    public let passage: LearningSource
    public var evidenceLevel: V28EvidenceLevel { kind == .related ? .inferredValidated : .sourceSupported }
    public var id: String { kind.rawValue + source.id }
    public func isCurrent(in analyses: [UUID: DocumentAnalysis]) -> Bool {
        guard source.isCurrent(in: analyses) else { return false }
        if kind != .example { return passage == source.passage }
        guard let analysis = analyses[source.documentID], let page = analysis.pages.first(where: { $0.pageIndex == source.pageIndex }),
              let card = CardContext(analysis: analysis, page: page) else { return false }
        return passage.documentID == source.documentID && passage.pageIndex == source.pageIndex &&
            card.exampleBlocks.contains { $0.text == passage.sourceText && $0.range == passage.range }
    }
}
public enum ExplainFromLibrary {
    public static func results(source: IntelligenceSource, index: V28ConnectionIndex, analyses: [UUID: DocumentAnalysis]) -> [LibraryExplanationItem] {
        results(source: source, index: index, analyses: analyses, connections: index.connections(from: source, analyses: analyses))
    }
    static func results(source: IntelligenceSource, index: V28ConnectionIndex, analyses: [UUID: DocumentAnalysis], connections: [GroundedConnectionV2]) -> [LibraryExplanationItem] {
        guard source.isCurrent(in: analyses) else { return [] }
        let anchors = index.anchors(for: source).filter { $0.isCurrent(in: analyses) }
        let explanations = anchors + connections.filter { $0.relationship == "sameMechanism" }.map { $0.related(to: source) }
        guard let clearest = explanations.min(by: { $0.quote.text.count < $1.quote.text.count }) else { return [] }
        var output = [LibraryExplanationItem(kind: .explanation, source: clearest, passage: clearest.passage)]
        for fact in anchors + connections.map({ $0.related(to: source) }) {
            guard let analysis = analyses[fact.documentID], let page = analysis.pages.first(where: { $0.pageIndex == fact.pageIndex }),
                  let card = CardContext(analysis: analysis, page: page), let example = card.exampleBlocks.first else { continue }
            output.append(.init(kind: .example, source: fact, passage: .init(documentID: fact.documentID,
                pageIndex: fact.pageIndex, sourceText: example.text, range: example.range, sectionTitle: card.title)))
            break
        }
        if let related = connections.first?.related(to: source) { output.append(.init(kind: .related, source: related, passage: related.passage)) }
        return output.filter { $0.isCurrent(in: analyses) }
    }
}

/// Prediction is collected before the existing V27 transition executes.
public struct KeyIdentityPrediction: Equatable, Sendable {
    public enum Prediction: String, CaseIterable, Sendable {
        case followsItem = "State follows the same item", staysAtPosition = "State stays at the position"
    }
    public private(set) var state = ActivityState()
    public private(set) var prediction: Prediction?
    public private(set) var revealed = false
    public init() {}
    public mutating func choose(_ keys: ActivityState.Keys, definition: ActivityDefinition) throws {
        guard definition.contract == .stableKeys else { throw ActivityError.invalidTransition }
        try state.apply(.chooseKeys(keys), definition: definition); prediction = nil; revealed = false
    }
    public mutating func predict(_ value: Prediction) { guard !revealed else { return }; prediction = value }
    public mutating func edit(_ item: String, definition: ActivityDefinition) throws {
        guard !revealed, definition.contract == .stableKeys else { throw ActivityError.invalidTransition }
        try state.apply(.edit(item), definition: definition)
    }
    public mutating func reveal(definition: ActivityDefinition, analyses: [UUID: DocumentAnalysis]) throws {
        guard prediction != nil, !revealed, definition.contract == .stableKeys,
              ActivityValidator.accepts(definition, analyses: analyses) else { throw ActivityError.invalidTransition }
        try state.apply(.reorder, definition: definition); revealed = true
    }
}
