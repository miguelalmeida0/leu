import SwiftUI
import ShelfCore

@MainActor struct RabbitHoleSheet: View {
    @State var model: ReaderIntelligenceModel
    @State private var selection = 0
    @State private var collision: GroundedConnectionV2?
    @State private var path: [IntelligenceSource] = []
    var body: some View {
        ShelfSheet(title: "Connections") {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if !model.connections.isEmpty {
                        let connection = model.connections[min(selection, model.connections.count - 1)]
                        let readingA = connection.sourceA.documentID == model.source.packet.documentID
                        V28FactQuote(label: "CURRENT IDEA", fact: readingA ? connection.sourceA : connection.sourceB,
                            title: readingA ? connection.currentIdeaTitle : connection.relatedIdeaTitle, sourceLabel: readingA ? "SOURCE A" : "SOURCE B")
                        V28FactQuote(label: "RELATED IDEA", fact: connection.related(to: model.source),
                            title: readingA ? connection.relatedIdeaTitle : connection.currentIdeaTitle, sourceLabel: readingA ? "SOURCE B" : "SOURCE A")
                        Text("WHY THEY CONNECT").font(.caption.weight(.semibold)).foregroundStyle(ShelfTheme.accent)
                        Text(connection.readerExplanation).accessibilityIdentifier("connection-explanation")
                        Text("A connection drawn from these two passages.").font(.caption).foregroundStyle(ShelfTheme.secondary)
                        Button("View source A") { model.viewFact(connection.sourceA, returningTo: "Connections") }
                            .accessibilityIdentifier("connection-view-source-a")
                        Button("View source B") { model.viewFact(connection.sourceB, returningTo: "Connections") }
                            .accessibilityIdentifier("connection-view-source")
                        Button("Knowledge Collision") { collision = connection }
                            .buttonStyle(ShelfButtonStyle(filled: true)).accessibilityIdentifier("connection-collision")
                        if model.connections.count > 1 {
                            Button("Another connection") { selection = (selection + 1) % model.connections.count }
                                .accessibilityIdentifier("connection-next")
                        }
                        if path.count < 4 {
                            Button("Follow this idea") {
                                guard let source = connection.related(to: model.source).citation(in: model.learning.snapshot.analyses) else { return }
                                path.append(model.source); selection = 0
                                model = ReaderIntelligenceModel(learning: model.learning, source: source)
                            }.accessibilityIdentifier("connection-follow")
                        }
                    } else if model.retrieving { ProgressView("Finding connections in your library…") }
                    else { Text("No relationship could be established from both sources.").foregroundStyle(ShelfTheme.secondary) }
                    if let previous = path.last {
                        Button("Back to previous idea") {
                            path.removeLast(); selection = 0
                            model = ReaderIntelligenceModel(learning: model.learning, source: previous)
                        }
                    }
                    if let message = model.message { Text(message) }
                }.padding(22).frame(maxWidth: 680).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.accessibilityIdentifier("rabbit-hole-screen")
        .task(id: model.source.id) { await model.retrieve() }
        .fullScreenCover(item: $model.readerRoute) { route in ReaderScreen(model: route.reader, thumbnails: route.thumbnails) }
        .sheet(item: $collision) { connection in
            KnowledgeCollisionSheet(model: ReaderIntelligenceModel(learning: model.learning, source: model.source), connection: connection)
        }
    }
}
