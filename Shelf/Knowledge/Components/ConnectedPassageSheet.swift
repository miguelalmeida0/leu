import SwiftUI
import ShelfCore

@MainActor
struct ConnectedPassageSheet: View {
    @Bindable var knowledge: KnowledgeModel
    let source: LearningSource
    @Environment(\.dismiss) private var dismiss
    @State private var sourcePassage: KnowledgePassage?
    @State private var related: [RankedKnowledgeConnection] = []
    @State private var showingConstellation = false
    @State private var newChainTitle = ""
    @State private var chainCandidate: KnowledgePassage?
    @State private var conceptTitle = ""
    @State private var createConceptPresented = false

    var body: some View {
        ShelfSheet(title: "Connections") {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    sourceBlock
                    if let sourcePassage { confirmedSection(sourcePassage); relatedSection(sourcePassage) }
                    else { unavailableState }
                }
                .padding(ShelfTheme.gutter)
            }
        }
        .task { resolve() }
        .onChange(of: knowledge.snapshot.passages.count) { _, _ in resolve() }
        .sheet(isPresented: $showingConstellation) {
            if let sourcePassage {
                ConnectionConstellationSheet(knowledge: knowledge, source: sourcePassage, related: related)
            }
        }
        .leuDialog("Create Concept", isPresented: $createConceptPresented) {
            LeuTextField("Concept name", text: $conceptTitle)
            Button("Create") { createConcept() }
            Button("Cancel", role: .cancel) { conceptTitle = "" }
        } message: { Text("Make this passage part of a permanent concept in your library.") }
        .leuDialog("New trail", isPresented: Binding(get: { chainCandidate != nil }, set: { if !$0 { chainCandidate = nil } })) {
            LeuTextField("React Identity", text: $newChainTitle)
            Button("Create") { createChain() }
            Button("Cancel", role: .cancel) { chainCandidate = nil; newChainTitle = "" }
        } message: { Text("Start a reading path with these two passages.") }
        .accessibilityIdentifier("connected-passage-sheet")
    }

    private var sourceBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FROM THIS PASSAGE").font(.caption.weight(.bold)).tracking(1.8).foregroundStyle(ShelfTheme.accent)
            Text(source.sourceText).font(.system(.body, design: .serif)).lineLimit(8)
            HStack { Text(knowledge.title(for: source.documentID)); Spacer(); Text("p. \(source.pageIndex + 1)") }
                .font(.caption).foregroundStyle(ShelfTheme.secondary)
            if sourcePassage != nil {
                Text("Source anchored")
                    .font(ShelfTheme.eyebrow(9)).tracking(1.3)
                    .foregroundStyle(ShelfTheme.secondary)
            }
        }
        .padding(.leading, 14)
        .overlay(alignment: .leading) { Rectangle().fill(ShelfTheme.accent).frame(width: 2) }
    }

    @ViewBuilder private func confirmedSection(_ passage: KnowledgePassage) -> some View {
        let links = knowledge.connections(for: passage.id)
        if !links.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("SAVED CONNECTIONS").font(ShelfTheme.eyebrow(10)).tracking(1.8).foregroundStyle(ShelfTheme.secondary)
                ForEach(links) { link in
                    if let other = otherPassage(link, source: passage.id) {
                        passageRow(other, reason: "You connected these", sourcePassage: passage, existingConnection: link)
                    }
                }
            }
        }
    }

    private func relatedSection(_ passage: KnowledgePassage) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("RELATED IN YOUR LIBRARY").font(ShelfTheme.eyebrow(10)).tracking(1.8).foregroundStyle(ShelfTheme.secondary)
                    Text("Only strong local matches are shown.").font(.caption).foregroundStyle(ShelfTheme.secondary)
                }
                Spacer()
                if related.count >= 3 {
                    Button { showingConstellation = true } label: { Image(systemName: "circle.hexagongrid").frame(width: 44, height: 44) }
                        .accessibilityLabel("Explore connections spatially")
                        .accessibilityIdentifier("connection-constellation")
                }
            }
            if related.isEmpty {
                Text(knowledge.isIndexing ? "Connecting this book to your library…" : "No strong connections yet.")
                    .font(.body).foregroundStyle(ShelfTheme.secondary).padding(.vertical, 16)
            } else {
                ForEach(related, id: \.passage.id) { item in
                    passageRow(item.passage, reason: item.reason.explanation, sourcePassage: passage,
                               existingConnection: connection(between: passage.id, and: item.passage.id))
                }
            }
        }
    }

    private func passageRow(_ passage: KnowledgePassage, reason: String, sourcePassage: KnowledgePassage, existingConnection: KnowledgeConnection?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                knowledge.queueNavigation(to: passage, from: sourcePassage); dismiss()
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(knowledge.title(for: passage.documentID)).font(.headline).foregroundStyle(ShelfTheme.text).lineLimit(1)
                        Spacer(); Text("p. \(passage.pageIndex + 1)").font(.caption.monospacedDigit()).foregroundStyle(ShelfTheme.secondary)
                    }
                    if let section = passage.sectionTitle { Text(section).font(.caption.weight(.semibold)).foregroundStyle(ShelfTheme.accent).lineLimit(1) }
                    Text(passage.text).font(.system(.callout, design: .serif)).foregroundStyle(ShelfTheme.secondary).lineLimit(4)
                    Text(reason).font(.caption).foregroundStyle(LeuDesign.textSecondary)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain)
            HStack(spacing: 10) {
                if let existingConnection {
                    Label("Saved", systemImage: "link")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ShelfTheme.olive)
                    Spacer()
                    LeuMenu {
                        Section("Relationship") {
                            connectionType("Related", .related, sourcePassage, passage)
                            connectionType("Prerequisite", .prerequisite, sourcePassage, passage)
                            connectionType("Example", .example, sourcePassage, passage)
                            connectionType("Contrast", .contrast, sourcePassage, passage)
                            connectionType("Builds on", .buildsOn, sourcePassage, passage)
                            connectionType("Same idea", .sameIdea, sourcePassage, passage)
                        }
                        Section("Trail") {
                            ForEach(knowledge.snapshot.topicChains.prefix(24)) { chain in
                                Button(chain.title) { Task { await knowledge.addPassages([sourcePassage.id, passage.id], to: chain.id) } }
                            }
                        }
                        Divider()
                        Button("Remove connection", systemImage: "link.badge.minus", role: .destructive) {
                            Task { await knowledge.removeConnection(existingConnection.id); resolve() }
                        }
                    } label: {
                        Label("Refine", systemImage: "ellipsis")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(ShelfTheme.secondary)
                    .accessibilityLabel("Saved connection options")
                } else {
                    Button {
                        Task {
                            await knowledge.confirm(source: sourcePassage.id, destination: passage.id, type: .related)
                            ShelfHaptics.shared.play(.selectionChanged)
                            resolve()
                        }
                    } label: {
                        Label("Save connection", systemImage: "link.badge.plus")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(ShelfTheme.action)
                            .frame(minHeight: 38)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("save-connection")
                    Spacer()
                }
            }
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { Divider().overlay(ShelfTheme.line) }
    }

    private func sourceTopicChainMenu(_ passage: KnowledgePassage) -> some View {
        LeuMenu("Add to Topic Chain") {
            ForEach(knowledge.snapshot.topicChains.prefix(24)) { chain in
                Button(chain.title) { Task { await knowledge.addPassages([passage.id], to: chain.id) } }
            }
            if !knowledge.snapshot.topicChains.isEmpty { Divider() }
            Button("New trail…") { chainCandidate = passage; newChainTitle = passage.sectionTitle ?? "New trail" }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(ShelfTheme.accent)
    }

    private func topicChainMenu(sourcePassage: KnowledgePassage, destination: KnowledgePassage) -> some View {
        LeuMenu("Add to Topic Chain") {
            ForEach(knowledge.snapshot.topicChains.prefix(24)) { chain in
                Button(chain.title) {
                    Task { await knowledge.addPassages([sourcePassage.id, destination.id], to: chain.id) }
                }
            }
            if !knowledge.snapshot.topicChains.isEmpty { Divider() }
            Button("New trail…") {
                chainCandidate = destination
                newChainTitle = sourcePassage.sectionTitle ?? destination.sectionTitle ?? "New trail"
            }
        }
        .font(.caption)
    }

    private func connection(between first: UUID, and second: UUID) -> KnowledgeConnection? {
        knowledge.connections(for: first).first { link in
            (link.sourcePassageID == first && link.destinationPassageID == second) ||
            (link.sourcePassageID == second && link.destinationPassageID == first)
        }
    }

    private func connectionType(_ title: String, _ type: KnowledgeConnectionType,
                                _ source: KnowledgePassage, _ destination: KnowledgePassage) -> some View {
        Button(title) { Task { await knowledge.confirm(source: source.id, destination: destination.id, type: type) } }
    }

    private var unavailableState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RELATED IN YOUR LIBRARY")
                .font(.caption.weight(.bold)).tracking(1.8).foregroundStyle(ShelfTheme.secondary)
            Text(knowledge.isIndexing ? "Connecting this book to your library…" : "No strong connections yet.")
                .font(.headline)
            Text(knowledge.isIndexing
                 ? "Results appear here as the local index becomes available. Reading stays fully usable while Leu works."
                 : "Leu only shows relationships that clear its relevance floor. You can still create a Concept or connect another passage manually.")
                .foregroundStyle(ShelfTheme.secondary)
        }.padding(.vertical, 18)
    }

    private func resolve() {
        sourcePassage = knowledge.passage(for: source)
        if let sourcePassage { related = knowledge.related(to: sourcePassage) }
    }

    private func otherPassage(_ connection: KnowledgeConnection, source: UUID) -> KnowledgePassage? {
        knowledge.passage(connection.sourcePassageID == source ? connection.destinationPassageID : connection.sourcePassageID)
    }

    private func createConcept() {
        guard let sourcePassage else { return }
        let clean = conceptTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count >= 2 else { return }
        Task { _ = await knowledge.createConcept(name: clean, passageID: sourcePassage.id) }
        conceptTitle = ""
    }

    private func suggestedConceptName(_ text: String) -> String {
        let words = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).prefix(4)
        return words.joined(separator: " ").trimmingCharacters(in: .punctuationCharacters)
    }

    private func createChain() {
        guard let sourcePassage, let chainCandidate else { return }
        let title = newChainTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        Task { _ = await knowledge.createChain(title: title.isEmpty ? "Trail" : title,
                                                passageIDs: [sourcePassage.id, chainCandidate.id]) }
        self.chainCandidate = nil; newChainTitle = ""
    }
}
