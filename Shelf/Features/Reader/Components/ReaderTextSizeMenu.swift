import SwiftUI

@MainActor
struct ReaderTextSizeMenu: View {
    @Bindable var model: ReaderModel

    var body: some View {
        LeuMenu {
            if model.displayMode == .read {
                Button("Smaller", systemImage: "textformat.size.smaller") { model.decreaseTextSize() }
                Button("Reset text size", systemImage: "arrow.counterclockwise") { model.resetTextSize() }
                Button("Larger", systemImage: "textformat.size.larger") { model.increaseTextSize() }
                Divider()
                Text("Read text · \(Int(model.preferences.readTextScale * 100))%")
            } else {
                Button("Zoom out", systemImage: "minus.magnifyingglass") { model.decreaseTextSize() }
                Button("Fit page", systemImage: "rectangle.inset.filled") { model.fitPDFPage() }
                Button("Fit width", systemImage: "arrow.left.and.right") { model.fitPDFWidth() }
                Button("Zoom in", systemImage: "plus.magnifyingglass") { model.increaseTextSize() }
                Divider()
                Text("PDF zoom · \(Int(model.preferences.pdfZoomScale * 100))%")
                if model.preferences.pdfZoomScale > 1.03 {
                    Text("Swipe pans the page while zoomed. Use arrows to change pages.")
                }
            }
        } label: {
            VStack(spacing: 5) {
                Image(systemName: model.displayMode == .read ? "textformat.size" : "magnifyingglass")
                    .font(.system(size: 19))
                Text(model.displayMode == .read ? "Text" : "Zoom")
                    .font(.system(size: 11, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 53)
            .foregroundStyle(ShelfTheme.secondary)
        }
        .accessibilityLabel(model.displayMode == .read ? "Text size" : "PDF zoom")
        .accessibilityIdentifier(model.displayMode == .read ? "reader-tool-text" : "reader-tool-zoom")
    }
}
