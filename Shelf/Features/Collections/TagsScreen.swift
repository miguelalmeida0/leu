import SwiftUI
import ShelfCore

@MainActor
struct TagsScreen: View {
    let model: LibraryModel
    @State private var showReview = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Button {
                        model.selectedTab = .library
                    } label: {
                        Label("Library", systemImage: "chevron.left")
                            .font(.system(.subheadline, design: .serif))
                            .foregroundStyle(ShelfTheme.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Library")
                    .accessibilityHint("Return to your library")
                    .accessibilityIdentifier("library-tags-back")
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("LEU").font(ShelfTheme.eyebrow()).tracking(3).foregroundStyle(ShelfTheme.secondary)
                    Text("Tags & Marks").leuScaledFont(36, weight: .regular, design: .serif)
                    Text("Labels for books, and passages worth returning to.")
                        .font(.system(.subheadline, design: .serif).italic())
                        .foregroundStyle(ShelfTheme.secondary)
                }

                Rectangle().fill(ShelfTheme.line).frame(height: 0.5)

                Button { showReview = true } label: {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: "bookmark")
                            .font(.title3).foregroundStyle(ShelfTheme.accent).frame(width: 28)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Your Marks").leuScaledFont(21, weight: .regular, design: .serif).foregroundStyle(ShelfTheme.text)
                            Text("\(model.studyMarks.count) important, review or confusing passages")
                                .font(.subheadline).foregroundStyle(ShelfTheme.secondary)
                        }
                        Spacer(); Image(systemName: "arrow.right").foregroundStyle(ShelfTheme.secondary)
                    }
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if model.allTags.isEmpty {
                    EmptyLibraryState(symbol: "tag", title: "No tags yet.",
                        message: "Add a label to a book when a subject becomes worth grouping.")
                } else {
                    VStack(spacing: 0) {
                        ForEach(model.allTags, id: \.self) { tag in
                            Button { model.chooseTag(tag) } label: {
                                HStack {
                                    Text(tag).font(.system(.body, design: .serif)).foregroundStyle(ShelfTheme.text)
                                    Spacer()
                                    Text(String(model.snapshot.activeBooks.filter { $0.tags.contains(tag) }.count))
                                        .font(.callout.monospacedDigit()).foregroundStyle(ShelfTheme.secondary)
                                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(ShelfTheme.secondary)
                                }
                                .frame(minHeight: 52).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Divider().overlay(ShelfTheme.line)
                        }
                    }
                }
            }
            .padding(ShelfTheme.gutter)
            .frame(maxWidth: 760).frame(maxWidth: .infinity)
        }
        .background(ShelfTheme.background)
        .sheet(isPresented: $showReview) { StudyReviewSheet(model: model) }
    }
}

@MainActor
struct StudyReviewSheet: View {
    let model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ShelfSheet(title: "Your Marks") {
            List {
                if model.studyMarks.isEmpty {
                    Text("Mark a passage while reading and it will stay here with its source.")
                }
                ForEach(model.studyMarks) { mark in
                    if let book = model.snapshot.books.first(where: { $0.id == mark.bookID }) {
                        Button {
                            dismiss()
                            Task { try? await Task.sleep(for: .milliseconds(400)); model.open(book, page: mark.pageIndex) }
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(mark.kind.title.uppercased())
                                        .font(ShelfTheme.eyebrow(10)).tracking(1.5).foregroundStyle(ShelfTheme.accent)
                                    Spacer(); Text("p. \(mark.pageIndex + 1)").foregroundStyle(ShelfTheme.secondary)
                                }
                                Text(mark.quote.isEmpty ? book.title : mark.quote)
                                    .font(.system(.body, design: .serif)).lineLimit(4)
                                Text(book.title).font(.caption).foregroundStyle(ShelfTheme.secondary)
                                if !mark.note.isEmpty { Text(mark.note).lineLimit(2).font(.caption).foregroundStyle(ShelfTheme.secondary) }
                            }.padding(.vertical, 8)
                        }.foregroundStyle(ShelfTheme.text)
                    }
                }
            }
        }
    }
}
