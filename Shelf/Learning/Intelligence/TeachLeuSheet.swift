import SwiftUI
import ShelfCore

@MainActor struct TeachLeuSheet: View {
    @Bindable var model: ReaderIntelligenceModel
    @State private var connections = false
    @State private var activity = false
    var body: some View {
        ShelfSheet(title: "Teach Leu") {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Explain it in your own words.").font(.system(.title, design: .serif))
                    Text("Compare your thought with the source. No score, and no guessing what the source cannot establish.")
                        .foregroundStyle(ShelfTheme.secondary)
                    TextEditor(text: Binding(get: { model.attempt.learnerExplanation }, set: model.edit))
                        .frame(minHeight: 160).scrollContentBackground(.hidden)
                        .padding(12).background(ShelfTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityIdentifier("teach-leu-explanation")
                        .accessibilityLabel("Your explanation")
                    Button("Compare with source", action: model.assess)
                        .buttonStyle(ShelfButtonStyle(filled: true))
                        .disabled(model.attempt.learnerExplanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.inferring)
                        .accessibilityIdentifier("teach-leu-compare")
                    if model.inferring { ProgressView("Comparing on this device…").accessibilityIdentifier("teach-leu-inference") }
                    if let result = model.attempt.result { comparison(result) }
                    if let message = model.message { Text(message).foregroundStyle(ShelfTheme.secondary) }
                    source
                    if model.attempt.result != nil {
                        if !model.connections.isEmpty {
                            Button("Find connections") { connections = true }.accessibilityIdentifier("teach-leu-connections")
                        }
                        if model.activity != nil {
                            Button("Try it") { activity = true }.accessibilityIdentifier("teach-leu-try-it")
                        }
                        Button("This thought is settled", action: model.resolve).disabled(model.attempt.resolved)
                            .accessibilityIdentifier("teach-leu-resolve")
                    }
                }.padding(22).frame(maxWidth: 680).frame(maxWidth: .infinity, alignment: .leading)
            }.scrollDismissesKeyboard(.interactively)
        }
        .accessibilityIdentifier("teach-leu-screen")
        .task { await model.retrieve() }
        .onDisappear { model.cancel() }
        .fullScreenCover(item: $model.readerRoute) { route in ReaderScreen(model: route.reader, thumbnails: route.thumbnails) }
        .sheet(isPresented: $connections) {
            RabbitHoleSheet(model: ReaderIntelligenceModel(learning: model.learning, source: model.source))
        }
        .sheet(isPresented: $activity) {
            if let definition = model.activity { TryItSheet(model: ReaderIntelligenceModel(learning: model.learning, source: model.source), definition: definition) }
        }
    }
    private var source: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FROM YOUR SOURCE").font(.caption.weight(.semibold)).foregroundStyle(ShelfTheme.accent)
            Text(model.sourceLabel).font(.headline)
            Text(model.source.passage.sourceText).font(.system(.body, design: .serif))
                .accessibilityIdentifier("teach-leu-source-quote")
            Button("View in PDF") { model.viewSource(returningTo: "Teach Leu") }.accessibilityIdentifier("teach-leu-view-source")
        }
    }
    @ViewBuilder private func comparison(_ result: TeachLeuResult) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            if !result.supported.isEmpty {
                Text("YOU CAPTURED").font(.caption.weight(.semibold)).foregroundStyle(ShelfTheme.accent)
                ForEach(Array(result.supported.enumerated()), id: \.offset) { _, point in Text(point.description) }
            }
            if !result.omitted.isEmpty {
                Text("WORTH ADDING").font(.caption.weight(.semibold))
                ForEach(result.omitted, id: \.id) { claim in Text(claim.evidence.text).font(.system(.body, design: .serif)) }
            }
            if !result.challenged.isEmpty {
                Text("CHECK THIS").font(.caption.weight(.semibold))
                ForEach(Array(result.challenged.enumerated()), id: \.offset) { _, point in
                    Text("“\(point.learnerText)”"); Text(point.explanation)
                }
            }
            if !result.unsettled.isEmpty {
                Text("Your source doesn't settle this.").font(.headline)
                ForEach(Array(result.unsettled.enumerated()), id: \.offset) { _, text in Text("“\(text)”") }
                Text("No conclusion has been drawn about these statements.").foregroundStyle(ShelfTheme.secondary)
            }
        }.accessibilityIdentifier("teach-leu-result")
    }
}
