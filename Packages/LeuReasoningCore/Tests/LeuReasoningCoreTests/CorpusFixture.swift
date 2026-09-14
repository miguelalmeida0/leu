import Foundation
import XCTest
@testable import LeuReasoningCore

/// Loads the golden corpus from the test bundle, or from an explicit path when
/// the harness is pointed at a different corpus.
enum CorpusFixture {
    static func url() throws -> URL {
        if let override = ProcessInfo.processInfo.environment["LEU_GOLDEN_CORPUS"] {
            return URL(fileURLWithPath: override)
        }
        guard let url = Bundle.module.url(forResource: "golden-corpus", withExtension: "json", subdirectory: "Fixtures")
            ?? Bundle.module.url(forResource: "golden-corpus", withExtension: "json") else {
            throw XCTSkip("golden-corpus.json is not in the test bundle")
        }
        return url
    }

    static func load() throws -> GoldenCorpus {
        try GoldenCorpus.load(from: url())
    }

    static func graph() throws -> KnowledgeGraph {
        try load().buildGraph()
    }
}
