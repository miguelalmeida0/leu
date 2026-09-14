import SwiftUI

@MainActor
struct BlindPageSheet: View {
    @Bindable var model: ReaderModel
    @State private var phase: Phase = .prompt
    enum Phase { case prompt, thinking, writing, revealed }

    var body: some View {
        ShelfSheet(title: "Before you continue") {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("What do you remember from what you just read?")
                        .font(LearningTokens.Typography.title)
                    if phase == .thinking {
                        Text("Hold the page in your head for a moment. When you are ready, compare it with the source.")
                            .foregroundStyle(ShelfTheme.secondary)
                        Button("Reveal previous page") { phase = .revealed; model.playHaptic(.sourceRevealed) }
                            .buttonStyle(ShelfButtonStyle(filled: true))
                    } else if phase == .writing {
                        TextEditor(text: $model.blindPageDraft).frame(minHeight: 150)
                            .padding(8).background(ShelfTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                        Button("Reveal previous page") { phase = .revealed; model.playHaptic(.sourceRevealed) }
                            .buttonStyle(ShelfButtonStyle(filled: true))
                    } else if phase == .revealed {
                        Text(model.blindPageSourceText()).font(.system(.body, design: .serif)).lineSpacing(4)
                        if !model.blindPageDraft.isEmpty {
                            Divider().overlay(ShelfTheme.line)
                            Text("What you wrote").font(.headline)
                            Text(model.blindPageDraft).foregroundStyle(ShelfTheme.secondary)
                        }
                        Button("Continue reading") { model.completeBlindPage() }.buttonStyle(ShelfButtonStyle(filled: true))
                    } else {
                        Text("Take a moment before looking back. No score is attached to this.")
                            .foregroundStyle(ShelfTheme.secondary)
                        HStack(spacing: 10) {
                            Button("Think") { phase = .thinking }.buttonStyle(ShelfButtonStyle(filled: true))
                            Button("Write") { phase = .writing }.buttonStyle(ShelfButtonStyle())
                            Button("Skip") { model.skipBlindPage() }.buttonStyle(ShelfButtonStyle())
                        }
                    }
                }.padding(ShelfTheme.gutter)
            }
        }
        .interactiveDismissDisabled()
    }
}
