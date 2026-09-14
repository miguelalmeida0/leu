import Foundation

public struct SemanticCompiler: Sendable {
    public static let semanticVersion = 4
    public static let ontologyVersion = 1

    public init() {}

    public func compile(_ analysis: DocumentAnalysis) -> SemanticIndex {
        var concepts: [String: SemanticConcept] = [:]
        var propositions: [SemanticProposition] = []
        var rejectionCounts: [String: Int] = [:]

        for page in analysis.pages where page.isIntelligenceEligible {
            for segment in page.segments {
                guard !InstructionalText.excludesFromStudy(segment) else { continue }
                let text = normalizedWhitespace(segment.text)
                guard text.count >= 5 else { continue }
                let evidence = SemanticEvidenceSpan(documentID: analysis.documentID, pageIndex: page.pageIndex,
                                                    sectionTitle: segment.sectionTitle, sourceText: segment.text)
                let anchored = knownConcepts(in: text)
                for concept in anchored { concepts[concept.id] = concept }

                // General grammar supplies teaching claims. The curated pack only
                // enriches identity/associations; it cannot manufacture quiz truth.
                let claims = segment.kind == .code ? [] : GeneralClaimExtractor().extract(text, evidence: evidence)
                let extracted = claims.map { claim -> SemanticProposition in
                    let concept = conceptForTerm(claim.subject)
                    concepts[concept.id] = concept
                    return SemanticProposition(subjectID: concept.id, relation: claim.relation,
                        objectText: claim.object, truthClass: .verifiedSource, confidenceClass: .verified,
                        evidence: claim.evidence, extractionRuleID: "general.\(claim.intent.rawValue).v4", claim: claim)
                }
                if extracted.isEmpty && !anchored.isEmpty { rejectionCounts["unsupported_inference", default: 0] += 1 }
                for proposition in extracted where propositions.allSatisfy({ $0.id != proposition.id }) {
                    propositions.append(proposition)
                }

                if segment.kind == .code {
                    let code = CodeSemanticParser().facts(in: segment.text, evidence: evidence)
                    for concept in code.concepts { concepts[concept.id] = concept }
                    for proposition in code.propositions where propositions.allSatisfy({ $0.id != proposition.id }) {
                        propositions.append(proposition)
                    }
                }
            }
        }

        let associations = cooccurrenceAssociations(analysis: analysis, concepts: Array(concepts.values))
        return SemanticIndex(documentID: analysis.documentID, documentFingerprint: analysis.fingerprint,
                             semanticVersion: Self.semanticVersion, ontologyVersion: Self.ontologyVersion,
                             concepts: concepts.values.sorted { $0.id < $1.id },
                             propositions: propositions.sorted { $0.id < $1.id },
                             associations: associations, rejectionCounts: rejectionCounts)
    }

    private func knownConcepts(in text: String) -> [SemanticConcept] {
        let lower = text.lowercased()
        return domainPack.filter { concept in
            ([concept.canonicalName] + concept.aliases).contains { token in
                let t = token.lowercased()
                return lower.range(of: #"(?<![A-Za-z0-9_])"# + NSRegularExpression.escapedPattern(for: t) + #"(?![A-Za-z0-9_])"#,
                                   options: .regularExpression) != nil
            }
        }
    }

    private func conceptForTerm(_ term: String) -> SemanticConcept {
        let normalized = normalize(term)
        if let curated = domainPack.first(where: { normalize($0.canonicalName) == normalized || $0.aliases.contains(where: { normalize($0) == normalized }) }) {
            return curated
        }
        return SemanticConcept(id: "doc." + String(StableIdentity.hash64(normalized), radix: 16),
                               canonicalName: term, domain: "document", isCurated: false)
    }

    private func cooccurrenceAssociations(analysis: DocumentAnalysis, concepts: [SemanticConcept]) -> [SemanticAssociation] {
        var pairCounts: [String: (ids: [String], count: Int)] = [:]
        for page in analysis.pages where page.isIntelligenceEligible {
            let lower = page.normalizedText.lowercased()
            let present = concepts.filter { lower.contains($0.canonicalName.lowercased()) }.map(\.id).sorted()
            guard present.count >= 2 else { continue }
            for i in 0..<(present.count - 1) {
                for j in (i + 1)..<present.count {
                    let ids = [present[i], present[j]]
                    let key = ids.joined(separator: "|")
                    pairCounts[key] = (ids, (pairCounts[key]?.count ?? 0) + 1)
                }
            }
        }
        return pairCounts.values.filter { $0.count >= 2 }.map {
            SemanticAssociation(conceptIDs: $0.ids, score: min(0.9, 0.45 + Double($0.count) * 0.08),
                                reason: "Repeated source proximity; candidate association only")
        }.sorted { $0.id < $1.id }
    }

