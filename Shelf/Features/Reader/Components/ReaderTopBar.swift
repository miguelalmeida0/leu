import SwiftUI

@MainActor
struct ReaderTopBar: View {
    @Bindable var model: ReaderModel
    let close: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                IconButton(
                    symbol: "chevron.left",
                    label: model.returnLabel,
                    accessibilityID: "close-reader",
                    action: close
                )

                VStack(spacing: 1) {
                    Text(model.book.title)
                        .font(.system(size: 14, weight: .medium, design: .serif))
                        .lineLimit(1)
                        .foregroundStyle(ShelfTheme.text)
                    if let section = model.currentOutlineTitle {
                        Text(section)
                            .font(.caption2)
                            .foregroundStyle(ShelfTheme.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Reading \(model.book.title)")

                LeuMenu {
                    if model.displayMode == .read {
                        Button(model.semanticLevel == .page ? "Reading overview" : "Back to current page",
                               systemImage: model.semanticLevel == .page ? "square.grid.2x2" : "doc.text") {
                            model.semanticLevel = model.semanticLevel == .page ? .chapter : .page
                        }
                    }
                    Button("Contents", systemImage: "list.bullet") { model.panel = .contents }
                    Button("Reading session", systemImage: "clock") { model.panel = .time }
                    Button("Reading appearance", systemImage: "textformat") { model.panel = .settings }
                    Button("Voice & listening", systemImage: "waveform") { model.showVoiceSettings = true }
                    Button("Search ideas", systemImage: "text.magnifyingglass") { model.showKnowledgeSearch = true }
                    Button("Focus mode", systemImage: "arrow.up.left.and.arrow.down.right") { model.focusMode = true }
                    Divider()
                    Button("Share original PDF", systemImage: "square.and.arrow.up") { Task { await model.export(annotated: false) } }
                    Button("Share annotated copy", systemImage: "pencil.and.outline") { Task { await model.export(annotated: true) } }
                    Divider()
                    Button("Undo annotation", systemImage: "arrow.uturn.backward") { Task { await model.undo() } }.disabled(!model.canUndo)
                    Button("Redo annotation", systemImage: "arrow.uturn.forward") { Task { await model.redo() } }.disabled(!model.canRedo)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .medium))
                        .frame(width: 44, height: 44)
                        .foregroundStyle(ShelfTheme.text)
                }
                .accessibilityLabel("Reader options")
                .disabled(!model.isLoaded || model.isSaving)
            }

            Picker("Reading mode", selection: Binding(
                get: { model.displayMode },
                set: { model.setDisplayMode($0) }
            )) {
                ForEach(ReaderDisplayMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 180)
            .controlSize(.small)
            .disabled(!model.isLoaded)

            if model.initialSourceText != nil || (model.initialKnowledgeTravel && model.knowledge.canNavigateBack) {
                Button(action: close) {
                    HStack(spacing: 7) {
                        Image(systemName: "arrow.uturn.backward")
                        Text(model.returnLabel)
                            .font(.system(.caption, design: .serif).weight(.semibold))
                        Spacer()
                        Text("Return")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(ShelfTheme.secondary)
                    }
                    .foregroundStyle(ShelfTheme.action)
                    .padding(.horizontal, 11)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(model.returnLabel)
                .accessibilityHint("Return to the study context you came from")
                .accessibilityIdentifier("reader-context-return")
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 2)
        .padding(.bottom, 7)
        .background(ShelfTheme.background)
        .overlay(alignment: .bottom) { ShelfTheme.line.frame(height: 0.5) }
    }
}
