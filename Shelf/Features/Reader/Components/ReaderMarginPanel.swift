import ShelfCore
import SwiftUI

/// The margin beside the page on wide iPad: your notes on this page, what Leu remembers
/// about it (anything fading is a loose end), where your other books say the same thing,
/// and an honest line about how the readable page was rebuilt from the PDF.
@MainActor
struct ReaderMarginPanel: View {
    @Bindable var model: ReaderModel
    @State private var related: [RankedKnowledgeConnection] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                section("In the margin") {
                    if notes.isEmpty {
                        quiet("Nothing written beside this page yet. Long-press a paragraph to keep a thought.")
                    } else {
                        ForEach(notes) { note in noteCard(note) }
                    }
                }
                if !memories.isEmpty {
                    section("What Leu remembers here") {
                        ForEach(memories.prefix(3)) { memory in memoryCard(memory.object, state: memory.state) }
                    }
                }
                if !related.isEmpty {
                    section("This page in your library") {
                        ForEach(related, id: \.passage.id) { connection in relatedRow(connection.passage) }
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    StitchDivider()
                    rebuiltLine
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 22)
        }
        .scrollIndicators(.hidden)
        .task(id: model.pageIndex) { related = relatedPassages() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Margin")
        .accessibilityIdentifier("reader-margin")
    }

    // MARK: Content

    private var notes: [StudyAnnotation] {
        model.annotations
            .filter { $0.pageIndex == model.pageIndex && !$0.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private struct PageMemory: Identifiable {
        let object: LearningObject
        let state: MasteryState
        var id: UUID { object.id }
    }

    private var memories: [PageMemory] {
        let learning = model.learning
        return learning.snapshot.studyObjects
            .filter { $0.source.documentID == model.book.id && $0.source.pageIndex == model.pageIndex }
            .map { object in
                let review = learning.snapshot.reviewStates[object.id] ?? ReviewState(learningObjectID: object.id)
                return PageMemory(object: object, state: learning.scheduler.mastery(for: review, at: Date()))
            }
            .sorted { Self.urgency($0.state) > Self.urgency($1.state) }
    }

    private static func urgency(_ state: MasteryState) -> Int {
        switch state {
        case .fading: 3
        case .due: 2
        case .new, .learning: 1
        case .strengthening, .durable: 0
        }
    }

    private func relatedPassages() -> [RankedKnowledgeConnection] {
        let here = model.knowledge.snapshot.passages.filter { $0.documentID == model.book.id && $0.pageIndex == model.pageIndex }
        var seen = Set<UUID>(), found: [RankedKnowledgeConnection] = []
        for passage in here.prefix(4) {
            for connection in model.knowledge.related(to: passage, limit: 3)
            where connection.passage.documentID != model.book.id && !seen.contains(connection.passage.documentID) {
                seen.insert(connection.passage.documentID)
                found.append(connection)
            }
        }
        return Array(found.sorted { $0.score > $1.score }.prefix(2))
    }

    // MARK: Pieces

    private func noteCard(_ note: StudyAnnotation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOUR NOTE · \(note.createdAt.formatted(.dateTime.weekday(.wide)).uppercased())")
                .font(LeuDesign.eyebrow(10))
                .tracking(LeuDesign.eyebrowTracking)
                .foregroundStyle(LeuDesign.eyebrowOnPaper)
            Text(note.note)
                .font(.leu(.subheadline, weight: .semibold))
                .foregroundStyle(LeuDesign.ink)
                .fixedSize(horizontal: false, vertical: true)
            if !note.quote.isEmpty {
                Text("↩ “\(note.quote.prefix(70))\(note.quote.count > 70 ? "…" : "")”")
                    .font(.leu(.caption, serif: true))
                    .foregroundStyle(LeuDesign.secondary)
                    .lineLimit(2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LeuDesign.cream, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(LeuDesign.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .padding(5)
                .accessibilityHidden(true)
        }
        .shadow(color: LeuDesign.ink.opacity(0.10), radius: 8, x: 0, y: 5)
        .accessibilityElement(children: .combine)
    }

    private func memoryCard(_ object: LearningObject, state: MasteryState) -> some View {
        let loose = state == .fading || state == .due
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                if loose { Circle().fill(LeuDesign.redThread).frame(width: 7, height: 7).accessibilityHidden(true) }
                Text(Self.stateWords(state).uppercased())
                    .font(LeuDesign.eyebrow(10))
                    .tracking(LeuDesign.eyebrowTracking)
                    .foregroundStyle(loose ? LeuDesign.redThreadText : LeuDesign.eyebrowOnFelt)
            }
            Text(object.title)
                .font(.leu(.subheadline, weight: .semibold))
                .foregroundStyle(LeuDesign.ink)
                .fixedSize(horizontal: false, vertical: true)
            Button("Go over it now") { model.learning.startReview(objectID: object.id) }
                .font(.leu(.footnote, weight: .semibold))
                .underline()
                .foregroundStyle(LeuDesign.ink)
                .frame(minHeight: LeuDesign.touchTarget, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LeuDesign.feltLight, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private func relatedRow(_ passage: KnowledgePassage) -> some View {
        let book = model.learning.library.snapshot.activeBooks.first { $0.id == passage.documentID }
        return Button { model.knowledge.queueNavigation(to: passage) } label: {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(book.map { CoverColors($0.palette).background } ?? LeuDesign.blush)
                    .frame(width: 30, height: 22)
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(book?.title ?? "Another book"), p. \(passage.pageIndex + 1)")
                        .font(.leu(.subheadline, weight: .bold))
                        .foregroundStyle(LeuDesign.ink)
                    Text(passage.text)
                        .font(.leu(.footnote, serif: true))
                        .foregroundStyle(LeuDesign.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens that page")
    }

    private var rebuiltLine: some View {
        let original = model.displayMode != .read
        return VStack(alignment: .leading, spacing: 4) {
            Text(original ? "You're looking at the original PDF page." : "Reading order rebuilt from the PDF.")
                .font(.leu(.footnote))
                .foregroundStyle(LeuDesign.secondary)
            Button(original ? "Read it rebuilt" : "Show the original page") {
                model.setDisplayMode(original ? .read : .original)
            }
            .font(.leu(.footnote, weight: .bold))
            .underline()
            .foregroundStyle(LeuDesign.ink)
            .frame(minHeight: LeuDesign.touchTarget, alignment: .leading)
            .disabled(!model.isLoaded)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(LeuDesign.eyebrow(10))
                .tracking(LeuDesign.eyebrowTracking)
                .foregroundStyle(LeuDesign.eyebrowOnFelt)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    private func quiet(_ text: String) -> some View {
        Text(text).font(.leu(.footnote)).foregroundStyle(LeuDesign.secondary).fixedSize(horizontal: false, vertical: true)
    }

    static func stateWords(_ state: MasteryState) -> String {
        switch state {
        case .new: "New to you"
        case .learning: "Still sinking in"
        case .strengthening: "Getting stronger"
        case .durable: "Held"
        case .due: "Loose end · due again"
        case .fading: "Loose end · fading"
        }
    }
}
