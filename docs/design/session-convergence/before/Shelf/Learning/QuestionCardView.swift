import SwiftUI
import ShelfCore

@MainActor
struct QuestionCardView: View {
    @ScaledMetric(relativeTo: .callout) private var optionDiameter: CGFloat = 30
    @Bindable var model: LearningModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .callout) private var confidenceMinimumWidth = 100.0

    var body: some View {
        if let question = model.currentQuestion {
            VStack(alignment: .leading, spacing: 24) {
                sourceLabel(question)
                Text(question.prompt).accessibilityIdentifier("question-prompt")
                    .leuScaledFont(30, weight: .regular, design: .serif)
                    .fixedSize(horizontal: false, vertical: true)
                confidencePicker
                options(question)
                if model.answerCommitted { revealed(question) }
                else { preCommit(question) }
            }
            .background { UITestFrameProbe(identifier: "question-card") }
            .background {
                if question.modelProvenance != nil {
                    UITestFrameProbe(identifier: "study-model-question-page-\(question.source.pageIndex + 1)")
                }
            }
            .onAppear { StudyInteractionTrace.record("study.questionCard question=\(question.id) document=\(question.source.documentID) page=\(question.source.pageIndex + 1) backend=\(question.modelProvenance?.backend ?? "deterministic")") }
        } else {
            Text("This question is no longer available.").foregroundStyle(ShelfTheme.secondary)
            Button("Continue") { model.advance() }.buttonStyle(ShelfButtonStyle(filled: true))
        }
    }

    private func sourceLabel(_ question: LearningQuestion) -> some View {
        HStack(spacing: 8) {
            Text(question.source.sectionTitle ?? "Source question")
            Text("· p. \(question.source.pageIndex + 1)")
        }.font(ShelfTheme.eyebrow(10)).tracking(1.2).foregroundStyle(ShelfTheme.accent)
    }

    @ViewBuilder
    private var confidencePicker: some View {
        if shouldAskConfidence && !model.answerCommitted {
            VStack(alignment: .leading, spacing: 8) {
                Text("How sure are you?").font(.callout.weight(.semibold))
                confidenceOptions
            }
        }
    }

    /// Four equal-width chips at normal sizes. At accessibility sizes the row becomes
    /// full-width stacked chips, so longer labels get more room instead of smaller type.
    @ViewBuilder
    private var confidenceOptions: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 8) {
                ForEach(ConfidenceLevel.allCases, id: \.self) { confidenceChip($0) }
            }
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    ForEach(ConfidenceLevel.allCases, id: \.self) { confidenceChip($0).frame(minWidth: confidenceMinimumWidth) }
                }
                VStack(spacing: 8) {
                    HStack(spacing: 8) { confidenceChip(.guessing); confidenceChip(.unsure) }
                    HStack(spacing: 8) { confidenceChip(.fairlySure); confidenceChip(.certain) }
                }.frame(minWidth: confidenceMinimumWidth * 2 + 8)
                VStack(spacing: 8) {
                    ForEach(ConfidenceLevel.allCases, id: \.self) { confidenceChip($0) }
                }
            }
        }
    }

    private func confidenceChip(_ level: ConfidenceLevel) -> some View {
        Button(level.displayName) {
            model.selectConfidence(level)
        }
        .buttonStyle(ConfidenceChipStyle(selected: model.selectedConfidence == level))
        .accessibilityIdentifier("question-confidence-" + level.rawValue)
        .accessibilityLabel(level.displayName)
        .accessibilityValue(model.selectedConfidence == level ? "Selected" : "Not selected")
    }

    private var shouldAskConfidence: Bool {
        model.activeSession?.mode == .interview || model.activityIndex.isMultiple(of: 3)
    }

    private func options(_ question: LearningQuestion) -> some View {
        VStack(spacing: 10) {
            ForEach(Array(question.options.enumerated()), id: \.element.id) { index, option in
                Button { model.selectAnswer(option.id) } label: {
                    HStack(alignment: .top, spacing: 13) {
                        Text(optionLetter(index))
                            .font(.system(.callout, design: .serif).weight(.semibold))
                            .foregroundStyle(optionAccent(option, question: question))
                            .frame(width: optionDiameter, height: optionDiameter)
                            .background(Color.clear, in: Circle())
                            .overlay { Circle().stroke(optionAccent(option, question: question), lineWidth: 0.8) }
                        Text(option.text).font(.system(.body, design: .serif)).multilineTextAlignment(.leading).foregroundStyle(ShelfTheme.text)
                        Spacer(minLength: 0)
                        if model.answerCommitted && option.id == question.correctOptionID {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(ShelfTheme.reviewAccent)
                        } else if model.answerCommitted && option.id == model.selectedAnswerID {
                            Image(systemName: "circle.slash").foregroundStyle(ShelfTheme.danger)
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                    .background(optionBackground(option, question: question), in: RoundedRectangle(cornerRadius: ShelfTheme.smallRadius))
                    .overlay(RoundedRectangle(cornerRadius: ShelfTheme.smallRadius).stroke(optionStroke(option, question: question), lineWidth: 0.8))
                }
                .accessibilityIdentifier("question-option-\(index)")
                .accessibilityLabel("Option \(optionLetter(index)). \(option.text)")
                .accessibilityHint(model.answerCommitted ? "Answer already committed" : "Select this answer")
                .accessibilityValue(model.selectedAnswerID == option.id ? "Selected" : "Not selected")
                .buttonStyle(PressScaleStyle(enabled: !reduceMotion))
                .disabled(model.answerCommitted)
            }
        }
    }

    @ViewBuilder
    private func preCommit(_ question: LearningQuestion) -> some View {
        if !model.progressiveHints().isEmpty {
            hintStack
        }
        HStack {
            Button("Hint") { model.revealNextHint() }.buttonStyle(ShelfButtonStyle())
            Spacer()
            Button("Commit answer") { model.commitAnswer() }
                .accessibilityIdentifier("commit-answer")
                .buttonStyle(ShelfButtonStyle(filled: true)).disabled(model.selectedAnswerID == nil)
        }
    }

    private func revealed(_ question: LearningQuestion) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if let explanation = question.modelProvenance?.explanation {
                Text(explanation).accessibilityIdentifier("question-explanation")
            }
            HStack(spacing: 10) {
                Image(systemName: model.selectedAnswerID == question.correctOptionID ? "checkmark.circle.fill" : "arrow.clockwise.circle")
                    .foregroundStyle(model.selectedAnswerID == question.correctOptionID ? ShelfTheme.olive : ShelfTheme.accent)
                Text(model.selectedAnswerID == question.correctOptionID ? "Correct" : "Look once more")
                    .leuScaledFont(24, weight: .regular, design: .serif)
            }
            Text(question.source.sourceText)
                .accessibilityIdentifier("question-supporting-quote")
                .font(.system(.body, design: .serif)).foregroundStyle(ShelfTheme.text)
                .lineSpacing(4)
                .padding(.leading, 14)
                .overlay(alignment: .leading) { Rectangle().fill(ShelfTheme.accent).frame(width: 2) }
            Button("View source") { model.openSource(question.source) }
                .buttonStyle(ShelfButtonStyle()).accessibilityIdentifier("view-question-source")
            judgement
        }
    }

    private var hintStack: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(model.progressiveHints()) { hint in
                Text(hint.text).font(.callout).foregroundStyle(ShelfTheme.secondary)
                    .padding(.vertical, 4)
            }
        }
    }

    private var judgement: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("HOW DID RECALL FEEL?").font(ShelfTheme.eyebrow(10)).tracking(1.5).foregroundStyle(ShelfTheme.secondary)
            HStack(spacing: 8) {
                rating("Forgot", .forgot)
                rating("Difficult", .difficult)
                rating("Knew it", .knewIt)
            }
        }
    }

    private func rating(_ title: String, _ rating: RecallRating) -> some View {
        Button(title) { Task { await model.rateCurrent(rating) } }
            .accessibilityIdentifier("recall-rating-" + rating.rawValue)
            .buttonStyle(ShelfButtonStyle(filled: rating == .knewIt))
            .frame(maxWidth: .infinity)
    }

    private func optionLetter(_ index: Int) -> String {
        guard index >= 0, index < 26, let scalar = UnicodeScalar(65 + index) else { return "•" }
        return String(Character(scalar))
    }

    private func optionBackground(_ option: QuestionOption, question: LearningQuestion) -> Color {
        if model.answerCommitted && option.id == question.correctOptionID { return ShelfTheme.reviewBackground }
        if model.answerCommitted && option.id == model.selectedAnswerID { return ShelfTheme.surface }
        return model.selectedAnswerID == option.id ? ShelfTheme.raised : ShelfTheme.surface
    }

    private func optionStroke(_ option: QuestionOption, question: LearningQuestion) -> Color {
        if model.answerCommitted && option.id == question.correctOptionID { return ShelfTheme.reviewAccent }
        return model.selectedAnswerID == option.id ? ShelfTheme.accent : ShelfTheme.line
    }

    private func optionAccent(_ option: QuestionOption, question: LearningQuestion) -> Color {
        if model.answerCommitted && option.id == question.correctOptionID { return ShelfTheme.reviewAccent }
        return model.selectedAnswerID == option.id ? ShelfTheme.accent : ShelfTheme.secondary
    }
}

private struct ConfidenceChipStyle: ButtonStyle {
    let selected: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(selected ? ShelfTheme.olive : ShelfTheme.surface, in: Capsule())
            .overlay { Capsule().stroke(selected ? ShelfTheme.olive : LeuDesign.separator, lineWidth: selected ? 1.4 : 0.7) }
            .foregroundStyle(selected ? LeuDesign.onSignal : ShelfTheme.text)
            .contentShape([.interaction, .accessibility], Capsule())
            
    }
}

private struct PressScaleStyle: ButtonStyle {
    let enabled: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(enabled && configuration.isPressed ? 0.985 : 1)
            .animation(enabled ? .spring(response: 0.18, dampingFraction: 0.86) : nil, value: configuration.isPressed)
    }
}
