import XCTest
import PDFKit
import UIKit
import ShelfCore
@testable import Shelf

/// Apple-only tests. Run in the iPhone simulator with ./scripts/test-ios.sh.
final class PDFIntegrationTests: XCTestCase {
    private func sample(_ name: String) throws -> URL {
        try XCTUnwrap(Bundle.main.url(forResource: name, withExtension: "pdf"))
    }
    func testAllBundledSamplesAreRealReadablePDFs() throws {
        for name in ["React Notes", "System Design", "JavaScript Deep Dive", "Coding Interviews",
                     "Computer Science Essentials", "Design Patterns"] {
            let document = try XCTUnwrap(PDFDocument(url: sample(name)))
            XCTAssertEqual(document.pageCount, 4, name)
            XCTAssertFalse(document.isLocked)
            XCTAssertFalse((document.string ?? "").isEmpty)
        }
    }
    func testInspectorBuildsSelectableTextIndex() async throws {
        let result = try await PDFInspector().inspect(sample("JavaScript Deep Dive"))
        XCTAssertEqual(result.pageCount, 4)
        XCTAssertEqual(result.status, .ready)
        XCTAssertTrue(result.index.pages.contains { $0.text.lowercased().contains("closure") })
    }
    func testInspectorRejectsInvalidFile() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("not a PDF".utf8).write(to: url)
        do { _ = try await PDFInspector().inspect(url); XCTFail("Expected invalid PDF rejection") } catch {}
    }
    func testSearchReturnsMatchingSourcePages() async throws {
        let id = UUID()
        let matches = try await PDFPageSearch().search(url: sample("JavaScript Deep Dive"), query: "closure", bookID: id)
        XCTAssertFalse(matches.isEmpty)
        XCTAssertTrue(matches.allSatisfy { $0.bookID == id && $0.pageIndex < 4 && $0.length > 0 })
    }
    func testAnnotatedExportKeepsOriginalBytesAndPortableNotes() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let vault = FileDocumentVault(root: root)
        let id = UUID(); let original = try vault.stageCopy(from: sample("React Notes"), id: id)
        let hash = try FileDigest.sha256(url: original)
        let size = try original.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        let book = Book(id: id, title: "React Notes", originalFilename: "React Notes.pdf", fingerprint: hash, pageCount: 4, byteCount: Int64(size))
        let mark = StudyAnnotation(bookID: id, pageIndex: 0, kind: .note, note: "A portable note")
        let exporter = PDFExportService(vault: vault, temporary: root.appendingPathComponent("exports"))
        let output = try await exporter.export(book: book, annotations: [mark], annotated: true)
        XCTAssertEqual(try FileDigest.sha256(url: original), hash)
        let document = try XCTUnwrap(PDFDocument(url: output))
        let notes = try XCTUnwrap(document.page(at: 0)).annotations
        XCTAssertTrue(notes.contains { ($0.contents ?? "").contains("A portable note") })
    }
    func testOriginalExportIsByteIdentical() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let vault = FileDocumentVault(root: root); let id = UUID()
        let original = try vault.stageCopy(from: sample("React Notes"), id: id)
        let hash = try FileDigest.sha256(url: original)
        let size = try original.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        let book = Book(id: id, title: "React Notes", originalFilename: "React Notes.pdf", fingerprint: hash, pageCount: 4, byteCount: Int64(size))
        let output = try await PDFExportService(vault: vault, temporary: root).export(book: book, annotations: [], annotated: false)
        XCTAssertEqual(try FileDigest.sha256(url: output), hash)
    }
    @MainActor
    func testSynchronizingAnnotationsDoesNotDuplicateThem() throws {
        let document = try XCTUnwrap(PDFDocument(url: sample("React Notes")))
        let controller = PDFSessionController(); controller.view.document = document
        let note = StudyAnnotation(bookID: UUID(), pageIndex: 0, kind: .note, note: "One note")
        controller.synchronize([note]); controller.synchronize([note])
        let page = try XCTUnwrap(document.page(at: 0))
        XCTAssertEqual(page.annotations.filter { ($0.contents ?? "").contains("One note") }.count, 1)
        controller.synchronize([])
        XCTAssertFalse(page.annotations.contains { ($0.contents ?? "").contains("One note") })
    }
    func testThumbnailProducesAnImage() async throws {
        let data = try await PDFThumbnailService().thumbnail(url: sample("React Notes"), pageIndex: 0, width: 260)
        XCTAssertNotNil(data)
        XCTAssertNotNil(data.flatMap { UIImage(data: $0) })
    }
    func testReadableModeRepairsKnownExtractionSeamsWithoutChangingSourcePDF() throws {
        // Text without geometry cannot distinguish tracking from word spaces.
        // Draw fragmented runs with real word gaps; retain every content assertion.
        let font = UIFont.systemFont(ofSize: 20)
        let data = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 600, height: 800)).pdfData { context in
            context.beginPage()
            func runs(_ words: [String], y: CGFloat) {
                var x: CGFloat = 40
                for word in words {
                    for character in word {
                        let fragment = String(character) as NSString
                        fragment.draw(at: CGPoint(x: x, y: y), withAttributes: [.font: font])
                        x += fragment.size(withAttributes: [.font: font]).width
                    }
                    x += 12
                }
            }
            runs(["JAVASCRIPT", "CORE", "MENTAL", "MODELS"], y: 60)
            runs(["IN", "ONE", "BREATH"], y: 100)
            runs(["FOLLOW-UP"], y: 140)
            runs(["Answer", "aloud", "before", "revealing"], y: 200)
            runs(["02.05"], y: 770)
        }
        let originalURL = FileManager.default.temporaryDirectory.appendingPathComponent("read-source-\(UUID()).pdf")
        try data.write(to: originalURL)
        defer { try? FileManager.default.removeItem(at: originalURL) }
        let document = try XCTUnwrap(PDFDocument(url: originalURL))
        let control = try XCTUnwrap(PDFDocument(data: data))
        let controlFirst = control.dataRepresentation()
        logByteDifference("control: serialize twice without extraction", controlFirst, control.dataRepresentation())
        _ = control.page(at: 0)?.string
        logByteDifference("control: page.string", controlFirst, control.dataRepresentation())
        _ = control.page(at: 0)?.attributedString
        logByteDifference("control: page.attributedString", controlFirst, control.dataRepresentation())
        let before = try Data(contentsOf: originalURL)
        let page = PDFReadablePageExtractor().extract(document: document, pageIndex: 0, diagnostics: true)
        logByteDifference("Read extraction", before, document.dataRepresentation())
        // The control above proves dataRepresentation creates a new trailer /ID
        // even with no extraction. Compare the immutable original PDF's bytes.
        XCTAssertEqual(try Data(contentsOf: originalURL), before)
        let visible = page.blocks.map(\.text).joined(separator: "\n")
        XCTAssertTrue(visible.contains("JAVASCRIPT"))
        XCTAssertTrue(visible.contains("MENTAL MODELS"))
        XCTAssertTrue(visible.contains("IN ONE BREATH"))
        XCTAssertTrue(visible.contains("FOLLOW-UP"))
        XCTAssertFalse(visible.contains("02.05"))
    }

    private func logByteDifference(_ stage: String, _ before: Data?, _ after: Data?) {
        guard let before, let after else { print("[leu-pdf-bytes] \(stage): missing serialization"); return }
        let offset = zip(before, after).enumerated().first { $0.element.0 != $0.element.1 }?.offset
            ?? (before.count == after.count ? nil : min(before.count, after.count))
        guard let offset else { print("[leu-pdf-bytes] \(stage): identical \(before.count) bytes"); return }
        let start = max(0, offset - 48)
        print("[leu-pdf-bytes] \(stage): firstDifference=\(offset) beforeCount=\(before.count) afterCount=\(after.count)")
        print("[leu-pdf-bytes] before=\(String(decoding: before[start..<min(before.count, offset + 96)], as: UTF8.self).debugDescription)")
        print("[leu-pdf-bytes] after=\(String(decoding: after[start..<min(after.count, offset + 96)], as: UTF8.self).debugDescription)")
    }

}
