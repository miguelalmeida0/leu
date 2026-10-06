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
                VStack(alignment: .leading, spacing: 22) {
                    header
                    passageDisclosure
                    body(for: controller.state)
                    diagnostics
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 22)
                .frame(maxWidth: 680, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
        .onDisappear { onClose() }
        .background { UITestFrameProbe(identifier: "explain-like-ten") }
    }

    private var header: some View {
        Text(sourceLabel.uppercased())
            .font(LeuDesign.eyebrow(11)).tracking(LeuDesign.eyebrowTracking)
            .foregroundStyle(LeuDesign.eyebrowOnFelt)
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
                    Image(systemName: showingPassage ? "chevron.up" : "chevron.down").font(.leu(.caption2))
                }
                .font(.leu(.footnote, weight: .semibold))
                .foregroundStyle(LeuDesign.ink)
                .underline()
                .frame(minHeight: 44)
                .contentShape([.interaction, .accessibility], Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("explain-toggle-passage")
            if showingPassage, let packet = controller.packet {
                Text(verbatim: packet.selectionText)
                    .font(.leu(.body, serif: true))
                    .lineSpacing(4)
                    .foregroundStyle(LeuDesign.readingForeground)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(LeuDesign.readingSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: LeuDesign.ink.opacity(0.10), radius: 8, x: 0, y: 4)
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
            Text(label).font(.leu(.callout)).foregroundStyle(ShelfTheme.secondary)
        }
        .frame(minHeight: 44)
        .accessibilityIdentifier("explain-progress")
    }

    private func explanation(_ record: ExplanationRecord) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 10) {
                    Text("EXPLAINED LIKE YOU'RE")
                        .font(LeuDesign.eyebrow(11)).tracking(LeuDesign.eyebrowTracking)
                        .foregroundStyle(LeuDesign.ink)
                    Spacer(minLength: 8)
                    Text(level(record.mode))
                        .font(.leu(.caption, weight: .bold))
                        .foregroundStyle(LeuDesign.cream)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(LeuDesign.ink, in: Capsule())
                }
                .accessibilityElement(children: .combine)
                ForEach(Array(record.candidate.blocks.enumerated()), id: \.offset) { index, block in
                    if block.kind == .example {
                        StitchDivider()
                        Text("Illustration").font(.leu(.caption, weight: .bold)).foregroundStyle(LeuDesign.ink)
                    }
                    Text(verbatim: block.text)
                        .font(blockFont(block.kind))
                        .tracking(block.kind == .plainMeaning ? -0.4 : 0)
                        .foregroundStyle(LeuDesign.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("explain-block-\(index)")
                }
                if let term = record.candidate.preservedTerm,
                   let meaning = record.candidate.preservedTermMeaning {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: term).font(.leu(.callout, weight: .bold)).foregroundStyle(LeuDesign.ink)
                        Text(verbatim: meaning).font(.leu(.callout)).foregroundStyle(LeuDesign.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityIdentifier("explain-term")
                }
            }
            .padding(26)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LeuDesign.butter, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(LeuDesign.ink.opacity(0.4), style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
                    .padding(8)
                    .accessibilityHidden(true)
            }
            .shadow(color: LeuDesign.ink.opacity(0.16), radius: 16, x: 0, y: 9)
            provenance(record)
            refinements
        }
    }

    /// The level the explanation is written at, said plainly.
    private func level(_ mode: ExplanationMode) -> String {
        switch mode {
        case .standard: return "10"
        case .evenSimpler: return "even simpler"
        case .withExample: return "10, with an example"
        }
    }

    @ViewBuilder private var diagnostics: some View {
        #if DEBUG
        DisclosureGroup("Development diagnostics") {
            let value = controller.diagnostics
            Text("Backend: \(controller.backend) · Availability: \(value.availability?.rawValue ?? "not checked")").font(.leu(.caption))
            Text("Calls: \(value.attempts) · Responses: \(value.responses) · Accepted: \(value.accepted) · Rejected: \(value.rejections)")
                .font(.caption.monospaced()).accessibilityIdentifier("explain-diagnostics")
            if let error = value.lastError { Text(verbatim: error).font(.caption.monospaced()) }
            Text("Last validation failures: " + value.lastValidationFailures.joined(separator: ", ")).font(.leu(.caption))
            Text("Last validation warnings: " + value.lastValidationWarnings.joined(separator: ", ")).font(.leu(.caption))
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
        case .plainMeaning: return LeuDesign.display(26)
        case .mechanism, .example: return .leu(.body, weight: .semibold)
        case .caveat: return .leu(.callout)
        }
    }

    private var refinements: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("WHAT NEXT")
                .font(LeuDesign.eyebrow(11)).tracking(LeuDesign.eyebrowTracking)
                .foregroundStyle(LeuDesign.eyebrowOnFelt)
                .accessibilityAddTraits(.isHeader)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { refinementButtons }
                VStack(alignment: .leading, spacing: 10) { refinementButtons }
            }
        }
    }

    @ViewBuilder private var refinementButtons: some View {
        Button("Even simpler") { controller.evenSimpler() }
            .buttonStyle(LeuPrimaryButtonStyle(filled: true, pill: true))
            .disabled(controller.isBusy)
            .accessibilityIdentifier("explain-even-simpler")
        Button("Show an example") { controller.showExample() }
            .buttonStyle(LeuPrimaryButtonStyle(filled: false, pill: true))
            .disabled(controller.isBusy)
            .accessibilityIdentifier("explain-show-example")
        Button("Back to reading", action: onClose)
            .buttonStyle(LeuPrimaryButtonStyle(filled: false, pill: true))
    }

    /// Honest labelling. No confidence percentage and no "verified" badge.
    private func provenance(_ record: ExplanationRecord) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.leu(.subheadline))
                .foregroundStyle(LeuDesign.ink)
                .accessibilityHidden(true)
            Text(record.servedFromCache
                 ? "Saved on this iPhone from an earlier reading of this passage."
                 : "Written from this passage only, on this iPhone.")
                .font(.leu(.footnote, weight: .medium))
                .foregroundStyle(LeuDesign.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("explain-provenance")
                .accessibilityValue(record.mode.rawValue)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LeuDesign.feltLight, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func notice(title: String, detail: String, id: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(LeuDesign.display(24)).foregroundStyle(LeuDesign.ink)
            Text(detail).font(.leu(.callout)).foregroundStyle(ShelfTheme.secondary)
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
