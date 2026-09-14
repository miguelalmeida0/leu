import XCTest
import UIKit
import PDFKit
import ShelfCore
@testable import Shelf

@MainActor final class PDFReadFurnitureTests: XCTestCase {
    func testRealReactReadModeHidesFurnitureButPreservesCanonicalSource() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "React Notes", withExtension: "pdf"))
        let bytes = try Data(contentsOf: url)
        let pdf = try XCTUnwrap(PDFDocument(url: url))
        let furniture = PDFDocumentFurniture(document: pdf)
        let headings = ["React Notes", "State is a snapshot", "Keys describe identity"]
        for index in 0..<3 {
            let page = try XCTUnwrap(pdf.page(at: index))
            let canonical = try XCTUnwrap(page.string)
            let read = PDFReadablePageExtractor().extract(document: pdf, pageIndex: index, furniture: furniture)
            let text = read.blocks.map(\.text).joined(separator: "\n")
            XCTAssertTrue(canonical.contains("SHELF SAMPLES /"))
            XCTAssertTrue(canonical.contains("SHELF / ORIGINAL SAMPLE NOTES"))
            XCTAssertFalse(text.contains("SHELF SAMPLES /"))
            XCTAssertFalse(text.contains("SHELF / ORIGINAL SAMPLE NOTES"))
            XCTAssertTrue(read.blocks.contains { $0.kind == .heading && $0.text == headings[index] })
            XCTAssertTrue(read.sourceIntegrityPassed)
            let range = try XCTUnwrap(SourcePassageMatcher.range(of: text, in: canonical))
            let exact = (canonical as NSString).substring(with: range)
            XCTAssertEqual(page.selection(for: range)?.string, exact)
            XCTAssertTrue(exact.contains(headings[index]))
        }
        XCTAssertEqual(try Data(contentsOf: url), bytes)
    }

    func testOnlyRepeatedEdgeTextIsHidden() throws {
        let pdf = try fixture(pages: 4)
        let furniture = PDFDocumentFurniture(document: pdf)
        for index in 0..<4 {
            let text = PDFReadablePageExtractor().extract(document: pdf, pageIndex: index, furniture: furniture).blocks.map(\.text).joined(separator: "\n")
            XCTAssertFalse(text.contains("FIELD GUIDE /"))
            XCTAssertFalse(text.contains("REFERENCE EDITION"))
            XCTAssertTrue(text.contains("A repeated sentence in the body must remain."))
            XCTAssertTrue(text.contains("Chapter \(index + 1): unique content"))
        }
    }

    func testTwoPagesDoNotProvideEnoughEvidenceToHideContent() throws {
        let pdf = try fixture(pages: 2)
        let text = PDFReadablePageExtractor().extract(document: pdf, pageIndex: 0,
            furniture: PDFDocumentFurniture(document: pdf)).blocks.map(\.text).joined(separator: "\n")
        XCTAssertTrue(text.contains("FIELD GUIDE / 1"))
        XCTAssertTrue(text.contains("REFERENCE EDITION 1"))
    }

    private func fixture(pages: Int) throws -> PDFDocument {
        let data = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 432, height: 624)).pdfData { context in
            for index in 1...pages {
                context.beginPage()
                func draw(_ text: String, y: CGFloat, size: CGFloat) {
                    (text as NSString).draw(at: CGPoint(x: 36, y: y), withAttributes: [.font: UIFont.systemFont(ofSize: size)])
                }
                draw("FIELD GUIDE / \(index)", y: 18, size: 9)
                draw("Chapter \(index): unique content", y: 84, size: 23)
                draw("A repeated sentence in the body must remain.", y: 160, size: 12)
                draw("REFERENCE EDITION \(index)", y: 598, size: 9)
            }
        }
        return try XCTUnwrap(PDFDocument(data: data))
    }
}
