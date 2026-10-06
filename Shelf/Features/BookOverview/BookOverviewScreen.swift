import PDFKit
import ShelfCore
import SwiftUI

/// A book (05): the whole book chapter by chapter, each chapter as wide as it is long and
/// filled as far as you understand it; the sections of the chapter you are in; the line
/// where you left off; your loose ends; and where else the book lives.
@MainActor
struct BookOverviewScreen: View {
    let book: Book
    let library: LibraryModel
    let learning: LearningModel
    let openStudy: () -> Void
    @State private var outline: [OutlineEntry] = []
    @State private var leftOff: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var typeSize

    private var wide: Bool { sizeClass == .regular && !typeSize.isAccessibilitySize }
    private var currentPage: Int { max(book.currentPageNumber - 1, 0) }

    var body: some View {
        ShelfSheet(title: book.title) {
            ScrollView {
                VStack(alignment: .leading, spacing: wide ? 36 : 26) {
                    header
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            eyebrow("The whole book, chapter by chapter")
                            Text("wider is longer · it fills as you understand it")
                                .font(.leu(.caption)).foregroundStyle(LeuDesign.secondary)
                        }
                        ChapterStrip(chapters: chapters, wide: wide) { chapter in open(page: chapter.pages.lowerBound) }
                    }
                    if wide {
                        HStack(alignment: .top, spacing: 48) {
                            sectionList.frame(maxWidth: .infinity, alignment: .topLeading)
                            sideColumn.frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                    } else {
                        sectionList
                        sideColumn
                    }
                }
                .padding(.horizontal, wide ? 40 : 20)
                .padding(.vertical, 24)
                .frame(maxWidth: 1240, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
        .task { await load() }
        .accessibilityIdentifier("book-overview")
    }

    // MARK: Data

    private var objects: [(LearningObject, MasteryState)] {
        learning.snapshot.studyObjects.filter { $0.source.documentID == book.id }.map { object in
            let review = learning.snapshot.reviewStates[object.id] ?? ReviewState(learningObjectID: object.id)
            return (object, learning.scheduler.mastery(for: review, at: Date()))
        }
    }

    private func understanding(_ pages: Range<Int>) -> Double? {
        let here = objects.filter { pages.contains($0.0.source.pageIndex) }
        guard !here.isEmpty else { return nil }
        return Double(here.filter { $0.1 == .strengthening || $0.1 == .durable }.count) / Double(here.count)
    }

    private var chapters: [ChapterSpan] {
        BookOverviewModel.chapters(outline: outline, pageCount: book.pageCount, currentPage: currentPage, understanding: understanding)
    }

    private var looseEnds: [LearningObject] {
        objects.filter { $0.1 == .fading || $0.1 == .due }.map { $0.0 }
    }

    private func load() async {
        let url = library.vault.originalURL(for: book.id)
        guard let loaded = try? await PDFDocumentLoader().load(url: url) else { return }
        outline = loaded.outline
        let text = loaded.document.page(at: currentPage)?.string?
            .split(whereSeparator: \.isNewline).joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        leftOff = text.isEmpty ? nil : String(text.prefix(220))
    }

    /// The reader is a full-screen cover; it opens once this sheet has finished closing.
    private func open(page: Int) {
        dismiss()
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            library.open(book, page: page)
        }
    }

    // MARK: Pieces

    private var header: some View {
        let whole = understanding(0..<max(book.pageCount, 1))
        let added = book.importedAt.formatted(.dateTime.day().month(.wide))
        let understood = whole.map { "You understand \(BookOverviewModel.fractionWords($0)) of it so far." }
            ?? "Leu hasn't asked you about it yet."
        let summary = "\(book.pageCount) pages, added \(added). \(understood)"
        let count = min(objects.count, 3)
        let ask = count == 1 ? "Ask me 1 question" : "Ask me \(count) questions"
        let buttons = Group {
            Button(book.lastOpenedAt == nil ? "Start reading" : "Continue on p. \(book.currentPageNumber)") { open(page: currentPage) }
                .buttonStyle(LeuPrimaryButtonStyle(filled: true, pill: true))
                .accessibilityIdentifier("overview-continue")
            if !objects.isEmpty {
                Button(ask) {
                    learning.startActiveRecall(documentID: book.id)
                    dismiss()
                    openStudy()
                }
                .buttonStyle(LeuPrimaryButtonStyle(filled: false, pill: true))
                .accessibilityIdentifier("overview-ask-me")
            }
        }
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .bottom, spacing: 24) {
                titleBlock(summary).frame(maxWidth: 640, alignment: .leading)
                Spacer(minLength: 12)
                HStack(spacing: 10) { buttons }
            }
            VStack(alignment: .leading, spacing: 18) {
                titleBlock(summary)
                VStack(alignment: .leading, spacing: 10) { buttons }
            }
        }
    }

    private func titleBlock(_ summary: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(shelfName.map { "Library / \($0)" } ?? "Library")
                .font(.leu(.footnote, weight: .semibold)).foregroundStyle(LeuDesign.secondary)
            Text(book.title)
                .font(LeuDesign.display(wide ? 60 : 38)).tracking(wide ? -2 : -1.2)
                .foregroundStyle(LeuDesign.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(summary)
                .font(.leu(.body, weight: .medium)).foregroundStyle(LeuDesign.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var shelfName: String? {
        library.collections.first { book.collectionIDs.contains($0.id) }?.name
    }

    private var sectionList: some View {
        let chapter = chapters.first(where: \.isCurrent) ?? chapters.first
        let pages = Set(looseEnds.map(\.source.pageIndex))
        let sections = chapter.map { BookOverviewModel.sections(outline: outline, chapter: $0, currentPage: currentPage, looseEndPages: pages) } ?? []
        return VStack(alignment: .leading, spacing: 0) {
            if let chapter {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(chapter.number) · \(chapter.title)")
                        .font(.leu(.title3, weight: .heavy)).foregroundStyle(LeuDesign.ink)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 8)
                    Text("pp. \(chapter.pages.lowerBound + 1)–\(chapter.pages.upperBound)")
                        .font(.leu(.caption, weight: .medium)).foregroundStyle(LeuDesign.secondary)
                }
                .padding(.bottom, 12)
            }
            if sections.isEmpty {
                Text("This chapter has no smaller sections in its outline.")
                    .font(.leu(.footnote)).foregroundStyle(LeuDesign.secondary)
            }
            ForEach(sections) { section in
                Button { open(page: section.page - 1) } label: {
                    HStack(spacing: 16) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(section.read ? LeuDesign.butter : LeuDesign.oat)
                            .frame(width: 42, height: 32)
                            .overlay {
                                if section.looseEnd {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(LeuDesign.redThread, lineWidth: 2)
                                }
                            }
                        Text(section.title).font(.leu(.subheadline, weight: .semibold)).foregroundStyle(LeuDesign.ink)
                            + Text(section.looseEnd ? " · a loose end" : "").font(.leu(.caption, weight: .semibold)).foregroundStyle(LeuDesign.redThreadText)
                        Spacer(minLength: 8)
                        Text("p. \(section.page)").font(.leu(.caption, weight: .medium)).foregroundStyle(LeuDesign.secondary)
                    }
                    .padding(.vertical, 10)
                    .frame(minHeight: 56)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(section.title), page \(section.page)\(section.read ? ", read" : "")\(section.looseEnd ? ", a loose end" : "")")
                StitchDivider()
            }
        }
    }

    private var sideColumn: some View {
        VStack(alignment: .leading, spacing: 26) {
            if let leftOff, book.lastOpenedAt != nil {
                VStack(alignment: .leading, spacing: 12) {
                    eyebrow("Where you left off")
                    VStack(alignment: .leading, spacing: 12) {
                        Text("“…\(leftOff)…”").font(.leu(.title3, serif: true)).foregroundStyle(LeuDesign.readingForeground)
                            .lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                        Text("p. \(book.currentPageNumber)").font(.leu(.caption, weight: .semibold)).foregroundStyle(LeuDesign.readingSecondary)
                    }
                    .padding(22)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(LeuDesign.readingSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: LeuDesign.ink.opacity(0.12), radius: 14, x: 0, y: 8)
                }
            }
            HStack(alignment: .top, spacing: 28) {
                list("Loose ends · \(looseEnds.count)", items: looseEnds.prefix(4).map(\.title),
                     empty: "Nothing fading from this book.")
                list("Also lives in", items: alsoLivesIn, empty: "Only in your library so far.")
            }
        }
    }

    private var alsoLivesIn: [String] {
        let shelves = library.collections.filter { book.collectionIDs.contains($0.id) }.map { "Shelf: \($0.name)" }
        let trails = learning.snapshot.trails.filter { trail in
            trail.nodes.contains { TrailNavigation.source(for: $0, snapshot: learning.snapshot)?.documentID == book.id }
        }.map { "Trail: \($0.title)" }
        return Array((trails + shelves).prefix(4))
    }

    private func list(_ title: String, items: [String], empty: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            eyebrow(title)
            if items.isEmpty {
                Text(empty).font(.leu(.footnote)).foregroundStyle(LeuDesign.secondary)
            }
            ForEach(items, id: \.self) { item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Circle().fill(LeuDesign.redThread).frame(width: 7, height: 7).accessibilityHidden(true)
                    Text(item).font(.leu(.subheadline, weight: .semibold)).foregroundStyle(LeuDesign.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func eyebrow(_ text: String) -> some View {
        Text(text.uppercased())
            .font(LeuDesign.eyebrow(10)).tracking(LeuDesign.eyebrowTracking)
            .foregroundStyle(LeuDesign.eyebrowOnFelt)
            .accessibilityAddTraits(.isHeader)
    }
}
