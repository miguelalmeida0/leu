import SwiftUI
import ShelfCore

@MainActor struct TryItSheet: View {
    @Bindable var model: ReaderIntelligenceModel
    let definition: ActivityDefinition
    @State private var state = ActivityState()
    @State private var moved = false
    var body: some View {
        ShelfSheet(title: "Try it") {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(definition.title).font(.system(.title, design: .serif))
                    Text(definition.premise).foregroundStyle(ShelfTheme.secondary)
                    if definition.contract == .stableKeys { keys } else { cache }
                    Text(state.lastAction).font(.headline).accessibilityIdentifier("try-it-outcome")
                    Button("Reset the illustration") { apply(.reset); moved = false }
                    Divider()
                    Text("FROM YOUR SOURCE").font(.caption.weight(.semibold)).foregroundStyle(ShelfTheme.accent)
                    Text(model.sourceLabel).font(.headline)
                    Text(definition.source.passage.sourceText).font(.system(.body, design: .serif))
                    Button("View source") { model.viewSource(definition.source, returningTo: "Try it") }.accessibilityIdentifier("try-it-view-source")
                    if let message = model.message { Text(message) }
                }.padding(22).frame(maxWidth: 680).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.accessibilityIdentifier("try-it-screen")
        .fullScreenCover(item: $model.readerRoute) { route in ReaderScreen(model: route.reader, thumbnails: route.thumbnails) }
    }
    private var keys: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Match rows using", selection: Binding(get: { state.keys }, set: { apply(.chooseKeys($0)); moved = false })) {
                Text("Stable IDs").tag(ActivityState.Keys.stableIDs)
                Text("Index keys").tag(ActivityState.Keys.positions)
            }.pickerStyle(.segmented).accessibilityIdentifier("try-it-key-mode")
            ForEach(Array(state.order.enumerated()), id: \.element) { index, item in
                HStack(spacing: 16) {
                    Image(systemName: moved && state.keys == .stableIDs ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(moved && state.keys == .stableIDs ? Color.green : ShelfTheme.secondary)
                        .accessibilityLabel(moved && state.keys == .stableIDs ? "Identity preserved" : "Item")
                    Text(item).font(.system(.title, design: .serif))
                    Spacer()
                    Text("State \(state.rowState[index])").monospacedDigit()
                    Button("Edit \(item)") { apply(.edit(item)) }.frame(minHeight: 44)
                        .accessibilityIdentifier("try-it-edit-\(item)")
                }.padding(.vertical, 8).accessibilityIdentifier("try-it-row-\(item)")
            }
            Button("Move last item to first") { apply(.reorder); moved = true }
                .buttonStyle(ShelfButtonStyle(filled: true)).accessibilityIdentifier("try-it-reorder")
        }
    }
    private var cache: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Original: \(state.original)").font(.title2).accessibilityIdentifier("try-it-original")
            Text("Stored copy: \(state.cached.map(String.init) ?? "none")").font(.title2).accessibilityIdentifier("try-it-copy")
            Text("Work performed: \(state.computations) computations").foregroundStyle(ShelfTheme.secondary)
            Button("Reuse copy") { apply(.reuse) }.buttonStyle(ShelfButtonStyle(filled: true)).accessibilityIdentifier("try-it-reuse")
            Button("Change original") { apply(.changeOriginal) }.accessibilityIdentifier("try-it-change-original")
            Button("Recompute copy") { apply(.recompute) }.accessibilityIdentifier("try-it-recompute")
            if let copy = state.cached { Text(copy == state.original ? "The copy agrees with the original." : "The copy is now stale.") }
        }
    }
    private func apply(_ transition: ActivityTransition) {
        guard ActivityValidator.accepts(definition, analyses: model.learning.snapshot.analyses) else {
            model.message = "The source changed. Reopen this activity from its passage."; return
        }
        do { try state.apply(transition, definition: definition); Task { await model.record(.triedActivity, citation: definition.source) } }
        catch { model.message = "That change isn't part of this activity." }
    }
}
