import SwiftUI

struct ReadablePageView: View {
    let page: ReadablePage
    let textScale: Double
    let activeSentence: String?
    var scrollEnabled: Bool = true
    var surround: ReaderSurround = .paper
    var onLearnBlock: (@MainActor (ReadableBlock) -> Void)?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                ReadPageContent(page: page, textScale: textScale, activeSentence: activeSentence, onLearnBlock: onLearnBlock)
            }
            .background(surround.readingBackground)
            .foregroundStyle(surround.readingText)
            .scrollDisabled(!scrollEnabled)
            .scrollBounceBehavior(.basedOnSize)
            .onChange(of: activeSentence) { _, sentence in
                guard let sentence, let block = page.blocks.first(where: {
                    $0.text.range(of: sentence, options: [.caseInsensitive, .diacriticInsensitive]) != nil
                }) else { return }
                proxy.scrollTo(block.id, anchor: .center)
            }
        }
        .id(page.pageIndex)
    }
}
