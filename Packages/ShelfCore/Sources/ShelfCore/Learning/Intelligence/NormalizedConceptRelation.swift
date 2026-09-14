import Foundation

public struct NormalizedConceptRelation: Codable, Equatable, Hashable, Sendable {
    public let subject: String
    public let relation: String
    public let object: String
    public let rule: String
}

public struct RelationalSourceFact: Codable, Equatable, Sendable, Identifiable {
    public let documentID: UUID
    public let documentTitle: String
    public let fingerprint: String
    public let extractionVersion: Int
    public let pageIndex: Int
    public let title: String
    public let titleSpan: CanonicalWhitespaceResolver.Span?
    public let quote: CanonicalWhitespaceResolver.Span
    public let role: String
    public var id: String { "\(documentID)|\(fingerprint)|\(pageIndex)|\(quote.range.location)" }
    public var relations: [NormalizedConceptRelation] { ConceptRelationNormalizer.relations(self) }
    public func isCurrent(in analyses: [UUID: DocumentAnalysis]) -> Bool {
        guard let analysis = analyses[documentID], analysis.fingerprint == fingerprint,
              analysis.extractionVersion == extractionVersion,
              let page = analysis.pages.first(where: { $0.pageIndex == pageIndex }), page.spatialIntegrityPassed == true,
              let text = page.canonicalText, let span = CanonicalWhitespaceResolver.resolve(quote.text, in: text), span == quote else { return false }
        return Self.extract(analysis: analysis, documentTitle: documentTitle, onlyPage: pageIndex).contains(self)
    }
    public static func extract(analysis: DocumentAnalysis, documentTitle: String, onlyPage: Int? = nil) -> [Self] {
        guard analysis.extractionVersion == SourceExtractionVersion.current else { return [] }
        var result: [Self] = []
        for page in analysis.pages where onlyPage == nil || page.pageIndex == onlyPage {
            guard page.spatialIntegrityPassed == true, let canonical = page.canonicalText else { continue }
            if let card = CardContext(analysis: analysis, page: page) {
                for claim in ContextualClaimComposer().compose(analysis: analysis, page: page).claims {
                    result.append(.init(documentID: analysis.documentID, documentTitle: documentTitle,
                        fingerprint: analysis.fingerprint, extractionVersion: SourceExtractionVersion.current,
                        pageIndex: page.pageIndex, title: card.title, titleSpan: card.titleSpan, quote: claim.original, role: "primary_factual"))
                }
                continue
            }
            // A malformed card never falls through into generic prose admission.
            guard !page.segments.contains(where: { SourceRoleMap.headingRole($0.text) != nil }) else { continue }
            for segment in page.segments where segment.kind != .code && segment.kind != .heading {
                guard !InstructionalText.excludesFromStudy(segment),
                      let span = CanonicalWhitespaceResolver.resolve(segment.text, in: canonical) else { continue }
                var group: [CanonicalWhitespaceResolver.Span] = []
                func flush() {
                    guard let first = group.first, let last = group.last else { return }
                    let range = SourceTextRange(location: first.range.location, length: last.range.location + last.range.length - first.range.location)
                    let quote = CanonicalWhitespaceResolver.Span(range: range,
                        text: (canonical as NSString).substring(with: NSRange(location: range.location, length: range.length)))
                    let value = Self(documentID: analysis.documentID, documentTitle: documentTitle, fingerprint: analysis.fingerprint,
                        extractionVersion: SourceExtractionVersion.current, pageIndex: page.pageIndex,
                        title: segment.sectionTitle ?? documentTitle, titleSpan: nil, quote: quote, role: "ordinary_factual_prose")
                    if !value.relations.isEmpty { result.append(value) }
                    group = []
                }
                for sentence in ContextualClaimComposer.sentences(span) {
                    let text = CanonicalWhitespaceResolver.normalize(sentence.text)
                    if InstructionalText.isReaderInstruction(text) ||
                        text.range(of: #"(?i)^(?:decide|ask|identify|practice|review exercise|close the document|primary reading|reading question|use a bookmark|these are original|this is original)\b"#, options: .regularExpression) != nil {
                        flush(); continue
                    }
                    group.append(sentence)
                    if group.count == 3 { flush() }
                }
                flush()
            }
        }
        return result
    }
}

