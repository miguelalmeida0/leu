import SwiftUI
import ShelfCore

/// Creates a source-bound test object without inventing content. If the local
/// deterministic engine already produced a strong question for the same source
/// page, Shelf can preserve that question. Otherwise the learner writes the
/// recall prompt and the selected PDF passage remains the answer/source.
@MainActor
struct RecallPromptEditorSheet: View {
    @Bindable var model: LearningModel
    let source: LearningSource
    let onSaved: (LearningObject) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var prompt = ""

    var body: some View {
        ShelfSheet(title: "Test yourself") {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    sourceBlock
                    if let question = model.bestQuestion(for: source) {
                        deterministicQuestion(question)
                        dividerLabel("or write your own recall prompt")
                    } else {
                        Text("Leu could not construct a reliable multiple-choice question from this exact source. Write a recall prompt instead; the answer remains the passage you selected.")
                            .font(.callout)
                            .foregroundStyle(ShelfTheme.secondary)
                    }
                    manualPrompt
                }
                .padding(ShelfTheme.gutter)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityIdentifier("recall-prompt-editor")
        .onAppear {
            if prompt.isEmpty { prompt = model.suggestedRecallPrompt(for: source) }
        }
    }

    private var sourceBlock: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("SOURCE").font(.caption.weight(.bold)).tracking(1.6).foregroundStyle(ShelfTheme.accent)
            Text(source.sourceText)
                .font(.system(.body, design: .serif))
                .foregroundStyle(ShelfTheme.secondary)
                .lineLimit(9)
                .padding(.leading, 13)
                .overlay(alignment: .leading) { Rectangle().fill(ShelfTheme.accent).frame(width: 2) }
        }
    }

    private func deterministicQuestion(_ question: LearningQuestion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Source question available").font(LearningTokens.Typography.compactTitle)
            Text(question.prompt).font(.body).foregroundStyle(ShelfTheme.text)
            Text("Every option was extracted from this PDF. Leu will keep the question linked to page \(question.source.pageIndex + 1).")
                .font(.caption).foregroundStyle(ShelfTheme.secondary)
            Button("Save source question") {
                save(type: .question, prompt: question.prompt)
            }
            .buttonStyle(ShelfButtonStyle(filled: true))
            .accessibilityIdentifier("save-source-question")
        }
    }

    private var manualPrompt: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recall prompt").font(.headline)
            TextEditor(text: $prompt)
                .frame(minHeight: 112)
                .padding(10)
                .background(ShelfTheme.surface, in: RoundedRectangle(cornerRadius: LearningTokens.Corner.control))
                .accessibilityIdentifier("manual-recall-prompt")
            Button("Save recall prompt") {
                save(type: .recall, prompt: prompt)
            }
            .buttonStyle(ShelfButtonStyle(filled: true))
            .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("save-recall-prompt")
        }
    }

    private func dividerLabel(_ title: String) -> some View {
        HStack(spacing: 10) {
            Rectangle().fill(ShelfTheme.line).frame(height: 1)
            Text(title.uppercased()).font(.caption2.weight(.semibold)).tracking(1).foregroundStyle(ShelfTheme.secondary)
            Rectangle().fill(ShelfTheme.line).frame(height: 1)
        }
    }

    private func save(type: LearningObjectType, prompt: String) {
        Task {
            do {
                let object = try await model.capture(type: type, source: source, promptOverride: prompt)
                model.play(.objectCaptured)
                onSaved(object)
                dismiss()
            } catch {
                model.errorMessage = error.localizedDescription
            }
        }
    }
}
