import ShelfCore
import SwiftUI

/// A book as a patch of dyed felt: its size in pages, its title, and a running stitch
/// along the bottom edge that is sewn as far as you have read.
///
/// The whole patch opens the book. The ellipsis keeps every action from the old tile
/// (favorite, edit, connections, trash), and a long press still lifts related books.
@MainActor
struct FeltBookPatch: View {
    let book: Book
    let model: LibraryModel
    @Bindable var knowledge: KnowledgeModel
    var emphasis: Bool = false
    /// When the reader prefers PDF covers, the first page sits in the patch's corner.
    var cover: (url: URL, service: PDFThumbnailService)? = nil
    var relationshipLift: Double = 0
    var onRelationshipProbe: (() -> Void)? = nil
    @State private var suppressNextOpen = false

    private var colors: CoverColors { CoverColors(book.palette) }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button {
                StudyInteractionTrace.record("library.tile.tap document=\(book.id) suppressed=\(suppressNextOpen)")
                if suppressNextOpen { suppressNextOpen = false; return }
                model.open(book)
            } label: {
                patch
            }
            .buttonStyle(FeltPressStyle())
            .accessibilityLabel(BookStatus(book).spoken)
            .accessibilityHint("Opens the book where you left it")
            .accessibilityIdentifier("book-" + book.title)
            BookActionsMenu(book: book, model: model, knowledge: knowledge)
                .foregroundStyle(colors.foreground)
                .padding(2)
        }
        .scaleEffect(1 + CGFloat(min(max(relationshipLift, 0), 1)) * 0.02)
        .offset(y: -CGFloat(min(max(relationshipLift, 0), 1)) * 8)
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

    private var patch: some View {
        let status = BookStatus(book)
        return VStack(alignment: .leading, spacing: 6) {
            Text(status.eyebrow)
                .font(LeuDesign.eyebrow(10))
                .tracking(LeuDesign.eyebrowTracking)
                .foregroundStyle(colors.muted)
            Text(book.title)
                .font(.leu(.headline, weight: .heavy))
                .foregroundStyle(colors.foreground)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .padding(.trailing, cover == nil ? 30 : 64)
            Spacer(minLength: 4)
            HStack(spacing: 8) {
                StitchProgress(progress: status.progress, color: colors.foreground)
                Text(status.short)
                    .font(.leu(.caption, weight: .semibold).monospacedDigit())
                    .foregroundStyle(colors.foreground)
                    .lineLimit(1)
                    .layoutPriority(1)
            }
        }
        .padding(.horizontal, 15)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay(alignment: .bottomTrailing) {
            if let cover {
                PDFCoverImage(url: cover.url, service: cover.service)
                    .frame(width: 40, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .padding(.trailing, 14)
                    .padding(.bottom, 24)
            }
        }
        .background(colors.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            // The stitched edge of the patch, just inside the felt.
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(colors.foreground.opacity(0.32), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .padding(5)
                .accessibilityHidden(true)
        }
        .overlay {
            if emphasis {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(LeuDesign.ink, lineWidth: 2)
                    .padding(-3)
                    .accessibilityHidden(true)
            }
        }
        .shadow(color: LeuDesign.ink.opacity(0.16), radius: 10, x: 0, y: 7)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// A running stitch sewn as far as the reader has read: solid dashes behind, faint ahead.
struct StitchProgress: View {
    let progress: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let done = proxy.size.width * min(max(progress, 0), 1)
            ZStack(alignment: .leading) {
                StitchLine().stroke(color.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                StitchLine().stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [6, 3]))
                    .frame(width: done)
            }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }
}

private struct StitchLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

/// Felt gives a little under a press and springs back slowly.
struct FeltPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.975 : 1)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// What a book's patch says about it, in words a reader would use.
struct BookStatus {
    let progress: Double
    let eyebrow: String
    let short: String
    let spoken: String

    init(_ book: Book) {
        let pages = max(book.pageCount, 1)
        let opened = book.lastOpenedAt != nil
        let finished = opened && book.currentPageNumber >= pages
        progress = opened ? Double(book.currentPageNumber) / Double(pages) : 0
        let pageWord = book.pageCount == 1 ? "1 PAGE" : "\(book.pageCount) PAGES"
        if finished {
            eyebrow = pageWord + " · FINISHED"
            short = "sewn shut"
        } else if !opened {
            eyebrow = (Date().timeIntervalSince(book.importedAt) < 7 * 86_400 ? "NEW · " : "") + pageWord
            short = "not started"
        } else {
            eyebrow = pageWord
            short = "\(Int((progress * 100).rounded()))%"
        }
        let state = finished ? "finished" : !opened ? "not started" : "page \(book.currentPageNumber) of \(book.pageCount)"
        spoken = "\(book.title), \(book.pageCount) pages, \(state)" + (book.isFavorite ? ", kept close" : "")
    }
}
