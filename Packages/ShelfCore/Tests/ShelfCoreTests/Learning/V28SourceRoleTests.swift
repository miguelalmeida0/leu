import XCTest
@testable import ShelfCore

final class V28SourceRoleTests: XCTestCase {
    func testActualTrackedHeadingsHaveDistinctRoles() {
        let examples: [(String, IntelligenceSourceRole)] = [
            ("I N O N E B R E AT H", .factualExplanation), ("M A K E I T S T I C K", .mnemonic),
            ("R E A L E X A M P L E", .supportingExample), ("S AY T H I S I N T H E I N T E R V I E W", .interviewInstruction),
            ("WAT C H / L E V E L- U P", .advice)]
        for (heading, expected) in examples { XCTAssertEqual(SourceRoleMap.headingRole(heading), expected) }
    }
    func testHeadingsAndCrossRoleSpansCannotBecomeFacts() {
        let text = "IN ONE BREATH\nA cache preserves derived data.\nMAKE IT STICK\nA cache is a fridge."
        let map = SourceRoleMap(canonicalText: text), ns = text as NSString
        XCTAssertEqual(map.role(for: ns.range(of: "IN ONE BREATH")), .heading)
        XCTAssertEqual(map.role(for: ns.range(of: "A cache preserves derived data.")), .factualExplanation)
        XCTAssertEqual(map.role(for: ns.range(of: "A cache is a fridge.")), .mnemonic)
        XCTAssertNil(map.role(for: NSRange(location: 15, length: 55)))
    }
    func testCanonicalUnicodeOffsetsAreUnchanged() {
        let text = "🧠\nIN ONE BREATH\r\nPromise.all returns results in input order.\r\nREAL EXAMPLE\r\nPromise.all([a,b])"
        let ns = text as NSString, map = SourceRoleMap(canonicalText: text)
        let range = ns.range(of: "Promise.all returns results in input order.")
        XCTAssertEqual(map.role(for: range), .factualExplanation)
        XCTAssertEqual(ns.substring(with: range), "Promise.all returns results in input order.")
        XCTAssertEqual(map.role(for: ns.range(of: "Promise.all([a,b])")), .supportingExample)
    }
    func testOrdinarySourceProseRetainsExistingAdmission() {
        let text = "A transaction must not publish partial updates before commit."
        XCTAssertEqual(SourceRoleMap(canonicalText: text).role(for: NSRange(location: 0, length: text.utf16.count)), .unclassified)
        XCTAssertNil(SourceRoleMap.headingRole("The phrase MAKE IT STICK is an instruction."))
    }
    func testMnemonicAndInterviewStatementsAreExcludedEvenWhenGrammaticallyFactual() throws {
        let parts = ["IN ONE BREATH", "A stable key helps React match an item to its previous instance within a list of siblings.",
            "MAKE IT STICK", "A fridge preserves cold sandwiches throughout the delivery process.",
            "SAY THIS IN THE INTERVIEW", "A cache reduces repeated computation across subsequent requests.",
            "REAL EXAMPLE", "A sample helps clients compare the repeated execution results.",
            "WATCH / LEVEL-UP", "A retry budget limits repeated operations after the deadline."]
        let helper = V27IntelligenceTests(), analysis = helper.fixture(parts)
        let packet = try XCTUnwrap(LearningSourcePacket(analysis: analysis, page: analysis.pages[0]))
        let claims = GroundedQuestionCompiler().compile(packet).meaningfulClaims
        XCTAssertEqual(claims.map(\.evidence.text), [parts[1]])
    }
}
