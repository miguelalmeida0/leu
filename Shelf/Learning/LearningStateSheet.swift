import SwiftUI
import ShelfCore
/// One calm Progress surface with current state and understanding history.
@MainActor
struct LearningStateSheet: View {
    @Bindable var model: LearningModel
    let onDone: () -> Void
    @State private var view: ProgressView = .now
    private enum ProgressView: String, CaseIterable {
        case now = "Now"
        case history = "History"
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PROGRESS")
                        .font(ShelfTheme.eyebrow())
                        .tracking(2.0)
                        .foregroundStyle(ShelfTheme.olive)
                    Text("Your understanding")
                        .leuScaledFont(28, weight: .regular, design: .serif)
                        .foregroundStyle(ShelfTheme.text)
                        .accessibilityLabel("Your understanding")
                        .accessibilityAddTraits(.isHeader)
                }
                Spacer()
                Button("Done", action: onDone)
                    .font(.system(.callout, design: .serif).weight(.semibold))
                    .foregroundStyle(ShelfTheme.action)
                    .frame(minWidth: 52, minHeight: 44)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("progress-done")
            }
            .padding(.horizontal, ShelfTheme.gutter)
            .padding(.top, 18)
            .padding(.bottom, 12)
            progressTabs
                .padding(.horizontal, ShelfTheme.gutter)
                .padding(.bottom, 12)
            Divider().overlay(ShelfTheme.line)
            if view == .now { nowContent }
            else { historyContent }
        }
        .background(ShelfTheme.background.ignoresSafeArea())
        .onAppear { StudyInteractionTrace.record("surface.progress.appeared") }
    }
    private var progressTabs: some View {
        HStack(spacing: 8) {
            progressTab(.now, identifier: "progress-tab-now")
            progressTab(.history, identifier: "progress-tab-history")
        }
    }
    private func progressTab(_ tab: ProgressView, identifier: String) -> some View {
        let selected = view == tab
        return Button {
            StudyInteractionTrace.record("activate.progress-tab-\(tab.rawValue.lowercased())")
            withAnimation(ShelfMotion.gentle) { view = tab }
            ShelfHaptics.shared.play(.selectionChanged)
        } label: {
            Text(tab.rawValue)
                .font(.system(.callout, design: .serif).weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 42)
                .foregroundStyle(selected ? LeuDesign.onSignal : ShelfTheme.text)
                .background(selected ? ShelfTheme.olive : ShelfTheme.surface,
                            in: RoundedRectangle(cornerRadius: ShelfTheme.smallRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: ShelfTheme.smallRadius)
                        .stroke(selected ? ShelfTheme.olive : LeuDesign.separator, lineWidth: 0.7)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.rawValue)
        .accessibilityValue(selected ? "Selected" : "")
        .accessibilityIdentifier(identifier)
    }
    private var nowContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("What you are strengthening")
                        .font(LearningTokens.Typography.title)
                        .accessibilityIdentifier("progress-now-view")
                    Text("Your own study attempts determine what should return next. No public scoring or ranking is used.")
                        .font(.callout)
                        .foregroundStyle(ShelfTheme.secondary)
                }
                if model.visibleTopics.isEmpty {
                    Text("Study a PDF and Leu will build this view from your local learning history.")
                        .font(.body)
                        .foregroundStyle(ShelfTheme.secondary)
                } else {
                    ForEach(model.visibleTopics) { topic in
                        topicRow(topic)
                        Divider().overlay(ShelfTheme.line)
                    }
                }
            }
            .padding(ShelfTheme.gutter)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .clipped()
        .accessibilityIdentifier("progress-now-scroll").background { UITestFrameProbe(identifier: "progress-now-scroll-frame") }
    }
    private var historyContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("UNDERSTANDING TIME MACHINE")
                        .font(ShelfTheme.eyebrow()).tracking(1.8).foregroundStyle(ShelfTheme.olive)
                        .accessibilityIdentifier("progress-history-view")
                    Text("See how your thinking evolves.")
                        .leuScaledFont(27, weight: .regular, design: .serif)
                    Text("Earlier attempts and notes stay attached to the source that shaped them.")
                        .font(.system(.callout, design: .serif)).foregroundStyle(ShelfTheme.secondary)
                }
                .padding(.top, 18).padding(.bottom, 16)
                if groupedDays.isEmpty {
                    Text("Your learning history will appear here after you study or mark source material.")
                        .font(.callout)
                        .foregroundStyle(ShelfTheme.secondary)
                        .padding(.vertical, 18)
                } else {
                    ForEach(groupedDays) { group in
                        Text(group.title)
                            .font(LearningTokens.Typography.compactTitle)
                            .padding(.top, 18)
                            .padding(.bottom, 8)
                        ForEach(group.events) { event in
                            Button {
                                if let source = event.source { model.openSource(source) }
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    Circle().fill(dotColor(event.kind)).frame(width: 7, height: 7).padding(.top, 7)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(event.title).foregroundStyle(ShelfTheme.text).lineLimit(2)
                                        Text(event.kind.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                            .font(.caption).foregroundStyle(ShelfTheme.secondary)
                                    }
                                    Spacer()
                                    Text(event.occurredAt, style: .time)
                                        .font(.caption).foregroundStyle(ShelfTheme.secondary)
                                }
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("progress-event-\(event.kind.rawValue)-\(event.id.uuidString)")
                            Divider().overlay(ShelfTheme.line)
                        }
                    }
                }
            }
            .padding(.horizontal, ShelfTheme.gutter)
            .padding(.bottom, 30)
        }
        .clipped()
        .accessibilityIdentifier("progress-history-scroll")
        .background { UITestFrameProbe(identifier: "progress-history-scroll-frame") }
    }
    private func topicRow(_ topic: LearningTopic) -> some View {
        let state = model.mastery(topic: topic)
        return Button {
            StudyInteractionTrace.record("activate.progress-recall")
            model.startActiveRecall(topicID: topic.id)
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .firstTextBaseline) {
                    Text(topic.name).font(LearningTokens.Typography.compactTitle).foregroundStyle(ShelfTheme.text)
                    Spacer()
                    Text(stateLabel(state.state)).font(.callout.weight(.semibold)).foregroundStyle(ShelfTheme.accent)
                }
                HStack(spacing: 14) {
                    metric("Objects", state.encounters)
                    metric("Attempts", state.attempts)
                    metric("Recalled", state.successfulRecalls)
                    if state.failedRecalls > 0 { metric("Forgot", state.failedRecalls) }
                }
                if let calibration = calibrationCopy(state), state.attempts > 0 {
                    Text(calibration).font(.caption).foregroundStyle(ShelfTheme.secondary)
                }
                if let due = state.nextReviewAt {
                    Text(dueCopy(due)).font(.caption).foregroundStyle(ShelfTheme.secondary)
                }
            }
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("progress-topic-\(topic.id.uuidString)")
        .disabled(!model.snapshot.learningObjects.contains { $0.topicIDs.contains(topic.id) })
        .accessibilityLabel("\(topic.name), \(stateLabel(state.state)), \(state.attempts) attempts")
        .accessibilityHint("Starts active recall for this topic")
    }
    private func metric(_ title: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)").font(.callout.monospacedDigit().weight(.semibold)).foregroundStyle(ShelfTheme.text)
            Text(title).font(.caption2).foregroundStyle(ShelfTheme.secondary)
        }
    }
    private func stateLabel(_ state: MasteryState) -> String {
        switch state {
        case .new: return "New"
        case .learning: return "Learning"
        case .strengthening: return "Strengthening"
        case .durable: return "Durable"
        case .due: return "Due"
        case .fading: return "Fading"
        }
    }
    private func calibrationCopy(_ state: TopicLearningState) -> String? {
        guard state.attempts >= 2 else { return nil }
        if state.calibrationDelta > 0.22 { return "Your confidence has been running ahead of recall here. Worth another look." }
        if state.calibrationDelta < -0.22 { return "Your recall has been stronger than your confidence suggests." }
        return "Confidence and recall have been broadly aligned."
    }
    private func dueCopy(_ date: Date) -> String {
        let calendar = Calendar.current
        if date <= Date() { return "Ready for another recall" }
        if calendar.isDateInTomorrow(date) { return "Next recall tomorrow" }
        return "Next recall " + date.formatted(date: .abbreviated, time: .omitted)
    }
    private var groupedDays: [ProgressDayGroup] {
        let formatter = DateFormatter(); formatter.dateStyle = .medium
        let calendar = Calendar.current
        let sorted = model.snapshot.timeline.sorted { $0.occurredAt > $1.occurredAt }
        let grouped = Dictionary(grouping: sorted) { dayTitle(for: $0.occurredAt, calendar: calendar, formatter: formatter) }
        var seen = Set<String>()
        return sorted.compactMap { event in
            let title = dayTitle(for: event.occurredAt, calendar: calendar, formatter: formatter)
            guard seen.insert(title).inserted else { return nil }
            return ProgressDayGroup(title: title, events: grouped[title] ?? [])
        }
    }
    private func dayTitle(for date: Date, calendar: Calendar, formatter: DateFormatter) -> String {
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return formatter.string(from: date)
    }
    private func dotColor(_ kind: TimelineEventKind) -> Color {
        switch kind {
        case .forgot: return ShelfTheme.danger
        case .recalled, .learned: return ShelfTheme.reviewAccent
        default: return ShelfTheme.accent
        }
    }
}
private struct ProgressDayGroup: Identifiable {
    let title: String
    let events: [LearningTimelineEvent]
    var id: String { title }
}
