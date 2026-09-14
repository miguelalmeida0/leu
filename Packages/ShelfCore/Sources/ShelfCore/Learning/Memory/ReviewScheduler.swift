import Foundation

public protocol ReviewScheduling: Sendable {
    func reviewed(_ state: ReviewState, rating: RecallRating, hintCount: Int, at date: Date) -> ReviewState
    func mastery(for state: ReviewState, at date: Date) -> MasteryState
}

public extension ReviewScheduling {
    func reviewed(_ state: ReviewState, rating: RecallRating, at date: Date) -> ReviewState {
        reviewed(state, rating: rating, hintCount: 0, at: date)
    }
}

public struct ShelfReviewScheduler: ReviewScheduling, Sendable {
    public init() {}

    public func reviewed(_ state: ReviewState, rating: RecallRating, hintCount: Int = 0,
                         at date: Date) -> ReviewState {
        var next = state
        let support = min(max(hintCount, 0), 3)
        next.reviewCount += 1
        next.lastReviewedAt = date
        switch rating {
        case .forgot:
            next.failedRecalls += 1
            next.difficulty = min(1, next.difficulty + 0.12)
            next.stability = max(0.35, next.stability * 0.58)
        case .difficult:
            next.successfulRecalls += 1
            next.difficulty = min(1, max(0, next.difficulty + 0.035 + Double(support) * 0.01))
            let supportFactor = max(1.08, 1.35 - Double(support) * 0.08)
            next.stability = max(0.8, next.stability * supportFactor)
        case .knewIt:
            next.successfulRecalls += 1
            let reduction = max(0.015, 0.055 - Double(support) * 0.012)
            next.difficulty = max(0, next.difficulty - reduction)
            let growth = max(1.30, 1.9 - Double(support) * 0.18)
            let bonus = max(0.1, 0.4 - Double(support) * 0.08)
            next.stability = max(1.2, next.stability * growth + bonus)
        }
        next.nextReviewAt = date.addingTimeInterval(interval(for: next, rating: rating, hintCount: support))
        return next
    }

    public func mastery(for state: ReviewState, at date: Date) -> MasteryState {
        guard state.reviewCount > 0 else { return .new }
        if let due = state.nextReviewAt, due <= date {
            let overdue = date.timeIntervalSince(due)
            let fadeThreshold = max(86_400, state.stability * 86_400 * 0.7)
            return overdue >= fadeThreshold ? .fading : .due
        }
        if state.stability >= 18 && state.successfulRecalls >= 4 { return .durable }
        if state.stability >= 5 && state.successfulRecalls >= 2 { return .strengthening }
        return .learning
    }

    private func interval(for state: ReviewState, rating: RecallRating, hintCount: Int) -> TimeInterval {
        let day: TimeInterval = 86_400
        let importance = 1.15 - state.importance * 0.25
        let supportPenalty = max(0.55, 1 - Double(hintCount) * 0.14)
        switch rating {
        case .forgot:
            return max(8 * 60, min(6 * 60 * 60, state.stability * 45 * 60))
        case .difficult:
            return max(10 * 60 * 60, state.stability * 0.75 * day * importance * supportPenalty)
        case .knewIt:
            return max(18 * 60 * 60, state.stability * 1.35 * day * importance * supportPenalty)
        }
    }
}
