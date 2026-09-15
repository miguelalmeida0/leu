import SwiftUI
import ShelfCore
import LeuReasoningCore
import LeuQwenRuntime
import UniformTypeIdentifiers

@MainActor struct TeachLeuSheet: View {
    @Bindable var model: ReaderIntelligenceModel
    @State private var connections = false
    @State private var activity = false
    @State private var offline = OfflineModelStore.shared
    @State private var confirmDownload = false
    @State private var importModel = false
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        ShelfSheet(title: "Teach Leu") {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Explain it in your own words.").font(.system(.title, design: .serif))
                    Text("Compare your thought with the source. No score, and no guessing what the source cannot establish.")
                        .foregroundStyle(ShelfTheme.secondary)
                    offlineControls
                    TextEditor(text: Binding(get: { model.attempt.learnerExplanation }, set: model.edit))
                        .frame(minHeight: 160).scrollContentBackground(.hidden)
                        .padding(12).background(ShelfTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityIdentifier("teach-leu-explanation")
                        .accessibilityLabel("Your explanation")
                    Button("Compare with source", action: model.assess)
                        .buttonStyle(ShelfButtonStyle(filled: true))
                        .disabled(model.attempt.learnerExplanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.inferring)
                        .accessibilityIdentifier("teach-leu-compare")
                    if model.inferring {
                        HStack {
                            ProgressView("Comparing on this device…").accessibilityIdentifier("teach-leu-inference")
                            Button("Cancel", action: model.cancel).accessibilityIdentifier("teach-leu-cancel")
                        }
                    }
                    if let provider = model.assessmentProvider { Text(provider).font(.caption).foregroundStyle(ShelfTheme.secondary) }
                    if let result = model.offlineFeedback { offlineComparison(result) }
                    if let result = model.feedback { comparison(result) }
                    if let message = model.message { Text(message).foregroundStyle(ShelfTheme.secondary) }
                    source
                    if model.feedback != nil || model.offlineFeedback != nil {
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
        .onChange(of: scenePhase) { _, phase in if phase != .active { model.cancel() } }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
            model.cancel(); model.message = "Comparison stopped under memory pressure. Your draft is kept."
        }
        .onReceive(Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()) { _ in model.checkOfflineResources() }
        .confirmationDialog("Download Offline model?", isPresented: $confirmDownload, titleVisibility: .visible) {
            Button("Download 1,280,835,840 bytes") { offline.download() }
        } message: {
            Text("Qwen 2B uses 1.28 GB storage. Downloaded from Hugging Face; no inference account or service fee. Device performance is still experimental.")
        }
        .fileImporter(isPresented: $importModel, allowedContentTypes: [.data]) { result in
            if case .success(let url) = result { offline.importFile(url) }
        }
        .fullScreenCover(item: $model.readerRoute) { route in ReaderScreen(model: route.reader, thumbnails: route.thumbnails) }
        .sheet(isPresented: $connections) {
            RabbitHoleSheet(model: ReaderIntelligenceModel(learning: model.learning, source: model.source))
        }
        .sheet(isPresented: $activity) {
            if let definition = model.activity { TryItSheet(model: ReaderIntelligenceModel(learning: model.learning, source: model.source), definition: definition) }
        }
    }
    private var offlineControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            if offline.installed {
                Toggle("Offline model", isOn: $offline.enabled)
                    .disabled(!EmbeddedQwen.available || offline.busy || model.inferring)
                    .onChange(of: offline.enabled) { _, _ in model.changeAssessmentProvider() }
                Text("Experimental Qwen 2B. Assessments may be wrong; verify with your source.")
                    .font(.caption).foregroundStyle(ShelfTheme.secondary)
                Button("Remove download") { model.cancel(); offline.remove() }
                    .disabled(offline.busy || model.inferring)
            } else {
                Text("Offline model").font(.headline)
                Toggle("Prefer Wi-Fi", isOn: $offline.wifiOnly).disabled(offline.busy)
                HStack {
                    Button("Download") { confirmDownload = true }.disabled(offline.busy || model.inferring)
                    Button("Import model file") { importModel = true }.disabled(offline.busy || model.inferring)
                }
                Text("Optional · 1,280,835,840 bytes").font(.caption).foregroundStyle(ShelfTheme.secondary)
            }
            if !EmbeddedQwen.available {
                Text("This build has no embedded runtime. Existing Teach Leu remains available.")
                    .font(.caption).foregroundStyle(ShelfTheme.secondary)
            }
            if offline.busy {
                ProgressView(value: offline.progress)
                Button("Cancel download", action: offline.cancel)
            }
            if let message = offline.message { Text(message).font(.caption).foregroundStyle(ShelfTheme.secondary) }
        }.padding(14).background(ShelfTheme.surface, in: RoundedRectangle(cornerRadius: 12))
    }
    private func offlineComparison(_ result: LocalExplanationAssessment) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(result.claims.enumerated()), id: \.offset) { _, claim in
                Text(claim.support == .supported ? "YOU CAPTURED" :
                     claim.support == .uncertain ? "UNCERTAIN" :
                     claim.support == .unsupported ? "NOT ESTABLISHED" :
                     claim.support == .overgeneralized ? "SCOPE TO CHECK" : "CONFLICT TO CHECK")
                    .font(.caption.weight(.semibold))
                Text("“\(claim.learner_quote)”")
                Text(claim.feedback).foregroundStyle(ShelfTheme.secondary)
                Text(claim.source_quote).font(.system(.body, design: .serif))
                Button("Read this passage") { model.viewSource(exactQuote: claim.source_quote, returningTo: "Teach Leu") }
            }
            ForEach(Array(result.coverage.enumerated()), id: \.offset) { _, detail in
                Text("WORTH ADDING").font(.caption.weight(.semibold))
                Text(detail.detail)
                Text(detail.source_quote).foregroundStyle(ShelfTheme.secondary)
                Button("Read this passage") { model.viewSource(exactQuote: detail.source_quote, returningTo: "Teach Leu") }
            }
            Button("Dismiss feedback", action: model.dismissOfflineFeedback)
        }.accessibilityIdentifier("teach-leu-offline-result")
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
    @ViewBuilder private func comparison(_ result: ReasonedTeachFeedback) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            if !result.captured.isEmpty {
                Text("YOU CAPTURED").font(.caption.weight(.semibold)).foregroundStyle(ShelfTheme.accent)
                ForEach(Array(result.captured.enumerated()), id: \.offset) { _, point in
                    Text("“\(point.learner)”")
                    Text(point.explanation).foregroundStyle(ShelfTheme.secondary)
                }
            }
            if !result.worthAdding.isEmpty {
                Text("WORTH ADDING").font(.caption.weight(.semibold))
                ForEach(Array(result.worthAdding.enumerated()), id: \.offset) { _, point in
                    Text(point.explanation).foregroundStyle(ShelfTheme.secondary)
                    Text(point.source.quote.text)
                    Button("Read this passage") { model.viewFact(point.source, returningTo: "Teach Leu") }
                }
            }
            if !result.check.isEmpty {
                Text("CHECK THIS").font(.caption.weight(.semibold))
                ForEach(Array(result.check.enumerated()), id: \.offset) { _, point in
                    Text("“\(point.learner)”"); Text(point.explanation)
                    Text(point.source.quote.text).foregroundStyle(ShelfTheme.secondary)
                    Button("Check the passage") { model.viewFact(point.source, returningTo: "Teach Leu") }
                }
            }
            if !result.unsettled.isEmpty {
                Text("NOT ESTABLISHED HERE").font(.caption.weight(.semibold))
                ForEach(Array(result.unsettled.enumerated()), id: \.offset) { _, text in Text("“\(text)”") }
                Text("No conclusion has been drawn about these statements.").foregroundStyle(ShelfTheme.secondary)
            }
        }.accessibilityIdentifier("teach-leu-result")
    }
}
