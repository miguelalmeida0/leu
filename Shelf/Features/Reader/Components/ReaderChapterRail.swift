import ShelfCore
import SwiftUI

/// The left rail beside the page on wide iPad: the chapter you are in, its sections as
/// small felt swatches (warm once read), and the marks you have left in this chapter.
@MainActor
struct ReaderChapterRail: View {
    @Bindable var model: ReaderModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.book.title)
                    .font(.leu(.footnote, weight: .semibold))
                    .foregroundStyle(LeuDesign.secondary)
                    .lineLimit(2)
                if let chapter {
                    Text(chapter.title)
                        .font(.leu(.title3, weight: .heavy))
                        .foregroundStyle(LeuDesign.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 6)
                        .padding(.bottom, 12)
                        .accessibilityAddTraits(.isHeader)
                }
                ForEach(sections) { entry in row(entry) }
                if sections.isEmpty && model.isDetectingOutline {
                    Text("Finding the chapters…")
                        .font(.leu(.footnote))
                        .foregroundStyle(LeuDesign.tertiary)
                }
                marks.padding(.top, 22)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 22)
        }
        .scrollIndicators(.hidden)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Chapter")
        .accessibilityIdentifier("reader-chapter-rail")
    }

    private var structural: [OutlineEntry] { model.outline.filter { $0.source != .landmark } }

    /// The top-level entry the current page sits under.
    private var chapter: OutlineEntry? {
        let top = structural.filter { $0.depth == 0 }
        return (top.isEmpty ? structural : top).last { $0.pageIndex <= model.pageIndex }
    }

    /// The entries inside the current chapter, or a window around the page without chapters.
    private var sections: [OutlineEntry] {
        guard let chapter else { return Array(structural.prefix(12)) }
        let nextTop = structural.first { $0.depth <= chapter.depth && $0.pageIndex > chapter.pageIndex && $0.id != chapter.id }
        let inside = structural.filter { entry in
            entry.depth > chapter.depth && entry.pageIndex >= chapter.pageIndex && entry.pageIndex < (nextTop?.pageIndex ?? .max)
        }
        return Array((inside.isEmpty ? [chapter] : inside).prefix(16))
    }

    private var currentSectionID: String? { sections.last { $0.pageIndex <= model.pageIndex }?.id }

    private func row(_ entry: OutlineEntry) -> some View {
        let current = entry.id == currentSectionID
        let read = entry.pageIndex < model.pageIndex || current
        return Button { model.go(to: entry.pageIndex) } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(read ? LeuDesign.butter : LeuDesign.oat)
                    .frame(width: 26, height: 18)
                    .overlay {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .strokeBorder(LeuDesign.ink.opacity(0.25), style: StrokeStyle(lineWidth: 0.75, dash: [2.5, 2]))
                            .padding(2.5)
                    }
                Text(entry.title)
                    .font(.leu(.subheadline, weight: current ? .bold : .semibold))
                    .foregroundStyle(LeuDesign.ink)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(minHeight: LeuDesign.touchTarget)
            .background(current ? LeuDesign.feltLight : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(entry.title), page \(entry.pageIndex + 1)\(read && !current ? ", read" : "")")
        .accessibilityAddTraits(current ? .isSelected : [])
    }

    private var marks: some View {
        let range = chapterRange
        let here = model.annotations.filter { range.contains($0.pageIndex) }
        let notes = here.filter { !$0.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
        let highlights = here.count - notes
        return VStack(alignment: .leading, spacing: 8) {
            StitchDivider()
            Text("YOUR MARKS HERE")
                .font(LeuDesign.eyebrow(10))
                .tracking(LeuDesign.eyebrowTracking)
                .foregroundStyle(LeuDesign.eyebrowOnFelt)
                .accessibilityAddTraits(.isHeader)
            Text(here.isEmpty ? "Nothing marked in this chapter yet." : Self.marksSummary(highlights: highlights, notes: notes))
                .font(.leu(.footnote))
                .foregroundStyle(LeuDesign.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var chapterRange: Range<Int> {
        guard let chapter else { return 0..<max(model.book.pageCount, 1) }
        let next = structural.first { $0.depth <= chapter.depth && $0.pageIndex > chapter.pageIndex }
        return chapter.pageIndex..<(next?.pageIndex ?? max(model.book.pageCount, chapter.pageIndex + 1))
    }

    static func marksSummary(highlights: Int, notes: Int) -> String {
        var parts: [String] = []
        if highlights > 0 { parts.append(highlights == 1 ? "1 highlight" : "\(highlights) highlights") }
        if notes > 0 { parts.append(notes == 1 ? "1 note" : "\(notes) notes") }
        return parts.joined(separator: " · ")
    }
}
