import Foundation
import PDFKit
import ShelfCore

actor PDFExportService {
    private let vault: any DocumentVault
    private let temporary: URL
    init(vault: any DocumentVault, temporary: URL) { self.vault = vault; self.temporary = temporary }
    func export(book: Book, annotations: [StudyAnnotation], annotated: Bool) throws -> URL {
        let source = vault.originalURL(for: book.id)
        let folder = temporary.appendingPathComponent("PDF-Export-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let cleaned = book.title.components(separatedBy: CharacterSet(charactersIn: "/\\:\n"))
            .joined(separator: "-")
        let filename = String(cleaned.prefix(120)) + (annotated ? " - annotated" : "") + ".pdf"
        let destination = folder.appendingPathComponent(filename)
        if !annotated {
            try FileManager.default.copyItem(at: source, to: destination)
        } else {
            guard let document = PDFDocument(url: source), !document.isLocked else {
                throw ShelfError.invalidPDF("The original PDF could not be read.")
            }
            PDFAnnotationRenderer.apply(annotations, to: document)
            guard document.write(to: destination) else { throw CocoaError(.fileWriteUnknown) }
        }
        return destination
    }
}
