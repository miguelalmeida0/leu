import XCTest
@testable import ShelfCore

final class TechnicalTokenizerTests: XCTestCase {
    func testTechnicalTokensSurviveNormalization() {
        let tokens = Set(TechnicalTokenizer().tokens(in: "useEffect() React.memo Promise.all() HTTP/2 Next.js C++ C# .NET CSS-in-JS z-index O(log n)"))
        XCTAssertTrue(tokens.contains("useeffect"))
        XCTAssertTrue(tokens.contains("react.memo"))
        XCTAssertTrue(tokens.contains("promise.all"))
        XCTAssertTrue(tokens.contains("http/2"))
        XCTAssertTrue(tokens.contains("next.js"))
        XCTAssertTrue(tokens.contains("c++"))
        XCTAssertTrue(tokens.contains("c#"))
        XCTAssertTrue(tokens.contains(".net"))
        XCTAssertTrue(tokens.contains("css-in-js"))
        XCTAssertTrue(tokens.contains("z-index"))
        XCTAssertTrue(tokens.contains("o(logn)"))
    }

    func testSafeWordFormsRelate() {
        let tokenizer = TechnicalTokenizer()
        XCTAssertEqual(tokenizer.normalize("rendering"), "render")
        XCTAssertEqual(tokenizer.normalize("rendered"), "render")
        XCTAssertEqual(tokenizer.normalize("renders"), "render")
    }
}
