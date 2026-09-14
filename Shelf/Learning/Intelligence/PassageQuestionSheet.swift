import SwiftUI
import ShelfCore

@MainActor struct PassageQuestionSheet: View {
    @Bindable var model: ReaderIntelligenceModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ShelfSheet(title: "Ask me") {
            ScrollView {
                if model.learning.sessionSummaryPresented {
                    Button("Return to reading") { dismiss() }.buttonStyle(ShelfButtonStyle(filled: true)).padding(22)
                } else {
                    QuestionCardView(model: model.learning, onViewSource: { source in
                        if let analysis = model.learning.snapshot.analyses[source.documentID],
                           let citation = IntelligenceSource(source: source, analysis: analysis) {
                            model.viewSource(citation, returningTo: "question")
                        }
                    }).padding(22)
                }
            }
        }
        .fullScreenCover(item: $model.readerRoute) { route in ReaderScreen(model: route.reader, thumbnails: route.thumbnails) }
    }
}

@MainActor struct QuestionConnectionsAction: View {
    let learning: LearningModel
    let source: LearningSource
    @State private var intelligence: ReaderIntelligenceModel?
    @State private var presented = false
    var body: some View {
        Group {
            if let intelligence, !intelligence.connections.isEmpty {
                Button("Find connections") { presented = true }.accessibilityIdentifier("question-find-connections")
            }
        }
        .task(id: source) {
            guard let analysis = learning.snapshot.analyses[source.documentID],
                  let citation = IntelligenceSource(source: source, analysis: analysis) else { return }
            let model = ReaderIntelligenceModel(learning: learning, source: citation)
            await model.retrieve(); if !Task.isCancelled { intelligence = model }
        }
        .sheet(isPresented: $presented) { if let intelligence { RabbitHoleSheet(model: intelligence) } }
    }
}
