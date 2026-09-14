import SwiftUI

/// One vertical scroll view spans the document, rather than a scroll view containing one PDF page.
@MainActor
struct ReadContinuousDocumentView: View {
    @Bindable var model: ReaderModel
    @State private var visiblePage: Int?
    @State private var navigating = false

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(0..<model.book.pageCount, id: \.self) { index in
                            ContinuousReadPage(model: model, index: index, minimumHeight: geometry.size.height)
                                .id(index)
                        }
                    }
                    .scrollTargetLayout()
                }
                .background(ShelfTheme.paper)
                .scrollPosition(id: $visiblePage, anchor: .top)
                .scrollBounceBehavior(.basedOnSize)
                .onAppear { jump(using: proxy) }
                .onChange(of: model.navigationRevision) { _, _ in jump(using: proxy) }
                .onChange(of: visiblePage) { _, page in
                    guard !navigating, let page else { return }
                    model.didScrollReadPage(to: page)
                }
            }
        }
        .accessibilityIdentifier("read-continuous-viewport")
    }

    private func jump(using proxy: ScrollViewProxy) {
        navigating = true
        visiblePage = model.pageIndex
        proxy.scrollTo(model.pageIndex, anchor: .top)
        DispatchQueue.main.async { navigating = false }
    }
}

@MainActor
private struct ContinuousReadPage: View {
    let model: ReaderModel
    let index: Int
    let minimumHeight: CGFloat

    var body: some View {
        let page = model.readablePage(at: index)
        VStack(alignment: .leading, spacing: 0) {
            if page.blocks.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Page \(index + 1) has no selectable text.")
                    Button("View this page in Original") {
                        model.go(to: index)
                        model.setDisplayMode(.original)
                    }
                }.padding(24)
            } else {
                ReadPageContent(page: page, textScale: model.preferences.readTextScale,
                    activeSentence: model.pageIndex == index ? model.speech.activeSentence : nil,
                    onLearnBlock: { block in model.selectReadBlock(block, pageIndex: index) })
            }
            Spacer(minLength: 12)
            Text("Page \(index + 1) of \(model.book.pageCount)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(LeuDesign.readingSecondary)
                .padding(.horizontal, 24).padding(.bottom, 16)
                .accessibilityIdentifier("read-boundary-\(index)")
            Rectangle().fill(LeuDesign.readingSecondary).frame(height: 1)
        }
        .frame(maxWidth: .infinity, minHeight: minimumHeight, alignment: .topLeading)
        .foregroundStyle(ShelfTheme.ink)
        .background(ShelfTheme.paper)
    }
}
