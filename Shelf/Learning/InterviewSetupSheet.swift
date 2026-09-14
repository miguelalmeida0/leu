import SwiftUI
import ShelfCore

@MainActor
struct InterviewSetupSheet: View {
    @Bindable var model: LearningModel
    @Environment(\.dismiss) private var dismiss
    @State private var topicID: UUID?
    @State private var choice: Choice = .ten
    enum Choice: String, CaseIterable { case ten = "10 questions", twenty = "20 questions", due = "All due" }

    var body: some View {
        ShelfSheet(title: "Interview Mode") {
            Form {
                Section("Subject") {
                    Picker("Subject", selection: $topicID) {
                        Text("All topics").tag(UUID?.none)
                        ForEach(model.visibleTopics) { topic in Text(topic.name).tag(UUID?.some(topic.id)) }
                    }.pickerStyle(.inline)
                }
                Section("Session") {
                    Picker("Questions", selection: $choice) { ForEach(Choice.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                        .pickerStyle(.inline)
                }
                Section {
                    Text("Answers stay hidden until you commit. Confidence is sampled more often, and source links appear after answering.")
                        .font(.callout).foregroundStyle(ShelfTheme.secondary)
                }
            }.scrollContentBackground(.hidden)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    Button {
                        let count = choice == .ten ? 10 : (choice == .twenty ? 20 : nil)
                        model.startInterview(topicID: topicID, questionCount: count); dismiss()
                    } label: {
                        Text("Start interview").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ShelfButtonStyle(filled: true))
                    .accessibilityIdentifier("start-interview")
                    .padding(.horizontal, ShelfTheme.gutter)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(ShelfTheme.background)
                }
        }
    }
}
