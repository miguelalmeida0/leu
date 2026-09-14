import ShelfCore

// These adapters record calls; they do not emulate SwiftUI or its presentation lifecycle.
@MainActor final class LensTrace { var events: [String] = [] }
@MainActor final class LensKnowledgeProbe {
    let trace: LensTrace
    var accepts = true
    var target: LearningSource?
    var origin: LearningSource?
    init(trace: LensTrace) { self.trace = trace }
    func queueLensNavigation(to target: LearningSource, from origin: LearningSource) -> Bool {
        self.target = target
        self.origin = origin
        trace.events.append("queue")
        return accepts
    }
}
@MainActor struct LensReaderProbe { let knowledge: LensKnowledgeProbe }
@MainActor struct LensDismissProbe {
    let trace: LensTrace
    func callAsFunction() { trace.events.append("dismiss") }
}
@MainActor struct LensRouteDependencies {
    let trace = LensTrace()
    var reader: LensReaderProbe { LensReaderProbe(knowledge: knowledge) }
    var dismiss: LensDismissProbe { LensDismissProbe(trace: trace) }
    let knowledge: LensKnowledgeProbe
    init() { knowledge = LensKnowledgeProbe(trace: trace) }
}
