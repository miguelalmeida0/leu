import ShelfCore
import SwiftUI

/// Explore (12): the ideas that run across your books, said as one sentence of felt
/// patches, then the passages where each book says it. Tap a neighbouring idea to walk
/// over to it; "Make it a trail" turns the passages into a trail you can walk later.
@MainActor
struct ExploreScreen: View {
    let knowledge: KnowledgeModel
    let learning: LearningModel
    let onTrailMade: () -> Void
    @State private var ideas: [ExploreIdea] = []
    @State private var selectedID: UUID?
    @State private var making = false
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var typeSize

    private var wide: Bool { sizeClass == .regular && !typeSize.isAccessibilitySize }
    private var idea: ExploreIdea? { ideas.first { $0.id == selectedID } ?? ideas.first }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: wide ? 40 : 28) {
                chips
                if let idea {
                    sentence(idea)
                    voices(idea)
                    agreement(idea)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(knowledge.isIndexing ? "Leu is still reading your books." : "Ideas show up here once two pages agree.")
                            .font(LeuDesign.display(28)).foregroundStyle(LeuDesign.ink)
                        Text("Explore is built only from your own PDFs: the ideas they share and the passages that say them.")
                            .font(.leu(.body)).foregroundStyle(LeuDesign.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.horizontal, wide ? 40 : 20)
            .padding(.vertical, 24)
            .frame(maxWidth: 1240, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(LeuDesign.void)
        .task(id: knowledge.snapshot.passages.count &+ knowledge.snapshot.concepts.count &* 31
              &+ knowledge.snapshot.detectedBindings.count &+ knowledge.snapshot.userBindings.count) {
            ideas = ExploreMap.ideas(in: knowledge.snapshot)
        }
        .accessibilityIdentifier("explore-screen")
    }

    // MARK: Pieces

    private var chips: some View {
        SentenceFlow(spacing: 8, lineSpacing: 8) {
            Text("Ideas across your books")
                .font(.leu(.footnote, weight: .semibold)).foregroundStyle(LeuDesign.secondary)
            ForEach(ideas) { option in
                let selected = option.id == idea?.id
                Button { withAnimation(.easeInOut(duration: 0.5)) { selectedID = option.id } } label: {
                    HStack(spacing: 7) {
                        RoundedRectangle(cornerRadius: 2).fill(LeuDesign.conceptColor(for: option.concept.name)).frame(width: 9, height: 9)
                        Text(option.concept.name).font(.leu(.footnote, weight: .semibold))
                    }
                    .foregroundStyle(selected ? LeuDesign.cream : LeuDesign.ink)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 36)
                    .background(selected ? LeuDesign.ink : LeuDesign.feltLight, in: Capsule())
                    .frame(minHeight: 44)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Ideas across your books")
    }

    private func sentence(_ idea: ExploreIdea) -> some View {
        let near = ExploreMap.neighbours(of: idea, among: ideas)
        let books = idea.bookIDs.count
        let size: CGFloat = wide ? 50 : 30
        return SentenceFlow(spacing: wide ? 14 : 8, lineSpacing: wide ? 14 : 10) {
            patch(idea, size: size, tappable: false)
            words(books == 1 ? "turns up on" : "turns up in", size: size)
            words(books == 1 ? "\(idea.passages.count == 1 ? "a page" : "\(idea.passages.count) pages") of \(title(idea.passages[0].documentID))" : "\(books) of your books", size: size)
            if near.isEmpty {
                words(".", size: size)
            } else {
                words(", close to", size: size)
                ForEach(Array(near.enumerated()), id: \.element.id) { index, other in
                    if index > 0 { words(index == near.count - 1 ? "and" : ",", size: size) }
                    patch(other, size: size, tappable: true)
                }
                words(".", size: size)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("explore-sentence")
    }

    private func words(_ text: String, size: CGFloat) -> some View {
        Text(text).font(LeuDesign.display(size)).tracking(wide ? -1.3 : -0.6).foregroundStyle(LeuDesign.secondary)
    }

    private func patch(_ idea: ExploreIdea, size: CGFloat, tappable: Bool) -> some View {
        let dye = LeuDesign.conceptColor(for: idea.concept.name)
        let text = dye == LeuDesign.denim || dye == LeuDesign.moss ? LeuDesign.cream : LeuDesign.ink
        let face = Text(idea.concept.name)
            .font(LeuDesign.display(size)).tracking(wide ? -1.3 : -0.6)
            .foregroundStyle(text)
            .padding(.horizontal, wide ? 18 : 12).padding(.vertical, wide ? 4 : 3)
            .background(dye, in: RoundedRectangle(cornerRadius: wide ? 14 : 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: wide ? 10 : 7, style: .continuous)
                    .strokeBorder(text.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 3])).padding(5)
            }
            .shadow(color: LeuDesign.ink.opacity(0.14), radius: 8, x: 0, y: 5)
        return Group {
            if tappable {
                Button { withAnimation(.easeInOut(duration: 0.5)) { selectedID = idea.id } } label: { face }
                    .buttonStyle(FeltPressStyle())
                    .accessibilityHint("Explore this idea")
            } else {
                face.accessibilityAddTraits(.isHeader)
            }
        }
    }

    private func voices(_ idea: ExploreIdea) -> some View {
        let passages = ExploreMap.voices(of: idea)
        let books = Set(passages.map(\.documentID)).count
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("WHERE YOUR BOOKS SAY IT")
                    .font(LeuDesign.eyebrow(10)).tracking(LeuDesign.eyebrowTracking).foregroundStyle(LeuDesign.eyebrowOnFelt)
                    .accessibilityAddTraits(.isHeader)
                Text("\(passages.count == 1 ? "1 passage" : "\(passages.count) passages") in \(books == 1 ? "1 book" : "\(books) books")")
                    .font(.leu(.footnote, weight: .medium)).foregroundStyle(LeuDesign.secondary)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: wide ? 380 : 280), spacing: 22, alignment: .top)], spacing: 22) {
                ForEach(passages) { passage in voice(passage, idea: idea) }
            }
        }
    }

    private func voice(_ passage: KnowledgePassage, idea: ExploreIdea) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(passage.sectionTitle ?? idea.concept.name)
                .font(.leu(.caption, weight: .bold)).foregroundStyle(LeuDesign.cream)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(LeuDesign.held, in: Capsule())
                .lineLimit(1)
            Text("“\(passage.text.trimmingCharacters(in: .whitespacesAndNewlines))”")
                .font(.leu(.title3, serif: true)).italic()
                .foregroundStyle(LeuDesign.readingForeground)
                .lineSpacing(4)
                .lineLimit(7)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            HStack {
                Text("\(title(passage.documentID)) · page \(passage.pageIndex + 1)")
                    .font(.leu(.caption, weight: .semibold)).foregroundStyle(LeuDesign.readingForeground)
                Spacer(minLength: 8)
                Button("Read the passage") { knowledge.queueNavigation(to: passage) }
                    .font(.leu(.caption, weight: .bold)).underline()
                    .foregroundStyle(LeuDesign.readingForeground)
                    .frame(minHeight: LeuDesign.touchTarget)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 200, alignment: .topLeading)
        .background(LeuDesign.cream, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: LeuDesign.ink.opacity(0.12), radius: 14, x: 0, y: 8)
        .accessibilityElement(children: .contain)
    }

    private func agreement(_ idea: ExploreIdea) -> some View {
        let titles = Array(Set(idea.passages.map(\.documentID))).map(title).sorted()
        let line = titles.count >= 2
            ? "\(titles[0]) and \(titles.count == 2 ? titles[1] : "\(titles.count - 1) more") both come back to \(idea.concept.name)."
            : "Only \(titles.first ?? "one book") talks about \(idea.concept.name) so far."
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) { Text(line).agreementStyle(); Spacer(minLength: 12); trailButton(idea) }
            VStack(alignment: .leading, spacing: 14) { Text(line).agreementStyle(); trailButton(idea) }
        }
        .padding(22)
        .background(LeuDesign.feltLight, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func trailButton(_ idea: ExploreIdea) -> some View {
        Button(making ? "Making the trail…" : "Make it a trail") { makeTrail(idea) }
            .buttonStyle(LeuPrimaryButtonStyle(filled: true, pill: true))
            .disabled(making)
            .accessibilityHint("Puts one passage from each book in order, as a trail you can walk")
            .accessibilityIdentifier("explore-make-trail")
    }

    private func title(_ documentID: UUID) -> String { knowledge.title(for: documentID) }

    private func makeTrail(_ idea: ExploreIdea) {
        let nodes = ExploreMap.voices(of: idea).map { passage in
            TrailNode(kind: .pageRange, documentID: passage.documentID, pageRange: passage.pageIndex...passage.pageIndex,
                      title: passage.sectionTitle ?? "\(title(passage.documentID)), p. \(passage.pageIndex + 1)")
        }
        guard !nodes.isEmpty else { return }
        making = true
        Task {
            defer { making = false }
            do {
                let name = idea.concept.name.prefix(1).uppercased() + idea.concept.name.dropFirst()
                _ = try await learning.repository.saveTrail(LearningTrail(title: name, nodes: nodes, currentNodeID: nodes.first?.id))
                learning.snapshot = try await learning.repository.snapshot()
                onTrailMade()
            } catch { learning.errorMessage = error.localizedDescription }
        }
    }
}

private extension Text {
    func agreementStyle() -> some View {
        font(.leu(.body, weight: .bold)).foregroundStyle(LeuDesign.ink).fixedSize(horizontal: false, vertical: true)
    }
}
