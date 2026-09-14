import SwiftUI
import ShelfCore

@MainActor
struct LearningObjectActionSheet: View {
    @Bindable var reader: ReaderModel
    @Bindable var learning: LearningModel
    @Bindable var knowledge: KnowledgeModel
    var onExplainLikeTen: ((LearningSource) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var source: LearningSource?
    @State private var createdObject: LearningObject?
    @State private var followUp: FollowUp?

    enum FollowUp: Identifiable { case mask, explain; var id: String { String(describing: self) } }
    @State private var testEditorPresented = false
    @State private var connectPresented = false
    @State private var intelligence: ReaderIntelligenceModel?
    @State private var destination: IntelligenceDestination?
    private enum IntelligenceDestination: String, Identifiable {
        case teach, connections, activity, question
        var id: String { rawValue }
    }

    var body: some View {
        ShelfSheet(title: "Learn from this") {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let source {
                        Text(source.sourceText).font(.system(.body, design: .serif)).lineLimit(8)
                            .foregroundStyle(ShelfTheme.secondary)
                            .padding(.leading, 14)
                            .overlay(alignment: .leading) { Rectangle().fill(ShelfTheme.accent).frame(width: 2) }
                    }
                    Text("Turn the source into something you can retrieve later.")
                        .font(LearningTokens.Typography.title)
                    actions
                }.padding(ShelfTheme.gutter)
            }
        }
        .background { UITestFrameProbe(identifier: "learning-object-actions") }
        .task(id: learning.snapshot.analyses[reader.book.id]?.fingerprint) {
            source = reader.currentLearningSource()
            if let source, let analysis = learning.snapshot.analyses[source.documentID],
               let citation = IntelligenceSource(source: source, analysis: analysis) {
                intelligence = ReaderIntelligenceModel(learning: learning, source: citation)
                learning.prepareIntelligence(for: source)
                await intelligence?.retrieve()
            }
        }
        .onDisappear { intelligence?.cancel() }
        .sheet(item: $destination, onDismiss: {
            if testEditorPresented { learning.endSession(); testEditorPresented = false }
        }) { destination in
            if let intelligence {
                switch destination {
                case .teach: TeachLeuSheet(model: intelligence)
                case .question: PassageQuestionSheet(model: intelligence)
                case .connections: RabbitHoleSheet(model: intelligence)
                case .activity:
                    if let definition = intelligence.activity { TryItSheet(model: intelligence, definition: definition) }
                }
            }
        }
        .sheet(item: $followUp) { follow in
            if let object = createdObject {
                switch follow {
                case .mask: DiagramMaskEditor(model: learning, object: object)
                case .explain: ExplanationRecorderSheet(model: learning, object: object)
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { connectPresented }, set: { if !$0 { connectPresented = false } }
        )) {
            if let source { ConnectedPassageSheet(knowledge: knowledge, source: source) }
        }
    }

    private var actions: some View {
        VStack(spacing: 0) {
            if let onExplainLikeTen {
                action("Explain like I'm 10", "text.book.closed", "Explain this passage in plain words.", id: "learning-action-explain-like-ten") {
                    if let source {
                        if let intelligence { Task { await intelligence.record(.askedExplanation) } }
                        onExplainLikeTen(source)
                    }
                }
            }
            if let intelligence, intelligence.canTeach {
                Divider().overlay(ShelfTheme.line)
                action("Teach Leu", "text.bubble", "Compare your explanation with this source.", id: "learning-action-teach-leu") { destination = .teach }
                if intelligence.activity != nil {
                    Divider().overlay(ShelfTheme.line)
                    action("Try it", "hand.draw", "Manipulate an idea from this passage.", id: "learning-action-try-it") { destination = .activity }
                } else if learning.activeSession == nil && learning.snapshot.questions.contains(where: {
                    $0.source.documentID == source?.documentID && $0.source.pageIndex == source?.pageIndex &&
                    $0.modelProvenance?.schemaVersion == 3 &&
                    CanonicalWhitespaceResolver.normalize(intelligence.source.passage.sourceText).contains(CanonicalWhitespaceResolver.normalize($0.source.sourceText))
                }) {
                    Divider().overlay(ShelfTheme.line)
                    action("Ask me", "questionmark.circle", "Retrieve an idea from this source.", id: "learning-action-test") {
                        if learning.startPassageQuestion(intelligence.source) { testEditorPresented = true; destination = .question }
                    }
                }
                if !intelligence.connections.isEmpty {
                    Divider().overlay(ShelfTheme.line)
                    action("Find connections", "link", "A relationship verified against both passages.", id: "learning-action-find-connections") { destination = .connections }
                }
            }
            DisclosureGroup("Passage tools") {
                action("Understand", "scope", "Inspect source-backed concepts.", id: "learning-action-understand") { if let source { reader.requestLens(source) } }
                action("Remember", "bookmark", "Keep this passage for later.", id: "learning-action-remember") { capture(.passage) }
                action("Mask", "rectangle.dashed", "Cover a region to recall later.", id: "learning-action-mask") { capture(.maskedRegion, follow: .mask) }
                action("Record explanation", "waveform", "Record your own voice locally.", id: "learning-action-explain") { capture(.explanationRecording, follow: .explain) }
            }.padding(15).accessibilityIdentifier("learning-passage-tools")
        }.background(ShelfTheme.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    private func action(_ title: String, _ symbol: String, _ detail: String, id: String,
                        perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            HStack(spacing: 14) {
                Image(systemName: symbol).font(.title3).foregroundStyle(ShelfTheme.accent).frame(width: 30)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline).foregroundStyle(ShelfTheme.text)
                    Text(detail).font(.caption).foregroundStyle(ShelfTheme.secondary).multilineTextAlignment(.leading)
                }
                Spacer(); Image(systemName: "chevron.right").foregroundStyle(ShelfTheme.secondary)
            }.padding(15)
        }
        .accessibilityIdentifier(id)
        .accessibilityLabel(title)
        .accessibilityHint(detail)
        .buttonStyle(.plain)
    }

    private func capture(_ type: LearningObjectType, follow: FollowUp? = nil) {
        guard let source else { return }
        Task {
            do {
                let object = try await learning.capture(type: type, source: source)
                createdObject = object
                learning.play(.objectCaptured)
                if let follow { followUp = follow } else { dismiss() }
            } catch { learning.errorMessage = error.localizedDescription }
        }
    }
}
