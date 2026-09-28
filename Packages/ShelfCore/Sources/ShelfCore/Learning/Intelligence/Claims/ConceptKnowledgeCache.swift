import Foundation

/// Compiled knowledge per document, rebuilt only when the document's extraction changes.
/// Derived data: held in memory, never persisted as truth. Compiling runs off the caller's
/// actor, so the interface never waits on it.
public actor ConceptKnowledgeCache {
    private var entries: [UUID: (key: String, base: ConceptKnowledgeBase, used: Int)] = [:]
    private var clock = 0
    private let limit: Int

    public init(limit: Int = 12) { self.limit = max(1, limit) }

    /// Identifies the extraction a compiled knowledge base belongs to.
    public static func key(_ analysis: DocumentAnalysis) -> String {
        "\(analysis.fingerprint)|\(analysis.extractionVersion ?? 0)|\(ConceptKnowledgeBase.compilerVersion)"
    }

    public func knowledge(for analysis: DocumentAnalysis) -> ConceptKnowledgeBase {
        clock += 1
        let key = Self.key(analysis)
        if let entry = entries[analysis.documentID], entry.key == key {
            entries[analysis.documentID]?.used = clock
            return entry.base
        }
        let base = ConceptKnowledgeCompiler().compile(analysis)
        entries[analysis.documentID] = (key, base, clock)
        if entries.count > limit, let oldest = entries.min(by: { $0.value.used < $1.value.used })?.key { entries[oldest] = nil }
        return base
    }

    /// The already-compiled knowledge for a document, if it is current. Never compiles.
    public func cached(_ analysis: DocumentAnalysis) -> ConceptKnowledgeBase? {
        guard let entry = entries[analysis.documentID], entry.key == Self.key(analysis) else { return nil }
        return entry.base
    }
}
