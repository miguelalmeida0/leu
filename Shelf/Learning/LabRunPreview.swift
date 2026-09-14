import SwiftUI
import ShelfCore

struct LabRunPreview: View {
    let lab: ReconstructionLab
    let order: [LabElement]
    let isSolved: Bool
    let runToken: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var activeIndex = -1
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(order.enumerated()), id: \.element.id) { index, element in
                        HStack(alignment: .top, spacing: 12) {
                            LeuStepIndicator(number: index + 1,
                                confirmed: runToken > 0 && lab.correctOrder.indices.contains(index) && lab.correctOrder[index] == element.id)
                            Text(element.title).font(.body).foregroundStyle(LeuDesign.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            } else {
            HStack(spacing: 7) {
                ForEach(Array(order.enumerated()), id: \.element.id) { index, element in
                    VStack(spacing: 6) {
                        LeuStepIndicator(number: index + 1,
                            confirmed: runToken > 0 && lab.correctOrder.indices.contains(index) && lab.correctOrder[index] == element.id)
                        Text(short(element.title))
                            .font(.caption2.weight(activeIndex == index ? .semibold : .regular))
                            .foregroundStyle(activeIndex == index ? ShelfTheme.text : ShelfTheme.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity)
                    }
                    if index < order.count - 1 {
                        Rectangle().fill(LeuDesign.separator).frame(width: 12, height: 1).padding(.bottom, 29)
                    }
                }
            }
            .frame(maxWidth: .infinity)

            }

            Text(isSolved ? insight : "The sequence is not coherent yet. Rearrange it and run again.")
                .font(.callout)
                .foregroundStyle(ShelfTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(ShelfTheme.raised, in: RoundedRectangle(cornerRadius: LearningTokens.Corner.surface))
        .task(id: runToken) { await animateRun() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isSolved ? "Simulation succeeded. \(insight)" : "Simulation needs another arrangement.")
    }

    private func animateRun() async {
        guard runToken > 0, isSolved else { activeIndex = -1; return }
        if reduceMotion { activeIndex = max(0, order.count - 1); return }
        activeIndex = -1
        for index in order.indices {
            guard !Task.isCancelled else { return }
            try? await Task.sleep(for: .milliseconds(260))
            withAnimation(LearningTokens.Motion.selection) { activeIndex = index }
        }
    }

    private func short(_ title: String) -> String {
        title.replacingOccurrences(of: " / ", with: "\n")
    }

    private var insight: String {
        switch lab.kind {
        case .eventLoop:
            return "Synchronous stack work completes first; queued continuations are then selected according to the runtime's queue semantics."
        case .reactIdentity:
            return "Identity is reconstructed from element type, key and sibling position so state can stay with the intended component instance."
        case .httpCaching:
            return "The cache decision starts with freshness; stale responses may be revalidated before a new representation is fetched."
        case .structuralTyping:
            return "Assignability follows the required structure: the source must provide compatible members rather than share a nominal class name."
        case .databaseTransaction:
            return "A transaction groups work behind a commit boundary; failed validation returns the unit to a safe state through rollback."
        }
    }
}
