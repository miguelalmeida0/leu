import Foundation

public struct SpeechCompiler: Sendable {
    private let cleaner = PDFTextCleaner()
    private let technical = TechnicalSpeechNormalizer()
    private let code = CodeSpeechNormalizer()
    private let prosody = SpeechProsodyPlanner()

    public init() {}

    public func compile(document: SpeechDocument, dictionary: PronunciationDictionary = PronunciationDictionary(),
                        rate: SpeechRateProfile = SpeechRateProfile(), codeMode: CodeSpeechMode = .natural) -> SpeechPlan {
        var segments: [SpeechSegment] = []
        var normalization = SpeechNormalizationCache()
        for block in document.blocks {
            let sourceParts = split(block)
            for part in sourceParts {
                let spoken = normalization.value(for: part.text, isCode: block.kind == .code) {
                    let cleaned = cleaner.clean(part.text)
                    guard cleaned.count > 1 else { return "" }
                    if block.kind == .code { return code.normalize(cleaned, mode: codeMode, dictionary: dictionary) }
                    return technical.normalize(cleaned, dictionary: dictionary)
                }
                guard !spoken.isEmpty else { continue }
                let mappedRange = offset(block.sourceRange, by: part.range.location, length: part.range.length)
                let mapping = SpeechSourceMapping(documentID: block.documentID ?? document.documentID,
                                                  pageIndex: block.pageIndex, sourceRange: mappedRange,
                                                  sourceText: part.text.trimmingCharacters(in: .whitespacesAndNewlines))
                let identity = "speech|\(mapping.documentID?.uuidString ?? "none")|\(mapping.pageIndex)|\(mappedRange?.location ?? 0)|\(mapping.sourceText)"
                segments.append(SpeechSegment(id: StableIdentity.uuid(identity), source: mapping,
                                              spokenText: spoken, kind: block.kind,
                                              prosody: prosody.prosody(for: block.kind, profile: rate), blockID: block.id,
                                              blockRange: SourceTextRange(location: part.range.location, length: part.range.length)))
            }
        }
        return SpeechPlan(segments: segments)
    }

    private struct SourcePart { var text: String; var range: NSRange }

    private func split(_ block: SpeechInputBlock) -> [SourcePart] {
        if [.code, .heading, .formula, .table, .caption, .metadata].contains(block.kind) {
            return [SourcePart(text: block.text, range: NSRange(location: 0, length: (block.text as NSString).length))]
        }
        let ns = block.text as NSString
        var parts: [SourcePart] = []
        var start = 0
        var index = 0
        while index < ns.length {
            let scalar = ns.character(at: index)
            let isStop = scalar == 46 || scalar == 33 || scalar == 63 // . ! ?
            if isStop {
                let next = index + 1
                let nextIsBoundary = next >= ns.length || CharacterSet.whitespacesAndNewlines.contains(UnicodeScalar(ns.character(at: next))!)
                if scalar != 46 || nextIsBoundary {
                    let range = NSRange(location: start, length: index - start + 1)
                    let text = ns.substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
                    if text.count > 1 { parts.append(SourcePart(text: text, range: range)) }
                    start = next
                }
            }
            index += 1
        }
        if start < ns.length {
            let range = NSRange(location: start, length: ns.length - start)
            let text = ns.substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
            if text.count > 1 { parts.append(SourcePart(text: text, range: range)) }
        }
        return parts.isEmpty ? [SourcePart(text: block.text, range: NSRange(location: 0, length: ns.length))] : parts.map { part in
            let local = (ns.substring(with: part.range) as NSString).range(of: part.text)
            guard local.location != NSNotFound else { return part }
            return SourcePart(text: part.text, range: NSRange(location: part.range.location + local.location, length: local.length))
        }
    }

    private func offset(_ parent: SourceTextRange?, by localOffset: Int, length: Int) -> SourceTextRange? {
        guard let parent else { return nil }
        return SourceTextRange(location: parent.location + max(0, localOffset), length: max(0, length))
    }
}
