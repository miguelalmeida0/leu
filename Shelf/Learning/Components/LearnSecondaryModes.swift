import SwiftUI

@MainActor
struct LearnSecondaryModes: View {
    @Bindable var model: LearningModel
    @Bindable var knowledge: KnowledgeModel
    let onProgress: () -> Void
    @State private var presentedDestination: Destination?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private enum Destination: String, Identifiable {
        case connections, documentTopics, interview, activeRecall, searchIdeas
        #if DEBUG
        case intelligence
        #endif
        var id: String { rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                row("Active Recall", detail: "Retrieve", symbol: "brain", identifier: "learning-mode-active-recall") {
                    presentedDestination = .activeRecall
                }
                row("Interview Mode", detail: "Questions", symbol: "quote.bubble", identifier: "learning-mode-interview") {
                    presentedDestination = .interview
                }
                row("Progress", detail: "Now & history", symbol: "clock.arrow.circlepath", identifier: "learning-progress", action: onProgress)
                Button {
                    StudyInteractionTrace.record("activate.learning-more")
                    model.moreLearningExpanded.toggle()
                    StudyInteractionTrace.record(model.moreLearningExpanded ? "disclosure.more.expanded" : "disclosure.more.collapsed")
                    ShelfHaptics.shared.play(.selectionChanged)
                } label: {
                    modeLabel("More", detail: model.moreLearningExpanded ? "Close tools" : "Study tools", symbol: "ellipsis")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("More learning options")
                .accessibilityValue(model.moreLearningExpanded ? "Expanded" : "Collapsed")
                .accessibilityIdentifier("learning-more")
            }

            // These rows have no local state. The sheet presenter stays on the stable parent.
            // Hidden controls must not survive behind the following Study sections.
            if model.moreLearningExpanded {
                VStack(spacing: 0) {
                    detailRow("Connections", detail: "Ideas related across your library", symbol: "link", identifier: "learning-connections") {
                        presentedDestination = .connections
                    }
                    Divider().overlay(ShelfTheme.line)
                    detailRow("Document topics", detail: "Topics found locally in your books", symbol: "tag", identifier: "learning-document-topics") {
                        presentedDestination = .documentTopics
                    }
                    Divider().overlay(ShelfTheme.line)
                    detailRow("Search ideas", detail: "Search passages across your library", symbol: "text.magnifyingglass", identifier: "learning-search-ideas") {
                        presentedDestination = .searchIdeas
                    }
                    #if DEBUG
                    detailRow("Learning Intelligence", detail: "Development diagnostics", symbol: "checkmark.shield", identifier: "learning-intelligence") {
                        presentedDestination = .intelligence
                    }
                    #endif
                }
                .padding(.top, 12)
                .transition(.identity)
            }
        }
        .sheet(item: $presentedDestination) { destination in
            switch destination {
            case .connections:
                ConnectionsOverviewSheet(knowledge: knowledge)
            case .documentTopics:
                DocumentTopicsSheet(model: model)
            case .interview:
                InterviewSetupSheet(model: model)
            case .activeRecall:
                ActiveRecallSetupSheet(model: model)
            case .searchIdeas:
                KnowledgeSearchSheet(knowledge: knowledge)
            #if DEBUG
            case .intelligence:
                LearningIntelligenceDiagnosticsView(model: model)
            #endif
            }
        }
    }

    private func row(_ title: String, detail: String, symbol: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button {
            StudyInteractionTrace.record("activate.\(identifier)")
            action()
        } label: {
            modeLabel(title, detail: detail, symbol: symbol)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(detail)
        .accessibilityIdentifier(identifier)
    }

    private func modeLabel(_ title: String, detail: String, symbol: String) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: symbol).font(.body.weight(.medium))
                .frame(width: 24).foregroundStyle(LeuDesign.signal)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                    .foregroundStyle(LeuDesign.textPrimary)
                Text(detail).font(.caption).foregroundStyle(LeuDesign.textSecondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .padding(.horizontal, 12).padding(.vertical, 4)
        .background(LeuDesign.surfaceSecondary, in: RoundedRectangle(cornerRadius: 7))
        .overlay { RoundedRectangle(cornerRadius: 7).stroke(LeuDesign.separator, lineWidth: 1) }
        .contentShape(Rectangle())
    }

    private func detailRow(_ title: String, detail: String, symbol: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button {
            // Reject an activation delivered from a stale accessibility snapshot.
            guard model.moreLearningExpanded else { return }
            StudyInteractionTrace.record("activate.\(identifier)")
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 26)
                    .foregroundStyle(ShelfTheme.olive)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(ShelfTheme.text)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(ShelfTheme.secondary)
                }
                Spacer(minLength: 12)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(ShelfTheme.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(detail)
        .accessibilityIdentifier(identifier)
    }
}
