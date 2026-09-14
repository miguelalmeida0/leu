import SwiftUI
import ShelfCore

extension GroundedConnectionV2 {
    var currentIdeaTitle: String { displayTitle(sourceA, relation: relationA) }
    var relatedIdeaTitle: String { displayTitle(sourceB, relation: relationB) }
    var readerExplanation: String {
        if relationship == "mechanism", relationA.subject == "react.stable-key", relationB.relation == "governs-with-type-and-keys" {
            return "Stable keys help React recognize an item across list changes. Reconciliation uses element type and keys when deciding whether to keep or replace a component instance."
        }
        return whyValid.components(separatedBy: " The comparison is inferred").first ?? whyValid
    }
    private func displayTitle(_ fact: RelationalSourceFact, relation: NormalizedConceptRelation) -> String {
        guard fact.titleSpan == nil else { return fact.title }
        let names = ["react.stable-key": "Stable React keys", "js.array.every": "Array.every",
            "js.array.filter": "Array.filter", "js.array.find": "Array.find", "js.array.some": "Array.some",
            "programming.closure": "Closure", "programming.immutable-update": "Immutable updates",
            "programming.shallow-copy": "Shallow copying", "cache.reuse": "Reusing cached results"]
        return names[relation.subject] ?? fact.title
    }
}

struct V28FactQuote: View {
    let label: String
    let fact: RelationalSourceFact
    var title: String? = nil
    var sourceLabel: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(ShelfTheme.accent)
            Text(title ?? fact.title).font(.system(.title2, design: .serif))
            Text((sourceLabel.map { $0 + " · " } ?? "") + "\(fact.documentTitle) · p. \(fact.pageIndex + 1)").font(.caption).foregroundStyle(ShelfTheme.secondary)
            Text(fact.quote.text).font(.system(.body, design: .serif)).fixedSize(horizontal: false, vertical: true)
        }
    }
}

