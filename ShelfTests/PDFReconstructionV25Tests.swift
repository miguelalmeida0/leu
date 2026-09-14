import XCTest
import PDFKit
import UIKit
import ShelfCore
@testable import Shelf

@MainActor
final class PDFReconstructionV25Tests: XCTestCase {
    func testReactCanonicalGeometryAndBlocksPreserveEveryCharacter() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "React Notes", withExtension: "pdf"))
        let bytes = try Data(contentsOf: url)
        let pdf = try XCTUnwrap(PDFDocument(url: url))
        let headings = ["React Notes", "State is a snapshot", "Keys describe identity"]
        for index in 0..<3 {
            let page = try XCTUnwrap(pdf.page(at: index))
            let canonical = try XCTUnwrap(page.string)
            let glyphs = PDFSpatialTextExtractor().glyphs(from: page)
                .sorted { $0.sourceIndex < $1.sourceIndex }.map(\.text).joined()
            let result = PDFReadablePageExtractor().extract(document: pdf, pageIndex: index)
            let reconstructed = result.blocks.map(\.text).joined(separator: "\n")
            XCTAssertTrue(result.sourceIntegrityPassed)
            XCTAssertEqual(canonical.filter { !$0.isWhitespace }, glyphs.filter { !$0.isWhitespace })
            XCTAssertEqual(canonical.filter { !$0.isWhitespace }, reconstructed.filter { !$0.isWhitespace })
            XCTAssertTrue(result.blocks.contains { $0.kind == .heading && $0.text == headings[index] })
            if index == 1 {
                XCTAssertTrue(result.blocks.contains { $0.kind == .code && $0.text.contains("setCount(count + 1);\nconsole.log(count);") })
            }
            if index == 2 {
                XCTAssertTrue(result.blocks.contains { $0.kind == .code && $0.text.contains("  <Row key={item.id} item={item} />") })
            }
        }
        XCTAssertEqual(try Data(contentsOf: url), bytes)
    }

    private func document(_ draw: () -> Void) throws -> PDFDocument {
        let data = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 600, height: 800)).pdfData { context in
            context.beginPage(); draw()
        }
        return try XCTUnwrap(PDFDocument(data: data))
    }
    private func draw(_ text: String, x: CGFloat, y: CGFloat, size: CGFloat = 12, mono: Bool = false) {
        let font = mono ? UIFont.monospacedSystemFont(ofSize: size, weight: .regular) : UIFont.systemFont(ofSize: size)
        (text as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: [.font: font])
    }

    func testFragmentedRunsBecomeOneHeadingFromRealPDFGeometry() throws {
        let pdf = try document {
            let font = UIFont.systemFont(ofSize: 26)
            var x: CGFloat = 40
            for fragment in ["18 — HTT", "P Hea", "ders"] {
                draw(fragment, x: x, y: 40, size: 26)
                x += (fragment as NSString).size(withAttributes: [.font: font]).width
            }
            draw("A body paragraph establishes the ordinary text size.", x: 40, y: 110)
            draw("The next line continues the same paragraph.", x: 40, y: 125)
        }
        let result = PDFReadablePageExtractor().extract(document: pdf, pageIndex: 0, diagnostics: true)
        XCTAssertTrue(result.blocks.contains { $0.kind == .heading && $0.text.contains("HTTP Headers") })
        XCTAssertFalse(result.blocks.contains { $0.text == "P Hea" })
    }

    func testTwoColumnsRemainInReadingOrder() throws {
        let pdf = try document {
            draw("Left first sentence.", x: 40, y: 100)
            draw("Right first sentence.", x: 330, y: 100)
            draw("Left second sentence.", x: 40, y: 116)
            draw("Right second sentence.", x: 330, y: 116)
        }
        let text = PDFReadablePageExtractor().extract(document: pdf, pageIndex: 0).blocks.map(\.text).joined(separator: "\n")
        let left = try XCTUnwrap(text.range(of: "Left second"))
        let right = try XCTUnwrap(text.range(of: "Right first"))
        XCTAssertLessThan(left.lowerBound, right.lowerBound)
    }

    func testNumberedListsCodeAndRealHyphensSurvive() throws {
        let pdf = try document {
            draw("1. Open the socket", x: 40, y: 100)
            draw("2. Send the frame", x: 40, y: 120)
            draw("Use a well-known strategy.", x: 40, y: 160)
            draw("02.05", x: 40, y: 180)
            draw("const values = await Promise.all(tasks);", x: 40, y: 200, mono: true)
        }
        let blocks = PDFReadablePageExtractor().extract(document: pdf, pageIndex: 0, diagnostics: true).blocks
        XCTAssertEqual(blocks.filter { $0.kind == .bullet }.count, 2)
        XCTAssertTrue(blocks.contains { $0.text.hasPrefix("1.") })
        XCTAssertTrue(blocks.contains { $0.kind == .code && $0.text.contains("Promise.all") })
        XCTAssertTrue(blocks.contains { $0.text.contains("well-known") })
        XCTAssertTrue(blocks.contains { $0.text.contains("02.05") }, "Numeric body content must not be mistaken for a footer")
    }

    func testSourceRoundTripHighlightsCorrectPageWithoutChangingOriginalBytes() throws {
        let pdf = try document { draw("A microtask runs after the current script completes.", x: 40, y: 100) }
        let before = try XCTUnwrap(pdf.dataRepresentation())
        let controller = PDFSessionController(); controller.view.document = pdf
        XCTAssertTrue(controller.showSourceHighlight("A microtask runs after the current script completes.", pageIndex: 0))
        XCTAssertFalse(controller.showSourceHighlight("An unrelated passage.", pageIndex: 0))
        controller.clearSourceHighlight()
        XCTAssertEqual(PDFDocument(data: before)?.page(at: 0)?.string, pdf.page(at: 0)?.string)
        XCTAssertTrue(pdf.page(at: 0)?.annotations.isEmpty == true)
    }

    func testAllBundledPDFPagesExerciseSpatialReconstruction() throws {
        for name in ["React Notes", "System Design", "JavaScript Deep Dive", "Coding Interviews", "Computer Science Essentials", "Design Patterns"] {
            let url = try XCTUnwrap(Bundle.main.url(forResource: name, withExtension: "pdf"))
            let pdf = try XCTUnwrap(PDFDocument(url: url))
            for page in 0..<pdf.pageCount {
                let output = PDFReadablePageExtractor().extract(document: pdf, pageIndex: page)
                XCTAssertFalse(output.blocks.isEmpty, "\(name) page \(page + 1)")
                XCTAssertTrue(output.blocks.allSatisfy { !$0.text.isEmpty })
            }
        }
    }

    func testDarkReadAppearanceUsesIndependentForegroundAndBackground() {
        XCTAssertNotEqual(ReaderSurround.dark.readingBackground, ReaderSurround.paper.readingBackground)
        XCTAssertNotEqual(ReaderSurround.dark.readingText, ReaderSurround.paper.readingText)
        let defaults = UserDefaults(suiteName: "v25-dark-\(UUID())")!
        let preferences = AppPreferences(defaults: defaults)
        preferences.readerSurround = .dark
        XCTAssertEqual(AppPreferences(defaults: defaults).readerSurround, .dark)
    }
}
