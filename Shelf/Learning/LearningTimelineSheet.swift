import SwiftUI
import ShelfCore

@MainActor
struct LearningTimelineSheet: View {
    @Bindable var model: LearningModel

    var body: some View {
        ShelfSheet(title: "Progress History") {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("UNDERSTANDING TIME MACHINE")
                            .font(ShelfTheme.eyebrow()).tracking(1.8).foregroundStyle(ShelfTheme.olive)
                        Text("See how your thinking evolves.")
                            .leuScaledFont(27, weight: .regular, design: .serif)
                        Text("Earlier attempts and notes stay attached to the source that shaped them.")
                            .font(.system(.callout, design: .serif)).foregroundStyle(ShelfTheme.secondary)
                    }
                    .padding(.top, 18).padding(.bottom, 16)
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
                                    Circle()
                                        .fill(dotColor(event.kind))
                                        .frame(width: 7, height: 7)
                                        .padding(.top, 7)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(event.title)
                                            .foregroundStyle(ShelfTheme.text)
                                            .lineLimit(2)
                                        Text(event.kind.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                            .font(.caption)
                                            .foregroundStyle(ShelfTheme.secondary)
                                    }
                                    Spacer()
                                    Text(event.occurredAt, style: .time)
                                        .font(.caption)
                                        .foregroundStyle(ShelfTheme.secondary)
                                }
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                            Divider().overlay(ShelfTheme.line)
                        }
                    }
                }
                .padding(.horizontal, ShelfTheme.gutter)
                .padding(.bottom, 30)
            }
        }
    }

    private var groupedDays: [TimelineDayGroup] {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let calendar = Calendar.current
        let sorted = model.snapshot.timeline.sorted { $0.occurredAt > $1.occurredAt }
        let grouped = Dictionary(grouping: sorted) { dayTitle(for: $0.occurredAt, calendar: calendar, formatter: formatter) }

        var seen = Set<String>()
        return sorted.compactMap { event in
            let title = dayTitle(for: event.occurredAt, calendar: calendar, formatter: formatter)
            guard seen.insert(title).inserted else { return nil }
            return TimelineDayGroup(title: title, events: grouped[title] ?? [])
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

private struct TimelineDayGroup: Identifiable {
    let title: String
    let events: [LearningTimelineEvent]
    var id: String { title }
}
