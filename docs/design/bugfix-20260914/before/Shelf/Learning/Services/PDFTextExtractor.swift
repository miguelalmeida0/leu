import Foundation
import PDFKit
import ShelfCore

struct PDFTextExtraction: Sendable {
    let pages: [SourcePageInput]
    let outlineTitles: [String]
    let nonEmptyCharacters: Int
    var canonicalPages: [Int: String] = [:]
}

protocol PDFTextExtracting: Sendable {
    func extract(documentID: UUID, fingerprint: String, url: URL,
                 progress: @Sendable (Double) async -> Void) async throws -> PDFTextExtraction
    func clearCheckpoint(documentID: UUID) async
}

actor PDFKitTextExtractor: PDFTextExtracting {
    static let extractionVersion = SourceExtractionVersion.current
    private let checkpoints: any PDFTextExtractionCheckpointing

    init(checkpoints: any PDFTextExtractionCheckpointing = NullPDFTextExtractionCheckpointStore()) {
        self.checkpoints = checkpoints
    }

    func extract(documentID: UUID, fingerprint: String, url: URL,
                 progress: @Sendable (Double) async -> Void) async throws -> PDFTextExtraction {
        try Task.checkCancellation()
        guard let document = PDFDocument(url: url) else {
            throw NSError(domain: "Shelf.Learning", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "The PDF could not be opened for study indexing."])
        }

        let pageCount = document.pageCount
        var pages = await resumablePages(documentID: documentID, fingerprint: fingerprint, pageCount: pageCount)
        var nonEmptyCharacters = pages.reduce(0) {
            $0 + $1.text.trimmingCharacters(in: .whitespacesAndNewlines).count
        }
        let startIndex = pages.count
        if pageCount == 0 { await progress(1) }
        if startIndex > 0 { await progress(Double(startIndex) / Double(max(1, pageCount))) }

        if startIndex < pageCount {
            for index in startIndex..<pageCount {
                try Task.checkCancellation()
                let readable = PDFReadablePageExtractor().extract(document: document, pageIndex: index)
                if !readable.sourceIntegrityPassed && !(document.page(at: index)?.string ?? "").isEmpty {
                    throw NSError(domain: "Shelf.SourceIntegrity", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "SOURCE_INTEGRITY_FAILED on page \(index + 1)"])
                }
                let text = readable.blocks.map(\.text).joined(separator: "\n\n")
                StudyInteractionTrace.record("index.extract document=\(documentID) page=\(index) blocks=\(readable.blocks.count) characters=\(text.count)")
                nonEmptyCharacters += text.trimmingCharacters(in: .whitespacesAndNewlines).count
                pages.append(SourcePageInput(pageIndex: index, text: text))
                if (index + 1).isMultiple(of: 16) || index == pageCount - 1 {
                    let checkpoint = PDFTextExtractionCheckpoint(
                        fingerprint: fingerprint,
                        extractionVersion: Self.extractionVersion,
                        pageCount: pageCount,
                        pages: pages
                    )
                    await checkpoints.save(checkpoint, documentID: documentID)
                }
                if index.isMultiple(of: 8) || index == pageCount - 1 {
                    await progress(Double(index + 1) / Double(max(1, pageCount)))
                    await Task.yield()
                }
            }
        }

        return PDFTextExtraction(pages: pages,
                                 outlineTitles: outlineTitles(document.outlineRoot),
                                 nonEmptyCharacters: nonEmptyCharacters,
                                 canonicalPages: Dictionary(uniqueKeysWithValues: (0..<pageCount).map { ($0, document.page(at: $0)?.string ?? "") }))
    }

    func clearCheckpoint(documentID: UUID) async {
        await checkpoints.remove(documentID: documentID)
    }

    private func resumablePages(documentID: UUID, fingerprint: String, pageCount: Int) async -> [SourcePageInput] {
        guard let checkpoint = await checkpoints.load(documentID: documentID),
              checkpoint.fingerprint == fingerprint,
              checkpoint.extractionVersion == Self.extractionVersion,
              checkpoint.pageCount == pageCount,
              checkpoint.pages.count <= pageCount,
              checkpoint.pages.enumerated().allSatisfy({ $0.offset == $0.element.pageIndex }) else {
            await checkpoints.remove(documentID: documentID)
            return []
        }
        return checkpoint.pages
    }

    private func outlineTitles(_ root: PDFOutline?) -> [String] {
        guard let root else { return [] }
        var result: [String] = []
        func walk(_ node: PDFOutline, depth: Int) {
            guard depth < 5 else { return }
            if let label = node.label?.trimmingCharacters(in: .whitespacesAndNewlines), !label.isEmpty {
                result.append(label)
            }
            for index in 0..<node.numberOfChildren {
                if let child = node.child(at: index) { walk(child, depth: depth + 1) }
            }
        }
        walk(root, depth: 0)
        return result
    }
}
