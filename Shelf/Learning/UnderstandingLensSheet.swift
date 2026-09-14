import SwiftUI
import ShelfCore

@MainActor
struct UnderstandingLensSheet: View {
    let reader: ReaderModel
    @Bindable var model: LearningModel
    let source: LearningSource
    @Environment(\.dismiss) private var dismiss
    @State private var howExpanded = false
    @State private var sourceExpanded = false

    var body: some View {
        ShelfSheet(title: "Understanding Lens") { scrollContent }
            .background { UITestFrameProbe(identifier: "understanding-lens") }
            #if DEBUG
            .onAppear { traceProjection() }
            .onChange(of: model.snapshot.semanticIndexes[source.documentID]) { _, _ in traceProjection() }
            #endif
    }

    private var scrollContent: some View {
        ScrollView { passageContent }
            .background { UITestFrameProbe(identifier: "lens-scroll-frame") }
    }

    private var passageContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            sourceContext
            originPassage
            if source.sourceText.count > 260 {
                Button(sourceExpanded ? "Show excerpt" : "Read full passage") { sourceExpanded.toggle() }.font(.caption)
            }
            meaningContent
            factContent
            questionsContent
        }
        .padding(ShelfTheme.gutter).frame(maxWidth: 680).frame(maxWidth: .infinity)
    }

    private var sourceContext: some View {
        Button { showSource(source) } label: {
            Label("\(model.library.snapshot.activeBooks.first(where: { $0.id == source.documentID })?.title ?? "Source") · p. \(source.pageIndex + 1)", systemImage: "doc.text.magnifyingglass")
                .font(.callout).frame(minHeight: 44)
        }.accessibilityIdentifier("lens-view-source")
    }

    private var meaning: SourceMeaningProjection {
        SourceMeaningComposer().project(source: source, index: model.snapshot.semanticIndexes[source.documentID])
    }

    @ViewBuilder private var meaningContent: some View {
        let projection = meaning
        if let learned = model.snapshot.questions.first(where: {
            $0.modelProvenance != nil && $0.source.documentID == source.documentID &&
                $0.source.pageIndex == source.pageIndex && source.sourceText.contains($0.source.sourceText)
        }), let explanation = learned.modelProvenance?.explanation {
            Text("From this source").font(.headline)
            Text(explanation).accessibilityIdentifier(learned.modelProvenance?.backend == "apple-on-device" ? "lens-model-explanation" : "lens-local-explanation")
                .background {
                    if learned.modelProvenance?.schemaVersion == 3 { UITestFrameProbe(identifier: "lens-v3-explanation") }
                }
        }
        if !projection.sentences.isEmpty {
            Text("What this says").font(.headline)
            ForEach(projection.sentences, id: \.propositionID) { sentence in
                Text(sentence.text).font(.system(.body, design: .serif))
            }
        }
        keyIdeaContent
        QuestionConnectionsAction(learning: model, source: source)
    }

    @ViewBuilder private var keyIdeaContent: some View {
        let projection = meaning
        if let idea = projection.keyIdea {
            Text("Key idea").font(.caption.weight(.semibold)).foregroundStyle(ShelfTheme.secondary)
            Text(idea).leuScaledFont(26, weight: .regular, design: .serif)
        }
        if projection.terms.count > 1 {
            Text(projection.terms.joined(separator: " · ")).font(.callout).foregroundStyle(ShelfTheme.secondary)
        }
    }

    @ViewBuilder private var questionsContent: some View {
        let projection = meaning
        if !projection.questions.isEmpty {
            DisclosureGroup("Questions") {
                ForEach(Array(projection.questions.enumerated()), id: \.offset) { _, question in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(question.prompt)
                        DisclosureGroup("Show explanation") { Text(question.answer).foregroundStyle(ShelfTheme.secondary) }
                    }.padding(.vertical, 8)
                }
            }
        }
    }

    private var originPassage: some View {
        Text(verbatim: source.sourceText)
            .lineLimit(sourceExpanded ? nil : 4)
            .accessibilityIdentifier("lens-origin-passage")
            .font(.system(.body, design: .serif))
            .foregroundStyle(ShelfTheme.secondary)
            .padding(.leading, 12)
            .overlay(alignment: .leading) { originRule }
    }

    private var originRule: some View {
        Rectangle().fill(ShelfTheme.accent).frame(width: 2)
    }

    @ViewBuilder
    private var factContent: some View {
        let rows: [UnderstandingLensFact] = facts
        if rows.isEmpty && meaning.sentences.isEmpty {
            emptyTitle
            emptyDetail
        } else {
            localFacts
            relatedFacts
        }
    }

    private func isLocal(_ fact: UnderstandingLensFact) -> Bool {
        fact.target.documentID == source.documentID && fact.target.pageIndex == source.pageIndex &&
            source.sourceText.lowercased().contains(fact.target.sourceText.lowercased())
    }

    @ViewBuilder private var localFacts: some View {
        let rows = Array(facts.filter(isLocal).prefix(3))
        if !rows.isEmpty {
            DisclosureGroup("How it works", isExpanded: $howExpanded) { factRows(rows) }
        }
    }

    @ViewBuilder private var relatedFacts: some View {
        let rows = facts.filter { !isLocal($0) } + Array(facts.filter(isLocal).dropFirst(3))
        if !rows.isEmpty { DisclosureGroup("Related") { factRows(rows) } }
    }

    private func factRows(_ rows: [UnderstandingLensFact]) -> some View {
        ForEach(rows) { (fact: UnderstandingLensFact) in
            UnderstandingLensFactRow(fact: fact, onSelect: showSource)
        }
    }

    private var emptyTitle: some View {
        Text("This passage needs more context before Leu can explain it.")
            .leuScaledFont(26, weight: .regular, design: .serif)
            .accessibilityIdentifier("understanding-lens-empty")
    }

    private var emptyDetail: some View {
        Text("Nothing is generated to fill the gap.")
            .font(.callout)
            .foregroundStyle(ShelfTheme.secondary)
    }

    private var facts: [UnderstandingLensFact] {
        UnderstandingLensFact.matching(source: source, semanticIndexes: model.snapshot.semanticIndexes)
    }

    private func traceProjection() {
        #if DEBUG
        StudyInteractionTrace.record("lens.project document=\(source.documentID) page=\(source.pageIndex) sourceCharacters=\(source.sourceText.count) propositions=\(model.snapshot.semanticIndexes[source.documentID]?.propositions.count ?? 0) plainMeaning=\(meaning.sentences.count) factRows=\(facts.count)")
        if ProcessInfo.processInfo.environment["LEU_PDF_DIAGNOSTICS"] == "1" {
            print("[leu-lens] source=\(source.sourceText) meaning=\(meaning.sentences.map(\.text)) facts=\(facts.map(\.relationshipText))")
        }
        #endif
    }

    private func showSource(_ target: LearningSource) {
        if reader.knowledge.queueLensNavigation(to: target, from: source) {
            dismiss()
        }
    }
}
