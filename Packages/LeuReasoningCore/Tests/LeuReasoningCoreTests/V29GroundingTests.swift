import XCTest
@testable import LeuReasoningCore

final class V29GroundingTests: XCTestCase {
    func packet(_ body: String, title: String = "Cache") -> FactualPacket {
        let text = "001\nSYSTEMS\n\(title)\nI N O N E B R E A T H\n\(body)\nM A K E I T S T I C K\nIt causes magic.\nREAL EXAMPLE\nexample\nSAY THIS IN THE INTERVIEW\nIt guarantees wealth.\nWATCH / LEVEL-UP\nIt prevents every failure."
        return CanonicalSource.card(in: .init(number: 1, text: text), documentID: "real-layout")!
    }

    func testCardRolesAndExactUnicodeOffsets() {
        let card = packet("A stored representation of data. It reduces repeated work.", title: "Caché")
        let result = PacketAtomExtractor().extract(card)
        XCTAssertEqual(result.atoms.count, 2)
        XCTAssertEqual(result.atoms.last?.subject, "Caché")
        XCTAssertFalse(result.atoms.contains { $0.object.contains("magic") || $0.object.contains("wealth") || $0.object.contains("every failure") })
        XCTAssertEqual(result.atoms.last?.canonicalSpan, "It reduces repeated work.")
        XCTAssertEqual(result.atoms.last?.provenance.spans.count, 2)
        XCTAssertNotNil(result.atoms.last?.provenance.spans.first?.characterOffset)
    }

    func testNoCrossCardOrAmbiguousPronounResolution() {
        let extractor = PacketAtomExtractor()
        _ = extractor.extract(packet("A stored value. It prevents repeated work."))
        let orphan = extractor.extract(packet("It prevents unrelated failures.", title: "Other"))
        XCTAssertTrue(orphan.atoms.isEmpty)
        XCTAssertEqual(orphan.unresolved.count, 1)
        let ambiguous = extractor.extract(packet("Alice meets Bob. It prevents repeated work."))
        XCTAssertTrue(ambiguous.atoms.isEmpty)
    }

    func testReductionNeverBecomesCausationAndGuardsRemain() {
        let atoms = PacketAtomExtractor().extract(packet("A reusable value. It can reduce repeated work when inputs are unchanged.")).atoms
        let effect = atoms.last!
        XCTAssertEqual(effect.relation, "reduces")
        XCTAssertTrue(effect.qualifiers.contains(.init(kind: .modality, text: "can")))
        XCTAssertEqual(effect.conditions.first?.text, "inputs are unchanged")
        XCTAssertFalse(effect.isNegated)
    }

    func testCounterfactualDoesNotAffirmFailureOrPropagateLostSupport() {
        let span = SourceSpan(documentID: "d", page: 1, canonicalSpan: "A guard prevents a failure.", sourceRole: .explanation)
        let a = KnowledgeAtom(claimType: .mechanism, subject: "a guard", relation: "prevents", object: "a failure", provenance: .stated(span))
        let b = KnowledgeAtom(claimType: .cause, subject: "a failure", relation: "causes", object: "data loss", provenance: .stated(span))
        let result = CounterfactualEngine().evaluate(.removed("a guard"), in: KnowledgeGraphBuilder().build(atoms: [a,b]))
        XCTAssertEqual(result.consequences.count, 1)
        XCTAssertEqual(result.consequences.first?.polarity, .ruleNoLongerApplies)
        XCTAssertFalse(result.consequences.contains { $0.label == "data loss" })
        XCTAssertFalse(result.openQuestions.isEmpty)
    }

    func testRelationAdmissionChecksPredicateDirectionAndParents() {
        let atoms = PacketAtomExtractor().extract(packet("A stored value. It prevents repeated work.")).atoms
        let base = KnowledgeGraphBuilder().build(atoms: atoms)
        var wrong = base.relations.first!
        swap(&wrong.subject, &wrong.object)
        XCTAssertTrue(GraphValidator().validate(atoms: atoms, relations: [wrong]).admittedRelations.isEmpty)
        var invented = wrong
        invented.provenance = .inferred(from: [atoms[0].provenance], ids: [StableID(rawValue: "missing-parent")], rule: .causalComposition)
        XCTAssertTrue(GraphValidator().validate(atoms: atoms, relations: [invented]).admittedRelations.isEmpty)
        wrong = base.relations.first!
        wrong.qualifiers = [.init(kind: .frequency, text: "always")]
        XCTAssertTrue(GraphValidator().validate(atoms: atoms, relations: [wrong]).admittedRelations.isEmpty)
    }

