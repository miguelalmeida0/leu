import SwiftUI
import ShelfCore

@MainActor
struct TrailsScreen: View {
    @Bindable var model: LearningModel
    @Bindable var knowledge: KnowledgeModel
    @State private var newTrailTitle = ""
    @State private var creating = false
    @State private var selectedTrail: LearningTrail?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    if model.snapshot.trails.isEmpty && knowledge.snapshot.topicChains.isEmpty {
                        emptyState
                    } else {
                        if !model.snapshot.trails.isEmpty { trailList }
                        TopicChainsSection(knowledge: knowledge)
                    }
                    Button { creating = true } label: {
                        HStack {
                            Text("New trail")
                            Spacer()
                            Image(systemName: "plus")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .accessibilityIdentifier("new-learning-trail")
                    .buttonStyle(ShelfButtonStyle(filled: true))
                }
                .padding(ShelfTheme.gutter)
                .padding(.top, 22)
                .padding(.bottom, 40)
                .frame(maxWidth: 760).frame(maxWidth: .infinity)
            }
            .background(ShelfTheme.background)
            .navigationDestination(item: $selectedTrail) { trail in TrailDetailScreen(model: model, trailID: trail.id) }
        }
        .task { await model.bootstrap() }
        .leuDialog("New trail", isPresented: $creating) {
            LeuTextField("Frontend interview", text: $newTrailTitle)
            Button("Create") { Task { await model.createTrail(title: newTrailTitle); newTrailTitle = "" } }
            Button("Cancel", role: .cancel) { newTrailTitle = "" }
        } message: {
            Text("Create one ordered path through books, passages and study material.")
        }
        .accessibilityIdentifier("trails-screen")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TRAILS")
                .font(ShelfTheme.eyebrow()).tracking(2.8).foregroundStyle(ShelfTheme.olive)
            Text("Ideas, across time.")
                .leuScaledFont(36, weight: .regular, design: .serif)
            Text("Keep related passages in an order that helps you think through them.")
                .font(.system(.callout, design: .serif).italic())
                .foregroundStyle(ShelfTheme.secondary)
            Rectangle().fill(ShelfTheme.line).frame(height: 0.5).padding(.top, 6)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No trails yet.").leuScaledFont(24, weight: .regular, design: .serif)
            Text("Save a path when one idea leads naturally into another. The underlying PDFs stay untouched.")
                .font(.system(.body, design: .serif)).foregroundStyle(ShelfTheme.secondary)
        }
        .padding(.vertical, 10)
    }

    private var trailList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("YOUR TRAILS")
                .font(ShelfTheme.eyebrow(10)).tracking(1.8).foregroundStyle(ShelfTheme.secondary)
                .padding(.bottom, 8)
            ForEach(model.snapshot.trails) { trail in
                Button { selectedTrail = trail } label: {
                    HStack(alignment: .top, spacing: 14) {
                        Text(String(format: "%02d", max(1, trail.nodes.count)))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(ShelfTheme.accent)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(trail.title)
                                .font(.system(.body, design: .serif).weight(.medium))
                                .foregroundStyle(ShelfTheme.text)
                            Text("\(trail.nodes.count) stops · \(trailState(trail))")
                                .font(.caption).foregroundStyle(ShelfTheme.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(ShelfTheme.secondary)
                    }
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Divider().overlay(ShelfTheme.line)
            }
        }
    }

    private func trailState(_ trail: LearningTrail) -> String {
        let objectIDs = trail.nodes.compactMap { $0.kind == .learningObject ? $0.referenceID : nil }
        guard !objectIDs.isEmpty else { return "Exploring" }
        let states = objectIDs.compactMap { model.snapshot.reviewStates[$0] }.map { model.scheduler.mastery(for: $0, at: Date()) }
        if states.contains(.fading) || states.contains(.due) { return "Learning" }
        if !states.isEmpty && states.allSatisfy({ $0 == .durable }) { return "Durable" }
        if states.contains(.strengthening) { return "Retrievable" }
        return "Exploring"
    }
}
