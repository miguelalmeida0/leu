import SwiftUI
import ShelfCore

@MainActor struct RabbitHoleSheet: View {
    @State var model: ReaderIntelligenceModel
    @State private var visited = Set<String>()
    @State private var path: [IntelligenceSource] = []
    var body: some View {
        ShelfSheet(title: "Follow this idea") {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("CURRENT IDEA").font(.caption.weight(.semibold)).foregroundStyle(ShelfTheme.accent)
                    Text(model.sourceLabel).font(.headline)
                    Text(model.source.passage.sourceText).font(.system(.body, design: .serif))
                    Button("View current source") { model.viewSource(returningTo: "Follow this idea") }
                    ForEach(model.connections.filter { !visited.contains($0.connected.id) }) { connection in
                        Divider()
                        Text("CONNECTED IDEA").font(.caption.weight(.semibold))
                        Text(title(connection.connected)).font(.headline)
                        Text(connection.connected.passage.sourceText).font(.system(.body, design: .serif))
                            .accessibilityIdentifier("connection-source-quote")
                        Text("WHY THEY CONNECT").font(.caption.weight(.semibold))
                        Text(connection.label).foregroundStyle(ShelfTheme.accent)
                        Text(connection.explanation)
                        Button("View in PDF") { model.viewSource(connection.connected, returningTo: "Follow this idea") }
                            .accessibilityIdentifier("connection-view-source")
                        if path.count < 4 {
                            Button("Follow this idea") {
                                visited.insert(model.source.id); path.append(model.source)
                                let learning = model.learning
                                model = ReaderIntelligenceModel(learning: learning, source: connection.connected)
                                Task { await model.record(.openedConnection) }
                            }.accessibilityIdentifier("connection-follow")
                        }
                    }
                    if model.connections.filter({ !visited.contains($0.connected.id) }).isEmpty {
                        Text("No further relationship could be established from both sources.").foregroundStyle(ShelfTheme.secondary)
                    }
                    if let previous = path.last {
                        Button("Back to previous idea") {
                            path.removeLast(); visited.remove(previous.id)
                            model = ReaderIntelligenceModel(learning: model.learning, source: previous)
                        }
                    }
                }.padding(22).frame(maxWidth: 680).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.accessibilityIdentifier("rabbit-hole-screen")
        .task(id: model.source.id) { await model.retrieve() }
        .fullScreenCover(item: $model.readerRoute) { route in ReaderScreen(model: route.reader, thumbnails: route.thumbnails) }
    }
    private func title(_ source: IntelligenceSource) -> String {
        (model.learning.library.snapshot.activeBooks.first { $0.id == source.packet.documentID }?.title ?? "Source") + " · p. \(source.packet.pageIndex + 1)"
    }
}
