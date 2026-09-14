import SwiftUI

/// Reusable page typography, intentionally independent of any scrolling/paging container.
struct ReadPageContent: View {
    let page: ReadablePage
    let textScale: Double
    let activeSentence: String?
    var onLearnBlock: (@MainActor (ReadableBlock) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if page.blocks.isEmpty {
                Text("This page has no selectable text.")
                    .font(.headline).padding(.bottom, 12)
                Text("Use Original to see the page. The arrows can still move to the next page.")
                    .font(.body)
            }
            ForEach(Array(page.blocks.enumerated()), id: \.element.id) { index, block in
                blockView(block, index: index)
                    .accessibilityIdentifier("read-block-\(page.pageIndex)-\(index)")
                    .id(block.id)
                    .contentShape(Rectangle())
                    .onLongPressGesture(minimumDuration: 0.42) {
                        onLearnBlock?(block)
                    }
                    .accessibilityAction(named: "Learn from this passage") {
                        onLearnBlock?(block)
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 28)
        .padding(.top, 30)
        .padding(.bottom, 40)
        .onAppear {
            #if DEBUG
            if ProcessInfo.processInfo.environment["LEU_PDF_DIAGNOSTICS"] == "1" {
                print("[leu-visible-text] page=\(page.pageIndex + 1) integrity=\(page.sourceIntegrityPassed) blocks=\(page.blocks.map(\.text))")
            }
            #endif
        }
    }

    @ViewBuilder
    private func blockView(_ block: ReadableBlock, index: Int) -> some View {
        switch block.kind {
        case .heading:
            highlightedText(block.text)
                .leuScaledFont((index == 0 ? 34 : 25) * textScale, weight: .semibold, design: .serif)
                .tracking(index == 0 ? -0.5 : 0.1)
                .padding(.top, index == 0 ? 0 : 24)
                .padding(.bottom, 12)
        case .paragraph:
            highlightedText(block.text)
                .leuScaledFont(20 * textScale, design: .serif)
                .lineSpacing(7 * textScale)
                .padding(.bottom, 20)
        case .bullet:
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                highlightedText(block.text)
                    .leuScaledFont(19 * textScale, design: .serif)
                    .lineSpacing(6 * textScale)
            }
            .padding(.bottom, 14)
        case .code:
            ScrollView(.horizontal) {
                highlightedText(block.text)
                    .leuScaledFont(17 * textScale, design: .monospaced)
                    .fixedSize(horizontal: true, vertical: false)
            }.padding(.bottom, 20)
        }
    }

    private func highlightedText(_ text: String) -> Text {
        var attributed = AttributedString(text)
        if let activeSentence,
           !activeSentence.isEmpty,
           let range = attributed.range(of: activeSentence, options: .caseInsensitive) {
            attributed[range][AttributeScopes.SwiftUIAttributes.BackgroundColorAttribute.self] = ShelfTheme.spokenHighlight
            attributed[range][AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute.self] = ShelfTheme.ink
        }
        return Text(attributed)
    }
}
