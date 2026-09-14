import Foundation

protocol ExplanationCachePersistence: Sendable {
    func loadExplanation(_ key: String) async -> ExplanationRecord?
    func saveExplanation(_ record: ExplanationRecord, key: String, limit: Int) async throws
    func retainExplanationDocuments(_ ids: Set<UUID>) async throws
    func removeExplanationDocument(_ id: UUID) async throws
}

/// Bounded memory front for the existing local intelligence store.
@MainActor
final class ExplanationCache {
    private var entries: [String: ExplanationRecord] = [:]
    private var order: [String] = []
    private let limit: Int
    private let persistence: (any ExplanationCachePersistence)?
    private var eligibleDocuments: Set<UUID>?
    private var removedDocuments: Set<UUID> = []
    private(set) var lastPersistenceError: String?

    init(limit: Int = 24, persistence: (any ExplanationCachePersistence)? = nil) {
        self.limit = max(1, limit)
        self.persistence = persistence
    }

    func value(for key: String) async -> ExplanationRecord? {
        let record: ExplanationRecord?
        if let memory = entries[key] { record = memory }
        else { record = await persistence?.loadExplanation(key) }
        guard let record, allows(record.packet.documentID), record.schemaVersion == ExplanationSchema.version,
              record.validatorVersion == ExplanationSchema.validatorVersion,
              record.packet.cacheKey(mode: record.mode, backend: record.backend, providerRevision: record.providerRevision) == key,
              !record.candidate.needsContext,
              ExplanationValidator().isDisplayable(ExplanationValidator().validate(record.candidate, packet: record.packet, mode: record.mode)) else { return nil }
        remember(record, for: key)
        return record
    }

    func store(_ record: ExplanationRecord, for key: String) async {
        guard allows(record.packet.documentID) else { return }
        remember(record, for: key)
        do { try await persistence?.saveExplanation(record, key: key, limit: limit) }
        catch { lastPersistenceError = "\((error as NSError).domain) \((error as NSError).code)" }
    }

    private func remember(_ record: ExplanationRecord, for key: String) {
        if entries[key] == nil { order.append(key) }
        entries[key] = record
        while order.count > limit, let oldest = order.first {
            order.removeFirst()
            entries[oldest] = nil
        }
    }

    /// Honour document deletion and cache clearing.
    func removeAll(documentID: UUID) async {
        removedDocuments.insert(documentID)
        for (key, record) in entries where record.packet.documentID == documentID {
            entries[key] = nil
            order.removeAll { $0 == key }
        }
        do { try await persistence?.removeExplanationDocument(documentID) }
        catch { lastPersistenceError = "\((error as NSError).domain) \((error as NSError).code)" }
    }

    func retainDocuments(_ ids: Set<UUID>) async {
        eligibleDocuments = ids
        removedDocuments.subtract(ids)
        for (key, record) in entries where !ids.contains(record.packet.documentID) {
            entries[key] = nil; order.removeAll { $0 == key }
        }
        do { try await persistence?.retainExplanationDocuments(ids) }
        catch { lastPersistenceError = "\((error as NSError).domain) \((error as NSError).code)" }
    }

    func removeAll() async {
        await retainDocuments([])
        eligibleDocuments = nil
    }

    private func allows(_ id: UUID) -> Bool {
        !removedDocuments.contains(id) && (eligibleDocuments?.contains(id) ?? true)
    }
}
