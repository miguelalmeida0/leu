import SwiftUI
import ShelfCore

@MainActor
struct TrailDetailScreen: View {
    @Bindable var model: LearningModel
    let trailID: UUID
    @State private var draft: LearningTrail?
    @State private var showingAdd = false
    @State private var activeLab: ReconstructionLab?
    @State private var saving = false
    @State private var confirmation: String?

    var body: some View {
        Group {
            if let draft { content(draft) }
            else { ProgressView().task { draft = model.snapshot.trails.first { $0.id == trailID } } }
        }
        .navigationTitle(draft?.title ?? "Trail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) { Button { showingAdd = true } label: { Image(systemName: "plus") }.accessibilityLabel("Add stop") }
            ToolbarItem(placement: .secondaryAction) { EditButton() }
        }
        .sheet(isPresented: $showingAdd) { TrailAddSheet(model: model, onAdd: add) }
        .sheet(item: $activeLab) { lab in LabScreen(lab: lab) }
        .disabled(saving)
    }

    private func content(_ trail: LearningTrail) -> some View {
        ScrollViewReader { proxy in
            List {
                walk(trail)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))
                if let confirmation { Text(confirmation).accessibilityIdentifier("trail-add-confirmation") }
                if trail.nodes.isEmpty {
                    Text("Add a passage, a page range, or a practice lab to begin your walk.")
                        .foregroundStyle(ShelfTheme.secondary).listRowBackground(Color.clear)
                }
                if let current = TrailNavigation.resumeNode(in: trail, availableIDs: availableIDs(trail)) {
                    let stop = (trail.nodes.firstIndex { $0.id == current.id } ?? 0) + 1
                    Button("Continue at stop \(stop) · \(current.title)") { open(current) }
                        .buttonStyle(LeuPrimaryButtonStyle(filled: true, pill: true))
                        .listRowBackground(Color.clear).listRowSeparator(.hidden)
                        .accessibilityIdentifier("trail-continue")
                    if let index = trail.nodes.firstIndex(where: { $0.id == current.id }),
                       let next = trail.nodes.dropFirst(index + 1).first(where: { availableIDs(trail).contains($0.id) }) {
                        Button("Next stop · \(next.title)") { open(next) }
                            .buttonStyle(LeuPrimaryButtonStyle(filled: false, pill: true))
                            .listRowBackground(Color.clear).listRowSeparator(.hidden)
                    }
                }
                if !trail.nodes.isEmpty {
                    Text("STOPS · HOLD ONE TO MOVE OR REMOVE IT")
                        .font(LeuDesign.eyebrow(10)).tracking(LeuDesign.eyebrowTracking)
                        .foregroundStyle(LeuDesign.eyebrowOnFelt)
                        .listRowBackground(Color.clear).listRowSeparator(.hidden)
                        .padding(.top, 14)
                }
                ForEach(Array(trail.nodes.enumerated()), id: \.element.id) { index, node in
                    Button { open(node) } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)").font(.leu(.subheadline, weight: .bold).monospacedDigit()).foregroundStyle(LeuDesign.ink).frame(width: 24)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(node.title).foregroundStyle(ShelfTheme.text)
                                Text(kindTitle(node.kind)).font(.leu(.caption)).foregroundStyle(ShelfTheme.secondary)
                                Text(sourceCaption(node)).font(.leu(.caption)).foregroundStyle(ShelfTheme.secondary)
                                if node.id == trail.currentNodeID { Text("Your place").font(.leu(.caption, weight: .semibold)) }
                            }
                        }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    .buttonStyle(.plain).id(node.id)
                    .leuContextMenu {
                        Button("Move up") { move(from: IndexSet(integer: index), to: index - 1) }.disabled(index == 0)
                        Button("Move down") { move(from: IndexSet(integer: index), to: index + 2) }.disabled(index == trail.nodes.count - 1)
                        Button("Remove stop", role: .destructive) { delete(at: IndexSet(integer: index)) }
                    }
                }
                .onMove(perform: move).onDelete(perform: delete)
            }
            .scrollContentBackground(.hidden).background(ShelfTheme.background)
            .onAppear { if let id = trail.currentNodeID { proxy.scrollTo(id, anchor: .center) } }
        }
    }

    /// The trail as a walk: its name, where you are, and every stop on the felt.
    private func walk(_ trail: LearningTrail) -> some View {
        let available = availableIDs(trail)
        let current = trail.nodes.firstIndex { $0.id == trail.currentNodeID }
        return VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text(trail.title)
                    .font(LeuDesign.display(34)).tracking(-0.9)
                    .foregroundStyle(LeuDesign.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(summary(trail, current: current))
                    .font(.leu(.subheadline))
                    .foregroundStyle(LeuDesign.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !trail.nodes.isEmpty {
                TrailWalkMap(stops: trail.nodes.map { node in
                    TrailWalkMap.Stop(id: node.id, title: node.title, caption: sourceCaption(node), available: available.contains(node.id))
                }, currentIndex: current) { index in open(trail.nodes[index]) }
            }
        }
    }

    private func summary(_ trail: LearningTrail, current: Int?) -> String {
        let made = trail.createdAt.formatted(.dateTime.day().month(.wide))
        guard !trail.nodes.isEmpty else { return "Made on \(made). A walk through pages you choose, in an order that makes sense to you." }
        let stops = trail.nodes.count == 1 ? "1 stop" : "\(trail.nodes.count) stops"
        let place = current.map { "You're at stop \($0 + 1)." } ?? "Not started yet."
        return "\(stops), made on \(made). \(place) Each stop opens at its exact page."
    }

    private func availableIDs(_ trail: LearningTrail) -> Set<UUID> {
        Set(trail.nodes.filter { node in
            if node.kind == .lab { return LabCatalog.all().contains { $0.id == node.referenceID } }
            guard let source = TrailNavigation.source(for: node, snapshot: model.snapshot),
                  let book = model.library.snapshot.activeBooks.first(where: { $0.id == source.documentID }) else { return false }
            return source.pageIndex < book.pageCount
        }.map(\.id))
    }

    private func open(_ node: TrailNode) {
        guard var trail = draft, availableIDs(trail).contains(node.id) else {
            model.errorMessage = "This stop's source is no longer available."; return
        }
        trail.currentNodeID = node.id
        commit(trail) {
            if node.kind == .lab { activeLab = LabCatalog.all().first { $0.id == node.referenceID } }
            else if let source = TrailNavigation.source(for: node, snapshot: model.snapshot),
                    let book = model.library.snapshot.activeBooks.first(where: { $0.id == source.documentID }) {
                model.library.open(book, page: source.pageIndex, sourceText: source.sourceText, sourceReturnLabel: "Back to Trail")
            }
        }
    }

    private func commit(_ trail: LearningTrail, after: @escaping @MainActor () -> Void = {}) {
        guard !saving else { return }
        saving = true
        Task {
            defer { saving = false }
            do {
                _ = try await model.repository.saveTrail(trail)
                model.snapshot = try await model.repository.snapshot()
                draft = trail
                after()
            } catch { model.errorMessage = error.localizedDescription }
        }
    }

    private func add(_ node: TrailNode) {
        guard var trail = draft else { return }
        trail.nodes.append(node); showingAdd = false
        commit(trail) { confirmation = "Added “\(node.title)”\n\(sourceCaption(node))"; model.play(.objectCaptured) }
    }
    private func move(from source: IndexSet, to destination: Int) {
        guard var trail = draft else { return }
        trail.nodes.move(fromOffsets: source, toOffset: destination); commit(trail)
    }
    private func delete(at offsets: IndexSet) {
        guard var trail = draft else { return }
        let oldIndex = trail.nodes.firstIndex { $0.id == trail.currentNodeID }
        trail.nodes.remove(atOffsets: offsets)
        if !trail.nodes.contains(where: { $0.id == trail.currentNodeID }), !trail.nodes.isEmpty {
            trail.currentNodeID = trail.nodes[min(oldIndex ?? 0, trail.nodes.count - 1)].id
        }
        commit(trail)
    }
    private func sourceCaption(_ node: TrailNode) -> String {
        guard let source = TrailNavigation.source(for: node, snapshot: model.snapshot) else {
            return node.kind == .lab ? "Practice on this iPhone" : "Source unavailable"
        }
        let title = model.library.snapshot.activeBooks.first { $0.id == source.documentID }?.title ?? "Source unavailable"
        return "\(title) · p. \(source.pageIndex + 1)" + (source.sectionTitle.map { " · \($0)" } ?? "")
    }
    private func kindTitle(_ kind: TrailNodeKind) -> String {
        switch kind {
        case .document: return "Document"
        case .pageRange: return "Page range"
        case .learningObject: return "Passage"
        case .question: return "Question"
        case .lab: return "Reconstruction lab"
        case .mask: return "Diagram recall"
        case .connection: return "Connection"
        }
    }
}
