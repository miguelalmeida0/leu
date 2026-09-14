import SwiftUI
import ShelfCore

/// A compact reading sheet, not a new app section. Uses existing tokens only.
@MainActor
struct ExplainLikeTenSheet: View {
    @ObservedObject var controller: ExplanationController
    /// Host-supplied location label, e.g. "React Notes · p. 18".
    let sourceLabel: String
    let onClose: () -> Void

    @State private var showingPassage = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ShelfSheet(title: "Explain like I'm 10") {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    passageDisclosure
                    body(for: controller.state)
                    diagnostics
                }
                .padding(ShelfTheme.gutter)
                .frame(maxWidth: 660, alignment: .leading)
            }
        }
        .onDisappear { onClose() }
        .background { UITestFrameProbe(identifier: "explain-like-ten") }
    }

    private var header: some View {
        Text(sourceLabel)
            .font(ShelfTheme.eyebrow(10)).tracking(1.2)
            .foregroundStyle(ShelfTheme.secondary)
            .accessibilityIdentifier("explain-source-label")
    }

    /// The original passage stays available but collapsed, so the explanation leads.
    private var passageDisclosure: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeOut(duration: 0.18)) { showingPassage.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Text(showingPassage ? "Hide original passage" : "Show original passage")
                    Image(systemName: showingPassage ? "chevron.up" : "chevron.down").font(.caption2)
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(ShelfTheme.accent)
                .frame(minHeight: 44)
                .contentShape([.interaction, .accessibility], Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("explain-toggle-passage")
            if showingPassage, let packet = controller.packet {
                Text(verbatim: packet.selectionText)
                    .font(.system(.footnote, design: .serif))
                    .foregroundStyle(ShelfTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 12)
                    .overlay(alignment: .leading) { Rectangle().fill(ShelfTheme.line).frame(width: 2) }
                    .accessibilityIdentifier("explain-original-passage")
            }
        }
    }

    @ViewBuilder
    private func body(for state: ExplanationController.State) -> some View {
        switch state {
        case .idle, .preparing:
            progress("Reading the passage")
        case .generating:
            progress("Working out a simpler explanation")
        case .validating:
            progress("Checking it against the passage")
        case .ready(let record):
            explanation(record)
                .onAppear { controller.recordVisible(record) }
        case .needsContext(let reason):
            notice(title: "This needs more context", detail: reason, id: "explain-needs-context")
        case .unavailable(let modelState):
            notice(title: "Not available on this iPhone right now",
                   detail: unavailableDetail(modelState), id: "explain-unavailable")
        case .failed(let message):
            notice(title: "That did not work", detail: message, id: "explain-failed")
        case .cancelled:
            EmptyView()
        }
    }

    /// A brief honest progress state, never partially validated streamed text.
    private func progress(_ label: String) -> some View {
        HStack(spacing: 10) {
            ProgressView()
            Text(label).font(.callout).foregroundStyle(ShelfTheme.secondary)
        }
        .frame(minHeight: 44)
        .accessibilityIdentifier("explain-progress")
    }

    private func explanation(_ record: ExplanationRecord) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(record.candidate.blocks.enumerated()), id: \.offset) { index, block in
                if block.kind == .example { Text("Illustration").font(.caption.weight(.semibold)) }
                Text(verbatim: block.text)
                    .font(blockFont(block.kind))
                    .foregroundStyle(ShelfTheme.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("explain-block-\(index)")
            }
            if let term = record.candidate.preservedTerm,
               let meaning = record.candidate.preservedTermMeaning {
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: term).font(.callout.weight(.semibold)).foregroundStyle(ShelfTheme.text)
                    Text(verbatim: meaning).font(.callout).foregroundStyle(ShelfTheme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityIdentifier("explain-term")
            }
            refinements
            provenance(record)
        }
    }

    @ViewBuilder private var diagnostics: some View {
        #if DEBUG
        DisclosureGroup("Development diagnostics") {
            let value = controller.diagnostics
            Text("Backend: \(controller.backend) · Availability: \(value.availability?.rawValue ?? "not checked")").font(.caption)
            Text("Calls: \(value.attempts) · Responses: \(value.responses) · Accepted: \(value.accepted) · Rejected: \(value.rejections)")
                .font(.caption.monospaced()).accessibilityIdentifier("explain-diagnostics")
            if let error = value.lastError { Text(verbatim: error).font(.caption.monospaced()) }
            Text("Last validation failures: " + value.lastValidationFailures.joined(separator: ", ")).font(.caption)
            Text("Last validation warnings: " + value.lastValidationWarnings.joined(separator: ", ")).font(.caption)
            let trace = ExplanationAttemptTrace.summary(for: controller.packet)
            if !trace.isEmpty {
                Text(verbatim: trace).font(.caption2.monospaced())
                    .accessibilityIdentifier("explain-attempt-trace")
            }
        }
        #endif
    }

    private func blockFont(_ kind: ExplanationBlock.Kind) -> Font {
        switch kind {
        case .plainMeaning: return .system(.title3, design: .serif)
        case .mechanism, .example: return .system(.body, design: .serif)
        case .caveat: return .callout
        }
    }

    private var refinements: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button("Even simpler") { controller.evenSimpler() }
                .buttonStyle(ShelfButtonStyle(filled: true))
                .disabled(controller.isBusy)
                .accessibilityIdentifier("explain-even-simpler")
            Button("Show an example") { controller.showExample() }
                .buttonStyle(.plain)
                .font(.callout.weight(.semibold))
                .foregroundStyle(ShelfTheme.accent)
                .frame(minHeight: 44)
                .contentShape([.interaction, .accessibility], Rectangle())
                .disabled(controller.isBusy)
                .accessibilityIdentifier("explain-show-example")
        }
    }

    /// Honest labelling. No confidence percentage and no "verified" badge.
    private func provenance(_ record: ExplanationRecord) -> some View {
        Text(record.servedFromCache
             ? "Saved on this iPhone from an earlier reading of this passage."
             : "Written from this passage only, on this iPhone.")
            .font(.caption)
            .foregroundStyle(ShelfTheme.secondary)
            .accessibilityIdentifier("explain-provenance")
            .accessibilityValue(record.mode.rawValue)
    }

    private func notice(title: String, detail: String, id: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).leuScaledFont(24, weight: .regular, design: .serif).foregroundStyle(ShelfTheme.text)
            Text(detail).font(.callout).foregroundStyle(ShelfTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityIdentifier(id)
    }

    private func unavailableDetail(_ state: LearningModelState) -> String {
        switch state {
        case .unsupportedDevice: return "This iPhone does not support on-device explanation."
        case .unsupportedOS: return "This needs a newer version of iOS."
        case .appleIntelligenceDisabled: return "Turn on Apple Intelligence in iPhone Settings to use this."
        case .modelNotReady, .loading: return "The on-device model is still getting ready. Try again shortly."
        default: return "On-device explanation is not available yet."
        }
    }
}
