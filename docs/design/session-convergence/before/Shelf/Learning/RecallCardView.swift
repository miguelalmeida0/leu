import SwiftUI
import ShelfCore

@MainActor
struct RecallCardView: View {
    @Bindable var model: LearningModel
    @State private var revealed = false

    var body: some View {
        if let object = model.currentObject {
            VStack(alignment: .leading, spacing: 22) {
                Text(object.source.sectionTitle ?? "Active recall")
                    .font(.caption.weight(.semibold)).foregroundStyle(ShelfTheme.accent)
                Text(object.prompt ?? object.title)
                    .font(LearningTokens.Typography.title)
                Text("Before revealing the source, reconstruct the idea in your own words.")
                    .foregroundStyle(ShelfTheme.secondary)
                if !revealed {
                    Button("Reveal source") { revealed = true; model.play(.sourceRevealed) }
                        .buttonStyle(ShelfButtonStyle(filled: true))
                } else {
                    Text(object.source.sourceText)
                        .font(.system(.title3, design: .serif)).lineSpacing(5)
                        .padding(.vertical, 4)
                    Button("View in PDF") { model.openSource(object.source) }.buttonStyle(ShelfButtonStyle())
                    HStack(spacing: 8) {
                        rate("Forgot", .forgot); rate("Difficult", .difficult); rate("Knew it", .knewIt)
                    }
                }
            }
            .background { UITestFrameProbe(identifier: "recall-card") }
            .onAppear {
                #if DEBUG
                StudyInteractionTrace.record("study.recall object=\(object.id) document=\(object.source.documentID) page=\(object.source.pageIndex + 1) source=\(object.source.sourceText)")
                #endif
            }
            .onChange(of: object.id) { _, _ in revealed = false }
        } else {
            Button("Continue") { model.advance() }.buttonStyle(ShelfButtonStyle(filled: true))
        }
    }

    private func rate(_ title: String, _ rating: RecallRating) -> some View {
        Button(title) { Task { await model.rateCurrent(rating) } }
            .accessibilityIdentifier("recall-rating-" + rating.rawValue)
            .buttonStyle(ShelfButtonStyle(filled: rating == .knewIt)).frame(maxWidth: .infinity)
    }
}
