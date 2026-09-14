import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

public struct ReaderIntelligenceCapabilities: Codable, Sendable {
    public let sources: [RelationalSourceFact]
    public let connections: [GroundedConnectionV2]
    public let explanations: [LibraryExplanationItem]
    public let activity: ActivityDefinition?
    public let canTeach: Bool
}

/// Per-document immutable facts and lazy admitted query results. All access and
/// cache writes run on this actor, never on the UI executor. Corruption is a miss.
public actor LibraryIntelligenceCache {
    private struct Stored<T: Codable>: Codable {
        let version: Int
        let key: String
        let digest: String
        let payload: T
    }
    private let root: URL
    public private(set) var lastPersistenceError: String?
    private var previous: [UUID: DocumentAnalysis] = [:]
    private var previousTitles: [UUID: String] = [:]
    private var index = V28ConnectionIndex(facts: [])
    private var keys: [UUID: String] = [:]
    private var facts: [UUID: [RelationalSourceFact]] = [:]
    private var capabilities: [String: ReaderIntelligenceCapabilities] = [:]
    public init(root: URL) { self.root = root.appendingPathComponent("Intelligence-v28.1") }

    private func read<T: Codable>(_ type: T.Type, key: String) -> T? {
        guard let data = try? Data(contentsOf: root.appendingPathComponent(key + ".json")),
              let stored = try? JSONDecoder().decode(Stored<T>.self, from: data), stored.version == 1,
              stored.key == key, (try? ValidatedIntelligenceReceipt.digest(stored.payload)) == stored.digest else { return nil }
        return stored.payload
    }
    private func write<T: Codable>(_ value: T, key: String) {
        guard let digest = try? ValidatedIntelligenceReceipt.digest(value) else { return }
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(Stored(version: 1, key: key, digest: digest, payload: value))
            try atomicReplace(data, destination: root.appendingPathComponent(key + ".json"))
            lastPersistenceError = nil
        } catch {
            let error = error as NSError
            lastPersistenceError = "\(error.domain):\(error.code)"
        }
    }
    private func atomicReplace(_ data: Data, destination: URL) throws {
        // Same-volume staging, like the learner snapshot store. Foundation's
        // .atomic path performs additional operations denied on this host.
        let staging = root.appendingPathComponent(".next-\(UUID()).json")
        let fd = open(staging.path, O_WRONLY | O_CREAT | O_EXCL, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? handle.close(); try? FileManager.default.removeItem(at: staging) }
        try handle.write(contentsOf: data); try handle.synchronize(); try handle.close()
        guard rename(staging.path, destination.path) == 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        let directoryFD = open(root.path, O_RDONLY)
        guard directoryFD >= 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        defer { _ = close(directoryFD) }
        guard fsync(directoryFD) == 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
    }
    private func update(analyses: [UUID: DocumentAnalysis], titles: [UUID: String]) throws {
        guard analyses != previous || titles != previousTitles else { return }
        for id in Array(facts.keys) where analyses[id] == nil { facts.removeValue(forKey: id); keys.removeValue(forKey: id) }
        for (id, analysis) in analyses where previous[id] != analysis || previousTitles[id] != titles[id] {
            try refresh(analysis, title: titles[id] ?? "Source")
        }
        index = V28ConnectionIndex(facts: facts.keys.sorted { $0.uuidString < $1.uuidString }.flatMap { facts[$0] ?? [] })
        previous = analyses; previousTitles = titles; capabilities.removeAll()
    }

    private func refresh(_ analysis: DocumentAnalysis, title: String) throws {
        let id = analysis.documentID
        let key = try ValidatedIntelligenceReceipt.digest([ValidatedIntelligenceReceipt.source(analysis), title, "relations-v28-1"])
        let started = DispatchTime.now().uptimeNanoseconds
        let cached = read([RelationalSourceFact].self, key: key)
        if let cached { facts[id] = cached }
        else {
            let extracted = RelationalSourceFact.extract(analysis: analysis, documentTitle: title)
            facts[id] = extracted; write(extracted, key: key)
        }
        keys[id] = key
        IntelligencePerformance.record("connection_snapshot", since: started, workCount: cached == nil ? analysis.pages.count : 0, cacheHit: cached != nil)
    }

    /// Small capability discovery can complete before the connection query.
    public func sources(for source: IntelligenceSource, analyses: [UUID: DocumentAnalysis], titles: [UUID: String]) throws -> [RelationalSourceFact] {
        let started = DispatchTime.now().uptimeNanoseconds
        defer { IntelligencePerformance.record("reader_availability", since: started) }
        guard source.isCurrent(in: analyses), let analysis = analyses[source.packet.documentID] else { return [] }
        let id = analysis.documentID
        if previous[id] != analysis || previousTitles[id] != titles[id] {
            let key = try ValidatedIntelligenceReceipt.digest([ValidatedIntelligenceReceipt.source(analysis), titles[id] ?? "Source", "relations-v28-1"])
            // A cold library must not hold up current-page tools while unrelated
            // documents are indexed. Existing shards decode without role work.
            let current = read([RelationalSourceFact].self, key: key) ?? RelationalSourceFact.extract(analysis: analysis, documentTitle: titles[id] ?? "Source", onlyPage: source.packet.pageIndex)
            return V28ConnectionIndex(facts: current).anchors(for: source)
        }
        return V28ConnectionIndex(facts: facts[id] ?? []).anchors(for: source)
    }

    public func retrieve(source: IntelligenceSource, analyses: [UUID: DocumentAnalysis], titles: [UUID: String]) throws -> ReaderIntelligenceCapabilities {
        try update(analyses: analyses, titles: titles)
        let key = try ValidatedIntelligenceReceipt.digest(keys.values.sorted() + [ValidatedIntelligenceReceipt.digest(source)])
        let started = DispatchTime.now().uptimeNanoseconds
        if let cached = capabilities[key] {
            IntelligencePerformance.record("connection_query", since: started, cacheHit: true)
            return cached
        }
        if let cached = read(ReaderIntelligenceCapabilities.self, key: "cap-" + key) {
            if capabilities.count >= 64 { capabilities.removeAll() }
            capabilities[key] = cached
            IntelligencePerformance.record("reader_snapshot", since: started, cacheHit: true)
            return cached
        }
        let anchors = source.isCurrent(in: analyses) ? index.anchors(for: source) : []
        let connections: [GroundedConnectionV2]
        if let cached = read([GroundedConnectionV2].self, key: key) { connections = cached }
        else { connections = index.connections(from: source, analyses: analyses); write(connections, key: key) }
        let result = ReaderIntelligenceCapabilities(sources: anchors, connections: connections,
            explanations: ExplainFromLibrary.results(source: source, index: index, analyses: analyses, connections: connections),
            activity: index.activity(from: source, analyses: analyses, connections: connections),
            canTeach: anchors.contains { TeachLeuV2.evaluate("", source: $0, analyses: analyses).family != nil })
        // Bound selected-passage variants; document fact shards remain reusable.
        if capabilities.count >= 64 { capabilities.removeAll() }
        capabilities[key] = result
        write(result, key: "cap-" + key)
        IntelligencePerformance.record("reader_snapshot", since: started, workCount: anchors.count, cacheHit: false)
        return result
    }
}
