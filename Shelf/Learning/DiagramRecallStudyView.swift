import SwiftUI
import PDFKit
import ShelfCore

@MainActor
struct DiagramRecallStudyView: View {
    @Bindable var model: LearningModel
    @State private var revealed = false
    var body: some View {
        if let object = model.currentObject,
           let mask = model.snapshot.masks.first(where: { $0.learningObjectID == object.id }) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Diagram recall").font(.caption.weight(.semibold)).foregroundStyle(ShelfTheme.accent)
                Text(mask.label ?? object.title).font(LearningTokens.Typography.title)
                Text(revealed ? "Regions revealed. Compare what you predicted." : "Recall what belongs in the masked regions before revealing.")
                    .foregroundStyle(ShelfTheme.secondary)
                MaskedPagePreview(source: mask.source, regions: mask.regions, revealed: revealed, library: model.library)
                Button(revealed ? "View source" : "Reveal masks") {
                    if revealed { model.openSource(mask.source) } else { revealed = true; model.play(.sourceRevealed) }
                }.buttonStyle(ShelfButtonStyle(filled: !revealed))
                if revealed {
                    HStack { rate("Forgot", .forgot); rate("Difficult", .difficult); rate("Knew it", .knewIt) }
                }
            }
        } else {
            RecallCardView(model: model)
        }
    }
    private func rate(_ title: String, _ rating: RecallRating) -> some View {
        Button(title) { Task { await model.rateCurrent(rating) } }.buttonStyle(ShelfButtonStyle()).frame(maxWidth: .infinity)
    }
}

private struct MaskedPagePreview: View {
    let source: LearningSource
    let regions: [SourceBounds]
    let revealed: Bool
    let library: LibraryModel
    var body: some View {
        if let book = library.snapshot.activeBooks.first(where: { $0.id == source.documentID }),
           let document = PDFKit.PDFDocument(url: library.originalURL(book)),
           let page = document.page(at: source.pageIndex) {
            GeometryReader { proxy in
                let image = page.thumbnail(of: CGSize(width: 900, height: 1200), for: .cropBox)
                Image(uiImage: image).resizable().scaledToFit()
                    .overlay(alignment: .topLeading) {
                        ForEach(Array(regions.enumerated()), id: \.offset) { _, region in
                            if !revealed {
                                RoundedRectangle(cornerRadius: 6).fill(ShelfTheme.ink)
                                    .frame(width: proxy.size.width * region.width, height: proxy.size.height * region.height)
                                    .offset(x: proxy.size.width * region.x, y: proxy.size.height * region.y)
                            }
                        }
                    }
            }.aspectRatio(0.72, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 14))
        } else { Text("Source page unavailable.").foregroundStyle(ShelfTheme.secondary) }
    }
}
