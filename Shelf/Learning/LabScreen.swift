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
                Text("Drag each row into the order that makes the system work. A step turns green as soon as it is in the right place.")
                    .font(.callout).foregroundStyle(ShelfTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                // A count, not a score, and it never names the steps still missing.
                Text("\(confirmedCount) of \(order.count) in place")
                    .font(.callout.monospacedDigit()).foregroundStyle(ShelfTheme.secondary)
                    .accessibilityIdentifier("lab-progress")
                List {
                    ForEach(order) { element in
                        HStack { LeuStepIndicator(number: (order.firstIndex(where: { $0.id == element.id }) ?? 0) + 1, confirmed: isCorrect(element)); Text(element.title); Spacer() }
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

    /// Recomputed on every render, so a move that invalidates a previously correct
    /// position clears its check immediately rather than after the next Run.
    private var confirmedCount: Int { order.filter(isCorrect).count }
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
    init(lab: ReconstructionLab) { self.lab = lab; _order = State(initialValue: lab.elements.shuffled()) }

    /// Correctness comes from the lab's own `correctOrder`, never from visual position.
    private func isConfirmed(_ item: LabElement, at index: Int) -> Bool {
        lab.correctOrder.indices.contains(index) && lab.correctOrder[index] == item.id
    }

    private var confirmedCount: Int {
        order.enumerated().filter { isConfirmed($0.element, at: $0.offset) }.count
    }

    private func moveButton(systemName: String, label: String, id: String,
                            enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(enabled ? ShelfTheme.text : LeuDesign.disabledForeground)
                .frame(width: 44, height: 44)
                .contentShape([.interaction, .accessibility], Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }

    private func move(from: Int, to: Int) {
        guard order.indices.contains(from), order.indices.contains(to) else { return }
        let moved = order.remove(at: from)
        order.insert(moved, at: to)
        ShelfHaptics.shared.play(.selectionChanged)
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("\(confirmedCount) of \(order.count) in place")
                .font(.callout.monospacedDigit()).foregroundStyle(ShelfTheme.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("mini-lab-progress")
            ForEach(Array(order.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 12) {
                    LeuStepIndicator(number: index + 1, confirmed: isConfirmed(item, at: index))
                    Text(item.title)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    // Visible, opaque reorder controls: the exercise is completable
                    // without dragging, and without a translucent system menu.
                    VStack(spacing: 0) {
                        moveButton(systemName: "chevron.up", label: "Move up",
                                   id: "mini-lab-up-\(index)", enabled: index > 0) {
                            move(from: index, to: index - 1)
                        }
                        moveButton(systemName: "chevron.down", label: "Move down",
                                   id: "mini-lab-down-\(index)", enabled: index < order.count - 1) {
                            move(from: index, to: index + 1)
                        }
                    }
                }
                    .padding(13).frame(minHeight: 56)
                    .background(ShelfTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isConfirmed(item, at: index) ? LeuDesign.success : ShelfTheme.line,
                                    lineWidth: isConfirmed(item, at: index) ? 1.4 : 0.7)
                    }
                    .draggable(item.id.uuidString)
                    .dropDestination(for: String.self) { values, _ in
                        guard let raw = values.first, let id = UUID(uuidString: raw), let from = order.firstIndex(where: { $0.id == id }) else { return false }
                        let moved = order.remove(at: from); order.insert(moved, at: min(index, order.count)); ShelfHaptics.shared.play(.snapToTarget); return true
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Step \(index + 1), \(item.title)")
                    .accessibilityValue(isConfirmed(item, at: index) ? "Confirmed correct" : "Unresolved")
                    .accessibilityIdentifier("mini-lab-step-\(index)")
                    // Reordering must be possible without dragging.
                    .accessibilityActions {
                        Button("Move up") { move(from: index, to: index - 1) }
                        Button("Move down") { move(from: index, to: index + 1) }
                    }
            }
            if order.map(\.id) == lab.correctOrder {
                // The scenario appears only on a complete, validator-confirmed solve,
                // so partial progress never reveals the remaining answers.
                LabScenarioView(lab: lab)
            }
        }
        .onChange(of: lab.id) { _, _ in order = lab.elements.shuffled() }
    }
}
