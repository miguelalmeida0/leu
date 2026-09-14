import Foundation

public struct BlindPageContext: Equatable, Sendable {
    public var pagesSincePrompt: Int
    public var secondsSincePrompt: TimeInterval
    public var atSectionBoundary: Bool
    public var consecutiveSkips: Int
    public init(pagesSincePrompt: Int, secondsSincePrompt: TimeInterval, atSectionBoundary: Bool, consecutiveSkips: Int) {
        self.pagesSincePrompt = pagesSincePrompt; self.secondsSincePrompt = secondsSincePrompt
        self.atSectionBoundary = atSectionBoundary; self.consecutiveSkips = consecutiveSkips
    }
}

public struct BlindPagePolicy: Sendable {
    public init() {}
    public func shouldPrompt(_ context: BlindPageContext) -> Bool {
        let skipPenalty = min(12, max(0, context.consecutiveSkips) * 2)
        let requiredPages = 5 + skipPenalty
        let requiredTime = TimeInterval(240 + skipPenalty * 45)
        guard context.pagesSincePrompt >= requiredPages, context.secondsSincePrompt >= requiredTime else { return false }
        return context.atSectionBoundary || context.pagesSincePrompt >= requiredPages + 3
    }
}
