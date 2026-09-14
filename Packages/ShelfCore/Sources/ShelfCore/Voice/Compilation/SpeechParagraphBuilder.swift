import Foundation

public struct SpokenSentence: Equatable, Sendable {
    public let segment: SpeechSegment
    public let spokenRange: SourceTextRange
    public let queueIndex: Int
}

public struct SpokenParagraph: Equatable, Sendable {
    public let sentences: [SpokenSentence]
    public let spokenText: String

    public func sentence(atUTF16 range: NSRange) -> SpokenSentence? {
        guard range.location != NSNotFound, range.length > 0 else { return nil }
        return sentences.first {
            NSIntersectionRange(range, NSRange(location: $0.spokenRange.location, length: $0.spokenRange.length)).length > 0
        }
    }
}

public struct SpeechParagraphBuilder: Sendable {
    public init() {}

    public func paragraph(from segments: [SpeechSegment], startingAt start: Int, mergeProse: Bool = true) -> SpokenParagraph? {
        guard segments.indices.contains(start) else { return nil }
        let first = segments[start]
        var sentences: [SpokenSentence] = [], spoken = ""
        for index in start..<segments.count {
            let segment = segments[index]
            if index != start {
                guard mergeProse, first.kind == .prose, segment.kind == .prose,
                      let block = first.blockID, segment.blockID == block,
                      first.source.documentID == segment.source.documentID,
                      first.source.pageIndex == segment.source.pageIndex,
                      (spoken as NSString).length + (segment.spokenText as NSString).length < 2_400 else { break }
            }
            if !spoken.isEmpty { spoken += " " }
            let range = SourceTextRange(location: (spoken as NSString).length, length: (segment.spokenText as NSString).length)
            spoken += segment.spokenText
            sentences.append(SpokenSentence(segment: segment, spokenRange: range, queueIndex: index))
        }
        return SpokenParagraph(sentences: sentences, spokenText: spoken)
    }
}
