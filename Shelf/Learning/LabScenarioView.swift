import SwiftUI
import ShelfCore

struct LabScenarioView: View {
    let lab: ReconstructionLab
    @State private var selectedID: UUID?
    @State private var committed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("PREDICT").font(.caption.weight(.bold)).tracking(1.8).foregroundStyle(ShelfTheme.accent)
            setup
            Text(lab.scenario.prompt).font(LearningTokens.Typography.compactTitle)
            VStack(spacing: 9) {
                ForEach(lab.scenario.choices) { choice in option(choice) }
            }
            if !committed {
                Button("Commit prediction") { commit() }
                    .buttonStyle(ShelfButtonStyle(filled: true))
                    .disabled(selectedID == nil)
            } else {
                reveal
            }
        }
        .padding(16)
        .background(ShelfTheme.raised, in: RoundedRectangle(cornerRadius: LearningTokens.Corner.surface))
        .accessibilityIdentifier("lab-scenario")
    }

    private var setup: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(lab.scenario.setup.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(ShelfTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ShelfTheme.surface, in: RoundedRectangle(cornerRadius: LearningTokens.Corner.control))
    }

    private func option(_ choice: LabChoice) -> some View {
        let selected = selectedID == choice.id
        let correct = choice.id == lab.scenario.correctChoiceID
        return Button {
            guard !committed else { return }
            withAnimation(reduceMotion ? nil : LearningTokens.Motion.selection) { selectedID = choice.id }
            ShelfHaptics.shared.play(.selectionChanged)
        } label: {
            HStack(spacing: 11) {
                Image(systemName: selected ? "circle.inset.filled" : "circle")
                    .foregroundStyle(selected ? ShelfTheme.accent : ShelfTheme.secondary)
                Text(choice.text).multilineTextAlignment(.leading).foregroundStyle(ShelfTheme.text)
                Spacer()
                if committed && selected {
                    Image(systemName: correct ? "checkmark.circle" : "arrow.turn.down.right")
                        .foregroundStyle(correct ? ShelfTheme.reviewAccent : ShelfTheme.secondary)
                }
            }
            .padding(13)
            .background(selected ? ShelfTheme.surface : Color.clear,
                        in: RoundedRectangle(cornerRadius: LearningTokens.Corner.control))
            .scaleEffect(selected && !committed && !reduceMotion ? 0.99 : 1)
        }
        .buttonStyle(.plain)
        .disabled(committed)
    }

    private var reveal: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(selectedID == lab.scenario.correctChoiceID ? "Prediction holds" : "Compare the mechanism")
                .font(.headline)
                .foregroundStyle(selectedID == lab.scenario.correctChoiceID ? ShelfTheme.reviewAccent : ShelfTheme.text)
            Text(lab.scenario.explanation).font(.callout).foregroundStyle(ShelfTheme.secondary)
            if let correct = lab.scenario.choices.first(where: { $0.id == lab.scenario.correctChoiceID }) {
                Text("Correct outcome: \(correct.text)").font(.callout.weight(.semibold)).foregroundStyle(ShelfTheme.text)
            }
        }
        .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
    }

    private func commit() {
        guard let selectedID else { return }
        withAnimation(reduceMotion ? nil : LearningTokens.Motion.reveal) { committed = true }
        ShelfHaptics.shared.play(selectedID == lab.scenario.correctChoiceID ? .answerCorrect : .answerIncorrect)
    }
}
