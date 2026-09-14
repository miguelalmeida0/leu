import SwiftUI
import ShelfCore

@MainActor
struct BookTile: View {
    let book: Book
    let model: LibraryModel
    let preferences: AppPreferences
    let thumbnails: PDFThumbnailService
    @Bindable var knowledge: KnowledgeModel
    var relationshipLift: Double = 0
    var onRelationshipProbe: (() -> Void)? = nil
    @ScaledMetric(relativeTo: .title3) private var height: CGFloat = 222
    @State private var suppressNextOpen = false
    private var colors: CoverColors { CoverColors(book.palette) }
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button {
                StudyInteractionTrace.record("library.tile.tap document=\(book.id) suppressed=\(suppressNextOpen)")
                if suppressNextOpen { suppressNextOpen = false; return }
                model.open(book)
            } label: {
                ZStack(alignment: .topLeading) {
                    colors.background
                    VStack { Spacer(minLength: height * 0.45)
                        CoverIllustration(art: book.artwork, colors: colors).frame(height: height * 0.55)
                    }
                    if preferences.usePDFCovers {
                        PDFCoverImage(url: model.originalURL(book), service: thumbnails)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(book.title).font(.system(.title3, design: .serif)).fontWeight(.medium)
                            .lineLimit(3).fixedSize(horizontal: false, vertical: true)
                            .padding(.trailing, 16)
                        Text("\(book.pageCount) pages" + (book.isSample ? " · Sample" : ""))
                            .font(.caption).foregroundStyle(colors.muted)
                        Spacer(minLength: 6)
                        if book.lastOpenedAt != nil {
                            HStack(spacing: 5) {
                                Image(systemName: "bookmark.fill").font(.caption2)
                                Text("Page \(book.currentPageNumber)").font(.caption)
                            }
                            .padding(.horizontal, 8).padding(.vertical, 5)
                            .background(colors.background, in: Capsule())
                        }
                    }
                    .foregroundStyle(colors.foreground)
                    .padding(.horizontal, 16).padding(.top, 22).padding(.bottom, 14)
                    .background(alignment: .top) {
                        if preferences.usePDFCovers {
                            colors.background.frame(height: height * 0.53)
                        }
                    }
                }.frame(height: height).clipShape(RoundedRectangle(cornerRadius: 7))
                    .overlay { RoundedRectangle(cornerRadius: 7).strokeBorder(ShelfTheme.line, lineWidth: 0.7) }
                    .contentShape(RoundedRectangle(cornerRadius: 7))
            }.buttonStyle(.plain)
                .accessibilityLabel("Open \(book.title), \(book.pageCount) pages" + (book.isFavorite ? ", favorite" : ""))
                .accessibilityIdentifier("book-" + book.title)
            BookActionsMenu(book: book, model: model, knowledge: knowledge)
                .foregroundStyle(colors.foreground).padding(3)
        }
        .scaleEffect(1 + CGFloat(min(max(relationshipLift, 0), 1)) * 0.018)
        .offset(y: -CGFloat(min(max(relationshipLift, 0), 1)) * 10)
        .animation(ShelfMotion.gentle, value: relationshipLift)
        .simultaneousGesture(LongPressGesture(minimumDuration: 0.42).onEnded { _ in
            StudyInteractionTrace.record("library.tile.longPress document=\(book.id)")
            suppressNextOpen = true
            onRelationshipProbe?()
            Task {
                try? await Task.sleep(for: .seconds(0.65))
                suppressNextOpen = false
            }
        })
    }
}

@MainActor
struct PDFCoverImage: View {
    let url: URL
    let service: PDFThumbnailService
    @State private var image: UIImage?
    var body: some View {
        GeometryReader { geo in
            if let image { Image(uiImage: image).resizable().scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height).clipped() }
        }.task(id: url) {
            if let data = try? await service.thumbnail(url: url, pageIndex: 0) {
                guard !Task.isCancelled else { return }; image = UIImage(data: data)
            }
        }.accessibilityHidden(true)
    }
}
