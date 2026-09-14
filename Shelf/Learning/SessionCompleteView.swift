import SwiftUI
import ShelfCore
@MainActor
struct SessionCompleteView: View {
    @Bindable var model: LearningModel
    var body: some View {
        Group {
            if model.releasePresented {
                ReleaseSurface(onRelease: { model.play(.selectionChanged) },
                               onContinue: closeRelease, onEnd: finishSession)
            } else {
                summaryContent
            }
        }
        .background(ShelfTheme.background)
        .background { UITestFrameProbe(identifier: "session-summary-frame") }
        .background { UITestFrameProbe(identifier: "session-complete-screen") }
    }
    private var summaryContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                sessionOverview
                if !practiced.isEmpty { practisedSection }
                if !revisit.isEmpty { revisitSection }
                if model.shouldOfferEmotionalCheckIn || model.selectedFeeling != nil { emotionalCheckIn }
                actions
            }
            .padding(ShelfTheme.gutter)
            .padding(.top, 18)
            .frame(maxWidth: 720).frame(maxWidth: .infinity)
        }
        .background(ShelfTheme.background)
    }
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SESSION COMPLETE")
                .font(ShelfTheme.eyebrow()).tracking(2.5).foregroundStyle(ShelfTheme.olive)
            Text(headline)
                .leuScaledFont(38, weight: .regular, design: .serif)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("session-summary-headline")
        }
    }
    /// States what the session recorded, with no adjective attached to it.
    private var headline: String {
        switch activityCount {
        case 0: return "Nothing was recorded this time."
        case 1: return "One activity completed."
        default: return "\(activityCount) activities completed."
        }
    }
    /// Counts only. `knewItCount` is what the learner said, not a measure of memory,
    /// so the label says so.
    private var sessionOverview: some View {
        VStack(spacing: 0) {
            overviewRow(symbol: "checkmark.circle", title: "You said you knew", value: "\(knewItCount)")
            Divider().overlay(ShelfTheme.line)
            overviewRow(symbol: "arrow.clockwise", title: "Marked for another pass", value: "\(revisit.count)")
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("session-summary-overview")
    }
    private func overviewRow(symbol: String, title: String, value: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).frame(width: 28).foregroundStyle(ShelfTheme.accent)
            Text(title).font(.system(.body)).foregroundStyle(ShelfTheme.text)
            Spacer()
            Text(value).font(.system(.callout).monospacedDigit()).foregroundStyle(ShelfTheme.secondary)
        }
        .frame(minHeight: 54)
        .accessibilityElement(children: .combine)
    }
    private var recentAttempts: [LearningAttempt] {
        let since = model.sessionStartedAt ?? .distantPast
        return Array(model.snapshot.attempts.filter { $0.occurredAt >= since }
            .sorted { $0.occurredAt > $1.occurredAt }.prefix(12))
    }
    /// Distinct items attempted in this session, newest first.
    private var practiced: [LearningAttempt] {
        var seen = Set<UUID>()
        return recentAttempts.filter { seen.insert($0.learningObjectID).inserted }
    }
    /// Only what the learner or the engine actually marked: a self-reported miss, or a
    /// recorded wrong answer. Nothing is inferred.
    private var revisit: [LearningAttempt] {
        practiced.filter { $0.rating != .knewIt || $0.wasCorrect == false }
    }
    private var practisedSection: some View {
        section("What you practised", rows: practiced, identifier: "session-summary-practised")
    }
    private var revisitSection: some View {
        section("Coming back", rows: revisit, identifier: "session-summary-revisit")
    }
    private func section(_ title: String, rows: [LearningAttempt], identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(ShelfTheme.eyebrow(10)).tracking(1.8).foregroundStyle(ShelfTheme.secondary)
                .padding(.bottom, 8)
            ForEach(rows) { attempt in
                HStack(alignment: .top, spacing: 12) {
                    Rectangle()
                        .fill(stateColor(attempt))
                        .frame(width: 2, height: 38)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(objectTitle(attempt.learningObjectID))
                            .font(.system(.body)).lineLimit(2)
                        Text(topicLabel(attempt.learningObjectID))
                            .font(.caption).foregroundStyle(ShelfTheme.secondary)
                    }
                    Spacer(minLength: 10)
                    Text(stateLabel(attempt))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(stateColor(attempt))
                        .multilineTextAlignment(.trailing)
                }
                .padding(.vertical, 12)
                .accessibilityElement(children: .combine)
                Divider().overlay(ShelfTheme.line)
            }
        }
        .accessibilityIdentifier(identifier)
    }
    /// One primary next action, one secondary route back. Revisiting what the learner
    /// just missed outranks reading on, and when there is neither, no primary appears
    /// rather than a button that does nothing meaningful.
    private var actions: some View {
        VStack(spacing: 10) {
            if !revisit.isEmpty {
                Button("Review what you marked") { startDifficult() }
                    .buttonStyle(ShelfButtonStyle(filled: true))
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("session-summary-primary")
            } else if let source = lastSessionSource {
                Button("Continue reading") { model.openSource(source) }
                    .buttonStyle(ShelfButtonStyle(filled: true))
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("session-summary-primary")
            }
            Button(action: finishSession) {
                // The shape goes on the label: a bare Text in a .plain button exports its
                // glyph box as the accessibility frame, which is smaller than the target.
                Text("Back to Study")
                    .font(.system(.callout))
                    .foregroundStyle(ShelfTheme.secondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape([.interaction, .accessibility], Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("session-summary-done")
        }
    }
    @ViewBuilder
    private var emotionalCheckIn: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let feeling = model.selectedFeeling {
                emotionalResponse(feeling)
            } else {
                Text("How did that one feel?")
                    .leuScaledFont(28, weight: .regular, design: .serif)
                Text("Optional. Leu only stores the feeling you choose on this device.")
                    .font(.caption).foregroundStyle(ShelfTheme.secondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(StudyFeeling.allCases, id: \.self) { feeling in
                        Button(feeling.displayName) { Task { await model.recordFeeling(feeling) } }
                            .buttonStyle(ShelfButtonStyle())
                            .accessibilityIdentifier("feeling-" + feeling.rawValue)
                    }
                }
            }
        }
        .padding(18)
        .background(ShelfTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .background { UITestFrameProbe(identifier: "emotional-check-in") }
    }
    @ViewBuilder
    private func emotionalResponse(_ feeling: StudyFeeling) -> some View {
        switch feeling {
        case .amazing:
            Text("Keep going while the idea is alive.").leuScaledFont(25, weight: .regular, design: .serif)
            Button("Keep going") { startDifficult() }.buttonStyle(ShelfButtonStyle(filled: true))
        case .accomplished:
            Text(concreteAccomplishment).leuScaledFont(25, weight: .regular, design: .serif)
            Button("Done", action: finishSession).buttonStyle(ShelfButtonStyle(filled: true))
        case .irritated:
            Text("Get it out?").leuScaledFont(25, weight: .regular, design: .serif)
            VStack(alignment: .leading, spacing: 10) {
                Button("Release") { model.releasePresented = true }
                    .buttonStyle(ShelfButtonStyle(filled: true))
                    .accessibilityIdentifier("check-in-open-release")
                Button("Continue") { model.selectedFeeling = nil }
                    .buttonStyle(ShelfButtonStyle())
                    .accessibilityIdentifier("check-in-continue")
                Button(action: finishSession) {
                    Text("I'm done").frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("check-in-done")
            }
        case .drained:
            Text("You can stop here. Your place is saved.").leuScaledFont(25, weight: .regular, design: .serif)
            VStack(alignment: .leading, spacing: 10) {
                Button("Save my place", action: finishSession)
                    .buttonStyle(ShelfButtonStyle(filled: true))
                    .accessibilityIdentifier("check-in-save-place")
                Button("Finish here", action: finishSession)
                    .buttonStyle(ShelfButtonStyle())
                    .accessibilityIdentifier("check-in-finish-here")
            }
            .disabled(model.isSavingStudyState)
        }
    }
    private var concreteAccomplishment: String {
        let correct = recentAttempts.filter { $0.wasCorrect == true }.count
        return correct > 0 ? "You answered \(correct) source-bound question\(correct == 1 ? "" : "s") correctly." : "You completed this study round."
    }
    private func closeRelease() {
        model.releasePresented = false
        model.selectedFeeling = nil
    }
    private func finishSession() {
        // Keep the summary available until its ordered checkpoint has been acknowledged.
        let finishingSessionID = model.activeSession?.id
        model.persistStudyState()
        Task {
            await model.studySaveTask?.value
            guard model.activeSession?.id == finishingSessionID, !model.isSavingStudyState else { return }
            guard model.studySaveError == nil else { return }
            model.endSession()
        }
    }
    private var activityCount: Int { model.activeSession?.activities.count ?? recentAttempts.count }
    /// What the learner reported, not a measure of retention.
    private var knewItCount: Int { practiced.filter { $0.rating == .knewIt && $0.wasCorrect != false }.count }
    private var lastSessionSource: LearningSource? {
        guard let session = model.activeSession else { return nil }
        for activity in session.activities.reversed() {
            if let id = activity.learningObjectID,
               let object = model.snapshot.learningObjects.first(where: { $0.id == id }) {
                return object.source
            }
        }
        return nil
    }
    private func objectTitle(_ id: UUID) -> String {
        model.snapshot.learningObjects.first(where: { $0.id == id })?.title ?? "Learning item"
    }
    private func topicLabel(_ id: UUID) -> String {
        guard let object = model.snapshot.learningObjects.first(where: { $0.id == id }) else { return "Source" }
        let names = object.topicIDs.compactMap { topicID in model.snapshot.topics.first(where: { $0.id == topicID })?.name }
        return names.prefix(2).joined(separator: " · ").isEmpty ? "Source" : names.prefix(2).joined(separator: " · ")
    }
    private var difficultObjectIDs: [UUID] {
        let since = model.sessionStartedAt ?? .distantPast
        return model.snapshot.attempts.filter { attempt in
            attempt.occurredAt >= since && (attempt.rating != .knewIt || attempt.wasCorrect == false)
        }.sorted { $0.occurredAt > $1.occurredAt }
            .reduce(into: [UUID]()) { ids, attempt in
                if !ids.contains(attempt.learningObjectID) { ids.append(attempt.learningObjectID) }
            }
    }
    private func stateLabel(_ attempt: LearningAttempt) -> String {
        if attempt.confidence == .certain && attempt.wasCorrect == false { return "Confident miss" }
        switch attempt.rating {
        case .forgot: return "Forgot"
        case .difficult: return "Difficult"
        case .knewIt: return "Knew it"
        }
    }
    private func stateColor(_ attempt: LearningAttempt) -> Color {
        attempt.rating == .knewIt ? ShelfTheme.olive : ShelfTheme.accent
    }
    private func startDifficult() {
        let ids = difficultObjectIDs
        model.endSession()
        model.startReview(objectIDs: ids)
    }
}
