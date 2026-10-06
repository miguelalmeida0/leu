import ShelfCore
import SwiftUI

/// Bring a PDF (02b): the moment a new book arrives. It sits in the middle of its shelf,
/// edged in red running stitch while Leu is still reading it, joined by dashed thread to
/// the books it already shares ideas with, each join named by the idea they share.
@MainActor
struct SewnScreen: View {
    let book: Book
    let library: LibraryModel
    let knowledge: KnowledgeModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var wide: Bool { sizeClass == .regular }
    private var current: Book { library.snapshot.books.first { $0.id == book.id } ?? book }
    private var shelf: BookCollection? { library.collections.first { current.collectionIDs.contains($0.id) } }
    private var stitching: Bool { knowledge.isIndexing || library.isIndexing }

    private struct Neighbour: Identifiable {
        let book: Book
        let idea: String?
        var id: UUID { book.id }
    }

    /// The books it already shares ideas with, strongest first, each with one shared idea.
    private var neighbours: [Neighbour] {
        let strengths = knowledge.documentRelationshipStrengths(from: book.id)
        let mine = concepts(of: book.id)
        return strengths.sorted { $0.value > $1.value }.prefix(4).compactMap { entry -> Neighbour? in
            guard let other = library.snapshot.activeBooks.first(where: { $0.id == entry.key }) else { return nil }
            let shared = mine.intersection(concepts(of: entry.key)).compactMap { knowledge.concept($0)?.name }.sorted().first
            return Neighbour(book: other, idea: shared)
        }
    }

    private func concepts(of documentID: UUID) -> Set<UUID> {
        knowledge.snapshot.indexRecords.filter { $0.documentID == documentID }.reduce(into: Set<UUID>()) { $0.formUnion($1.conceptIDs) }
    }

    var body: some View {
        ShelfSheet(title: "Sewn in") {
            ScrollView {
                VStack(alignment: .leading, spacing: wide ? 34 : 24) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(shelf.map { "\(current.title) is being sewn onto your \($0.name) shelf." }
                             ?? "\(current.title) is being sewn into your library.")
                            .font(LeuDesign.display(wide ? 50 : 32)).tracking(wide ? -1.8 : -1)
                            .foregroundStyle(LeuDesign.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        Text(summary)
                            .font(.leu(.body, weight: .medium)).foregroundStyle(LeuDesign.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    patches
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) { actions }
                        VStack(alignment: .leading, spacing: 10) { actions }
                    }
                    if !library.collections.isEmpty { shelves }
                }
                .padding(.horizontal, wide ? 40 : 20)
                .padding(.vertical, 26)
                .frame(maxWidth: 1240, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityIdentifier("sewn-screen")
    }

    private var summary: String {
        let count = neighbours.count
        let shares = count == 0 ? (stitching ? "Leu is still reading it; links to your other books appear as it goes."
                                             : "It doesn't share ideas with your other books yet.")
                                : "It already shares ideas with \(count == 1 ? "one book" : "\(count) books") you know."
        return shares + " Open it whenever you like" + (stitching ? ", Leu will finish the stitching on its own." : ".")
    }

    private var patches: some View {
        let others = neighbours
        let left = Array(others.prefix(2)), right = Array(others.dropFirst(2))
        return ScrollView(.horizontal) {
            HStack(alignment: .bottom, spacing: 14) {
                ForEach(left) { pair in neighbour(pair.book, idea: pair.idea) }
                patch(current, new: true)
                ForEach(right) { pair in neighbour(pair.book, idea: pair.idea) }
            }
            .padding(.vertical, 6)
        }
        .scrollIndicators(.hidden)
        .accessibilityElement(children: .contain)
    }

    private func neighbour(_ other: Book, idea: String?) -> some View {
        VStack(spacing: 10) {
            if let idea {
                (Text("both talk about ") + Text(idea).foregroundStyle(LeuDesign.redThreadText))
                    .font(.leu(.caption, weight: .semibold)).foregroundStyle(LeuDesign.ink)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(LeuDesign.cream, in: Capsule())
                    .lineLimit(1)
            }
            patch(other, new: false)
        }
    }

    private func patch(_ item: Book, new: Bool) -> some View {
        let colors = CoverColors(item.palette)
        let status = BookStatus(item)
        return VStack(alignment: .leading, spacing: 8) {
            Text(new ? "\(item.pageCount) PAGES · JUST ARRIVED" : status.eyebrow)
                .font(LeuDesign.eyebrow(9)).tracking(1.2).foregroundStyle(colors.muted)
            Text(item.title).font(.leu(.headline, weight: .heavy)).foregroundStyle(colors.foreground).lineLimit(3)
            Spacer(minLength: 0)
            Text(new ? (stitching ? "sewing in" : "sewn in") : status.short)
                .font(.leu(.caption, weight: .semibold)).foregroundStyle(colors.foreground)
        }
        .padding(16)
        .frame(width: new ? 250 : 190, height: 170, alignment: .topLeading)
        .background(colors.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(new ? LeuDesign.redThread : colors.foreground.opacity(0.3),
                              style: StrokeStyle(lineWidth: new ? 2 : 1, dash: new ? [7, 5] : [4, 3]))
                .padding(6)
        }
        .overlay {
            if new { RoundedRectangle(cornerRadius: 19, style: .continuous).stroke(LeuDesign.cream, lineWidth: 3).padding(-3) }
        }
        .shadow(color: LeuDesign.ink.opacity(0.16), radius: 12, x: 0, y: 7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(new ? "\(item.title), \(item.pageCount) pages, just arrived" : status.spoken)
    }

    @ViewBuilder private var actions: some View {
        Button("Open \(current.title)") {
            dismiss()
            Task { try? await Task.sleep(for: .milliseconds(450)); library.open(current) }
        }
        .buttonStyle(LeuPrimaryButtonStyle(filled: true, pill: true))
        .accessibilityIdentifier("sewn-open")
        Button(shelf == nil ? "Put it on a shelf" : "Put it on another shelf") {
            dismiss()
            Task { try? await Task.sleep(for: .milliseconds(450)); library.editingBook = current }
        }
        .buttonStyle(LeuPrimaryButtonStyle(filled: false, pill: true))
    }

    private var shelves: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("YOUR SHELVES")
                .font(LeuDesign.eyebrow(10)).tracking(LeuDesign.eyebrowTracking).foregroundStyle(LeuDesign.eyebrowOnFelt)
                .accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12)], spacing: 12) {
                ForEach(library.collections) { collection in
                    let books = library.snapshot.activeBooks.filter { $0.collectionIDs.contains(collection.id) }
                    HStack(spacing: 10) {
                        Text(collection.name).font(.leu(.subheadline, weight: .bold)).foregroundStyle(LeuDesign.ink)
                        Spacer(minLength: 8)
                        ForEach(books.prefix(5)) { item in
                            RoundedRectangle(cornerRadius: 4).fill(CoverColors(item.palette).background).frame(width: 20, height: 20)
                        }
                        Text("\(books.count)").font(.leu(.caption, weight: .semibold).monospacedDigit()).foregroundStyle(LeuDesign.secondary)
                    }
                    .padding(.horizontal, 18).frame(minHeight: 56)
                    .background(LeuDesign.feltLight, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(collection.name), \(books.count) books")
                }
            }
        }
    }
}
