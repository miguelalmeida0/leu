import XCTest
@testable import LeuReasoningCore

final class AtomExtractionTests: XCTestCase {
    let extractor = AtomExtractor()

    func atom(_ sentence: String, role: SourceRole = .explanation) -> KnowledgeAtom? {
        let span = SourceSpan(documentID: "t", page: 1, canonicalSpan: sentence, sourceRole: role)
        if case .success(let atoms) = extractor.extract(sentence: sentence, span: span) { return atoms.first }
        return nil
    }

    func testKeepsConditionOutOfTheClaim() throws {
        let atom = try XCTUnwrap(atom("If the failure is transient, retrying enables the operation to succeed."))
        XCTAssertEqual(atom.relation, RelationKind.enables.rawValue)
        XCTAssertEqual(atom.conditions.count, 1)
        XCTAssertEqual(atom.conditions.first?.text, "the failure is transient")
        XCTAssertFalse(atom.subject.lowercased().contains("if"))
    }

    func testPreservesNegation() throws {
        let atom = try XCTUnwrap(atom("A plain POST is not idempotent."))
        XCTAssertTrue(atom.isNegated)
    }

    func testPreservesNumbersWithComparator() throws {
        let atom = try XCTUnwrap(atom("A retry budget must be at most 3 attempts."))
        let number = try XCTUnwrap(atom.numbers.first)
        XCTAssertEqual(number.value, 3)
        XCTAssertEqual(number.comparator, .atMost)
    }

    func testPreservesIdentifiers() throws {
        let atom = try XCTUnwrap(atom("`useMemo` requires stable dependencies."))
        XCTAssertTrue(atom.identifiers.contains { $0.text == "useMemo" })
    }

    func testPreservesHttpStatusIdentifiers() throws {
        let atom = try XCTUnwrap(atom("503 means a temporarily unavailable dependency."))
        XCTAssertTrue(atom.identifiers.contains { $0.kind == .httpStatus && $0.text == "503" })
    }

    func testCapturesModalityQualifier() throws {
        let atom = try XCTUnwrap(atom("State may appear attached to another item.", role: .caution))
        XCTAssertTrue(atom.qualifiers.contains { $0.kind == .modality && $0.text == "may" })
    }

    func testSecondAtomForBecauseClause() {
        let sentence = "State is preserved because the key is stable."
        let span = SourceSpan(documentID: "t", page: 1, canonicalSpan: sentence, sourceRole: .explanation)
        guard case .success(let atoms) = extractor.extract(sentence: sentence, span: span) else {
            return XCTFail("expected extraction to succeed")
        }
        XCTAssertEqual(atoms.count, 2)
        XCTAssertTrue(atoms.contains { $0.claimType == .cause })
    }

    func testSkipsSentencesWithNoRelationCue() {
        let sentence = "Keys, identity, reconciliation"
        let span = SourceSpan(documentID: "t", page: 1, canonicalSpan: sentence, sourceRole: .explanation)
        guard case .failure(let reason) = extractor.extract(sentence: sentence, span: span) else {
            return XCTFail("expected a skip")
        }
        XCTAssertEqual(reason, .noRelationCue)
    }

    func testMnemonicBlocksProduceNoAtoms() {
        let block = SourceBlock(documentID: "t", page: 1, indexOnPage: 0, text: "Keys keep your identity.")
        let assignment = SourceRoleAssignment(block: block, role: .mnemonic, confidence: 1, evidence: [])
        let result = extractor.extract(from: [assignment])
        XCTAssertTrue(result.atoms.isEmpty)
        XCTAssertEqual(result.skipped.first?.reason, .roleDoesNotYieldClaims)
    }

    func testExtractionIsIdempotent() {
        let sentence = "An index enables row lookup without a full scan."
        let span = SourceSpan(documentID: "t", page: 1, canonicalSpan: sentence, sourceRole: .explanation)
        guard case .success(let first) = extractor.extract(sentence: sentence, span: span),
              case .success(let second) = extractor.extract(sentence: sentence, span: span) else {
            return XCTFail("expected extraction to succeed")
        }
        XCTAssertEqual(first.map(\.id), second.map(\.id))
    }

    func testParsingConfidenceIsNotSourceConfidence() throws {
        let atom = try XCTUnwrap(atom("An index enables row lookup without a full scan."))
        XCTAssertEqual(atom.provenance.admissibility, .sourceSupported)
        XCTAssertGreaterThan(atom.confidenceInParsing, 0.5)
    }

    func testSentenceSplitterDoesNotBreakOnDecimalsOrAbbreviations() {
        let text = "A max-age of 60.5 seconds is allowed, e.g. for static assets. Caching reuses data."
        XCTAssertEqual(TextScanning.sentences(in: text).count, 2)
    }
}
