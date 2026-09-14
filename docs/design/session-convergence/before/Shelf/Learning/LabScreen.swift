import SwiftUI
import ShelfCore

struct LabScreen: View {
    let lab: ReconstructionLab
    @Environment(\.dismiss) private var dismiss
    @State private var order: [LabElement]
    @State private var revealed = false
    @State private var runToken = 0
    init(lab: ReconstructionLab) { self.lab = lab; _order = State(initialValue: lab.elements.shuffled()) }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text(lab.instruction).foregroundStyle(ShelfTheme.secondary)
                Text("Drag each row into the order that makes the system work.").font(.callout).foregroundStyle(ShelfTheme.secondary)
                List {
                    ForEach(order) { element in
                        HStack { LeuStepIndicator(number: (order.firstIndex(where: { $0.id == element.id }) ?? 0) + 1, confirmed: revealed && isCorrect(element)); Text(element.title); Spacer() }
                            .padding(.vertical, 7).listRowBackground(ShelfTheme.surface)
                    }.onMove(perform: move)
                }.scrollContentBackground(.hidden).environment(\.editMode, .constant(.active))
                if revealed {
                    LabRunPreview(lab: lab, order: order, isSolved: isSolved, runToken: runToken)
                    if isSolved { LabScenarioView(lab: lab) }
                }
                HStack {
                    Button("Reset") { order = lab.elements.shuffled(); revealed = false; runToken = 0 }.buttonStyle(ShelfButtonStyle())
                    Spacer()
                    Button(revealed ? "Done" : "Run") {
                        if revealed { dismiss() } else {
                            revealed = true
                            runToken += 1
                            ShelfHaptics.shared.play(isSolved ? .snapToTarget : .answerIncorrect)
                        }
                    }.buttonStyle(ShelfButtonStyle(filled: true))
                }.padding(.horizontal, 4)
                if revealed {
                    Text(isSolved ? "The system is reconstructed. Now predict what it does in a concrete scenario." : "Compare the order, then try again. The correct relationships are deterministic.")
                        .font(.callout).foregroundStyle(ShelfTheme.secondary)
                }
            }.padding(.horizontal, 18).padding(.bottom, 18)
                .background(ShelfTheme.background).navigationTitle(lab.title).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }.preferredColorScheme(.dark).tint(ShelfTheme.accent)
    }

    private var isSolved: Bool { order.map(\.id) == lab.correctOrder }
    private func isCorrect(_ element: LabElement) -> Bool {
        guard let i = order.firstIndex(where: { $0.id == element.id }), lab.correctOrder.indices.contains(i) else { return false }
        return lab.correctOrder[i] == element.id
    }
    private func move(from source: IndexSet, to destination: Int) {
        order.move(fromOffsets: source, toOffset: destination); ShelfHaptics.shared.play(.selectionChanged)
    }
}

struct MiniLabSequence: View {
    let lab: ReconstructionLab
    @State private var order: [LabElement]
    @State private var checked = false
    init(lab: ReconstructionLab) { self.lab = lab; _order = State(initialValue: lab.elements.shuffled()) }
    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(order.enumerated()), id: \.element.id) { index, item in
                HStack { LeuStepIndicator(number: index + 1, confirmed: checked && lab.correctOrder.indices.contains(index) && lab.correctOrder[index] == item.id); Text(item.title); Spacer() }
                    .padding(13).background(ShelfTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                    .draggable(item.id.uuidString)
                    .dropDestination(for: String.self) { values, _ in
                        guard let raw = values.first, let id = UUID(uuidString: raw), let from = order.firstIndex(where: { $0.id == id }) else { return false }
                        let moved = order.remove(at: from); order.insert(moved, at: min(index, order.count)); ShelfHaptics.shared.play(.snapToTarget); return true
                    }
            }
            Button("Run") { checked = true; ShelfHaptics.shared.play(order.map(\.id) == lab.correctOrder ? .answerCorrect : .answerIncorrect) }
                .buttonStyle(ShelfButtonStyle())
            if checked && order.map(\.id) == lab.correctOrder {
                LabScenarioView(lab: lab)
            }
        }
    }
}
