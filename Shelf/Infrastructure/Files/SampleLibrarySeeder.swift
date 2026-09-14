import Foundation
import ShelfCore

/// Six small, original, bundled reading samples. This runs once, never on an existing library.
actor SampleLibrarySeeder {
    let repository: LibraryRepository
    let importer: DocumentImportService
    init(repository: LibraryRepository, importer: DocumentImportService) {
        self.repository = repository; self.importer = importer
    }
    func seed() async throws {
        let state = try await repository.snapshot()
        guard !state.didSeedSamples else { return }
        var collectionIDs: [String: UUID] = [:]
        for name in ["Study", "Frontend", "Backend"] {
            if let existing = state.collections.first(where: { $0.name == name }) {
                collectionIDs[name] = existing.id
            } else {
                collectionIDs[name] = try await repository.createCollection(name: name).id
            }
        }
        let samples: [(String, CoverPalette, CoverArt, String)] = [
            ("React Notes", .ocean, .dunes, "Frontend"),
            ("System Design", .graphite, .mountains, "Backend"),
            ("JavaScript Deep Dive", .graphite, .spheres, "Frontend"),
            ("Coding Interviews", .ivory, .cube, "Study"),
            ("Computer Science Essentials", .sand, .arches, "Study"),
            ("Design Patterns", .slate, .folds, "Backend")
        ]
        let date = Date()
        for (index, sample) in samples.enumerated() {
            guard let url = Bundle.main.url(forResource: sample.0, withExtension: "pdf") else {
                throw ShelfError.invalidPDF("A bundled sample is missing: " + sample.0)
            }
            let result = try await importer.importDocument(at: url)
            let group = collectionIDs[sample.3]
            let study = collectionIDs["Study"]
            try await repository.updateBook(id: result.book.id) { book in
                book.isSample = true; book.palette = sample.1; book.artwork = sample.2
                book.importedAt = date.addingTimeInterval(-Double(index))
                book.tags = [sample.3.lowercased()]
                book.collectionIDs = Set([group, study].compactMap { $0 })
            }
        }
        try await repository.markSamplesSeeded()
    }
}
