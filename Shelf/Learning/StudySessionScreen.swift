import SwiftUI
import ShelfCore

@MainActor
struct StudySessionScreen: View {
    @Bindable var model: LearningModel

    var body: some View {
        VStack(spacing: 0) {
            sessionHeader
            Divider().overlay(ShelfTheme.line)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    activityBody
                }
                .padding(.horizontal, ShelfTheme.gutter).padding(.vertical, 24)
                .frame(maxWidth: 720).frame(maxWidth: .infinity)
            }
            .background { UITestFrameProbe(identifier: "study-activity-frame") }
        }
        .background { UITestFrameProbe(identifier: "study-session-screen") }
        .onAppear { StudyInteractionTrace.record("surface.study-session.appeared") }
    }

    private var sessionHeader: some View {
        HStack(spacing: 14) {
            Button { model.endSession() } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }
                .accessibilityLabel("End study session")
            VStack(alignment: .leading, spacing: 2) {
                Text(model.activeSession?.mode == .interview ? "INTERVIEW" : "STUDY")
                    .font(ShelfTheme.eyebrow(9)).tracking(1.6).foregroundStyle(ShelfTheme.secondary)
                Text(progressText).font(.system(.callout, design: .serif).monospacedDigit().weight(.medium))
                    .accessibilityIdentifier("study-progress")
                Text(model.studySaveError != nil ? "Not saved" : (model.isSavingStudyState ? "Saving…" : "Saved"))
                    .font(.caption2).foregroundStyle(ShelfTheme.secondary)
                    .accessibilityIdentifier("study-save-status")
            }
            Spacer()
            if let session = model.activeSession {
                Text("~\(session.requestedMinutes) min").font(.system(.callout, design: .serif)).foregroundStyle(ShelfTheme.secondary)
            }
        }.padding(.horizontal, 12).frame(minHeight: 58)
    }

    private var progressText: String {
        let total = max(1, model.activeSession?.activities.count ?? 1)
        return "\(min(model.activityIndex + 1, total)) of \(total)"
    }

    @ViewBuilder
    private var activityBody: some View {
        if let activity = model.currentActivity {
            switch activity.kind {
            case .question:
                QuestionCardView(model: model)
            case .recall:
                RecallCardView(model: model)
            case .mask:
                DiagramRecallStudyView(model: model)
            case .reconstruction:
                SessionLabActivity(model: model)
            case .explain:
                RecallCardView(model: model)
            case .continueReading:
                ContinueReadingActivity(model: model)
            }
        } else {
            VStack(alignment: .leading, spacing: 14) {
                Text("No study material is available for this session yet.")
                    .foregroundStyle(ShelfTheme.secondary)
                Button("Done") { model.endSession() }
                    .buttonStyle(ShelfButtonStyle(filled: true))
            }
        }
    }
}
