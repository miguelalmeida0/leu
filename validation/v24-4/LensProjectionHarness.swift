import Foundation
import ShelfCore

private enum HarnessFailure: Error { case failed(String) }

@main
@MainActor
struct LensProjectionHarness {
    static func main() throws {
        var checks = 0
        func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
            guard condition() else { throw HarnessFailure.failed(message) }
            checks += 1
        }
        let a = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let b = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let concept = SemanticConcept(id: "react.useMemo", canonicalName: "useMemo", isCurated: true)
        let origin = LearningSource(documentID: a, pageIndex: 0, sourceText: "How does USEMEMO work?", sectionTitle: "Question")
        func proposition(_ document: UUID, _ page: Int, _ value: String,
                         truth: SemanticTruthClass = .verifiedSource,
                         confidence: SemanticConfidenceClass = .verified,
                         subject: String = "react.useMemo") -> SemanticProposition {
            SemanticProposition(subjectID: subject, relation: .memoizes, objectText: value,
                truthClass: truth, confidenceClass: confidence,
                evidence: SemanticEvidenceSpan(documentID: document, pageIndex: page,
                    sectionTitle: "Memoization", sourceText: "useMemo memoizes \(value)."),
                extractionRuleID: "memoizes-test")
        }
        let p = proposition(a, 4, "a calculated value")
        let row = UnderstandingLensFact(concept: concept, proposition: p)
        try expect(row.id == p.id, "The proposition ID is preserved.")
        try expect(row.conceptName == "useMemo", "The concept name is not reinterpreted.")
        try expect(row.relationshipText == "memoizes a calculated value", "Relationship wording is unchanged.")
        try expect(row.sourceCaption == "p. 5 · verifiedSource", "The visible citation is unchanged.")
        try expect(row.accessibilityIdentifier == "understanding-lens-fact-\(p.id)", "The native test ID is unchanged.")
        try expect(row.accessibilityLabel == "useMemo: memoizes a calculated value", "The accessibility label is unchanged.")
        try expect(row.accessibilityValue == "Page 5", "The accessibility page value is precomputed as String.")
        try expect(row.target == p.evidence.learningSource, "Navigation receives the exact existing source projection.")
        let firstPage = UnderstandingLensFact(concept: concept, proposition: proposition(a, 0, "a value"))
        try expect(firstPage.accessibilityValue == "Page 1", "Zero-based source page displays as page one.")
        let largePage = UnderstandingLensFact(concept: concept, proposition: proposition(a, 999, "a value"))
        try expect(largePage.accessibilityValue == "Page 1000", "Larger page numbers remain exact.")
        let unicode = UnderstandingLensFact(concept: concept, proposition: proposition(a, 7, "‘résumé’ **value**\nnext line"))
        try expect(unicode.relationshipText == "memoizes ‘résumé’ **value**\nnext line", "Source strings retain Unicode and literal markup.")

