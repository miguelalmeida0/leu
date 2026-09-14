import Foundation
import ShelfCore

extension KnowledgeModel {
    func related(to passage: KnowledgePassage, limit: Int = 7) -> [RankedKnowledgeConnection] {
        ranker.related(to: passage, snapshot: snapshot, limit: limit, minimumScore: 2.4)
    }

    func connections(for passageID: UUID) -> [KnowledgeConnection] {
        snapshot.confirmedConnections.filter {
            $0.sourcePassageID == passageID || $0.destinationPassageID == passageID
        }
    }

    func confirm(source: UUID, destination: UUID,
                 type: KnowledgeConnectionType = .related) async {
        do {
            _ = try await repository.confirmConnection(source: source, destination: destination, type: type)
            snapshot = try await repository.snapshot()
            ShelfHaptics.shared.play(.objectConnected)
        } catch { errorMessage = error.localizedDescription }
    }

    func removeConnection(_ id: UUID) async {
        do {
            try await repository.removeConnection(id)
            snapshot = try await repository.snapshot()
            ShelfHaptics.shared.play(.connectionRemoved)
        } catch { errorMessage = error.localizedDescription }
    }

    func queueNavigation(to passage: KnowledgePassage, from source: KnowledgePassage? = nil) {
        guard passage.isAvailable else {
            errorMessage = "That source is not currently available on this iPhone."
            return
        }
        if let source {
            backStack.append(KnowledgeDestination(documentID: source.documentID,
                pageIndex: source.pageIndex, sourceText: source.text))
        }
        pendingDestination = KnowledgeDestination(documentID: passage.documentID,
            pageIndex: passage.pageIndex, sourceText: passage.text)
    }

    @discardableResult
    func queueLensNavigation(to target: LearningSource, from origin: LearningSource) -> Bool {
        let active = Set(library.snapshot.activeBooks.map(\.id))
        guard active.contains(target.documentID), active.contains(origin.documentID) else {
            errorMessage = "A source PDF for this Lens journey is no longer available."
            return false
        }
        backStack.append(KnowledgeDestination(documentID: origin.documentID,
            pageIndex: origin.pageIndex, sourceText: origin.sourceText, restoreLens: origin))
        pendingDestination = KnowledgeDestination(documentID: target.documentID,
            pageIndex: target.pageIndex, sourceText: target.sourceText)
        return true
    }

    var canNavigateBack: Bool { !backStack.isEmpty }

    func queueBackNavigation() {
        guard let destination = backStack.popLast() else { return }
        pendingDestination = destination
        ShelfHaptics.shared.play(.selectionChanged)
    }

    func consumeDestination() -> KnowledgeDestination? {
        defer { pendingDestination = nil }
        return pendingDestination
    }

    func documentRelationshipStrengths(from documentID: UUID) -> [UUID: Double] {
        let sourceRecords = snapshot.indexRecords.filter { $0.documentID == documentID }
        guard !sourceRecords.isEmpty else { return [:] }
        let sourceConcepts = sourceRecords.reduce(into: Set<UUID>()) { $0.formUnion($1.conceptIDs) }
        let passageMap = Dictionary(uniqueKeysWithValues: snapshot.passages.map { ($0.id, $0) })
        var manualCounts: [UUID: Int] = [:]
        for connection in snapshot.confirmedConnections {
            guard let first = passageMap[connection.sourcePassageID],
                  let second = passageMap[connection.destinationPassageID] else { continue }
            if first.documentID == documentID && second.documentID != documentID {
                manualCounts[second.documentID, default: 0] += 1
            }
            if second.documentID == documentID && first.documentID != documentID {
                manualCounts[first.documentID, default: 0] += 1
            }
        }

        let grouped = Dictionary(grouping: snapshot.indexRecords.filter {
            $0.documentID != documentID
        }, by: \.documentID)
        var result: [UUID: Double] = [:]
        for (target, records) in grouped {
            let concepts = records.reduce(into: Set<UUID>()) { $0.formUnion($1.conceptIDs) }
            let shared = sourceConcepts.intersection(concepts).count
            let denominator = max(1, min(sourceConcepts.count, concepts.count))
            let conceptStrength = Double(shared) / Double(denominator)
            let manualStrength = min(1, Double(manualCounts[target, default: 0]) / 3)
            let strength = min(1, conceptStrength * 0.7 + manualStrength * 0.8)
            if strength >= 0.12 { result[target] = strength }
        }
        return result
    }
}
