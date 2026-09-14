import SwiftUI

@MainActor
struct SemanticZoomSurface: View {
    @Bindable var model: ReaderModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text(model.semanticLevel.title)
                        .font(.caption.weight(.bold))
                        .tracking(2)
                        .foregroundStyle(ShelfTheme.accent)
                    Spacer()
                    Button("Back to page") { model.semanticLevel = .page }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ShelfTheme.accent)
                }

                Text(title)
                    .leuScaledFont(34, weight: .semibold, design: .serif)
                    .foregroundStyle(ShelfTheme.text)

                content
            }
            .padding(24)
            .padding(.bottom, 120)
        }
        .background(ShelfTheme.background)
    }

    private var title: String {
        switch model.semanticLevel {
        case .sentence: return "The idea under your finger"
        case .page: return "Page \(model.pageNumber)"
        case .section: return model.currentOutlineTitle ?? "Current section"
        case .chapter: return "Nearby structure"
        case .book: return model.book.title
        }
    }

    @ViewBuilder private var content: some View {
        switch model.semanticLevel {
        case .sentence:
            Text(model.readingAnchor?.sentence ?? model.readablePage.blocks.first?.text ?? "No sentence is available on this page.")
                .font(.system(size: 25, design: .serif))
                .lineSpacing(8)
                .foregroundStyle(ShelfTheme.text)
        case .page:
            EmptyView()
        case .section:
            ForEach(Array(model.readablePage.blocks.prefix(6))) { block in
                Text(block.text)
                    .font(block.kind == .heading ? ShelfTheme.editorial(22, weight: .semibold) : .body)
                    .foregroundStyle(block.kind == .heading ? ShelfTheme.accent : ShelfTheme.secondary)
            }
        case .chapter, .book:
            let entries = model.semanticOutlineEntries
            if entries.isEmpty {
                Text("This PDF does not expose a table of contents. Leu will keep page navigation as the reliable source of structure.")
                    .foregroundStyle(ShelfTheme.secondary)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(entries) { entry in
                        Button {
                            model.go(to: entry.pageIndex)
                            model.semanticLevel = .page
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(entry.title).font(.body.weight(.medium)).lineLimit(2)
                                    Text("Page \(entry.pageIndex + 1)").font(.caption).foregroundStyle(ShelfTheme.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(ShelfTheme.secondary)
                            }
                            .padding(14)
                            .background(entry.pageIndex <= model.pageIndex ? ShelfTheme.raised : ShelfTheme.surface,
                                        in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
