import Foundation

public enum ActivityContract: String, Codable, Sendable { case stableKeys, cachedCopy }
public struct ActivityDefinition: Codable, Equatable, Sendable, Identifiable {
    public let contract: ActivityContract
    public let source: IntelligenceSource
    public var id: String { contract.rawValue + "|" + source.id }
    public var title: String { contract == .stableKeys ? "Keep track of the same item" : "Original and cached copy" }
    public var premise: String {
        contract == .stableKeys ? "An illustration with three rows of the same type. Edit a row's toy state, then move the items."
            : "A small copy experiment, not an HTTP protocol simulation. Compare reusing a copy with recomputing it after the original changes."
    }
}
public enum ActivityValidator {
    public static func definition(for source: IntelligenceSource) -> ActivityDefinition? {
        // Each prerequisite must be present in admissible prose, not in a heading,
        // instructional region, mnemonic, or an unverified page.
        let text = source.claims.map { CanonicalWhitespaceResolver.normalize($0.evidence.text).lowercased() }.joined(separator: " ")
        if text.contains("stable key helps react match an item to its previous instance"),
           text.contains("array index can be a poor key when items move"),
           text.contains("reordering should not make one item inherit the local state of another") {
            return .init(contract: .stableKeys, source: source)
        }
        if text.contains("cache avoids repeating work"), text.contains("can become stale") {
            return .init(contract: .cachedCopy, source: source)
        }
        return nil
    }
    public static func accepts(_ definition: ActivityDefinition, analyses: [UUID: DocumentAnalysis]) -> Bool {
        definition.source.isCurrent(in: analyses) && self.definition(for: definition.source) == definition
    }
}

public struct ActivityState: Codable, Equatable, Sendable {
    public enum Keys: String, Codable, Sendable { case stableIDs, positions }
    public var keys: Keys = .stableIDs
    public private(set) var order = ["A", "B", "C"]
    public private(set) var rowState = [7, 0, 0]
    public private(set) var original = 1
    public private(set) var cached: Int?
    public private(set) var computations = 0
    public private(set) var lastAction = "Try a change."
    public init() {}
    public mutating func apply(_ transition: ActivityTransition, definition: ActivityDefinition) throws {
        guard order.count == 3, Set(order) == Set(["A", "B", "C"]), rowState.count == 3 else { throw ActivityError.invalidState }
        switch (definition.contract, transition) {
        case (.stableKeys, .reorder):
            order = [order[2], order[0], order[1]]
            if keys == .stableIDs { rowState = [rowState[2], rowState[0], rowState[1]] }
            lastAction = keys == .stableIDs ? "The state moved with the same item." : "The position kept the state; another item now occupies it."
        case (.stableKeys, .edit(let item)):
            guard let index = order.firstIndex(of: item), rowState[index] < 999 else { throw ActivityError.invalidTransition }
            rowState[index] += 1; lastAction = "Changed the toy state for item \(item)."
        case (.stableKeys, .chooseKeys(let keys)):
            self = ActivityState(); self.keys = keys
        case (.cachedCopy, .changeOriginal):
            guard original < 999 else { throw ActivityError.invalidTransition }
            original += 1; lastAction = "The original changed; the stored copy did not."
        case (.cachedCopy, .reuse):
            if cached == nil { cached = original; computations += 1; lastAction = "No copy yet: computed and stored one." }
            else { lastAction = "Reused the stored copy without repeating the work." }
        case (.cachedCopy, .recompute):
            cached = original; computations += 1; lastAction = "Repeated the work to replace the stored copy."
        case (_, .reset): self = ActivityState()
        default: throw ActivityError.invalidTransition
        }
    }
}
public enum ActivityTransition: Equatable, Sendable {
    case reorder, edit(String), chooseKeys(ActivityState.Keys), changeOriginal, reuse, recompute, reset
}
public enum ActivityError: Error { case invalidState, invalidTransition }
