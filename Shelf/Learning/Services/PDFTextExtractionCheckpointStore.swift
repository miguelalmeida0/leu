import Foundation
import ShelfCore

struct PDFTextExtractionCheckpoint: Codable, Sendable {
    let fingerprint: String
    let extractionVersion: Int
    let pageCount: Int
    var pages: [SourcePageInput]
}

protocol PDFTextExtractionCheckpointing: Sendable {
    func load(documentID: UUID) async -> PDFTextExtractionCheckpoint?
    func save(_ checkpoint: PDFTextExtractionCheckpoint, documentID: UUID) async
    func remove(documentID: UUID) async
}

actor FilePDFTextExtractionCheckpointStore: PDFTextExtractionCheckpointing {
    private let directory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(root: URL) {
        directory = root.appendingPathComponent("Learning/IndexWork", isDirectory: true)
        encoder.outputFormatting = [.sortedKeys]
    }

    func load(documentID: UUID) async -> PDFTextExtractionCheckpoint? {
        let url = fileURL(documentID)
        guard let data = try? Data(contentsOf: url),
              let checkpoint = try? decoder.decode(PDFTextExtractionCheckpoint.self, from: data) else { return nil }
        return checkpoint
    }

    func save(_ checkpoint: PDFTextExtractionCheckpoint, documentID: UUID) async {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try encoder.encode(checkpoint)
            try data.write(to: fileURL(documentID), options: .atomic)
        } catch {
            // Checkpoints are an optimization. Failure must never block reading or import.
        }
    }

    func remove(documentID: UUID) async {
        try? FileManager.default.removeItem(at: fileURL(documentID))
    }

    private func fileURL(_ documentID: UUID) -> URL {
        directory.appendingPathComponent(documentID.uuidString.lowercased() + ".json")
    }
}

actor NullPDFTextExtractionCheckpointStore: PDFTextExtractionCheckpointing {
    func load(documentID: UUID) async -> PDFTextExtractionCheckpoint? { nil }
    func save(_ checkpoint: PDFTextExtractionCheckpoint, documentID: UUID) async {}
    func remove(documentID: UUID) async {}
}
