import SwiftUI
import ShelfCore

@MainActor struct TryItSheet: View {
    @Bindable var model: ReaderIntelligenceModel
    let definition: ActivityDefinition
    @State private var cacheState = ActivityState()
    @State private var keyExperiment = KeyIdentityPrediction()
    private var state: ActivityState { definition.contract == .stableKeys ? keyExperiment.state : cacheState }
    @State private var moved = false
    private var prediction: KeyIdentityPrediction.Prediction? { keyExperiment.prediction }
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
                    Text((model.learning.library.snapshot.activeBooks.first { $0.id == definition.source.packet.documentID }?.title ?? "Source") + " · p. \(definition.source.packet.pageIndex + 1)").font(.headline)
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
            Text("What changes if we use index keys when these rows move?").font(.headline)
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
                        .disabled(moved)
                        .accessibilityIdentifier("try-it-edit-\(item)")
                }.padding(.vertical, 8).accessibilityIdentifier("try-it-row-\(item)")
            }
            if !moved {
                Text("Predict where the state will go.").font(.headline)
                ForEach(KeyIdentityPrediction.Prediction.allCases, id: \.self) { choice in
                    Button { keyExperiment.predict(choice) } label: {
                        Label(choice.rawValue, systemImage: prediction == choice ? "checkmark.circle.fill" : "circle")
                    }.buttonStyle(ShelfButtonStyle()).accessibilityIdentifier("try-it-predict-" + (choice == .followsItem ? "item" : "position"))
                }
            }
            Button("Move last item to first") {
                guard prediction != nil else { return }
                apply(.reorder); moved = keyExperiment.revealed
            }.disabled(prediction == nil || moved)
                .buttonStyle(ShelfButtonStyle(filled: true)).accessibilityIdentifier("try-it-reorder")
            if moved {
                Text("Your prediction: \(prediction?.rawValue ?? "")").foregroundStyle(ShelfTheme.secondary)
                Text("Here the rows keep the same component type. Stable identity keeps toy state with the item; positional identity keeps it at the position. This illustrates the cited reordering condition.")
                    .accessibilityIdentifier("try-it-grounded-explanation")
            }
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
        do {
            if definition.contract == .stableKeys {
                switch transition {
                case .chooseKeys(let keys): try keyExperiment.choose(keys, definition: definition)
                case .edit(let item): try keyExperiment.edit(item, definition: definition)
                case .reorder: try keyExperiment.reveal(definition: definition, analyses: model.learning.snapshot.analyses)
                case .reset: keyExperiment = KeyIdentityPrediction()
                default: throw ActivityError.invalidTransition
                }
            } else { try cacheState.apply(transition, definition: definition) }
            Task { await model.record(.triedActivity, citation: definition.source) }
        }
        catch { model.message = "That change isn't part of this activity." }
    }
}
