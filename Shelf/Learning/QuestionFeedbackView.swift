import SwiftUI
import ShelfCore

/// What happened after the learner answered.
///
/// Split out of `QuestionCardView` so the question surface stays inside the 300-line
/// scrutiny boundary and so feedback can be reviewed on its own terms.
@MainActor
struct QuestionFeedbackView: View {
    @Bindable var model: LearningModel
    let question: LearningQuestion
    var onViewSource: ((LearningSource) -> Void)?

    /// Feedback as a comparison the learner can read, not a verdict banner.
    ///
    /// Grading is unchanged: correctness still comes from `question.correctOptionID`,
    /// which the engine owns. What changed is that the learner's own answer is placed
    /// beside the source instead of being replaced by a one-word judgement.
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            yourAnswer
            fromYourSource
            Button("View source") { if let onViewSource { onViewSource(question.source) } else { model.openSource(question.source) } }
                .buttonStyle(ShelfButtonStyle()).accessibilityIdentifier("view-question-source")
            QuestionConnectionsAction(learning: model, source: question.source)
            judgement
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(LeuDesign.surfaceSecondary,
                    in: RoundedRectangle(cornerRadius: ShelfTheme.radius, style: .continuous))
    }

    private var yourAnswer: some View {
        let chosen = question.options.first { $0.id == model.selectedAnswerID }
        let matchesSource = model.selectedAnswerID == question.correctOptionID
        return VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Your answer")
            Text(chosen?.text ?? "No answer was chosen.")
                .font(.system(.body)).foregroundStyle(ShelfTheme.text)
                .fixedSize(horizontal: false, vertical: true)
            Text(matchesSource
                 ? "This is the answer the page supports."
                 : "The page supports a different answer. Compare the two below.")
                .font(.caption).foregroundStyle(ShelfTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityIdentifier("question-your-answer")
    }

    private var fromYourSource: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("From your source")
            Text(question.source.sourceText)
                .accessibilityIdentifier("question-supporting-quote")
                .font(.system(.body, design: .serif)).foregroundStyle(ShelfTheme.text)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 14)
                .overlay(alignment: .leading) { Rectangle().fill(ShelfTheme.accent).frame(width: 2) }
            if let explanation = question.v4?.explanation ?? question.modelProvenance?.explanation {
                // This is the explanation generated for the QUESTION, not an assessment
                // of what the learner wrote. Leu does not evaluate open answers, so the
                // label says where the sentence came from rather than implying a verdict.
                VStack(alignment: .leading, spacing: 6) {
                    sectionLabel("Why this is the answer")
                    Text(explanation).accessibilityIdentifier("question-explanation")
                        .font(.callout).foregroundStyle(ShelfTheme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 4)
            }
        }
        .accessibilityIdentifier("question-from-source")
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(ShelfTheme.eyebrow(10)).tracking(1.4)
            .foregroundStyle(ShelfTheme.secondary)
    }


    private var judgement: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("How did recall feel?")
            Text("Your own read on it. This schedules the next visit; it does not mark the answer.")
                .font(.caption).foregroundStyle(ShelfTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
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
}
