import Foundation

/// What the learner can do with one kind of question about a concept.
///
/// Evidence is a Beta estimate over decayed pseudo-counts: old answers matter less than new
/// ones, and one lucky answer is weak evidence. Forgetting is separate: `retention` falls
/// with time and rises with successes on distinct days (spacing), not with repetition.
public struct OperationMastery: Codable, Equatable, Sendable {
    public let operation: ProbeOperation
    public var successWeight: Double
    public var failureWeight: Double
    public var attempts: Int
    public var lastEvidenceAt: Date
    public var lastSuccessAt: Date?
    /// Distinct days with a success.
    public var successDays: Int

    /// Probability of success from the evidence alone (uniform prior).
    public var estimate: Double { (successWeight + 1) / (successWeight + failureWeight + 2) }
    /// How much evidence stands behind `estimate` (0 = none).
    public var evidenceWeight: Double { successWeight + failureWeight }

    /// Days until retention falls to 1/e: 1.5 before any success, doubling per spaced success.
    public var stabilityDays: Double { successDays == 0 ? 1.5 : min(120, 3 * pow(2, Double(successDays - 1))) }

    public func retention(at date: Date) -> Double {
        guard let last = lastSuccessAt else { return 1 }
        return exp(-max(0, date.timeIntervalSince(last)) / 86_400 / stabilityDays)
    }

    /// Current expected success: evidence estimate discounted by forgetting.
    public func strength(at date: Date) -> Double { estimate * retention(at: date) }

    /// Mostly wrong over at least two answers' worth of evidence.
    public var isFailing: Bool { evidenceWeight >= 1.5 && estimate < 0.4 }
}

public struct ConceptMastery: Codable, Equatable, Sendable, Identifiable {
    public var id: LearnerConceptID { concept }
    public let concept: LearnerConceptID
    public var name: String
    public var operations: [OperationMastery]
    /// Wrong answers given with "fairly sure" or "certain": worth revisiting soon.
    public var confidentErrors: Int
    public var lastConfidentErrorAt: Date?
    public var firstSeenAt: Date
    public var lastSeenAt: Date

    public func operation(_ operation: ProbeOperation) -> OperationMastery? { operations.first { $0.operation == operation } }

    public func strength(_ operation: ProbeOperation, at date: Date) -> Double? { self.operation(operation)?.strength(at: date) }

    /// Highest operation level (1 recognise … 4 transfer) demonstrated reliably and not yet
    /// largely forgotten, with nothing below it failing. Forgetting is not failing: a faded
    /// level still counts as demonstrated while retention stays above one half.
    public func level(at date: Date) -> Int {
        var reached = 0
        for level in 1...4 {
            let here = operations.filter { $0.operation.level == level }
            if here.contains(where: { $0.isFailing }) { break }
            if here.contains(where: { $0.estimate >= 0.7 && $0.evidenceWeight >= 1.5 && $0.retention(at: date) >= 0.5 }) { reached = level }
        }
        return reached
    }

    /// Failing at recognising or explaining the concept: more wrong than right over at least two answers.
    public var failsBasics: Bool { operations.contains { $0.operation.level <= 2 && $0.isFailing } }

    /// Best current strength at recognising or explaining the concept (nil without evidence).
    public func coreStrength(at date: Date) -> Double? {
        operations.filter { $0.operation.level <= 2 }.map { $0.strength(at: date) }.max()
    }
}

public enum MisconceptionStatus: String, Codable, CaseIterable, Sendable {
    case active
    /// Answered correctly once since it was last seen.
    case resolving
    /// Answered correctly on two distinct days since it was last seen.
    case resolved
}

/// A wrong idea the learner has shown, remembered until spaced correct answers retire it.
/// It is never retired by time alone: time only lowers its salience.
public struct MisconceptionRecord: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let concept: LearnerConceptID
    public let kind: MisconceptionKind
    public let claimID: String?
    public let relatedConcept: ConceptKey?
    public var learnerWording: String
    public var occurrences: Int
    public var firstSeenAt: Date
    public var lastSeenAt: Date
    public var status: MisconceptionStatus
    /// Distinct days with a correct answer on the corrected idea since it was last seen.
    public var correctionDays: Int
    public var lastCorrectAt: Date?

    static func id(concept: LearnerConceptID, kind: MisconceptionKind, claimID: String?, related: ConceptKey?) -> String {
        "misconception-" + String(StableIdentity.hash64("\(concept)|\(kind.rawValue)|\(claimID ?? "")|\(related?.value ?? "")"), radix: 16)
    }

    /// 0…1. Recurring ideas weigh more; unrevisited ones fade with a 21-day half-life.
    public func salience(at date: Date) -> Double {
        guard status != .resolved else { return 0 }
        let days = max(0, date.timeIntervalSince(lastSeenAt)) / 86_400
        let recurrence = min(1, 0.6 + 0.2 * Double(occurrences - 1))
        return recurrence * pow(0.5, days / 21) * (status == .resolving ? 0.5 : 1)
    }
}

