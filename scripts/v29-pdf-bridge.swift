import Foundation
import PDFKit
import CryptoKit

struct Page: Codable { let number: Int; let text: String }
struct Document: Codable { let id: String; let title: String; let sha256: String; let pages: [Page] }
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let paths = ["docs/v28/fixtures/javascript_midlevel_interview_mobile_mastery.pdf", "Shelf/Resources/Samples/React Notes.pdf", "Shelf/Resources/Samples/JavaScript Deep Dive.pdf", "Shelf/Resources/Samples/System Design.pdf"]
var documents: [Document] = []
let started = Date()
for path in paths {
    let url = root.appendingPathComponent(path), data = try Data(contentsOf: url)
    guard let pdf = PDFDocument(data: data) else { fatalError("Unreadable PDF: \(path)") }
    let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    documents.append(Document(id: url.deletingPathExtension().lastPathComponent, title: url.deletingPathExtension().lastPathComponent,
        sha256: hash, pages: (0..<pdf.pageCount).map { Page(number: $0+1, text: pdf.page(at: $0)?.string ?? "") }))
}
let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
try encoder.encode(documents).write(to: root.appendingPathComponent("evidence/v29-real-reasoning/pdf-pages.json"))
print("PDFKit extracted", documents.map { "\($0.title): \($0.pages.count) pages" }.joined(separator: "; "))
try encoder.encode(["milliseconds": Date().timeIntervalSince(started) * 1000, "pdfCount": Double(documents.count), "pages": Double(documents.reduce(0) { $0 + $1.pages.count })]).write(to: root.appendingPathComponent("evidence/v29-real-reasoning/pdf-bridge-performance.json"))