        func index(_ document: UUID, _ items: [SemanticProposition], concepts: [SemanticConcept]? = nil) -> SemanticIndex {
            SemanticIndex(documentID: document, documentFingerprint: "fixture",
                          concepts: concepts ?? [concept], propositions: items)
        }
        let mixed = index(a, [p, proposition(a, 1, "association", truth: .associationCandidate),
            proposition(a, 2, "strong", confidence: .strong), proposition(a, 3, "weak", confidence: .associationOnly),
            proposition(a, 6, "unknown", subject: "unknown")])
        let filtered = UnderstandingLensFact.matching(source: origin, semanticIndexes: [a: mixed])
        try expect(filtered == [row], "Unverified, association and unresolved-subject facts are excluded.")
        try expect(UnderstandingLensFact.matching(source: origin, semanticIndexes: [:]).isEmpty, "No index means no filler.")
        let unrelated = LearningSource(documentID: a, pageIndex: 0, sourceText: "An unrelated paragraph")
        try expect(UnderstandingLensFact.matching(source: unrelated, semanticIndexes: [a: mixed]).isEmpty, "Unrelated passages remain empty.")
        let associationOnly = SemanticIndex(documentID: a, documentFingerprint: "fixture", concepts: [concept],
            associations: [SemanticAssociation(conceptIDs: [concept.id], score: 1, reason: "co-occurrence")])
        try expect(UnderstandingLensFact.matching(source: origin, semanticIndexes: [a: associationOnly]).isEmpty,
                   "Association metadata cannot create a Lens fact.")
        let cross = proposition(b, 1, "another source")
        let crossRows = UnderstandingLensFact.matching(source: origin, semanticIndexes: [b: index(b, [cross]), a: index(a, [p])])
        try expect(crossRows.count == 2 && crossRows[1].target.documentID == b, "Cross-source targets are retained.")
        try expect(crossRows.map(\.id) == [p.id, cross.id], "Documents sort before pages.")
        let samePage = [proposition(a, 3, "z"), proposition(a, 3, "a")]
        let sorted = UnderstandingLensFact.matching(source: origin, semanticIndexes: [a: index(a, samePage)])
        try expect(sorted.map(\.id) == samePage.map(\.id).sorted(), "Proposition ID breaks page ties deterministically.")

        let many = (0..<60).map { proposition($0.isMultiple(of: 2) ? a : b, $0 % 7, "value \($0)") }
        let indexes: [UUID: SemanticIndex] = [a: index(a, Array(many.filter { $0.evidence.documentID == a }.reversed())),
                                             b: index(b, Array(many.filter { $0.evidence.documentID == b }.reversed()))]
        let projected = UnderstandingLensFact.matching(source: origin, semanticIndexes: indexes)
        try expect(projected.count == 24, "The existing 24-row cap remains.")
        let legacy = legacyFacts(source: origin, semanticIndexes: indexes)
        let reference = legacy.map { UnderstandingLensFact(concept: $0.concept, proposition: $0.proposition) }
        try expect(projected == reference, "Projection matches the original V24.3 filter/order/cap algorithm.")
        let reversedIndexes: [UUID: SemanticIndex] = [b: indexes[b]!, a: indexes[a]!]
        try expect(projected == UnderstandingLensFact.matching(source: origin, semanticIndexes: reversedIndexes),
                   "Dictionary insertion order does not change the result.")
        for count in 0...60 {
            let items = Array(many.prefix(count))
            let data: [UUID: SemanticIndex] = [a: index(a, items)]
            let old = legacyFacts(source: origin, semanticIndexes: data)
                .map { UnderstandingLensFact(concept: $0.concept, proposition: $0.proposition) }
            guard UnderstandingLensFact.matching(source: origin, semanticIndexes: data) == old else {
                throw HarnessFailure.failed("Legacy equivalence failed for count \(count)")
            }
        }
        checks += 1

        let navigation = LensRouteDependencies()
        let route = LensRouteProbe(reader: navigation.reader, source: origin, dismiss: navigation.dismiss)
        route.showSource(row.target)
        try expect(navigation.trace.events == ["queue", "dismiss"], "A successful route queues before dismissing Lens.")
        try expect(navigation.reader.knowledge.target == row.target && navigation.reader.knowledge.origin == origin,
                   "The source action preserves its target and original Lens context.")
        navigation.trace.events = []
        navigation.reader.knowledge.accepts = false
        route.showSource(crossRows[1].target)
        try expect(navigation.trace.events == ["queue"], "Rejected navigation keeps Lens open.")
        var selected: LearningSource?
        let rowAction = LensRowActionProbe(fact: row) { selected = $0 }
        rowAction.selectSource()
        try expect(selected == row.target, "The actual row action forwards its own source, not a captured neighboring row.")
        print("PASS: \(checks) Lens projection/navigation checks; real source types and extracted actions, not Apple UI certification")
    }
}
