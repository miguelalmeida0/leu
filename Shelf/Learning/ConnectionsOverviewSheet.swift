import SwiftUI
import ShelfCore

/// Calm cross-library entry point. The dense ranking/index mechanics stay behind the reading experience.
@MainActor
struct ConnectionsOverviewSheet: View {
    @Bindable var knowledge: KnowledgeModel
    @State private var searchPresented = false
    @State private var selectedConcept: KnowledgeConcept?

    var body: some View {
        ShelfSheet(title: "Connections") {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    intro
                    Button { searchPresented = true } label: {
                        HStack { Image(systemName: "text.magnifyingglass"); Text("Search ideas across your library"); Spacer(); Image(systemName: "arrow.right") }
                    }
                    .buttonStyle(ShelfButtonStyle(filled: true))
                    if !confirmed.isEmpty { confirmedSection }
                    conceptsSection
                }
                .padding(ShelfTheme.gutter).frame(maxWidth: 720).frame(maxWidth: .infinity)
            }
        }
        .sheet(isPresented: $searchPresented) { KnowledgeSearchSheet(knowledge: knowledge) }
        .sheet(item: $selectedConcept) { ConceptDetailSheet(knowledge: knowledge, concept: $0) }
        .accessibilityIdentifier("connections-overview")
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("YOUR LIBRARY, BETWEEN THE BOOKS").font(.caption.weight(.bold)).tracking(1.8).foregroundStyle(ShelfTheme.accent)
            Text("Follow ideas instead of files.").font(.system(.title2, design: .serif))
            Text("Suggested relationships come from local lexical retrieval. Connections you confirm are permanent personal knowledge and survive index rebuilding.")
                .font(.callout).foregroundStyle(ShelfTheme.secondary)
        }
    }

    private var confirmed: [KnowledgeConnection] { knowledge.snapshot.confirmedConnections.filter { !$0.requiresRecovery } }

    private var confirmedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CONNECTED BY YOU").font(.caption.weight(.bold)).tracking(1.6).foregroundStyle(ShelfTheme.secondary)
            ForEach(confirmed.prefix(12)) { link in
                if let source = knowledge.passage(link.sourcePassageID), let target = knowledge.passage(link.destinationPassageID) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(source.sectionTitle ?? knowledge.title(for: source.documentID)).font(.headline)
                        Text("\(knowledge.title(for: source.documentID)) → \(knowledge.title(for: target.documentID))")
                            .font(.caption).foregroundStyle(ShelfTheme.secondary)
                        Text(target.text).font(.system(.callout, design: .serif)).foregroundStyle(ShelfTheme.secondary).lineLimit(2)
                    }.padding(.vertical, 8)
                    Divider().overlay(ShelfTheme.line)
                }
            }
        }
    }

    private var conceptsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CONCEPTS").font(.caption.weight(.bold)).tracking(1.6).foregroundStyle(ShelfTheme.secondary)
            ForEach(importantConcepts) { concept in
                Button { selectedConcept = concept } label: {
                    HStack { Text(concept.name).foregroundStyle(ShelfTheme.text); Spacer(); Image(systemName: "chevron.right").foregroundStyle(ShelfTheme.secondary) }
                        .frame(minHeight: 44).contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
        }
    }

    private var importantConcepts: [KnowledgeConcept] {
        let counts = Dictionary(grouping: knowledge.snapshot.detectedBindings + knowledge.snapshot.userBindings, by: \.conceptID)
            .mapValues(\.count)
        return knowledge.snapshot.concepts.filter { counts[$0.id, default: 0] > 0 }
            .sorted { counts[$0.id, default: 0] > counts[$1.id, default: 0] }.prefix(18).map { $0 }
    }
}
