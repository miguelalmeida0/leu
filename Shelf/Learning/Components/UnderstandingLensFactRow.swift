import SwiftUI
import ShelfCore

@MainActor
struct UnderstandingLensFactRow: View {
    let fact: UnderstandingLensFact
    let onSelect: @MainActor (LearningSource) -> Void

    var body: some View {
        Button(action: selectSource) { rowLabel }
            .buttonStyle(.plain)
            .accessibilityIdentifier(fact.accessibilityIdentifier)
            .accessibilityLabel(Text(verbatim: fact.accessibilityLabel))
            .accessibilityValue(Text(verbatim: fact.accessibilityValue))
            .onAppear { StudyInteractionTrace.record("lens.row.visible id=\(fact.id)") }
    }

    private var rowLabel: some View {
        VStack(alignment: .leading, spacing: 5) {
            conceptTitle
            relationship
            sourceCaption
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
    }

    private var conceptTitle: some View {
        Text(verbatim: fact.conceptName)
            .font(.headline)
            .foregroundStyle(ShelfTheme.text)
    }

    private var relationship: some View {
        Text(verbatim: fact.relationshipText)
            .font(.system(.body, design: .serif))
            .foregroundStyle(ShelfTheme.text)
    }

    private var sourceCaption: some View {
        Text(verbatim: fact.displaySourceCaption)
            .font(.caption)
            .foregroundStyle(ShelfTheme.secondary)
    }

    private func selectSource() {
        onSelect(fact.target)
    }
}
