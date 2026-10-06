import ShelfCore
import SwiftUI

/// "In your own words": the reader explains a page as they would to a curious friend, and
/// each idea from the page they get across lights a window in the snow globe.
///
/// iPad landscape mirrors the reference composition (globe and ideas left, words right).
/// iPhone, iPad portrait and accessibility text sizes reflow into one column with the
/// globe on top. The comparison itself is unchanged: verified against the source, no score.
@MainActor struct TeachLeuSheet: View {
    @Bindable var model: ReaderIntelligenceModel
    @State private var connections = false
    @State private var activity = false
    @FocusState private var writing: Bool
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ShelfSheet(title: "In your own words") {
            GeometryReader { proxy in
                let wide = proxy.size.width >= 860 && !typeSize.isAccessibilitySize
                ScrollView {
                    if wide {
                        HStack(alignment: .center, spacing: 56) {
                            globeColumn(wide: true).frame(maxWidth: 560)
                            words(wide: true).frame(maxWidth: 600)
                        }
                        .padding(.horizontal, 48)
                        .padding(.vertical, 36)
                        .frame(minHeight: proxy.size.height)
                        .frame(maxWidth: .infinity)
                    } else {
                        VStack(alignment: .leading, spacing: 26) {
                            globeColumn(wide: false)
                            words(wide: false)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 22)
                        .frame(maxWidth: 640)
                        .frame(maxWidth: .infinity)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
            }
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

    // MARK: The globe and the ideas it listens for

    private var ideas: [TeachIdea] { TeachGlobeProgress.ideas(claims: model.source.claims, result: model.attempt.result) }
    private var windows: Int { TeachGlobeProgress.windows(claims: model.source.claims, result: model.attempt.result) }
    private var page: Int { model.source.packet.pageIndex + 1 }

    private func globeColumn(wide: Bool) -> some View {
        VStack(alignment: .leading, spacing: wide ? 28 : 18) {
            SnowGlobe(lit: windows)
                .frame(maxWidth: wide ? 560 : 380)
                .frame(maxWidth: .infinity)
            if !ideas.isEmpty { TeachLeuIdeas(ideas: ideas, columns: wide) }
            VStack(alignment: .leading, spacing: 6) {
                Text("WHAT LEU IS LISTENING FOR")
                    .font(LeuDesign.eyebrow(11))
                    .tracking(LeuDesign.eyebrowTracking)
                    .foregroundStyle(LeuDesign.eyebrowOnFelt)
                    .accessibilityAddTraits(.isHeader)
                Text(TeachGlobeProgress.listening(ideaCount: ideas.count, page: page))
                    .font(.leu(.subheadline))
                    .foregroundStyle(LeuDesign.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: The reader's words and Leu's reply

    private var explanation: String { model.attempt.learnerExplanation }
    private var isEmpty: Bool { explanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private func words(wide: Bool) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(LeuDesign.display(wide ? 40 : 30))
                    .tracking(wide ? -1.2 : -0.8)
                    .foregroundStyle(LeuDesign.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text("Say it the way you'd tell a curious friend. No need for the right words, just the right idea.")
                    .font(.leu(.body))
                    .foregroundStyle(LeuDesign.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            editor
            if model.attempt.result == nil {
                Button(model.inferring ? "Listening…" : "See what got across", action: model.assess)
                    .buttonStyle(LeuPrimaryButtonStyle(filled: true, pill: true))
                    .disabled(isEmpty || model.inferring || !model.canTeach)
                    .accessibilityIdentifier("teach-leu-compare")
                if model.inferring {
                    ProgressView("Comparing on this device…")
                        .font(.leu(.footnote))
                        .tint(LeuDesign.ink)
                        .accessibilityIdentifier("teach-leu-inference")
                }
            }
            if let result = model.attempt.result {
                TeachLeuReply(result: result, windows: windows, tailLeading: wide)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            if let message = model.message {
                Text(message).font(.leu(.footnote)).foregroundStyle(LeuDesign.secondary)
            }
            actions
            source
        }
        .animation(.easeInOut(duration: 0.6), value: model.attempt.result == nil)
    }

    private var title: String {
        guard let section = model.source.passage.sectionTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
              !section.isEmpty else { return "In your own words" }
        return "In your own words: \(section)"
    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            if explanation.isEmpty {
                Text("Start anywhere. What happens, and why?")
                    .font(.leu(.title3, serif: true))
                    .foregroundStyle(LeuDesign.fieldPlaceholder)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 8)
                    .accessibilityHidden(true)
            }
            TextEditor(text: Binding(get: { model.attempt.learnerExplanation }, set: model.edit))
                .font(.leu(.title3, serif: true))
                .lineSpacing(6)
                .foregroundStyle(LeuDesign.ink)
                .scrollContentBackground(.hidden)
                .focused($writing)
                .frame(minHeight: 150)
                .accessibilityIdentifier("teach-leu-explanation")
                .accessibilityLabel("Your explanation")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(LeuDesign.raised, in: RoundedRectangle(cornerRadius: LeuDesign.radius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LeuDesign.radius, style: .continuous)
                .strokeBorder(writing ? LeuDesign.ink : LeuDesign.line, lineWidth: writing ? 1.5 : 1)
        }
        .shadow(color: LeuDesign.ink.opacity(0.08), radius: 10, x: 0, y: 6)
        .animation(.easeInOut(duration: 0.3), value: writing)
    }

    @ViewBuilder private var actions: some View {
        if model.attempt.result != nil {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { actionButtons }
                VStack(alignment: .leading, spacing: 10) { actionButtons }
            }
        }
    }

    @ViewBuilder private var actionButtons: some View {
        Button("Say it again") { writing = true }
            .buttonStyle(LeuPrimaryButtonStyle(filled: true, pill: true))
            .accessibilityHint("Puts the cursor back in your explanation")
        if !model.connections.isEmpty {
            Button("Find connections") { connections = true }
                .buttonStyle(LeuPrimaryButtonStyle(filled: false, pill: true))
                .accessibilityIdentifier("teach-leu-connections")
        }
        if model.activity != nil {
            Button("Try it") { activity = true }
                .buttonStyle(LeuPrimaryButtonStyle(filled: false, pill: true))
                .accessibilityIdentifier("teach-leu-try-it")
        }
        Button(model.attempt.resolved ? "Settled" : "This thought is settled", action: model.resolve)
            .buttonStyle(LeuPrimaryButtonStyle(filled: false, pill: true))
            .disabled(model.attempt.resolved)
            .accessibilityIdentifier("teach-leu-resolve")
    }

    private var source: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("FROM YOUR SOURCE")
                .font(LeuDesign.eyebrow(11))
                .tracking(LeuDesign.eyebrowTracking)
                .foregroundStyle(LeuDesign.eyebrowOnFelt)
                .accessibilityAddTraits(.isHeader)
            Text(model.sourceLabel).font(.leu(.subheadline, weight: .semibold)).foregroundStyle(LeuDesign.ink)
            Text(model.source.passage.sourceText)
                .font(.leu(.body, serif: true))
                .foregroundStyle(LeuDesign.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("teach-leu-source-quote")
            Button("Peek at page \(page)") { model.viewSource(returningTo: "In your own words") }
                .buttonStyle(LeuPrimaryButtonStyle(filled: false, pill: true))
                .accessibilityIdentifier("teach-leu-view-source")
        }
        .padding(.top, 8)
    }
}
