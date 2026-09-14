import XCTest
@testable import ShelfCore

final class TechnicalSpeechNormalizerTests: XCTestCase {
    private let normalizer = TechnicalSpeechNormalizer()

    func testHeroTechnicalSentenceBecomesSpeechSafe() {
        let input = "React uses reconciliation. useEffect runs after rendering. === performs strict equality. HTTP requests are asynchronous."
        let output = normalizer.normalize(input)
        XCTAssertTrue(output.contains("use effect runs after rendering"))
        XCTAssertTrue(output.contains("strict equality operator performs strict equality"))
        XCTAssertTrue(output.contains("H T T P requests are asynchronous"))
    }

    func testOperatorsAndComplexityAreNatural() {
        let output = normalizer.normalize("a !== b, x >= 4, y <= 9. Binary search is O(log n), linear search is O(n), nested work is O(n²).")
        XCTAssertTrue(output.contains("strictly does not equal"))
        XCTAssertTrue(output.contains("greater than or equal to"))
        XCTAssertTrue(output.contains("less than or equal to"))
        XCTAssertTrue(output.contains("O of log n"))
        XCTAssertTrue(output.contains("O of n"))
        XCTAssertTrue(output.contains("O of n squared"))
    }

    func testFrameworkAndAPIPronunciations() {
        let output = normalizer.normalize("TypeScript, JavaScript, Node.js, Next.js, React.memo, Promise.all(), DOM, JSON, SQL, OAuth, JWT and CLI.")
        XCTAssertTrue(output.contains("Type Script"))
        XCTAssertTrue(output.contains("Java Script"))
        XCTAssertTrue(output.contains("Node J S"))
        XCTAssertTrue(output.contains("React dot memo"))
        XCTAssertTrue(output.contains("promise dot all"))
        XCTAssertTrue(output.contains("dom"))
        XCTAssertTrue(output.contains("Jason"))
        XCTAssertTrue(output.contains("S Q L"))
        XCTAssertTrue(output.contains("oh auth"))
        XCTAssertTrue(output.contains("J W T"))
    }

    func testFalsePositiveDoesNotRewriteSubstrings() {
        let output = normalizer.normalize("effectiveness and domain are ordinary words")
        XCTAssertTrue(output.contains("effectiveness"))
        XCTAssertTrue(output.contains("domain"))
        XCTAssertFalse(output.contains("use effect iveness"))
    }

    func testURLIsReadable() {
        let output = normalizer.normalize("Open https://api.example.com/users/:id")
        XCTAssertTrue(output.contains("H T T P S"))
        XCTAssertTrue(output.contains("A P I dot example dot com"))
        XCTAssertTrue(output.contains("slash users"))
    }

    func testTypeScriptGenericPromiseIsReadAsTypeMeaning() {
        let output = normalizer.normalize("Promise<User[]> represents a promise containing an array of User objects.")
        XCTAssertTrue(output.contains("Promise of an array of User objects"))
        XCTAssertFalse(output.contains("less than"))
    }

    func testHTTPVersionsAndStatusCodesStayProtocolAware() {
        let output = normalizer.normalize("HTTP/2 can return HTTP 404 or HTTP 503.")
        XCTAssertTrue(output.contains("H T T P 2"))
        XCTAssertTrue(output.contains("H T T P four oh four"))
        XCTAssertTrue(output.contains("H T T P five oh three"))
    }
}
