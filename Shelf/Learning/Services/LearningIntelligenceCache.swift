import Foundation
import CryptoKit
import ShelfCore

struct LearningGenerationRecord: Codable, Sendable {
    let cacheKey: String
    let backend: String
    let timestamp: Date
    let candidate: LearningModelCandidate
    var acceptedQuestionID: UUID?
    var rejection: String?
    let inferenceMilliseconds: Double
    var sourcePacket: LearningSourcePacket?
    var validatedQuestion: LearningQuestion?
}

actor LearningIntelligenceCache {
    private let root: URL
    init(root: URL) { self.root = root.appendingPathComponent("Intelligence", isDirectory: true) }
    func load(_ key: String) -> LearningGenerationRecord? {
        guard let data = try? Data(contentsOf: url(key)) else { return nil }
        return try? JSONDecoder().decode(LearningGenerationRecord.self, from: data)
    }
    func save(_ record: LearningGenerationRecord) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try JSONEncoder().encode(record).write(to: url(record.cacheKey), options: .atomic)
    }
    private func url(_ key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return root.appendingPathComponent(digest + ".json")
    }
}

extension LearningIntelligenceCache: ExplanationCachePersistence {
    private var explanations: URL { root.appendingPathComponent("Explanations", isDirectory: true) }

    private func explanationURL(_ key: String) -> URL {
        explanations.appendingPathComponent(url(key).lastPathComponent)
    }

    func loadExplanation(_ key: String) -> ExplanationRecord? {
        guard let data = try? Data(contentsOf: explanationURL(key)) else { return nil }
        return try? JSONDecoder().decode(ExplanationRecord.self, from: data)
    }

    func saveExplanation(_ record: ExplanationRecord, key: String, limit: Int) throws {
        try FileManager.default.createDirectory(at: explanations, withIntermediateDirectories: true)
        try JSONEncoder().encode(record).write(to: explanationURL(key), options: .atomic)
        let files = try FileManager.default.contentsOfDirectory(at: explanations,
            includingPropertiesForKeys: [.contentModificationDateKey]).filter { $0.pathExtension == "json" }
        let newest = files.sorted {
            let left = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let right = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return left > right
        }
        for file in newest.dropFirst(max(1, limit)) { try FileManager.default.removeItem(at: file) }
    }

    func retainExplanationDocuments(_ ids: Set<UUID>) throws {
        guard FileManager.default.fileExists(atPath: explanations.path) else { return }
        for file in try FileManager.default.contentsOfDirectory(at: explanations, includingPropertiesForKeys: nil)
            where file.pathExtension == "json" {
            let record = try? JSONDecoder().decode(ExplanationRecord.self, from: Data(contentsOf: file))
            if record.map({ !ids.contains($0.packet.documentID) }) ?? true { try FileManager.default.removeItem(at: file) }
        }
    }

    func removeExplanationDocument(_ id: UUID) throws {
        guard FileManager.default.fileExists(atPath: explanations.path) else { return }
        for file in try FileManager.default.contentsOfDirectory(at: explanations, includingPropertiesForKeys: nil)
            where file.pathExtension == "json" {
            let record = try? JSONDecoder().decode(ExplanationRecord.self, from: Data(contentsOf: file))
            if record?.packet.documentID == id { try FileManager.default.removeItem(at: file) }
        }
    }
}
