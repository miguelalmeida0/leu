import SwiftUI
import ShelfCore

/// Open recall.
///
/// Honest about what exists today: typing is always available, and there is no transcript
/// field and no microphone waveform because Leu does not transcribe speech. Revealing the
/// source and rating recall stay two separate operations, and admitting a gap sits at the
/// same weight as answering.
@MainActor
struct RecallCardView: View {
    @Bindable var model: LearningModel
    @State private var revealed = false
    @FocusState private var typing: Bool

    var body: some View {
        if let object = model.currentObject {
            VStack(alignment: .leading, spacing: 22) {
                task(object)
                if !revealed { attempt } else { comparison(object) }
            }
            .background { UITestFrameProbe(identifier: "recall-card") }
            .onAppear {
                #if DEBUG
                StudyInteractionTrace.record("study.recall object=\(object.id) document=\(object.source.documentID) page=\(object.source.pageIndex + 1) source=\(object.source.sourceText)")
                #endif
            }
            .onChange(of: object.id) { _, _ in
                revealed = false // The model resets recall input when it advances the activity.
            }
        } else {
            Button("Continue") { model.advance() }.buttonStyle(ShelfButtonStyle(filled: true))
        }
    }

    private func task(_ object: LearningObject) -> some View {
        let prompt = object.prompt ?? object.title
        // A heading segment records itself as its own section title, which printed
        // the same sentence twice: once as the eyebrow, once as the prompt.
        let label = object.source.sectionTitle.flatMap { section -> String? in
            let a = section.trimmingCharacters(in: .whitespacesAndNewlines)
            let b = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            return a.isEmpty || a.caseInsensitiveCompare(b) == .orderedSame ? nil : section
        } ?? "Active recall"
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(label)
                Text("· p. \(object.source.pageIndex + 1)")
                    .accessibilityIdentifier("recall-source-page")
            }
            .font(ShelfTheme.eyebrow(10)).tracking(1.2).foregroundStyle(ShelfTheme.accent)
            Text(prompt)
                .font(LearningTokens.Typography.title)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("recall-prompt")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(LeuDesign.surfaceSecondary,
                    in: RoundedRectangle(cornerRadius: ShelfTheme.radius, style: .continuous))
    }

    private var attempt: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Reconstruct the idea in your own words before you look.")
                .font(.callout).foregroundStyle(ShelfTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)

            TextEditor(text: $model.recallDraft)
                .focused($typing)
                .font(.system(.body, design: .serif))
                .foregroundStyle(ShelfTheme.text)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 120)
                .padding(10)
                .background(LeuDesign.fieldSurface,
                            in: RoundedRectangle(cornerRadius: ShelfTheme.smallRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: ShelfTheme.smallRadius, style: .continuous)
                        .stroke(typing ? ShelfTheme.accent : ShelfTheme.line, lineWidth: typing ? 1.4 : 0.7)
                }
                .disabled(model.recallMarkedUnknown)
                .accessibilityLabel("Your answer")
                .accessibilityIdentifier("recall-typed-answer")

            Button {
                model.recallMarkedUnknown.toggle()
                if model.recallMarkedUnknown { typing = false }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: model.recallMarkedUnknown ? "checkmark.circle.fill" : "circle")
                    Text("I don't know yet").font(.callout.weight(.semibold))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(model.recallMarkedUnknown ? ShelfTheme.accent : ShelfTheme.secondary)
                .padding(13)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .background(ShelfTheme.surface,
                            in: RoundedRectangle(cornerRadius: ShelfTheme.smallRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: ShelfTheme.smallRadius, style: .continuous)
                        .stroke(model.recallMarkedUnknown ? ShelfTheme.accent : ShelfTheme.line,
                                lineWidth: model.recallMarkedUnknown ? 1.4 : 0.7)
                }
                .contentShape([.interaction, .accessibility], Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("recall-dont-know")
            .accessibilityAddTraits(model.recallMarkedUnknown ? .isSelected : [])

            Button("Reveal source") { revealed = true; typing = false; model.play(.sourceRevealed) }
                .buttonStyle(ShelfButtonStyle(filled: true))
                .accessibilityIdentifier("recall-reveal-source")
        }
    }

    /// Your words beside the page's words. Leu does not evaluate the answer, so nothing
    /// here claims the attempt was right or wrong: the learner decides that below.
    private func comparison(_ object: LearningObject) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            if model.recallMarkedUnknown || !model.recallDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    label("Your answer")
                    Text(model.recallMarkedUnknown ? "You marked this one as not known yet." : model.recallDraft)
                        .font(.system(.body)).foregroundStyle(ShelfTheme.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("recall-your-answer")
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                label("From your source")
                Text(object.source.sourceText)
                    .accessibilityIdentifier("recall-source-quote")
                    .font(.system(.title3, design: .serif)).lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 14)
                    .overlay(alignment: .leading) { Rectangle().fill(ShelfTheme.accent).frame(width: 2) }
            }
            Button("View in PDF") { model.openSource(object.source) }
                .buttonStyle(ShelfButtonStyle())
                .accessibilityIdentifier("recall-view-source")
            VStack(alignment: .leading, spacing: 10) {
                label("How did recall feel?")
                Text("Your own read on it. This schedules the next visit; it does not mark the answer.")
                    .font(.caption).foregroundStyle(ShelfTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    rate("Forgot", .forgot); rate("Difficult", .difficult); rate("Knew it", .knewIt)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(LeuDesign.surfaceSecondary,
                    in: RoundedRectangle(cornerRadius: ShelfTheme.radius, style: .continuous))
    }

    private func label(_ text: String) -> some View {
        Text(text.uppercased())
            .font(ShelfTheme.eyebrow(10)).tracking(1.4).foregroundStyle(ShelfTheme.secondary)
    }

    private func rate(_ title: String, _ rating: RecallRating) -> some View {
        Button(title) { Task { await model.rateCurrent(rating) } }
            .accessibilityIdentifier("recall-rating-" + rating.rawValue)
            .buttonStyle(ShelfButtonStyle(filled: rating == .knewIt)).frame(maxWidth: .infinity)
    }
}
