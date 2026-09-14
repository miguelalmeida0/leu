import SwiftUI
import ShelfCore

@MainActor
struct ReaderContentsSheet: View {
    let model: ReaderModel
    let thumbnails: PDFThumbnailService
    @AppStorage("reader.contentsTab") private var selected = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ShelfSheet(title: "Find your place") {
            VStack(spacing: 0) {
                Picker("Navigate", selection: $selected) {
                    Text("Sections").tag(0)
                    Text("Pages").tag(1)
                    Text("Bookmarks").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(16)

                switch selected {
                case 0: sections
                case 1: pages
                default: bookmarks
                }
            }
        }
    }

    private var sections: some View {
        ScrollViewReader { proxy in
        List {
            if model.outline.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    if model.isDetectingOutline {
                        ProgressView("Detecting headings locally…")
                    } else {
                        Text("No reliable section index was found.")
                            .font(.headline)
                        Text("Page thumbnails remain the reliable navigation fallback for this PDF.")
                            .foregroundStyle(ShelfTheme.secondary)
                    }
                    Button("Browse pages") { selected = 1 }
                }
                .padding(.vertical, 16)
            } else {
                Section {
                    ForEach(model.outline) { entry in
                        Button { navigate(entry.pageIndex) } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.title)
                                        .lineLimit(3)
                                        .multilineTextAlignment(.leading)
                                        .padding(.leading, CGFloat(min(entry.depth, 3)) * 12)
                                    if entry.id == activeEntryID {
                                        Text("Current location")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(ShelfTheme.accent)
                                    }
                                }
                                Spacer(minLength: 12)
                                Text(String(entry.pageIndex + 1))
                                    .foregroundStyle(entry.id == activeEntryID ? ShelfTheme.accent : ShelfTheme.secondary)
                                    .monospacedDigit()
                            }
                            .padding(.vertical, 7)
                        }
                        .foregroundStyle(ShelfTheme.text)
                        .accessibilityLabel("\(entry.title), page \(entry.pageIndex + 1)")
                        .id(entry.id)
                    }
                } header: {
                    Text(sectionSourceTitle)
                } footer: {
                    if model.outline.first?.source == .detected {
                        Text("Detected locally from the PDF text. Page thumbnails remain available when a heading looks incomplete.")
                    } else if model.outline.first?.source == .landmark {
                        Text("These are page landmarks, not inferred chapters.")
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .onAppear { if let activeEntryID { proxy.scrollTo(activeEntryID, anchor: .center) } }
        .onChange(of: activeEntryID) { _, entry in
            if let entry { proxy.scrollTo(entry, anchor: .center) }
        }
        }
    }

    private var activeEntryID: String? {
        ContentsLocation.activeEntryID(entries: model.outline.map { (id: $0.id, page: $0.pageIndex) }, pageIndex: model.pageIndex)
    }

    private var sectionSourceTitle: String {
        guard let source = model.outline.first?.source else { return "Sections" }
        switch source {
        case .embedded: return "Document contents"
        case .detected: return "Detected headings"
        case .landmark: return "Page landmarks"
        }
    }

    private var pages: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3), spacing: 18) {
                    ForEach(0..<model.book.pageCount, id: \.self) { index in
                        Button { navigate(index) } label: {
                            PDFPageThumbnail(
                                url: model.url,
                                index: index,
                                selected: index == model.pageIndex,
                                bookmarked: model.bookmarks.contains { $0.pageIndex == index },
                                marked: model.annotations.contains { $0.pageIndex == index && $0.kind.isStudyMarker },
                                service: thumbnails
                            )
                        }
                        .id(index)
                        .buttonStyle(.plain)
                        .accessibilityLabel(index == model.pageIndex ? "Current page \(index + 1)" : "Go to page \(index + 1)")
                    }
                }
                .padding(18)
            }
            .onAppear {
                DispatchQueue.main.async {
                    proxy.scrollTo(model.pageIndex, anchor: .center)
                }
            }
        }
    }

    private var bookmarks: some View {
        List {
            if model.bookmarks.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    Text("No bookmarked pages yet.")
                        .font(.headline)
                    Text("Bookmark your current page to return to it quickly.")
                        .foregroundStyle(ShelfTheme.secondary)
                    Button("Bookmark current page") {
                        Task { await model.toggleBookmark() }
                    }
                    .buttonStyle(ShelfButtonStyle(filled: true))
                }
                .padding(.vertical, 16)
            }

            ForEach(model.bookmarks) { bookmark in
                Button { navigate(bookmark.pageIndex) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "bookmark.fill")
                            .foregroundStyle(ShelfTheme.accent)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(model.sectionTitle(for: bookmark.pageIndex) ?? bookmark.title)
                                .foregroundStyle(ShelfTheme.text)
                                .lineLimit(2)
                            Text("Page \(bookmark.pageIndex + 1)")
                                .font(.caption)
                                .foregroundStyle(ShelfTheme.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func navigate(_ page: Int) {
        model.go(to: page)
        dismiss()
    }
}

@MainActor
struct PDFPageThumbnail: View {
    let url: URL
    let index: Int
    let selected: Bool
    let bookmarked: Bool
    let marked: Bool
    let service: PDFThumbnailService
    @State private var image: UIImage?

    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .topTrailing) {
                ShelfTheme.surface
                if let image {
                    Image(uiImage: image).resizable().scaledToFit()
                } else {
                    Image(systemName: "doc").foregroundStyle(ShelfTheme.secondary)
                }

                if bookmarked || marked {
                    HStack(spacing: 4) {
                        if marked { Image(systemName: "highlighter") }
                        if bookmarked { Image(systemName: "bookmark.fill") }
                    }
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(ShelfTheme.background)
                    .padding(6)
                    .background(ShelfTheme.accent, in: Capsule())
                    .padding(6)
                }
            }
            .aspectRatio(0.7, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(selected ? ShelfTheme.accent : Color.clear, lineWidth: 2)
            }

            HStack(spacing: 4) {
                Text(String(index + 1)).monospacedDigit()
                if selected { Text("Current") }
            }
            .font(.caption.weight(selected ? .semibold : .regular))
            .foregroundStyle(selected ? ShelfTheme.accent : ShelfTheme.secondary)
        }
        .task(id: index) {
            if let data = try? await service.thumbnail(url: url, pageIndex: index, width: 260) {
                guard !Task.isCancelled else { return }
                image = UIImage(data: data)
            }
        }
    }
}
