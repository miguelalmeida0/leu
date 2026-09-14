import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

/// Only repository admission creates these receipts. They detect changed source,
/// changed payload and contract upgrades; they are not signatures for imported data.
struct ValidatedIntelligenceReceipt: Codable, Equatable, Sendable {
    static let schemaVersion = 1
    static let questionContractVersion = 4
    let schema: Int
    let contract: Int
    let sourceDigest: String
    let questionDigest: String
    let completedPages: Set<Int>
    let completionDigest: String

    static func digest<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        #if canImport(CryptoKit)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        #else
        var hash = PortableSHA256(); hash.update(data); return hash.finalize()
        #endif
    }
    static func source(_ analysis: DocumentAnalysis) throws -> String {
        struct Input: Encodable {
            let documentID: UUID; let fingerprint: String; let extraction: Int?
            let algorithm: Int; let pages: [AnalyzedPage]
        }
        return try digest(Input(documentID: analysis.documentID, fingerprint: analysis.fingerprint,
            extraction: analysis.extractionVersion, algorithm: analysis.algorithmVersion, pages: analysis.pages))
    }
    static func questions(_ questions: [LearningQuestion]) throws -> String {
        // Set iteration order is not stable across processes. All semantic fields,
        // including option order and full V4 proof, remain in the checksum.
        struct Item: Encodable { var question: LearningQuestion; let topics: [String] }
        return try digest(questions.sorted { $0.id.uuidString < $1.id.uuidString }.map { q in
            var copy = q; copy.topicIDs = []
            return Item(question: copy, topics: q.topicIDs.map(\.uuidString).sorted())
        })
    }
    init(analysis: DocumentAnalysis, questions: [LearningQuestion], completedPages: Set<Int> = []) throws {
        schema = Self.schemaVersion; contract = Self.questionContractVersion
        sourceDigest = try Self.source(analysis); questionDigest = try Self.questions(questions)
        self.completedPages = completedPages
        completionDigest = try Self.digest(completedPages.sorted())
    }
    func matches(analysis: DocumentAnalysis, questions: [LearningQuestion]) -> Bool {
        schema == Self.schemaVersion && contract == Self.questionContractVersion &&
        analysis.extractionVersion == SourceExtractionVersion.current &&
        (try? Self.digest(completedPages.sorted())) == completionDigest &&
        (try? Self.source(analysis)) == sourceDigest && (try? Self.questions(questions)) == questionDigest
    }
}
