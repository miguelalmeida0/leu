import Foundation

/// A deterministic, content-derived identifier.
///
/// Reasoning artifacts must be stable across runs and across app launches so
/// that persisted understanding state keeps pointing at the same knowledge.
/// Every synthesized id is therefore a hash of the content that defines it,
/// never a random UUID.
public struct StableID: Codable, Equatable, Hashable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Derives an id from a namespace and the ordered components that define
    /// the artifact. Two artifacts with identical defining content collapse to
    /// the same id, which is what makes re-extraction idempotent.
    public init(namespace: String, components: [String]) {
        let joined = components.joined(separator: "\u{1F}")
        self.rawValue = "\(namespace).\(StableID.digest(joined))"
    }

    public var description: String { rawValue }

    /// FNV-1a (64 bit), rendered as 16 lowercase hex characters.
    /// Chosen over `Hasher` because `Hasher` is seeded per process.
    public static func digest(_ value: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in Array(value.utf8) {
            hash ^= UInt64(byte)
            hash = hash &* 0x100_0000_01b3
        }
        return String(format: "%016lx", hash)
    }
}

/// Identifies the exact place in a document that a piece of knowledge came from.
public struct SourceSpan: Codable, Equatable, Hashable, Sendable {
    public var documentID: String
    public var page: Int
    /// The verbatim sentence (or clause) as it appears in the document.
    public var canonicalSpan: String
    /// Character offset of `canonicalSpan` within the extracted page text,
    /// when the extractor can supply it.
    public var characterOffset: Int?
    public var sourceRole: SourceRole
    /// Version of the text-extraction pipeline that produced the span.
    /// Knowledge extracted by an older pipeline must not be silently mixed
    /// with knowledge from a newer one.
    public var extractionVersion: String

    public init(documentID: String,
                page: Int,
                canonicalSpan: String,
                characterOffset: Int? = nil,
                sourceRole: SourceRole = .unknown,
                extractionVersion: String = SourceSpan.currentExtractionVersion) {
        self.documentID = documentID
        self.page = page
        self.canonicalSpan = canonicalSpan
        self.characterOffset = characterOffset
        self.sourceRole = sourceRole
        self.extractionVersion = extractionVersion
    }

    public static let currentExtractionVersion = "leu.extract.1"

    public var locator: String { "\(documentID)#p\(page)" }
}

/// How a piece of knowledge earned its place in the graph.
///
/// These two cases are never collapsed. A user-facing surface may show
/// "the source says" only for `.sourceSupported`.
public enum Admissibility: String, Codable, CaseIterable, Sendable {
    /// The claim is stated by the source span it carries. Rendering it back to
    /// the learner is a quotation, not an inference.
    case sourceSupported
    /// The claim was derived by composing source-supported facts and then
    /// passed a deterministic validator. It must be attributed to Leu, never
    /// to the document.
    case inferredValidated
}

/// Why an inferred artifact was admitted. Purely mechanical: every rule below
/// composes existing source-supported facts, none of them invent content.
public enum InferenceRule: String, Codable, CaseIterable, Sendable {
    case transitiveEnablement
    case transitiveRequirement
    case causalComposition
    case contrapositiveOfRequirement
    case conditionPropagation
    case sharedSubjectRefinement
    case crossSourceEquivalence
    case none
}

/// The audit trail attached to every atom, relation, chain and rendered line.
public struct Provenance: Codable, Equatable, Hashable, Sendable {
    public var admissibility: Admissibility
    public var spans: [SourceSpan]
    /// Ids of the artifacts (atoms/relations) this one was derived from.
    /// Empty for directly extracted knowledge.
    public var derivedFrom: [StableID]
    public var rule: InferenceRule
    /// Confidence that the *parse* is faithful to the sentence.
    /// This is never confidence that the source is correct: the source stays
    /// authoritative. A low value means "Leu may have misread this sentence",
    /// not "this sentence may be wrong".
    public var confidenceInParsing: Double

    public init(admissibility: Admissibility,
                spans: [SourceSpan],
                derivedFrom: [StableID] = [],
                rule: InferenceRule = .none,
                confidenceInParsing: Double = 1.0) {
        self.admissibility = admissibility
        self.spans = spans
        self.derivedFrom = derivedFrom
        self.rule = rule
        self.confidenceInParsing = min(max(confidenceInParsing, 0), 1)
    }

    public static func stated(_ span: SourceSpan, confidenceInParsing: Double = 1.0) -> Provenance {
        Provenance(admissibility: .sourceSupported,
                   spans: [span],
                   confidenceInParsing: confidenceInParsing)
    }

    public static func inferred(from parents: [Provenance],
                                ids: [StableID],
                                rule: InferenceRule) -> Provenance {
        var spans: [SourceSpan] = []
        for parent in parents {
            for span in parent.spans where !spans.contains(span) {
                spans.append(span)
            }
        }
        let confidence = parents.map(\.confidenceInParsing).min() ?? 1.0
        return Provenance(admissibility: .inferredValidated,
                          spans: spans,
                          derivedFrom: ids,
                          rule: rule,
                          confidenceInParsing: confidence)
    }

    /// Provenance is complete when it can be traced back to at least one real
    /// document span, and every inferred artifact names its parents.
    public var isComplete: Bool {
        guard !spans.isEmpty else { return false }
        if admissibility == .inferredValidated {
            return !derivedFrom.isEmpty && rule != .none
        }
        return true
    }

    /// The one-line attribution Leu shows under any statement it renders.
    public var attribution: String {
        let locators = spans.map(\.locator).reduced()
        switch admissibility {
        case .sourceSupported:
            return "From \(locators)"
        case .inferredValidated:
            return "Leu connected \(locators)"
        }
    }
}

extension Array where Element == String {
    /// Stable, de-duplicated, comma joined rendering used in attributions.
    func reduced() -> String {
        var seen: [String] = []
        for value in self where !seen.contains(value) { seen.append(value) }
        return seen.joined(separator: ", ")
    }
}
