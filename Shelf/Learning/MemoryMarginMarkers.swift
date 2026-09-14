import SwiftUI
import ShelfCore

@MainActor
struct MemoryMarginMarkers: View {
    @Bindable var reader: ReaderModel
    @Bindable var learning: LearningModel
    @State private var selected: LearningObject?

    var body: some View {
        VStack(spacing: 9) {
            ForEach(Array(objects.prefix(5))) { object in
                Button { selected = object } label: {
                    Circle().fill(color(object)).frame(width: 7, height: 7)
                        .overlay(Circle().stroke(ShelfTheme.background, lineWidth: 1))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain).accessibilityLabel("Memory state for \(object.title)")
            }
            Spacer()
        }
        .padding(.top, 16).padding(.trailing, 2)
        .sheet(item: $selected) { object in MemoryMarkerSheet(object: object, learning: learning) }
    }

    private var objects: [LearningObject] {
        learning.snapshot.studyObjects.filter { $0.source.documentID == reader.book.id && $0.source.pageIndex == reader.pageIndex }
    }

    private func color(_ object: LearningObject) -> Color {
        let state = learning.snapshot.reviewStates[object.id] ?? ReviewState(learningObjectID: object.id)
        switch learning.scheduler.mastery(for: state, at: Date()) {
        case .new: return LeuDesign.textTertiary
        case .learning: return LeuDesign.textSecondary
        case .strengthening: return LeuDesign.signal
        case .durable: return ShelfTheme.reviewAccent
        case .due: return ShelfTheme.accent
        case .fading: return LeuDesign.danger
        }
    }
}

@MainActor
private struct MemoryMarkerSheet: View {
    let object: LearningObject
    @Bindable var learning: LearningModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ShelfSheet(title: "Memory") {
            VStack(alignment: .leading, spacing: 16) {
                Text(object.title).font(LearningTokens.Typography.title)
                if let state = learning.snapshot.reviewStates[object.id] {
                    Text("Reviewed \(state.reviewCount) times")
                    if let last = state.lastReviewedAt { Text("Last recall · \(last.formatted(date: .abbreviated, time: .omitted))").foregroundStyle(ShelfTheme.secondary) }
                    Text(status(state)).foregroundStyle(ShelfTheme.secondary)
                } else { Text("Not reviewed yet").foregroundStyle(ShelfTheme.secondary) }
                Button("Review now") { dismiss(); learning.startReview(objectID: object.id) }
                    .buttonStyle(ShelfButtonStyle(filled: true))
                Spacer()
            }.padding(ShelfTheme.gutter)
        }
    }
    private func status(_ state: ReviewState) -> String {
        let mastery = learning.scheduler.mastery(for: state, at: Date())
        if let due = state.nextReviewAt {
            return mastery == .due || mastery == .fading ? "Ready for another recall" : "Next recall · \(due.formatted(date: .abbreviated, time: .omitted))"
        }
        return mastery.rawValue.capitalized
    }
}