    func testCompatibleNumericLimitsAreNotDisagreement() {
        func atom(_ max: Double, doc: String) -> KnowledgeAtom {
            KnowledgeAtom(claimType: .constraint, subject: "retry budget", relation: "qualifies", object: "at most \(Int(max)) attempts",
                          numbers: [.init(comparator: .atMost, value: max, unit: "attempts", rawText: String(Int(max)))],
                          provenance: .stated(.init(documentID: doc, page: 1, canonicalSpan: "at most \(Int(max)) attempts", sourceRole: .explanation)))
        }
        let a = atom(3, doc: "a"), b = atom(5, doc: "b")
        XCTAssertNil(MultiSourceSynthesizer().numericConflict(a,b))
        var c = b
        c.numbers[0].comparator = .atLeast
        c.object = "at least 5 attempts"
        XCTAssertNotNil(MultiSourceSynthesizer().numericConflict(a,c))
    }

    func testNoEquivalenceFromSameVocabularyOrMissingCondition() {
        let a = PacketAtomExtractor().extract(packet("A stored value. It can reduce work when inputs are unchanged.")).atoms.last!
        var b = a
        b.conditions = []
        XCTAssertFalse(MultiSourceSynthesizer().equivalent(a,b))
        b = a; b.isNegated = true
        XCTAssertFalse(MultiSourceSynthesizer().equivalent(a,b))
        b = a; b.relation = "increases"
        XCTAssertFalse(MultiSourceSynthesizer().equivalent(a,b))
    }

    func testUnresolvedSynthesisIsNotAnAdmittedStatement() {
        let result = MultiSourceSynthesizer().render(.init(concept: "unknown", commonThread: [], contributions: [], refinements: [], disagreements: [], examples: [], openQuestions: ["Source does not establish it."]))
        XCTAssertTrue(result.allLines.isEmpty)
        XCTAssertEqual(result.openQuestions.count, 1)
    }

    func testOpeningContentDoesNotCreateAnExplanationAttemptOrMastery() {
        let state = UnderstandingStateProjector().project(events: [.openedRelatedSource(documentID: "d", concept: "Cache", at: Date(timeIntervalSince1970: 1))])
        XCTAssertTrue(state.attemptedExplanations.isEmpty)
        XCTAssertTrue(state.resolvedByUser.isEmpty)
        XCTAssertEqual(state.relatedSourcesSeen, ["d"])
    }

    func testCoordinatedUnsupportedClauseCannotHideBehindSupportedFirstClause() {
        let atoms = PacketAtomExtractor().extract(packet("A stored representation. It prevents repeated work.")).atoms
        let graph = KnowledgeGraphBuilder().build(atoms: atoms)
        let result = SourceBoundExplanationAligner().align(explanation: "Cache prevents repeated work and creates encrypted backups.", concept: "Cache", in: graph)
        XCTAssertEqual(result.alignments.count, 2)
        XCTAssertEqual(result.verdict, .partiallySupported)
        XCTAssertEqual(result.alignments.first?.verdict, .supported)
        XCTAssertTrue(result.findings.contains { $0.type == .unsupportedAddition })
    }

    func testCanonicalAdmissionRejectsChangedObjectAndLocator() {
        let text = "001\nSYSTEMS\nCache\nIN ONE BREATH\nA stored value. It prevents repeated work.\nMAKE IT STICK\nmagic"
        let document = CanonicalDocument(id: "d", title: "d", sha256: "test-input", pages: [.init(number: 1, text: text)])
        let index = CertifiedReasoningIndex(documents: [document], sampledPages: [1])
        var proposal = index.atoms[0]
        XCTAssertTrue(index.admits(proposal))
        proposal.object = "unsupported invention"
        XCTAssertFalse(index.admits(proposal))
        proposal = index.atoms[0]
        proposal.provenance.spans[0].characterOffset! += 1
        XCTAssertFalse(index.admits(proposal))
        XCTAssertFalse(CanonicalSource.verifies(proposal.provenance.spans[0], documents: [document]))
    }

    func testNodeIdentityRetainsNegationAndScope() {
        XCTAssertNotEqual(KnowledgeNode.key(for: "retry failed requests"), KnowledgeNode.key(for: "retry every failed request"))
        XCTAssertNotEqual(KnowledgeNode.key(for: "state is preserved"), KnowledgeNode.key(for: "state is not preserved"))
        XCTAssertNotEqual(KnowledgeNode.key(for: "A requires B"), KnowledgeNode.key(for: "B requires A"))
    }
}
