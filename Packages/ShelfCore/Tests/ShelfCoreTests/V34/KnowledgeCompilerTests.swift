import XCTest
@testable import ShelfCore

final class KnowledgeCompilerTests: XCTestCase {
    private var kb: ConceptKnowledgeBase { LearningCorpus.mastery }

    func testAnActionPhraseCanBeASubjectButARunOnHeadingCannot() {
        XCTAssertTrue(ClaimAdmission.admitsSubject("Passing a database object through every screen"))
        XCTAssertFalse(ClaimAdmission.admitsSubject("View Use case Storage Passing a database object through every screen"))
        let design = LearningCorpus.knowledge["System Design"]!
        XCTAssertTrue(design.claims.contains { $0.statement.hasPrefix("Passing a database object through every screen makes boundaries difficult to change") })
    }

    func testNounsAreNotMistakenForVerbs() {
        XCTAssertTrue(ClauseParser.isDefinitionalFragment("A managed set of reusable database connections shared by application requests."))
        XCTAssertTrue(ClauseParser.isDefinitionalFragment("Automatically integrating changes through repeatable checks such as build, lint, typecheck, and tests."))
        XCTAssertEqual(ClauseParser.parse("A cache can reduce latency for repeated requests.")?.verbLemma, "reduce")
    }

    func testARelativeClauseWithoutThatIsNotTheMainClause() {
        XCTAssertTrue(ClauseParser.isDefinitionalFragment("A message a client sends asking a server to perform an operation."))
        XCTAssertTrue(ClauseParser.isDefinitionalFragment("The stack data structure the runtime uses to track active function calls."))
        XCTAssertEqual(ClauseParser.parse("Each request the server receives is logged.")?.subject, "Each request the server receives")
        XCTAssertEqual(ClauseParser.parse("Developers structure the code into modules.")?.verbLemma, "structure")
        XCTAssertEqual(ClauseParser.parse("Arrow functions with a block body return their value automatically.")?.verbLemma, "return",
                       "the noun before the verb is inside a prepositional phrase, not the subject")
        XCTAssertEqual(kb.definition(of: ConceptKey("Request"))?.statement,
                       "Request is a message a client sends asking a server to perform an operation or return data.")
        XCTAssertEqual(kb.definition(of: ConceptKey("Call stack"))?.statement,
                       "Call stack is the stack data structure the runtime uses to track active function calls.")
    }

    func testAPronounIsResolvedOnlyToTheHeadingItSitsUnder() {
        for (title, knowledge) in LearningCorpus.knowledge {
            for claim in knowledge.claims {
                guard case .resolvedSubject(let antecedent, .leadingPronoun) = claim.grounding else { continue }
                XCTAssertTrue(knowledge.concepts.contains { $0.origin == .heading && $0.key == claim.concept && $0.heading == antecedent },
                              "\(title): \(claim.statement)")
            }
        }
        XCTAssertFalse(kb.claims.contains { $0.statement.hasPrefix("A callback explains") }, "on the Stale closure card, “It” is not the callback")
        let text = "Token checks\n\nA client sends a token to the API. It validates the signature before any handler runs."
        var input = SourcePageInput(pageIndex: 0, text: text); input.spatialIntegrityPassed = true
        var analysis = DocumentAnalyzer().analyze(documentID: UUID(), fingerprint: "pronoun", pages: [input])
        analysis.extractionVersion = SourceExtractionVersion.current
        analysis.pages[0].canonicalText = text
        let claims = ConceptKnowledgeCompiler().compile(analysis).claims
        XCTAssertTrue(claims.contains { $0.statement.hasPrefix("A client sends a token") })
        XCTAssertFalse(claims.contains { $0.statement.contains("validates the signature") },
                       "“It” may be the client, the token or the API; Leu does not guess")
    }

    func testAnAcronymExpansionIsAnAliasAndItsFragmentTheDefinition() throws {
        let card = try XCTUnwrap(kb.concept(ConceptKey("CI")))
        XCTAssertTrue(card.aliases.contains("Continuous Integration"))
        let definition = try XCTUnwrap(kb.definition(of: ConceptKey("CI")))
        XCTAssertTrue(definition.statement.hasPrefix("CI: automatically integrating changes"), definition.statement)
        XCTAssertTrue(definition.grounding.isInferred, "the resolution from the heading is recorded, not hidden")
    }

    func testCodeExamplesAreKeptAsExamples() throws {
        let card = try XCTUnwrap(kb.concept(ConceptKey("Derived state")))
        XCTAssertTrue(card.examples.contains { $0.text.contains("const fullName") })
    }

    func testTheGraphIsDeterministicAndNamesAreMatchedWhole() {
        let analysis = LearningCorpus.analysis("Mobile Mastery")
        XCTAssertEqual(ConceptKnowledgeCompiler().compile(analysis).edges, kb.edges, "no hash-order dependence")
        let index = ConceptMentionIndex(kb.cards)
        let mentioned = index.mentions(in: ConceptNameMatcher.stems("An HttpOnly cookie keeps the token away from scripts over HTTPS."))
        XCTAssertTrue(mentioned.contains(ConceptKey("HttpOnly cookie")))
        XCTAssertFalse(mentioned.contains(ConceptKey("Cookie")), "a name inside a longer name is not a second mention")
        XCTAssertFalse(mentioned.contains(ConceptKey("HTTP")), "HTTPS is not HTTP plus a plural")
        XCTAssertEqual(ConceptNameMatcher.stems("HTTPS"), ["https"])
    }

    func testContrastsNeedTheSourceToSetTheConceptsSideBySide() {
        XCTAssertTrue(kb.contrasts(of: ConceptKey("Authentication")).contains(ConceptKey("Authorization")))
        XCTAssertTrue(kb.contrasts(of: ConceptKey("Encryption")).contains(ConceptKey("Hashing")))
        XCTAssertFalse(kb.contrasts(of: ConceptKey("Cache invalidation")).contains(ConceptKey("Response")),
                       "two consecutive sentences about related things are not a contrast")
        XCTAssertLessThanOrEqual(kb.edges.filter { $0.relation == .contrastsWith }.count, 20)
    }

    func testCompilingIsFastEnoughForTheDevice() {
        let analysis = LearningCorpus.analysis("Mobile Mastery")
        let start = Date()
        _ = ConceptKnowledgeCompiler().compile(analysis)
        XCTAssertLessThan(Date().timeIntervalSince(start), 8, "345 pages; debug build on Linux (was 4.3 s before edge indexing, now ~2.5 s)")
    }
}
