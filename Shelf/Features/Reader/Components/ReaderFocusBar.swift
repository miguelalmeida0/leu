import SwiftUI

/// Real layout space above the document, never floating controls over printed content.
@MainActor
struct ReaderFocusBar: View {
    @Bindable var model: ReaderModel
    let close: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            IconButton(symbol: "chevron.left", label: "Back to library",
                       accessibilityID: "close-reader", action: close)
            Spacer(minLength: 0)
            Text("\(model.pageNumber) / \(model.book.pageCount)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(ShelfTheme.secondary)
                .accessibilityLabel("Page \(model.pageNumber) of \(model.book.pageCount)")
                .accessibilityIdentifier("focus-page-count")
            if model.displayMode == .original && model.preferences.pdfZoomScale > 1.025 {
                Button("Fit page") { model.fitPDFPage() }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ShelfTheme.accent)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("focus-fit-page")
            }
            Spacer(minLength: 0)
            IconButton(symbol: "rectangle.compress.vertical", label: "Show reading controls",
                       accessibilityID: "show-reader-controls") { model.focusMode = false }
        }
        .padding(.horizontal, 12)
        .frame(height: 48)
        .background(ShelfTheme.background)
        .background(UITestFrameProbe(identifier: "reader-focus-chrome-frame"))
        .overlay(alignment: .bottom) { ShelfTheme.line.frame(height: 0.5) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reader-focus-chrome")
    }
}
