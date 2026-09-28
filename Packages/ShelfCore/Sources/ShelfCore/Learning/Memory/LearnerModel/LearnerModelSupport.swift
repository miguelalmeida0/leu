import Foundation

public struct CalibrationBin: Codable, Equatable, Sendable {
    public let confidence: ConfidenceLevel
    public var answered: Int
    public var correct: Int
    public var accuracy: Double? { answered == 0 ? nil : Double(correct) / Double(answered) }
}

/// How well stated confidence matches objective results (choice answers only).
public struct CalibrationProfile: Codable, Equatable, Sendable {
    public var bins: [CalibrationBin]
    public init() { bins = ConfidenceLevel.allCases.map { CalibrationBin(confidence: $0, answered: 0, correct: 0) } }

    public var answered: Int { bins.reduce(0) { $0 + $1.answered } }

    /// Mean stated confidence minus accuracy. Positive means overconfident. Nil under 6 answers.
    public var bias: Double? {
        guard answered >= 6 else { return nil }
        let stated = bins.reduce(0.0) { $0 + $1.confidence.numericValue * Double($1.answered) }
        let correct = bins.reduce(0) { $0 + $1.correct }
        return (stated - Double(correct)) / Double(answered)
    }

    public var isOverconfident: Bool { (bias ?? 0) >= 0.15 }

    mutating func record(_ confidence: ConfidenceLevel, correct: Bool) {
        guard let index = bins.firstIndex(where: { $0.confidence == confidence }) else { return }
        bins[index].answered += 1
        if correct { bins[index].correct += 1 }
    }
}

public struct ProbeRecord: Codable, Equatable, Sendable {
    public let probeID: String
    public let concept: LearnerConceptID
    public let operation: ProbeOperation
    public let askedAt: Date
    public let outcome: EvidenceOutcome
}

/// A detour to a weak prerequisite, remembering the concept to return to.
public struct RemediationObjective: Codable, Equatable, Sendable {
    public let objective: LearnerConceptID
    public let prerequisite: LearnerConceptID
    public let startedAt: Date
    public var detourAttempts: Int
    public init(objective: LearnerConceptID, prerequisite: LearnerConceptID, startedAt: Date, detourAttempts: Int = 0) {
        self.objective = objective; self.prerequisite = prerequisite; self.startedAt = startedAt; self.detourAttempts = detourAttempts
    }
}

/// Any JSON value, decoded and re-encoded without interpretation.
enum PreservedJSON: Codable, Equatable, Sendable {
    case null, bool(Bool), integer(Int64), number(Double), string(String), array([PreservedJSON]), object([String: PreservedJSON])

    init(from decoder: Decoder) throws {
        if let keyed = try? decoder.container(keyedBy: AnyKey.self) {
            var object: [String: PreservedJSON] = [:]
            for key in keyed.allKeys { object[key.stringValue] = try keyed.decode(PreservedJSON.self, forKey: key) }
            self = .object(object); return
        }
        if var list = try? decoder.unkeyedContainer() {
            var array: [PreservedJSON] = []
            while !list.isAtEnd { array.append(try list.decode(PreservedJSON.self)) }
            self = .array(array); return
        }
        let single = try decoder.singleValueContainer()
        if single.decodeNil() { self = .null }
        else if let value = try? single.decode(Bool.self) { self = .bool(value) }
        else if let value = try? single.decode(Int64.self) { self = .integer(value) }
        else if let value = try? single.decode(Double.self) { self = .number(value) }
        else { self = .string(try single.decode(String.self)) }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .object(let object):
            var keyed = encoder.container(keyedBy: AnyKey.self)
            for (key, value) in object { try keyed.encode(value, forKey: AnyKey(stringValue: key)) }
        case .array(let array):
            var list = encoder.unkeyedContainer()
            for value in array { try list.encode(value) }
        case .null: var single = encoder.singleValueContainer(); try single.encodeNil()
        case .bool(let value): var single = encoder.singleValueContainer(); try single.encode(value)
        case .integer(let value): var single = encoder.singleValueContainer(); try single.encode(value)
        case .number(let value): var single = encoder.singleValueContainer(); try single.encode(value)
        case .string(let value): var single = encoder.singleValueContainer(); try single.encode(value)
        }
    }

    struct AnyKey: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }
}