/// Everything Leu has learned about the learner. Persisted inside `LearningSnapshot` and
/// updated in the same transaction as the attempt it derives from. Bounded.
public struct LearnerModelState: Codable, Equatable, Sendable {
    public static let currentVersion = 1
    static let conceptLimit = 2_000, misconceptionLimit = 300, probeLimit = 80, evidenceIDLimit = 400

    public var version: Int
    public var concepts: [ConceptMastery]
    public var misconceptions: [MisconceptionRecord]
    public var calibration: CalibrationProfile
    public var recentProbes: [ProbeRecord]
    public var objective: RemediationObjective?
    /// Recently applied evidence, so a retried save never counts twice.
    public var appliedEvidenceIDs: [String]
    /// A model this Leu cannot read — written by a newer Leu, or damaged — kept as it is so
    /// nothing that cannot be rebuilt is ever overwritten.
    private var preserved: PreservedJSON?

    public init(version: Int = LearnerModelState.currentVersion, concepts: [ConceptMastery] = [], misconceptions: [MisconceptionRecord] = [],
                calibration: CalibrationProfile = CalibrationProfile(), recentProbes: [ProbeRecord] = [],
                objective: RemediationObjective? = nil, appliedEvidenceIDs: [String] = []) {
        self.version = version; self.concepts = concepts; self.misconceptions = misconceptions; self.calibration = calibration
        self.recentProbes = recentProbes; self.objective = objective; self.appliedEvidenceIDs = appliedEvidenceIDs
    }

    private enum CodingKeys: String, CodingKey { case version, concepts, misconceptions, calibration, recentProbes, objective, appliedEvidenceIDs }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        guard version <= Self.currentVersion else {
            concepts = []; misconceptions = []; calibration = CalibrationProfile(); recentProbes = []; objective = nil; appliedEvidenceIDs = []
            preserved = try PreservedJSON(from: decoder)
            return
        }
        do {
            concepts = try c.decodeIfPresent([ConceptMastery].self, forKey: .concepts) ?? []
            misconceptions = try c.decodeIfPresent([MisconceptionRecord].self, forKey: .misconceptions) ?? []
            calibration = try c.decodeIfPresent(CalibrationProfile.self, forKey: .calibration) ?? CalibrationProfile()
            recentProbes = try c.decodeIfPresent([ProbeRecord].self, forKey: .recentProbes) ?? []
            objective = try c.decodeIfPresent(RemediationObjective.self, forKey: .objective)
            appliedEvidenceIDs = try c.decodeIfPresent([String].self, forKey: .appliedEvidenceIDs) ?? []
        } catch {
            // Unreadable at this version: kept verbatim and left untouched, like a newer model.
            concepts = []; misconceptions = []; calibration = CalibrationProfile(); recentProbes = []; objective = nil; appliedEvidenceIDs = []
            preserved = try PreservedJSON(from: decoder)
        }
    }

    public func encode(to encoder: Encoder) throws {
        if let preserved { try preserved.encode(to: encoder); return }
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(version, forKey: .version)
        try c.encode(concepts, forKey: .concepts)
        try c.encode(misconceptions, forKey: .misconceptions)
        try c.encode(calibration, forKey: .calibration)
        try c.encode(recentProbes, forKey: .recentProbes)
        try c.encodeIfPresent(objective, forKey: .objective)
        try c.encode(appliedEvidenceIDs, forKey: .appliedEvidenceIDs)
    }

    public var isEmpty: Bool { concepts.isEmpty && misconceptions.isEmpty }
    /// A model written by a newer Leu, or one this Leu cannot read, is kept intact and never
    /// modified here.
    public var isWritable: Bool { preserved == nil }

    public func mastery(_ concept: LearnerConceptID) -> ConceptMastery? { concepts.first { $0.concept == concept } }

    public func misconceptions(for concept: LearnerConceptID, includeResolved: Bool = false) -> [MisconceptionRecord] {
        misconceptions.filter { $0.concept == concept && (includeResolved || $0.status != .resolved) }
    }

    /// The live misconception most worth addressing now.
    public func strongestMisconception(for concept: LearnerConceptID, at date: Date) -> MisconceptionRecord? {
        misconceptions(for: concept).filter { $0.salience(at: date) > 0.1 }
            .max { ($0.salience(at: date), $1.id) < ($1.salience(at: date), $0.id) }
    }
}
