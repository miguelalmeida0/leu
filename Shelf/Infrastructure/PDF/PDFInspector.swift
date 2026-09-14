import PDFKit
import ShelfCore

/// Import-time inspection. This actor owns its own PDF instances, never the reader's PDFView.
actor PDFInspector: DocumentInspecting {
    func inspect(_ url: URL) async throws -> PDFInspection {
        guard let document = PDFDocument(url: url) else {
            throw ShelfError.invalidPDF("The file is damaged or is not a PDF.")
        }
        guard !document.isLocked else {
            throw ShelfError.invalidPDF("Password-protected PDFs must be unlocked and exported before import.")
        }
        guard document.pageCount > 0, document.pageCount <= 100_000 else {
            throw ShelfError.invalidPDF("The page count is not supported.")
        }
        var pages: [IndexedPage] = []
        var bytes = 0
        var partial = false
        for index in 0..<document.pageCount {
            try Task.checkCancellation()
            if index >= 5_000 { partial = true; break }
            let text = autoreleasepool { document.page(at: index)?.string ?? "" }
            let remaining = DocumentLimits.maxIndexBytes - bytes
            guard remaining > 0 else { partial = true; break }
            if text.utf8.count > remaining { partial = true; break }
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                pages.append(IndexedPage(pageIndex: index, text: text))
                bytes += text.utf8.count
            }
        }
        let status: TextIndexStatus = partial ? .partial : (pages.isEmpty ? .noText : .ready)
        return PDFInspection(pageCount: document.pageCount, index: BookTextIndex(pages: pages), status: status)
    }
}