/// Finite technical aliases plus a required relational assertion. Finding a
/// keyword or a similar embedding alone never produces an edge.
public enum ConceptRelationNormalizer {
    public static func relations(_ fact: RelationalSourceFact) -> [NormalizedConceptRelation] {
        let text = CanonicalWhitespaceResolver.normalize(fact.quote.text).lowercased()
        let title = TechnicalConceptCatalog.titleKey(fact.title)
        var edges: [NormalizedConceptRelation] = []
        func has(_ options: String...) -> Bool { options.contains(where: text.contains) }
        func add(_ subject: String, _ relation: String, _ object: String, _ rule: String) {
            edges.append(.init(subject: subject, relation: relation, object: object, rule: rule))
        }
        let reversed = text.range(of: #"\b(?:does not|do not|never|cannot|can not|not) (?:help|match|select|return|create|keep|retain|reuse|avoid|preserve|access|allow|let)\b"#, options: .regularExpression) != nil
        guard !reversed else { return [] }
        if has("react"), has("stable key", "correct keys", "react key"), has("match"), has("item", "instance") {
            add("react.stable-key", "enables", "react.item-correspondence", "react-key-positive-match")
        }
        if title == "reconciliation", has("comparing previous and next"), has("preserves or replaces component instances"), has("element type and keys") {
            add("react.item-correspondence", "governs-with-type-and-keys", "react.instance-preservation-or-replacement", "react-reconciliation-comparison-and-qualified-instance-rule")
        }
        let js = fact.documentTitle.lowercased().contains("javascript") || title.hasPrefix("array.") || has("array method")
        if js {
            if (title == "array.find" || has("find selects")), has("first"), has("matching", "predicate") {
                add("js.array.find", "selects", "js.first-matching-value", "find-first-matching")
            }
            if (title == "array.filter" || has("filter creates")), has("array"), has("matching values", "elements that pass a predicate") {
                add("js.array.filter", "selects", "js.collection-of-matches", "filter-matching-collection")
            }
            if (title == "array.some" || has("some asks")), has("a match exists", "at least one"), has("predicate", "match") {
                add("js.array.some", "tests", "js.predicate-existence", "some-existential-predicate")
            }
            if (title == "array.every" || has("every asks")), has("all"), has("pass"), has("predicate", "visited items") {
                add("js.array.every", "tests", "js.universal-predicate", "every-universal-predicate-scope-retained")
            }
        }
        if (title == "closure" || has("a closure is", "closure keeps")), has("function"), has("access"), has("lexical", "scope where it was created") {
            add("programming.closure", "retains-access", "programming.lexical-environment", "closure-lexical-access")
        }
        if (title == "immutability" && has("existing data as unchanged") && has("creating new values")) ||
            (has("without mutating the source array") && has("create a new array and a new object")) {
            add("programming.immutable-update", "creates", "programming.new-value-preserving-input", "immutable-update-preserves-input")
        }
        if (title == "shallow copy" || has("shallow update")), has("reused", "reuse"), has("object", "references") {
            add("programming.shallow-copy", "reuses", "programming.existing-object-references", "shallow-reference-reuse-scope-retained")
        }
        if (title == "cache" || has("cache")), has("avoids repeating work", "reusable results so expensive work can be avoided") {
            add("cache.reuse", "avoids", "computation.repeated-work", "cache-reuse-work-avoidance")
        }
        return Array(Set(edges)).sorted { ($0.subject + $0.object) < ($1.subject + $1.object) }
    }
    public static func effectLabel(_ node: String) -> String {
        ["react.item-correspondence": "matching list items across renders using keys",
         "js.first-matching-value": "selecting the first matching value",
         "js.collection-of-matches": "forming an array of matching elements",
         "js.predicate-existence": "checking whether a matching element exists",
         "js.universal-predicate": "checking the predicate across all elements in the stated scope",
         "programming.lexical-environment": "a function's access to its lexical environment",
         "programming.new-value-preserving-input": "creating new values while preserving the input",
         "programming.existing-object-references": "reusing existing object references in a shallow copy or update",
         "computation.repeated-work": "avoiding repeated work through cached results"][node] ?? node
    }
}

public struct GroundedConnectionV2: Codable, Equatable, Sendable, Identifiable {
    public let sourceA: RelationalSourceFact
    public let sourceB: RelationalSourceFact
    public let relationA: NormalizedConceptRelation
    public let relationB: NormalizedConceptRelation
    public let relationship: String
    public let proofLevel: String
    public let whyValid: String
    public var id: String { sourceA.id + "|" + sourceB.id + "|" + relationA.object }
}

public enum ConnectionAdmissionV2 {
    public static func admit(_ a: RelationalSourceFact, _ b: RelationalSourceFact) -> GroundedConnectionV2? {
        guard a.documentID != b.documentID, !a.relations.isEmpty, !b.relations.isEmpty,
              CanonicalWhitespaceResolver.normalize(a.quote.text) != CanonicalWhitespaceResolver.normalize(b.quote.text) else { return nil }
        for x in a.relations { for y in b.relations {
            if x.subject == y.subject, x.relation == y.relation, x.object == y.object {
                return .init(sourceA: a, sourceB: b, relationA: x, relationB: y, relationship: "sameMechanism",
                    proofLevel: "INFERRED_VALIDATED", whyValid: "Both factual passages independently describe " + ConceptRelationNormalizer.effectLabel(x.object) + ". The comparison is inferred from those two explicit assertions; their original conditions remain in the quotations.")
            }
            if x.object == y.subject, x.relation == "enables", y.relation == "governs-with-type-and-keys" {
                return .init(sourceA: a, sourceB: b, relationA: x, relationB: y, relationship: "mechanism",
                    proofLevel: "INFERRED_VALIDATED", whyValid: "A links stable keys to matching list items with earlier instances. B links render comparison, element type and keys to preserving or replacing component instances. The shared correspondence concept connects the passages; B's type-and-key condition is retained.")
            }
        } }
        return nil
    }
    public static func validate(_ connection: GroundedConnectionV2, analyses: [UUID: DocumentAnalysis]) -> String? {
        guard connection.sourceA.isCurrent(in: analyses), connection.sourceB.isCurrent(in: analyses) else { return "source_binding_or_role_failed" }
        guard admit(connection.sourceA, connection.sourceB) == connection else { return "unsupported_relation_or_bridge" }
        return nil
    }
}

public struct ConnectionResultsV2: Sendable {
    public let admitted: [GroundedConnectionV2]
    public let rejected: [[String: String]]
    public init(analyses: [UUID: DocumentAnalysis], titles: [UUID: String], limit: Int = 10) {
        let facts = analyses.values.flatMap { RelationalSourceFact.extract(analysis: $0, documentTitle: titles[$0.documentID] ?? "Source") }
        let originals = facts.filter { !$0.relations.isEmpty }
        var records: [KnowledgeIndexRecord] = [], byID: [UUID: RelationalSourceFact] = [:]
        for fact in facts where !fact.relations.isEmpty {
            let id = StableIdentity.uuid(fact.id)
            let terms = HybridLocalIndex.tokens(fact.quote.text) + fact.relations.flatMap { [$0.subject, $0.object] }
            byID[id] = fact; records.append(.init(passageID: id, documentID: fact.documentID,
                termCounts: Dictionary(terms.map { ($0, 1) }, uniquingKeysWith: +), tokenCount: terms.count))
        }
        let index = BM25Index(records: records)
        var admitted: [GroundedConnectionV2] = [], rejected: [[String: String]] = [], seen = Set<String>()
        for a in originals.sorted(by: { ($0.documentTitle, $0.pageIndex, $0.quote.range.location) < ($1.documentTitle, $1.pageIndex, $1.quote.range.location) }) {
            let query = HybridLocalIndex.tokens(a.quote.text) + a.relations.flatMap { [$0.subject, $0.object] }
            for hit in index.search(terms: query, limit: 40) {
                guard let b = byID[hit.passageID], a.documentID != b.documentID else { continue }
                if let result = ConnectionAdmissionV2.admit(a, b), ConnectionAdmissionV2.validate(result, analyses: analyses) == nil {
                    let facet = result.relationA.subject + "|" + result.relationA.object + "|" + result.relationB.object
                    if seen.insert(facet).inserted { admitted.append(result) }
                } else if rejected.count < 20 {
                    rejected.append(["sourceA": "\(a.documentTitle) p.\(a.pageIndex + 1)", "sourceB": "\(b.documentTitle) p.\(b.pageIndex + 1)",
                        "quoteA": a.quote.text, "quoteB": b.quote.text, "reason": "no_shared_proved_relation_or_two_source_bridge"])
                }
            }
        }
        self.admitted = Array(admitted.prefix(limit)); self.rejected = rejected
    }
}