@MainActor struct KnowledgeCollisionSheet: View {
    @State var model: ReaderIntelligenceModel
    let connection: GroundedConnectionV2
    @State private var teaching = false
    @State private var response = ""
    @State private var feedback: TeachSourceFeedback?
    @State private var activityPresented = false
    private var valid: Bool { ConnectionAdmissionV2.validate(connection, analyses: model.learning.snapshot.analyses) == nil }
    var body: some View {
        ShelfSheet(title: teaching ? "Teach this connection" : "Knowledge Collision") {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if valid {
                        Text("\(connection.currentIdeaTitle) + \(connection.relatedIdeaTitle)")
                            .font(.system(.title, design: .serif)).accessibilityIdentifier("collision-pair")
                        Text("WHY THESE BELONG TOGETHER").font(.caption.weight(.semibold)).foregroundStyle(ShelfTheme.accent)
                        Text(connection.readerExplanation).accessibilityIdentifier("collision-explanation")
                        if teaching { teach }
                        else {
                            Button("Teach this connection") { teaching = true }
                                .buttonStyle(ShelfButtonStyle(filled: true)).accessibilityIdentifier("collision-teach")
                        }
                        if model.activity?.contract == .stableKeys {
                            Button("What changes if?") { activityPresented = true }.accessibilityIdentifier("collision-what-changes")
                        }
                        if teaching { Text("FROM BOTH SOURCES").font(.caption.weight(.semibold)).foregroundStyle(ShelfTheme.accent) }
                        V28FactQuote(label: "SOURCE ONE", fact: connection.sourceA, title: connection.currentIdeaTitle)
                        Button("View first source") { model.viewFact(connection.sourceA, returningTo: "Knowledge Collision") }
                            .accessibilityIdentifier("collision-source-one")
                        V28FactQuote(label: "SOURCE TWO", fact: connection.sourceB, title: connection.relatedIdeaTitle)
                        Button("View second source") { model.viewFact(connection.sourceB, returningTo: "Knowledge Collision") }
                            .accessibilityIdentifier("collision-source-two")
                    } else { Text("A source changed. Reopen Connections to compare the current passages.") }
                    if let message = model.message { Text(message) }
                }.padding(22).frame(maxWidth: 680).frame(maxWidth: .infinity, alignment: .leading)
            }.scrollDismissesKeyboard(.interactively)
        }.accessibilityIdentifier("knowledge-collision-screen")
        .task { await model.retrieve() }
        .fullScreenCover(item: $model.readerRoute) { route in ReaderScreen(model: route.reader, thumbnails: route.thumbnails) }
        .sheet(isPresented: $activityPresented) {
            if let definition = model.activity {
                TryItSheet(model: ReaderIntelligenceModel(learning: model.learning, source: model.source), definition: definition)
            }
        }
    }
    private var teach: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Why do these ideas belong together?").font(.headline)
            TextEditor(text: Binding(get: { response }, set: { response = String($0.prefix(6000)); feedback = nil }))
                .frame(minHeight: 150).scrollContentBackground(.hidden).padding(12)
                .background(ShelfTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel("Your connection explanation").accessibilityIdentifier("teach-connection-input")
            Button("Compare with both sources") {
                feedback = V28TeachPresentation.compare(response, sources: [connection.sourceA, connection.sourceB],
                    analyses: model.learning.snapshot.analyses, connection: connection)
            }.buttonStyle(ShelfButtonStyle(filled: true))
                .disabled(response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !valid)
                .accessibilityIdentifier("teach-connection-compare")
            if let feedback {
                if feedback.connected {
                    Text("YOU CONNECTED").font(.caption.weight(.semibold)).foregroundStyle(ShelfTheme.accent)
                    ForEach(Array(feedback.captured.enumerated()), id: \.offset) { _, point in
                        Text(point.assessment.explanation)
                        Text("\(point.source.documentTitle) · p. \(point.source.pageIndex + 1)").font(.caption).foregroundStyle(ShelfTheme.secondary)
                    }
                }
                let missing = [connection.sourceA, connection.sourceB].filter { source in !feedback.captured.contains { $0.source.id == source.id } }
                if !feedback.worthAdding.isEmpty || !missing.isEmpty {
                    Text("WORTH ADDING").font(.caption.weight(.semibold))
                    ForEach(Array(feedback.worthAdding.enumerated()), id: \.offset) { _, point in Text(point.assessment.explanation) }
                    ForEach(missing) { source in Text("Bring in this part from \(source.documentTitle): \(source.quote.text)") }
                }
                if !feedback.check.isEmpty {
                    Text("CHECK THIS").font(.caption.weight(.semibold))
                    ForEach(Array(feedback.check.enumerated()), id: \.offset) { _, point in Text(point.assessment.explanation) }
                }
                if !feedback.unsettled.isEmpty {
                    Text("YOUR SOURCE DOESN'T SETTLE THIS").font(.caption.weight(.semibold))
                    ForEach(Array(feedback.unsettled.enumerated()), id: \.offset) { _, text in Text(text) }
                }
            }
        }.accessibilityIdentifier("teach-connection-content")
    }
}

@MainActor struct ExplainFromLibrarySheet: View {
    @State var model: ReaderIntelligenceModel
    var body: some View {
        ShelfSheet(title: "Explain from my library") {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(model.libraryExplanations.filter { $0.isCurrent(in: model.learning.snapshot.analyses) }) { item in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(item.kind.rawValue).font(.caption.weight(.semibold)).foregroundStyle(ShelfTheme.accent)
                            Text("\(item.source.documentTitle) · p. \(item.passage.pageIndex + 1)").font(.headline)
                            Text(item.passage.sourceText).font(.system(.body, design: .serif)).fixedSize(horizontal: false, vertical: true)
                            if item.kind == .example {
                                Text("Rule from the same source: \(item.source.quote.text)").font(.callout).foregroundStyle(ShelfTheme.secondary)
                            }
                            Button("View in PDF") { model.viewLibraryItem(item) }.accessibilityIdentifier("library-explanation-source-" + item.kind.rawValue)
                        }
                    }
                    if model.libraryExplanations.isEmpty {
                        if model.retrieving { ProgressView("Reading related sources…") }
                        else { Text("Your library doesn't contain a grounded explanation for this passage yet.") }
                    }
                    if let message = model.message { Text(message) }
                }.padding(22).frame(maxWidth: 680).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.accessibilityIdentifier("explain-from-library-screen")
        .task { await model.retrieve() }
        .fullScreenCover(item: $model.readerRoute) { route in ReaderScreen(model: route.reader, thumbnails: route.thumbnails) }
    }
}
