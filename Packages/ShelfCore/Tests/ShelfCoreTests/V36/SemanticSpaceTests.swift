import XCTest
@testable import ShelfCore

/// The bundled semantic space is the one `scripts/build-semantic-space.py` built, reads words the
/// way the model's own tokenizer does, and gives the same exact similarities on every machine.
/// Reference values come from the build (Python: tokenizers, numpy integer arithmetic).
final class SemanticSpaceTests: XCTestCase {
    private func space() throws -> SemanticSpace { try XCTUnwrap(SemanticSpace.shared, "the bundled semantic space loads") }

    func testTheBundledSpaceIsTheOneThatWasBuilt() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: SemanticSpace.resource, withExtension: "leusem", subdirectory: "SemanticSpace"))
        XCTAssertEqual(try FileDigest.sha256(url: url), SemanticSpace.digest)
        XCTAssertEqual(try space().dimensions, 256)
    }

    func testWordsSplitIntoTheSamePiecesAsTheModelsTokenizer() throws {
        let space = try space()
        XCTAssertEqual(space.pieces("retain"), [9279])
        XCTAssertEqual(space.pieces("javascript"), [9262, 22483])
        XCTAssertEqual(space.pieces("useCallback"), [2224, 9289, 20850, 8684], "lowercased, then longest pieces first")
        XCTAssertEqual(space.pieces("idempotency"), [8909, 6633, 11008, 11916])
        XCTAssertEqual(space.pieces("décor"), [25545], "accents are removed as the uncased model does")
        XCTAssertEqual(space.pieces("naïve"), [15743])
        XCTAssertNil(space.pieces(""))
    }

    func testSimilaritiesAreExactIntegerArithmeticAndMatchTheBuild() throws {
        let space = try space()
        let reference: [(String, String, Double)] = [
            ("retain", "keep", 0.3698355192560534), ("variables", "values", 0.505028976725352),
            ("fast", "slow", 0.666481602722903), ("increase", "decrease", 0.5332570718113915),
            ("closure", "function", 0.20395126397185842), ("authentication", "identity", 0.4092565219061113)
        ]
        for (a, b, expected) in reference {
            let value = try XCTUnwrap(space.similarity(a, b))
            XCTAssertEqual(value, expected, accuracy: 1e-12, "\(a) / \(b)")
            XCTAssertEqual(value, try XCTUnwrap(space.similarity(b, a)), accuracy: 0, "symmetric")
        }
        // A word joined from parts ("one_way", "set-state") is the sum of its parts.
        XCTAssertNotNil(space.vector("one_way"))
    }

    func testOppositesAreNeverParaphrases() {
        // In the space itself "fast" is closer to "slow" than "retain" is to "keep": the reason the
        // antonym guard exists.
        XCTAssertTrue(SemanticAntonyms.opposed(Lexicon.stem("fast"), Lexicon.stem("slow")))
        XCTAssertTrue(SemanticAntonyms.opposed(Lexicon.stem("increase"), Lexicon.stem("decrease")))
        XCTAssertTrue(SemanticAntonyms.opposed(Lexicon.stem("temporary"), Lexicon.stem("permanent")))
        XCTAssertFalse(SemanticAntonyms.opposed(Lexicon.stem("retain"), Lexicon.stem("keep")))
        let learner = LexicalProfile("the writes get faster").terms
        let claim = LexicalProfile("writes get slower").terms
        let evidence = SemanticMatcher.evidence(claim: claim, learner: learner, lexical: { LexicalProfile("the writes get faster").match($0) },
                                                space: SemanticSpace.shared!)
        XCTAssertEqual(evidence.opposites.map(\.learner), ["faster"])
        XCTAssertFalse(evidence.substitutions.contains { $0.learner == "faster" }, "an opposite earns no credit")
    }
}
