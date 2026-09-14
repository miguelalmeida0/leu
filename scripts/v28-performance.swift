import Foundation
@testable import ShelfCore

@main struct Performance {
    static func main() async throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let output = root.appendingPathComponent("docs/v28.1/performance")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        var analyses: [UUID: DocumentAnalysis] = [:], titles: [UUID: String] = [:]
        for name in ["javascript_midlevel_interview_mobile_mastery", "React Notes", "JavaScript Deep Dive", "System Design"] {
            let a = try decoder.decode(DocumentAnalysis.self, from: Data(contentsOf: root.appendingPathComponent("docs/v28/evidence/baseline/\(name)-analysis.json")))
            analyses[a.documentID] = a; titles[a.documentID] = name
        }
        let primary = analyses.values.first { $0.pages.count == 345 }!
        var metrics: [[String: Any]] = []
        func record(_ name: String, _ start: Date, _ count: Int, _ bytes: Int = 0, hit: Bool = false) {
            let ms = Date().timeIntervalSince(start) * 1000
            metrics.append(["stage": name, "milliseconds": ms, "workCount": count, "bytes": bytes, "cacheHit": hit])
            print("\(name): \(ms) ms; count=\(count); bytes=\(bytes)"); fflush(stdout)
        }
        var start = Date()
        let bank = V4StudyBank.build(primary)
        record("question_generation", start, bank.count)
        let location = root.appendingPathComponent(".build/v28-performance-\(UUID())")
        let store = FileLearningSnapshotStore(root: location)
        let initial = LearningSnapshot(analyses: analyses)
        start = Date(); try store.save(initial); record("initial_raw_persistence", start, 1)
        let repo = LearningRepository(persistence: store)
        start = Date(); try await repo.storeV4Questions(bank); record("admission_and_persistence", start, bank.count)
        let snapshot = try await repo.snapshot()
        let bytes = try Data(contentsOf: location.appendingPathComponent("Learning/learning.json")).count
        start = Date(); try store.save(snapshot); record("raw_persistence", start, bank.count, bytes)
        for _ in 0..<10 {
            start = Date(); _ = try FileLearningSnapshotStore(root: location).load(); record("snapshot_decode", start, bank.count, bytes, hit: true)
            start = Date(); let reopened = try await LearningRepository(persistence: FileLearningSnapshotStore(root: location)).open()
            record("document_open", start, reopened.questions.count, bytes, hit: true)
            precondition(reopened.questions.count == bank.count)
        }
        start = Date(); let index = V28ConnectionIndex(analyses: analyses, titles: titles); record("connection_index", start, index.facts.count)
        let anchor = index.facts.first { titles[$0.documentID] == "React Notes" && $0.pageIndex == 2 && $0.relations.contains { $0.subject == "react.stable-key" } }!
        let source = anchor.citation(in: analyses)!
        for _ in 0..<20 {
            start = Date(); let found = index.connections(from: source, analyses: analyses); record("connection_query", start, found.count, hit: true)
            start = Date(); let feedback = V28TeachPresentation.compare("React needs a consistent ID so it knows it's still the same item after the list moves.", sources: [anchor], analyses: analyses)
            record("teach_analysis", start, feedback.captured.count)
            start = Date(); _ = index.anchors(for: source); record("reader_availability", start, 1, hit: true)
        }
        let cache = LibraryIntelligenceCache(root: location)
        start = Date(); _ = try await cache.retrieve(source: source, analyses: analyses, titles: titles)
        record("reader_cache_miss", start, 1)
        for _ in 0..<20 {
            start = Date(); _ = try await cache.retrieve(source: source, analyses: analyses, titles: titles)
            record("cached_connection_query", start, 0, hit: true)
            start = Date(); _ = try await cache.sources(for: source, analyses: analyses, titles: titles)
            record("cached_reader_availability", start, 0, hit: true)
        }
        start = Date(); _ = try await LibraryIntelligenceCache(root: location).retrieve(source: source, analyses: analyses, titles: titles)
        record("reopened_connection_snapshot", start, 0, hit: true)
        let generation = V4GenerationSession(analysis: primary)
        start = Date(); let batch = try await generation.batch(pages: primary.pages.map(\.pageIndex))
        record("production_validated_generation", start, batch.questions.count)
        start = Date(); try await repo.storeV4Batch(batch)
        record("production_validated_persistence", start, batch.questions.count, bytes)
        let samples = IntelligencePerformance.samples()
        let sampleEncoder = JSONEncoder(); sampleEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try sampleEncoder.encode(samples).write(to: output.appendingPathComponent("production-metrics.json"))
        let name = CommandLine.arguments.dropFirst().first ?? "optimized"
        try JSONSerialization.data(withJSONObject: ["metrics": metrics, "bankCount": bank.count, "library": location.path, "configuration": "Swift 5 unoptimized host; same compiler and corpus for before/after"], options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent(name + ".json"))
        precondition(bank.count >= 90)
    }
}
