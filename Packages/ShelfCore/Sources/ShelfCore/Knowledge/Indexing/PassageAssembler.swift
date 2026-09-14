import Foundation

public struct PassageAssembly: Sendable {
    public var passages: [KnowledgePassage]
    public var sections: [KnowledgeSection]
    public var chapters: [KnowledgeChapter]
    public init(passages: [KnowledgePassage], sections: [KnowledgeSection], chapters: [KnowledgeChapter]) {
        self.passages = passages; self.sections = sections; self.chapters = chapters
    }
}

public struct PassageAssembler: Sendable {
    public static let segmentationVersion = 1
    public init() {}

    public func assemble(_ analysis: DocumentAnalysis) -> PassageAssembly {
        let ordered = analysis.pages.sorted { $0.pageIndex < $1.pageIndex }
        let flatSegments = ordered.flatMap { $0.segments }.filter { segment in
            segment.kind != .heading && segment.text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 18
        }
        let sections = buildSections(analysis)
        let chapters = sections.enumerated().map { offset, section in
            KnowledgeChapter(id: StableIdentity.uuid("knowledge-chapter|\(analysis.documentID)|\(section.title.lowercased())|\(section.startPageIndex)"),
                             documentID: analysis.documentID, title: section.title,
                             startPageIndex: section.startPageIndex, endPageIndex: section.endPageIndex, order: offset)
        }
        var passages: [KnowledgePassage] = []
        for (index, segment) in flatSegments.enumerated() {
            let clean = cleanPassage(segment.text)
            guard clean.count >= 18 else { continue }
            let fingerprint = hex(StableIdentity.hash64(canonical(clean)))
            let previous = index > 0 ? hex(StableIdentity.hash64(canonical(flatSegments[index - 1].text))) : nil
            let next = index + 1 < flatSegments.count ? hex(StableIdentity.hash64(canonical(flatSegments[index + 1].text))) : nil
            let section = sections.last { $0.startPageIndex <= segment.pageIndex }
            let chapter = chapters.last { $0.startPageIndex <= segment.pageIndex }
            let range = sourceRange(for: clean, in: ordered.first(where: { $0.pageIndex == segment.pageIndex })?.normalizedText)
            let identity = "knowledge-passage|\(analysis.documentID)|\(fingerprint)|\(previous ?? "")|\(next ?? "")"
            passages.append(KnowledgePassage(id: StableIdentity.uuid(identity), documentID: analysis.documentID,
                pageIndex: segment.pageIndex, chapterID: chapter?.id, sectionID: section?.id,
                sectionTitle: segment.sectionTitle ?? section?.title, text: clean, normalizedText: canonical(clean),
                sourceRange: range, precedingContextFingerprint: previous, followingContextFingerprint: next,
                contentFingerprint: fingerprint, indexVersion: Self.segmentationVersion))
        }
        return PassageAssembly(passages: passages, sections: sections, chapters: chapters)
    }

    private func buildSections(_ analysis: DocumentAnalysis) -> [KnowledgeSection] {
        let headings = analysis.pages.flatMap { $0.segments }.filter { $0.kind == .heading }
        guard !headings.isEmpty else {
            let last = max(0, (analysis.pages.map(\.pageIndex).max() ?? 0))
            return [KnowledgeSection(id: StableIdentity.uuid("knowledge-section|\(analysis.documentID)|document"),
                                     documentID: analysis.documentID, title: "Document", startPageIndex: 0,
                                     endPageIndex: last, order: 0)]
        }
        return headings.enumerated().map { index, heading in
            let end = index + 1 < headings.count ? max(heading.pageIndex, headings[index + 1].pageIndex - 1) : (analysis.pages.map(\.pageIndex).max() ?? heading.pageIndex)
            return KnowledgeSection(id: StableIdentity.uuid("knowledge-section|\(analysis.documentID)|\(heading.text.lowercased())|\(heading.pageIndex)"),
                                    documentID: analysis.documentID, title: heading.text,
                                    startPageIndex: heading.pageIndex, endPageIndex: end, order: index)
        }
    }

    private func sourceRange(for text: String, in pageText: String?) -> SourceTextRange? {
        guard let pageText else { return nil }
        let range = (pageText as NSString).range(of: text, options: [.caseInsensitive, .diacriticInsensitive])
        return range.location == NSNotFound ? nil : SourceTextRange(location: range.location, length: range.length)
    }

    private func cleanPassage(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func canonical(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline }).joined(separator: " ")
    }

    private func hex(_ value: UInt64) -> String { String(format: "%016llx", value) }
}
