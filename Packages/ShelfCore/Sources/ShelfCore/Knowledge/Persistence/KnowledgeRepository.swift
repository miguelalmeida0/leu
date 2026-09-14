import Foundation

public actor KnowledgeRepository {
    private let persistence: any KnowledgeSnapshotPersistence
    private var state: KnowledgeSnapshot?
    private let reanchorer = PassageReanchorer()

    public init(persistence: any KnowledgeSnapshotPersistence) { self.persistence = persistence }

    @discardableResult
    public func open() throws -> KnowledgeSnapshot {
        if let state { return state }
        var loaded = try persistence.load()
        if loaded.concepts.isEmpty {
            let seeded = ConceptCatalog.seeded()
            loaded.concepts = seeded.concepts; loaded.aliases = seeded.aliases
            try persistence.save(loaded)
        }
        state = loaded
        return loaded
    }

    public func snapshot() throws -> KnowledgeSnapshot { try open() }

    public func needsIndex(documentID: UUID, fingerprint: String) throws -> Bool {
        let snapshot = try open()
        guard let existing = snapshot.importStates[documentID] else { return true }
        return existing.fingerprint != fingerprint || existing.versions != .current
    }

    public func replaceDocumentIndex(_ bundle: KnowledgeDocumentBundle) throws {
        try transaction { snapshot in
            let documentID = bundle.importState.documentID
            let oldPassages = snapshot.passages.filter { $0.documentID == documentID }
            let newPassages = bundle.assembly.passages
            let newIDs = Set(newPassages.map(\.id))
            var remap: [UUID: UUID] = [:]
            for old in oldPassages where !newIDs.contains(old.id) {
                if let match = reanchorer.bestMatch(for: old, among: newPassages) { remap[old.id] = match.id }
            }
            repairUserKnowledge(snapshot: &snapshot, documentID: documentID, oldPassages: oldPassages,
                                newPassages: newPassages, remap: remap)
            let retainedTombstones = unresolvedTombstones(snapshot: snapshot, oldPassages: oldPassages,
                                                          documentID: documentID, remap: remap)
            snapshot.passages.removeAll { $0.documentID == documentID }
            snapshot.passages.append(contentsOf: newPassages)
            snapshot.passages.append(contentsOf: retainedTombstones)
            snapshot.sections.removeAll { $0.documentID == documentID }
            snapshot.sections.append(contentsOf: bundle.assembly.sections)
            snapshot.chapters.removeAll { $0.documentID == documentID }
            snapshot.chapters.append(contentsOf: bundle.assembly.chapters)
            let removedIDs = Set(oldPassages.map(\.id))
            snapshot.indexRecords.removeAll { removedIDs.contains($0.passageID) || $0.documentID == documentID }
            snapshot.indexRecords.append(contentsOf: bundle.index.records)
            snapshot.detectedBindings.removeAll { removedIDs.contains($0.passageID) }
            snapshot.detectedBindings.append(contentsOf: bundle.index.bindings)
            snapshot.importStates[documentID] = bundle.importState
        }
    }

    public func markDocumentUnavailable(_ documentID: UUID) throws {
        try transaction { snapshot in
            for index in snapshot.passages.indices where snapshot.passages[index].documentID == documentID {
                snapshot.passages[index].isAvailable = false
            }
            snapshot.indexRecords.removeAll { $0.documentID == documentID }
            snapshot.detectedBindings.removeAll { binding in
                snapshot.passages.first(where: { $0.id == binding.passageID })?.documentID == documentID
            }
            snapshot.importStates.removeValue(forKey: documentID)
        }
    }

    @discardableResult
    public func confirmConnection(source: UUID, destination: UUID, type: KnowledgeConnectionType = .related,
                                  customLabel: String? = nil) throws -> KnowledgeConnection {
        try transaction { snapshot in
            guard source != destination,
                  snapshot.passages.contains(where: { $0.id == source && $0.isAvailable }),
                  snapshot.passages.contains(where: { $0.id == destination && $0.isAvailable }) else { throw ShelfError.notFound }
            if let existing = snapshot.confirmedConnections.first(where: {
                (($0.sourcePassageID == source && $0.destinationPassageID == destination) ||
                 ($0.sourcePassageID == destination && $0.destinationPassageID == source)) && $0.type == type
            }) { return existing }
            let connection = KnowledgeConnection(sourcePassageID: source, destinationPassageID: destination,
                                                 type: type, origin: .user, customLabel: customLabel)
            snapshot.confirmedConnections.append(connection)
            return connection
        }
    }

    public func removeConnection(_ id: UUID) throws { try transaction { $0.confirmedConnections.removeAll { $0.id == id } } }

    public func connections(for passageID: UUID) throws -> [KnowledgeConnection] {
        try open().confirmedConnections.filter { $0.sourcePassageID == passageID || $0.destinationPassageID == passageID }
    }

    @discardableResult
    public func createConcept(name: String) throws -> KnowledgeConcept {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count >= 2 else { throw ShelfError.emptyTitle }
        return try transaction { snapshot in
            if let existing = snapshot.concepts.first(where: { $0.name.compare(clean, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) { return existing }
            let concept = KnowledgeConcept(id: UUID(), name: clean, isUserCreated: true)
            snapshot.concepts.append(concept)
            snapshot.aliases.append(ConceptAlias(id: UUID(), conceptID: concept.id, value: clean))
            return concept
        }
    }

    public func addAlias(_ value: String, to conceptID: UUID) throws {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count >= 2 else { throw ShelfError.emptyTitle }
        try transaction { snapshot in
            guard snapshot.concepts.contains(where: { $0.id == conceptID }) else { throw ShelfError.notFound }
            if !snapshot.aliases.contains(where: { $0.conceptID == conceptID && $0.value.caseInsensitiveCompare(clean) == .orderedSame }) {
                snapshot.aliases.append(ConceptAlias(id: UUID(), conceptID: conceptID, value: clean))
            }
        }
    }

    public func bind(passageID: UUID, conceptID: UUID) throws {
        try transaction { snapshot in
            guard snapshot.passages.contains(where: { $0.id == passageID }), snapshot.concepts.contains(where: { $0.id == conceptID }) else { throw ShelfError.notFound }
            let binding = PassageConceptBinding(passageID: passageID, conceptID: conceptID, source: .user)
            if !snapshot.userBindings.contains(binding) { snapshot.userBindings.append(binding) }
        }
    }

    @discardableResult
    public func createChain(title: String, conceptID: UUID? = nil) throws -> TopicChain {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { throw ShelfError.emptyTitle }
        return try transaction { snapshot in
            let chain = TopicChain(title: clean, conceptID: conceptID)
            snapshot.topicChains.append(chain); return chain
        }
    }

    public func saveChain(_ chain: TopicChain) throws {
        try transaction { snapshot in
            var normalized = chain
            normalized.updatedAt = Date()
            normalized.items = normalized.items.sorted { $0.position < $1.position }.enumerated().map { index, item in
                var next = item; next.chainID = chain.id; next.position = index; return next
            }
            if let index = snapshot.topicChains.firstIndex(where: { $0.id == chain.id }) { snapshot.topicChains[index] = normalized }
            else { snapshot.topicChains.append(normalized) }
        }
    }

    public func clearDerivedIndex() throws {
        try transaction { snapshot in
            let protected = protectedPassageIDs(snapshot)
            snapshot.passages = snapshot.passages.filter { protected.contains($0.id) }.map { passage in
                var tombstone = passage; tombstone.isAvailable = false; return tombstone
            }
            snapshot.sections = []; snapshot.chapters = []; snapshot.indexRecords = []
            snapshot.detectedBindings = []; snapshot.importStates = [:]
        }
    }

    private func transaction<T>(_ mutate: (inout KnowledgeSnapshot) throws -> T) throws -> T {
        var next = try open(); let result = try mutate(&next); try validate(next); try persistence.save(next); state = next; return result
    }

    private func validate(_ snapshot: KnowledgeSnapshot) throws {
        guard snapshot.schemaVersion == 1 else { throw ShelfError.unsupportedVersion(snapshot.schemaVersion) }
        guard Set(snapshot.passages.map(\.id)).count == snapshot.passages.count else { throw ShelfError.corruptLibrary("Duplicate passage identity.") }
        let ids = Set(snapshot.passages.map(\.id))
        guard snapshot.confirmedConnections.allSatisfy({ ids.contains($0.sourcePassageID) && ids.contains($0.destinationPassageID) }) else {
            throw ShelfError.corruptLibrary("A confirmed knowledge connection lost its passage anchor.")
        }
    }

    private func repairUserKnowledge(snapshot: inout KnowledgeSnapshot, documentID: UUID,
                                     oldPassages: [KnowledgePassage], newPassages: [KnowledgePassage], remap: [UUID: UUID]) {
        let oldIDs = Set(oldPassages.map(\.id)); let newIDs = Set(newPassages.map(\.id))
        for index in snapshot.confirmedConnections.indices {
            let source = snapshot.confirmedConnections[index].sourcePassageID
            let destination = snapshot.confirmedConnections[index].destinationPassageID
            if oldIDs.contains(source), let mapped = remap[source] { snapshot.confirmedConnections[index].sourcePassageID = mapped }
            if oldIDs.contains(destination), let mapped = remap[destination] { snapshot.confirmedConnections[index].destinationPassageID = mapped }
            let repairedSource = snapshot.confirmedConnections[index].sourcePassageID
            let repairedDestination = snapshot.confirmedConnections[index].destinationPassageID
            snapshot.confirmedConnections[index].requiresRecovery = (oldIDs.contains(repairedSource) && !newIDs.contains(repairedSource)) || (oldIDs.contains(repairedDestination) && !newIDs.contains(repairedDestination))
        }
        snapshot.userBindings = snapshot.userBindings.map { binding in
            var next = binding; if let mapped = remap[binding.passageID] { next.passageID = mapped }; return next
        }
        snapshot.topicChains = snapshot.topicChains.map { chain in
            var next = chain
            next.items = chain.items.map { item in var i = item; if let id = item.passageID, let mapped = remap[id] { i.passageID = mapped }; return i }
            return next
        }
    }

    private func unresolvedTombstones(snapshot: KnowledgeSnapshot, oldPassages: [KnowledgePassage], documentID: UUID,
                                      remap: [UUID: UUID]) -> [KnowledgePassage] {
        let protected = protectedPassageIDs(snapshot)
        return oldPassages.filter { protected.contains($0.id) && remap[$0.id] == nil }.map { old in
            var tombstone = old; tombstone.isAvailable = false; return tombstone
        }
    }

    private func protectedPassageIDs(_ snapshot: KnowledgeSnapshot) -> Set<UUID> {
        var ids = Set(snapshot.confirmedConnections.flatMap { [$0.sourcePassageID, $0.destinationPassageID] })
        ids.formUnion(snapshot.userBindings.map(\.passageID))
        ids.formUnion(snapshot.topicChains.flatMap { $0.items.compactMap(\.passageID) })
        return ids
    }
}
