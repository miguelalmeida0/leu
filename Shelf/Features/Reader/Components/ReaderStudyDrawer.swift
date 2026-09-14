import SwiftUI
import ShelfCore

@MainActor
struct ReaderStudyDrawer: View {
    @Bindable var model: ReaderModel
    @State private var filter: AnnotationKind?

    private var marks: [StudyAnnotation] {
        model.annotations.filter { $0.kind.isStudyMarker && (filter == nil || $0.kind == filter) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            filters
            Divider().overlay(ShelfTheme.line)
            content
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(ShelfTheme.background)
        .overlay(alignment: .leading) { Rectangle().fill(ShelfTheme.line).frame(width: 1) }
        .accessibilityIdentifier("study-drawer")
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Your Marks")
                    .leuScaledFont(28, weight: .regular, design: .serif)
                Text("Highlights, notes and passages worth returning to.")
                    .font(.caption)
                    .foregroundStyle(ShelfTheme.secondary)
            }
            Spacer()
            IconButton(symbol: "xmark", label: "Close marks") {
                model.showStudyDrawer = false
            }
        }
        .padding(20)
    }

    private var filters: some View {
        HStack(spacing: 8) {
            chip("All", nil)
            chip("Important", .important)
            chip("Review", .review)
            chip("Confusing", .confusing)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var content: some View {
        if marks.isEmpty {
            EmptyLibraryState(
                symbol: "highlighter",
                title: "Nothing marked yet.",
                message: "In Original mode, select text and mark the passage. In Read mode, marks save the current page."
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(marks) { mark in
                        markCard(mark)
                        Divider().overlay(ShelfTheme.line)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func markCard(_ mark: StudyAnnotation) -> some View {
        ZStack(alignment: .topTrailing) {
            Button {
                model.openStudyMark(mark)
                model.showStudyDrawer = false
            } label: {
                VStack(alignment: .leading, spacing: 9) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(mark.kind.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(accent(for: mark.kind))
                        Spacer()
                        Text("p. \(mark.pageIndex + 1)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(ShelfTheme.secondary)
                            .padding(.trailing, 34)
                    }

                    if let section = model.sectionTitle(for: mark.pageIndex) {
                        Text(section)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(ShelfTheme.secondary)
                            .lineLimit(2)
                    }

                    Text(mark.quote.isEmpty ? "Page \(mark.pageIndex + 1) saved" : mark.quote)
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(mark.quote.isEmpty ? ShelfTheme.secondary : ShelfTheme.text)
                        .lineLimit(mark.quote.isEmpty ? 2 : 6)

                    if !mark.note.isEmpty {
                        Text(mark.note)
                            .font(.callout)
                            .foregroundStyle(ShelfTheme.secondary)
                            .lineLimit(4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 15)
                .padding(.trailing, 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(mark.kind.title), page \(mark.pageIndex + 1), \(mark.quote.isEmpty ? "saved page" : mark.quote)")

            markMenu(mark)
                .padding(.top, 3)
                .padding(.trailing, 3)
        }
    }

    private func markMenu(_ mark: StudyAnnotation) -> some View {
        LeuMenu {
            Button("Go to mark", systemImage: "arrow.right") {
                model.openStudyMark(mark)
                model.showStudyDrawer = false
            }
            Button("Delete mark", systemImage: "trash", role: .destructive) {
                Task { await model.deleteAnnotation(mark) }
            }
        } label: {
            Image(systemName: "ellipsis")
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Actions for mark on page \(mark.pageIndex + 1)")
    }

    private func chip(_ title: String, _ kind: AnnotationKind?) -> some View {
        Button { filter = kind } label: {
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(filter == kind ? ShelfTheme.background : ShelfTheme.secondary)
                .background(filter == kind ? accent(for: kind) : ShelfTheme.surface, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(filter == kind ? .isSelected : [])
    }

    private func background(for kind: AnnotationKind) -> Color {
        switch kind {
        case .important: return ShelfTheme.importantBackground
        case .review: return ShelfTheme.reviewBackground
        case .confusing: return ShelfTheme.confusingBackground
        default: return ShelfTheme.surface
        }
    }

    private func accent(for kind: AnnotationKind?) -> Color {
        switch kind {
        case .important: return ShelfTheme.importantAccent
        case .review: return ShelfTheme.reviewAccent
        case .confusing: return ShelfTheme.confusingAccent
        default: return ShelfTheme.accent
        }
    }
}