    private func normalizedWhitespace(_ text: String) -> String {
        text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalize(_ text: String) -> String {
        normalizedWhitespace(text).lowercased()
    }
}

private let domainPack: [SemanticConcept] = [
    .init(id: "js.promise.all", canonicalName: "Promise.all", aliases: ["promise all"], domain: "javascript", isCurated: true),
    .init(id: "js.async.await", canonicalName: "await", domain: "javascript", isCurated: true),
    .init(id: "js.strict.equality", canonicalName: "strict equality", aliases: ["===", "strictly equals"], domain: "javascript", isCurated: true),
    .init(id: "react.useEffect", canonicalName: "useEffect", aliases: ["effect hook"], domain: "react", isCurated: true),
    .init(id: "react.useMemo", canonicalName: "useMemo", domain: "react", isCurated: true),
    .init(id: "react.useCallback", canonicalName: "useCallback", domain: "react", isCurated: true),
    .init(id: "react.reconciliation", canonicalName: "reconciliation", domain: "react", isCurated: true),
    .init(id: "react.component", canonicalName: "component", domain: "react", isCurated: true),
    .init(id: "react.rendering", canonicalName: "rendering", aliases: ["render"], domain: "react", isCurated: true),
    .init(id: "react.commit", canonicalName: "committing", aliases: ["commit"], domain: "react", isCurated: true),
    .init(id: "react.key", canonicalName: "stable key", aliases: ["key"], domain: "react", isCurated: true),
    .init(id: "react.functionalUpdater", canonicalName: "functional updater", aliases: ["updater"], domain: "react", isCurated: true),

    .init(id: "web.event.delegation", canonicalName: "event delegation", domain: "browser", isCurated: true),
    .init(id: "web.event.bubbling", canonicalName: "event bubbling", aliases: ["bubbling"], domain: "browser", isCurated: true),
    .init(id: "http.cors", canonicalName: "CORS", domain: "http", isCurated: true),
    .init(id: "http.preflight", canonicalName: "preflight request", aliases: ["preflight"], domain: "http", isCurated: true),
    .init(id: "css.specificity", canonicalName: "specificity", domain: "css", isCurated: true),
    .init(id: "a11y.accessible.name", canonicalName: "accessible name", domain: "accessibility", isCurated: true),
]

public struct CodeSemanticParser: Sendable {
    public init() {}

    public func facts(in code: String, evidence: SemanticEvidenceSpan) -> (concepts: [SemanticConcept], propositions: [SemanticProposition]) {
        let compact = code.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        var concepts: [SemanticConcept] = []
        var facts: [SemanticProposition] = []

        func add(_ concept: SemanticConcept, _ relation: SemanticRelation, _ object: String, rule: String) {
            concepts.append(concept)
            facts.append(SemanticProposition(subjectID: concept.id, relation: relation, objectText: object,
                                             truthClass: .structural, confidenceClass: .verified,
                                             evidence: evidence, extractionRuleID: rule))
        }

        if compact.contains("Promise.all(") {
            add(SemanticConcept(id: "js.promise.all", canonicalName: "Promise.all", domain: "javascript", isCurated: true),
                .awaits, "multiple input promises as one aggregate", rule: "code.promiseAll.call.v1")
        }
        if compact.contains(".map(") {
            add(SemanticConcept(id: "js.array.map", canonicalName: "Array.map", domain: "javascript", isCurated: true),
                .returns, "one transformed output per input element", rule: "code.arrayMap.call.v1")
        }
        if compact.contains(".filter(") {
            add(SemanticConcept(id: "js.array.filter", canonicalName: "Array.filter", domain: "javascript", isCurated: true),
                .returns, "a subset selected by a predicate", rule: "code.arrayFilter.call.v1")
        }
        if compact.contains("useEffect(") && compact.contains("return") && compact.contains("removeEventListener") {
            add(SemanticConcept(id: "react.useEffect", canonicalName: "useEffect", domain: "react", isCurated: true),
                .cleansUp, "the registered side effect", rule: "code.useEffect.cleanup.v1")
        }
        if compact.contains("addEventListener") {
            add(SemanticConcept(id: "web.event.listener", canonicalName: "event listener", domain: "browser", isCurated: true),
                .subscribesTo, "a named DOM event", rule: "code.addEventListener.subscription.v1")
        }
        return (Array(Dictionary(grouping: concepts, by: \.id).compactMap { $0.value.first }).sorted { $0.id < $1.id }, facts)
    }
}
