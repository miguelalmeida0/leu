import Foundation

public enum ReconstructionLabKind: String, Codable, CaseIterable, Sendable {
    case eventLoop, reactIdentity, httpCaching, structuralTyping, databaseTransaction
}

public struct LabElement: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var detail: String?
    public init(id: UUID = UUID(), title: String, detail: String? = nil) {
        self.id = id; self.title = title; self.detail = detail
    }
}

public struct LabChoice: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var text: String
    public init(id: UUID = UUID(), text: String) { self.id = id; self.text = text }
}

/// A pre-authored deterministic prediction after the learner reconstructs the
/// system. Nothing is generated from user content and every answer is fixed by
/// the scenario definition.
public struct LabScenario: Codable, Equatable, Sendable {
    public var setup: [String]
    public var prompt: String
    public var choices: [LabChoice]
    public var correctChoiceID: UUID
    public var explanation: String

    public init(setup: [String], prompt: String, choices: [LabChoice],
                correctChoiceID: UUID, explanation: String) {
        self.setup = setup; self.prompt = prompt; self.choices = choices
        self.correctChoiceID = correctChoiceID; self.explanation = explanation
    }
}

public struct ReconstructionLab: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var kind: ReconstructionLabKind
    public var title: String
    public var instruction: String
    public var elements: [LabElement]
    public var correctOrder: [UUID]
    public var scenario: LabScenario

    public init(id: UUID = UUID(), kind: ReconstructionLabKind, title: String,
                instruction: String, elements: [LabElement], correctOrder: [UUID],
                scenario: LabScenario) {
        self.id = id; self.kind = kind; self.title = title; self.instruction = instruction
        self.elements = elements; self.correctOrder = correctOrder; self.scenario = scenario
    }
}
