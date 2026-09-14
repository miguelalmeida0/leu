import XCTest
@testable import ShelfCore

final class CodeSpeechNormalizerTests: XCTestCase {
    func testReactStateDestructuringUsesNaturalCodeMode() {
        let output = CodeSpeechNormalizer().normalize("const [count, setCount] = useState(0)")
        XCTAssertEqual(output, "Const. count and set count equals use state, initialized to zero.")
    }

    func testBooleanExpressionIsNotReadCharacterByCharacter() {
        let output = CodeSpeechNormalizer().normalize("isAuthenticated && user !== null")
        XCTAssertTrue(output.contains("and"))
        XCTAssertTrue(output.contains("strictly does not equal"))
        XCTAssertFalse(output.contains("ampersand"))
    }

    func testLiteralModeRemainsPossibleArchitecturally() {
        let output = CodeSpeechNormalizer().normalize("foo(bar)", mode: .literal)
        XCTAssertTrue(output.contains("open parenthesis"))
        XCTAssertTrue(output.contains("close parenthesis"))
    }
}
