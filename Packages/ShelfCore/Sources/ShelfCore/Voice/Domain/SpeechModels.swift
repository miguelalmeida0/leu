import Foundation

public enum SpeechBlockKind: String, Codable, CaseIterable, Sendable {
    case prose, heading, code, list, quote, table, formula, caption, metadata
}

public struct SpeechProsody: Codable, Equatable, Sendable {
    public var rateMultiplier: Double
    public var pitchMultiplier: Double
    public var prePause: Double
    public var postPause: Double

    public init(rateMultiplier: Double = 1, pitchMultiplier: Double = 1,
                prePause: Double = 0, postPause: Double = 0) {
        self.rateMultiplier = rateMultiplier; self.pitchMultiplier = pitchMultiplier
        self.prePause = prePause; self.postPause = postPause
    }
}

public struct SpeechInputBlock: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var documentID: UUID?
    public var pageIndex: Int
    public var kind: SpeechBlockKind
    public var text: String
    public var sourceRange: SourceTextRange?

    public init(id: UUID = UUID(), documentID: UUID? = nil, pageIndex: Int,
                kind: SpeechBlockKind, text: String, sourceRange: SourceTextRange? = nil) {
        self.id = id; self.documentID = documentID; self.pageIndex = max(0, pageIndex)
        self.kind = kind; self.text = text; self.sourceRange = sourceRange
    }
}

public struct SpeechSourceMapping: Codable, Equatable, Sendable {
    public var documentID: UUID?
    public var pageIndex: Int
    public var sourceRange: SourceTextRange?
    public var sourceText: String

    public init(documentID: UUID?, pageIndex: Int, sourceRange: SourceTextRange?, sourceText: String) {
        self.documentID = documentID; self.pageIndex = pageIndex
        self.sourceRange = sourceRange; self.sourceText = sourceText
    }
}

public struct SpeechSegment: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var source: SpeechSourceMapping
    public var spokenText: String
    public var kind: SpeechBlockKind
    public var prosody: SpeechProsody
    public var blockID: UUID?
    public var blockRange: SourceTextRange?

    public init(id: UUID = UUID(), source: SpeechSourceMapping, spokenText: String,
                kind: SpeechBlockKind, prosody: SpeechProsody, blockID: UUID? = nil, blockRange: SourceTextRange? = nil) {
        self.id = id; self.source = source; self.spokenText = spokenText
        self.kind = kind; self.prosody = prosody
        self.blockID = blockID; self.blockRange = blockRange
    }
}

public struct SpeechPlan: Codable, Equatable, Sendable {
    public var segments: [SpeechSegment]
    public var createdAt: Date
    public init(segments: [SpeechSegment], createdAt: Date = Date()) {
        self.segments = segments; self.createdAt = createdAt
    }
}

public struct SpeechDocument: Codable, Equatable, Sendable {
    public var documentID: UUID?
    public var blocks: [SpeechInputBlock]
    public init(documentID: UUID? = nil, blocks: [SpeechInputBlock]) {
        self.documentID = documentID; self.blocks = blocks
    }
}

public struct SpeechToken: Codable, Equatable, Sendable {
    public var source: String
    public var spoken: String
    public init(source: String, spoken: String) { self.source = source; self.spoken = spoken }
}
