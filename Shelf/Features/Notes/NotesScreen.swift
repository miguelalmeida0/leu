import ShelfCore
import SwiftUI

/// Notes (11b): everything you have kept, as an open notebook. This week on the left page,
/// earlier on the right, a red ribbon down the spine, and a tab for each book. Each note
/// opens its book at the exact page, where it can be changed or removed.
///
/// iPad landscape mirrors the reference spread. iPhone, portrait and large text sizes use
/// one page with both sections, and the book tabs become a row of chips.
@MainActor
struct NotesScreen: View {
    let library: LibraryModel
    let knowledge: KnowledgeModel
    @State private var bookID: UUID?
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var typeSize

    private var all: [NotebookEntry] { NotebookModel.entries(annotations: library.snapshot.annotations, books: library.snapshot.activeBooks) }
    private var shown: [NotebookEntry] { NotebookModel.entries(annotations: library.snapshot.annotations, books: library.snapshot.activeBooks, bookID: bookID) }
    private var spread: Bool { sizeClass == .regular && !typeSize.isAccessibilitySize }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("YOUR NOTEBOOK")
                        .font(LeuDesign.eyebrow(11)).tracking(LeuDesign.eyebrowTracking)
                        .foregroundStyle(LeuDesign.eyebrowOnFelt)
                    Text(NotebookModel.headline(count: all.count))
                        .font(LeuDesign.display(spread ? 38 : 30)).tracking(-1)
                        .foregroundStyle(LeuDesign.ink)
                        .accessibilityAddTraits(.isHeader)
                }
                if all.isEmpty {
                    Text("Long-press a paragraph while you read to keep a thought. It lands here, tied to its page.")
                        .font(.leu(.body)).foregroundStyle(LeuDesign.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else if spread {
                    HStack(alignment: .top, spacing: 0) {
                        notebook
                        tabs(vertical: true).padding(.top, 30)
                    }
                } else {
                    tabs(vertical: false)
                    notebook
                }
            }
            .padding(.horizontal, spread ? 40 : 20)
            .padding(.vertical, 24)
            .frame(maxWidth: 1240)
            .frame(maxWidth: .infinity)
        }
        .background(LeuDesign.void)
        .accessibilityIdentifier("notes-screen")
    }

    // MARK: The notebook

    private var notebook: some View {
        let pages = NotebookModel.split(shown)
        return Group {
            if spread {
                HStack(alignment: .top, spacing: 0) {
                    page("This week", entries: pages.thisWeek, margin: true)
                    Rectangle().fill(LeuDesign.redThread).frame(width: 18)
                        .overlay(alignment: .bottom) { Ribbon().fill(LeuDesign.redThread).frame(width: 18, height: 26).offset(y: 30) }
                        .accessibilityHidden(true)
                    page("Earlier", entries: pages.earlier, margin: false)
                }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    page("This week", entries: pages.thisWeek, margin: true)
                    page("Earlier", entries: pages.earlier, margin: true)
                }
            }
        }
        .background(LeuDesign.cream)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(spread ? 14 : 8)
        .background(LeuDesign.tomato, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: LeuDesign.ink.opacity(0.18), radius: 22, x: 0, y: 14)
    }

    private func page(_ title: String, entries: [NotebookEntry], margin: Bool) -> some View {
        VStack(alignment: .leading, spacing: 26) {
            Text(title)
                .font(.leu(.title3, serif: true).italic())
                .foregroundStyle(LeuDesign.eyebrowOnPaper)
                .accessibilityAddTraits(.isHeader)
            if entries.isEmpty {
                Text(title == "This week" ? "Nothing new this week." : "Nothing from before this week.")
                    .font(.leu(.body, serif: true).italic())
                    .foregroundStyle(LeuDesign.readingSecondary)
            }
            ForEach(entries) { entry in note(entry) }
        }
        .padding(.leading, margin ? 52 : 28)
        .padding(.trailing, 28)
        .padding(.vertical, 30)
        .frame(maxWidth: .infinity, minHeight: spread ? 560 : 0, alignment: .topLeading)
        .background { RuledPaper(margin: margin) }
    }

    private func note(_ entry: NotebookEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.text)
                .font(.leu(.title3, serif: true))
                .italic(entry.isQuote)
                .foregroundStyle(LeuDesign.readingForeground)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
            Button { knowledge.queueNavigation(to: entry.annotation) } label: {
                HStack(spacing: 7) {
                    RoundedRectangle(cornerRadius: 2).fill(dye(entry.annotation.bookID)).frame(width: 9, height: 9)
                    Text(entry.place).font(.leu(.caption, weight: .semibold))
                    Image(systemName: "arrow.up.right").font(.leu(.caption2, weight: .bold))
                }
                .foregroundStyle(LeuDesign.readingForeground)
                .frame(minHeight: LeuDesign.touchTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open \(entry.place)")
            .accessibilityHint("Opens the book at this page, where you can change or remove the note")
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: Book tabs

    private func tabs(vertical: Bool) -> some View {
        let books = NotebookModel.books(in: all, from: library.snapshot.activeBooks)
        let content = Group {
            tab("All notes", fill: LeuDesign.ink, text: LeuDesign.cream, selected: bookID == nil) { bookID = nil }
            ForEach(books) { book in
                let colors = CoverColors(book.palette)
                tab(book.title, fill: colors.background, text: colors.foreground, selected: bookID == book.id) { bookID = book.id }
            }
        }
        return Group {
            if vertical {
                VStack(alignment: .leading, spacing: 10) { content }.frame(width: 170)
            } else {
                ScrollView(.horizontal) { HStack(spacing: 8) { content } }.scrollIndicators(.hidden)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Books")
    }

    private func tab(_ title: String, fill: Color, text: Color, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.leu(.footnote, weight: .bold))
                .foregroundStyle(text)
                .lineLimit(1)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                .background(fill, in: UnevenRoundedRectangle(topLeadingRadius: 2, bottomLeadingRadius: 2,
                                                             bottomTrailingRadius: 14, topTrailingRadius: 14, style: .continuous))
                .overlay {
                    if selected {
                        UnevenRoundedRectangle(topLeadingRadius: 2, bottomLeadingRadius: 2, bottomTrailingRadius: 14,
                                               topTrailingRadius: 14, style: .continuous)
                            .stroke(LeuDesign.ink, lineWidth: 2)
                    }
                }
                .offset(x: selected ? 8 : 0)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.35), value: selected)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func dye(_ bookID: UUID) -> Color {
        library.snapshot.activeBooks.first { $0.id == bookID }.map { CoverColors($0.palette).background } ?? LeuDesign.oat
    }
}

/// Faint ruled lines and, on the left page, the red margin line of a school notebook.
private struct RuledPaper: View {
    let margin: Bool

    var body: some View {
        Canvas { context, size in
            var y: CGFloat = 76
            while y < size.height {
                context.stroke(Path { $0.move(to: CGPoint(x: 0, y: y)); $0.addLine(to: CGPoint(x: size.width, y: y)) },
                               with: .color(LeuDesign.denim.opacity(0.16)), lineWidth: 1)
                y += 34
            }
            if margin {
                context.stroke(Path { $0.move(to: CGPoint(x: 38, y: 0)); $0.addLine(to: CGPoint(x: 38, y: size.height)) },
                               with: .color(LeuDesign.tomato.opacity(0.45)), lineWidth: 1)
            }
        }
        .accessibilityHidden(true)
    }
}

/// The tail of a ribbon bookmark, cut in a V.
private struct Ribbon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - 9))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
