import SwiftUI
import ShelfCore

@MainActor
struct TrailsScreen: View {
    @Bindable var model: LearningModel
    @Bindable var knowledge: KnowledgeModel
    @State private var newTrailTitle = ""
    @State private var creating = false
    @State private var selectedTrail: LearningTrail?

    @State private var wide = false
    @State private var shownTrailID: UUID?

    var body: some View {
        NavigationStack {
            Group {
                if wide, let shown = shownTrail {
                    HStack(alignment: .top, spacing: 0) {
                        ScrollView { sidebar.padding(.horizontal, 20).padding(.vertical, 24) }
                            .frame(width: 330)
                        TrailDetailScreen(model: model, trailID: shown.id).id(shown.id)
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 28) {
                            header
                            if model.snapshot.trails.isEmpty && knowledge.snapshot.topicChains.isEmpty {
                                emptyState
                            } else {
                                if !model.snapshot.trails.isEmpty { trailList }
                                TopicChainsSection(knowledge: knowledge)
                            }
                            newTrailButton
                        }
                        .padding(ShelfTheme.gutter)
                        .padding(.top, 22)
                        .padding(.bottom, 40)
                        .frame(maxWidth: 760).frame(maxWidth: .infinity)
                    }
                }
            }
            .background(ShelfTheme.background)
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { wide = proxy.size.width >= 900 }
                        .onChange(of: proxy.size.width) { _, width in wide = width >= 900 }
                }
            }
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

    private var shownTrail: LearningTrail? {
        model.snapshot.trails.first { $0.id == shownTrailID } ?? model.snapshot.trails.first
    }

    private var newTrailButton: some View {
        Button { creating = true } label: { Label("Make a trail", systemImage: "plus") }
            .buttonStyle(LeuPrimaryButtonStyle(filled: !wide, pill: true))
            .accessibilityIdentifier("new-learning-trail")
    }

    /// Wide iPad: every trail down the left, the chosen one walked out on the right.
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            trailList
            newTrailButton
            Text("Explore is wandering. A trail is a walk you chose, in an order that makes sense to you.")
                .font(.leu(.footnote)).foregroundStyle(LeuDesign.secondary)
                .fixedSize(horizontal: false, vertical: true)
            TopicChainsSection(knowledge: knowledge)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TRAILS")
                .font(LeuDesign.eyebrow(11)).tracking(LeuDesign.eyebrowTracking).foregroundStyle(LeuDesign.eyebrowOnFelt)
            Text("Walks through your books.")
                .font(LeuDesign.display(36)).tracking(-1)
                .foregroundStyle(LeuDesign.ink)
                .accessibilityAddTraits(.isHeader)
            Text("A trail is a walk you chose, through exact pages, in an order that makes sense to you.")
                .font(.leu(.callout))
                .foregroundStyle(LeuDesign.secondary)
            StitchDivider().padding(.top, 6)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No trails yet.").font(LeuDesign.display(24)).foregroundStyle(LeuDesign.ink)
            Text("Make one when one idea leads naturally into another. Your PDFs stay untouched.")
                .font(.leu(.body)).foregroundStyle(LeuDesign.secondary)
        }
        .padding(.vertical, 10)
    }

    private var trailList: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("YOUR TRAILS")
                .font(LeuDesign.eyebrow(10)).tracking(LeuDesign.eyebrowTracking).foregroundStyle(LeuDesign.eyebrowOnFelt)
                .padding(.bottom, 8)
                .accessibilityAddTraits(.isHeader)
            ForEach(Array(model.snapshot.trails.enumerated()), id: \.element.id) { index, trail in
                let chosen = wide && trail.id == shownTrail?.id
                Button {
                    if wide { shownTrailID = trail.id } else { selectedTrail = trail }
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Rectangle()
                            .fill(.clear)
                            .frame(width: 3)
                            .overlay {
                                GeometryReader { proxy in
                                    Path { path in
                                        path.move(to: CGPoint(x: 1.5, y: 0))
                                        path.addLine(to: CGPoint(x: 1.5, y: proxy.size.height))
                                    }
                                    .stroke(Self.threads[index % Self.threads.count], style: StrokeStyle(lineWidth: 3, dash: [5, 3]))
                                }
                            }
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(trail.title)
                                .font(.leu(.body, weight: .bold))
                                .foregroundStyle(LeuDesign.ink)
                            Text("\(trail.nodes.count) stops · \(trailState(trail))")
                                .font(.leu(.caption)).foregroundStyle(LeuDesign.secondary)
                        }
                        Spacer(minLength: 8)
                        if !wide { Image(systemName: "chevron.right").font(.leu(.caption)).foregroundStyle(LeuDesign.secondary) }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(chosen ? LeuDesign.feltLight : .clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(chosen ? .isSelected : [])
            }
        }
    }

    private static let threads: [Color] = [LeuDesign.redThread, LeuDesign.denim, LeuDesign.held, LeuDesign.butter, LeuDesign.tomato]

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
