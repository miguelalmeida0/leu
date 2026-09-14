import SwiftUI

@MainActor
struct ReaderStateSheet: View {
    @Bindable var model: ReaderModel
    var body: some View {
        ShelfSheet(title: "Reading State") {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Your place, not just your page.")
                        .leuScaledFont(27, weight: .semibold, design: .serif)
                    Text("Leu keeps the reading position aligned across Read, Original and voice playback.")
                        .foregroundStyle(ShelfTheme.secondary)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack { Text("Page \(model.pageNumber)").font(.headline); Spacer(); Text(model.displayMode.title).font(.caption.weight(.semibold)).foregroundStyle(ShelfTheme.accent) }
                        if let sentence = model.readingAnchor?.sentence, !sentence.isEmpty {
                            Text(sentence).font(.system(.body, design: .serif)).lineLimit(6)
                        } else {
                            Text("Your page position is saved automatically as you read.").font(.callout).foregroundStyle(ShelfTheme.secondary)
                        }
                    }.padding(16).background(ShelfTheme.raised, in: RoundedRectangle(cornerRadius: 16))
                    Text("Physical-page camera matching is intentionally not part of this release: Leu uses deterministic document parsing only, with no model inference.")
                        .font(.footnote).foregroundStyle(ShelfTheme.secondary)
                }.padding(20)
            }
        }
    }
}
