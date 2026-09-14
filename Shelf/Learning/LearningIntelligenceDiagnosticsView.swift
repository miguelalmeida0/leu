import SwiftUI
@MainActor struct LearningIntelligenceDiagnosticsView: View {
    @Bindable var model: LearningModel
    var body: some View {
        ShelfSheet(title: "Learning Intelligence") {
            Form {
                LabeledContent("Backend", value: model.intelligenceProvider.backend)
                LabeledContent("Availability", value: model.modelAvailability.rawValue)
                LabeledContent("Capability", value: model.intelligenceCapability.foundationModels.rawValue)
                Text(model.intelligenceCapability.reason).font(.caption)
                LabeledContent("Generation verified", value: model.intelligenceCapability.generationVerified ? "YES" : "NO")
                ForEach(model.intelligenceCapability.errorChain, id: \.self) { Text($0).font(.caption.monospaced()) }
                LabeledContent("Last operation", value: model.modelState.rawValue)
                LabeledContent("Inference calls this run", value: String(model.modelInferenceAttempts))
                LabeledContent("Real response received this run", value: model.modelGenerated > 0 ? "YES" : "NO")
                LabeledContent("Real responses this run", value: String(model.modelGenerated))
                LabeledContent("Accepted this run", value: String(model.modelAccepted))
                LabeledContent("Rejected this run", value: String(model.modelRejections.values.reduce(0, +)))
                LabeledContent("Persisted model questions", value: String(model.snapshot.questions.filter { $0.modelProvenance?.backend == "apple-on-device" }.count))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Persisted model questions")
                    .accessibilityValue(String(model.snapshot.questions.filter { $0.modelProvenance?.backend == "apple-on-device" }.count))
                    .accessibilityIdentifier("model-persisted-question-count")
                ForEach(model.modelRejections.keys.sorted(), id: \.self) { key in
                    LabeledContent(key, value: String(model.modelRejections[key] ?? 0))
                }
                if let date = model.lastModelGeneration { Text(date, style: .time) }
                if let error = model.lastModelError { Text(error).font(.caption).textSelection(.enabled) }
                if let packet = model.lastModelPacket {
                    DisclosureGroup("Last attempted source packet") { json(packet) }
                }
                Section("Source migration") {
                    ForEach(model.migrationDiagnostics, id: \.self) { Text($0).font(.caption).textSelection(.enabled) }
                }
                ForEach(model.modelGenerations, id: \.cacheKey) { record in
                    Section("Page \((record.sourcePacket?.pageIndex ?? -1) + 1) · \(record.backend)") {
                        Text(record.timestamp, style: .time)
                        DisclosureGroup("Source packet") { json(record.sourcePacket) }
                        DisclosureGroup("Raw structured candidate") { json(record.candidate) }
                        DisclosureGroup("Validated candidate") {
                            if let question = record.validatedQuestion { json(question) }
                            else { Text(record.rejection ?? "Not validated") }
                        }
                        DisclosureGroup("Persisted Study question") {
                            if let question = model.snapshot.questions.first(where: { $0.id == record.acceptedQuestionID }) { json(question) }
                            else { Text("Not persisted") }
                        }
                    }
                }
                Button("Check local model") { model.prepareIntelligence() }
            }
        }.accessibilityIdentifier("learning-intelligence-diagnostics")
    }

    private func json<T: Encodable>(_ value: T) -> some View {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let text = (try? encoder.encode(value)).map { String(decoding: $0, as: UTF8.self) } ?? "Encoding failed"
        return Text(text).font(.caption.monospaced()).textSelection(.enabled)
    }
}
