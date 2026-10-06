import ShelfCore
import SwiftUI

/// "I'd like to [explain it my way] using [React Notes], mostly the bit about [keys]."
/// The study session as one sentence the reader finishes with felt patches. Each patch
/// opens a small opaque Leu menu. The sentence wraps like text at every width and size.
@MainActor
struct StudySentence: View {
    @Binding var way: StudyWay
    @Binding var topicID: UUID?
    @Binding var minutes: Int
    @Binding var passageID: String?
    let topics: [LearningTopic]
    let passages: [StudyPassage]
    var large: Bool

    private var passage: StudyPassage? { passages.first { $0.id == passageID } ?? passages.first }
    private var topicName: String { topics.first { $0.id == topicID }?.name ?? "anything I've read" }

    var body: some View {
        SentenceFlow(spacing: large ? 14 : 8, lineSpacing: large ? 14 : 10) {
            words("I'd like to")
            patch(way.phrase, fill: LeuDesign.butter, label: "How to study", id: "study-sentence-way") {
                ForEach(StudyWay.allCases.filter { $0 != .explain || !passages.isEmpty }) { option in
                    Button(option.phrase) { way = option }.accessibilityAddTraits(option == way ? .isSelected : [])
                }
            }
            if way == .explain, let passage {
                words("using")
                staticPatch(passage.bookTitle, fill: Self.denimFelt)
                words("mostly the bit about")
                patch(passage.bit, fill: LeuDesign.cream, label: "Which part", id: "study-sentence-bit") {
                    ForEach(passages) { option in
                        Button("\(option.bit) · \(option.bookTitle), p. \(option.page)") { passageID = option.id }
                    }
                }
            } else {
                words(way == .recall ? "on" : "with")
                patch(topicName, fill: Self.denimFelt, label: "Subject", id: "study-sentence-subject") {
                    Button("anything I've read") { topicID = nil }
                    ForEach(topics) { topic in Button(topic.name) { topicID = topic.id } }
                }
                if way.usesMinutes {
                    words("for about")
                    patch("\(minutes) minutes", fill: LeuDesign.cream, label: "Time", id: "study-sentence-minutes") {
                        ForEach([5, 10, 20, 30], id: \.self) { value in Button("\(value) minutes") { minutes = value } }
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.45), value: way)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Plan your study")
        .accessibilityIdentifier("study-sentence")
    }

    static let denimFelt = Color(hex: 0xA9C1D6)

    private var size: CGFloat { large ? 52 : 30 }

    private func words(_ text: String) -> some View {
        Text(text)
            .font(LeuDesign.display(size))
            .tracking(large ? -1.4 : -0.6)
            .foregroundStyle(LeuDesign.secondary)
    }

    private func patchFace(_ text: String, fill: Color, chevron: Bool) -> some View {
        HStack(spacing: large ? 10 : 6) {
            Text(text)
                .font(LeuDesign.display(size))
                .tracking(large ? -1.4 : -0.6)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            if chevron {
                Image(systemName: "chevron.down")
                    .font(.leu(large ? .title3 : .footnote, weight: .bold))
                    .accessibilityHidden(true)
            }
        }
        .foregroundStyle(LeuDesign.ink)
        .padding(.horizontal, large ? 20 : 12)
        .padding(.vertical, large ? 4 : 3)
        .background(fill, in: RoundedRectangle(cornerRadius: large ? 16 : 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: large ? 12 : 8, style: .continuous)
                .strokeBorder(LeuDesign.ink.opacity(0.28), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .padding(large ? 5 : 4)
        }
        .shadow(color: LeuDesign.ink.opacity(0.14), radius: 8, x: 0, y: 5)
    }

    private func patch<Items: View>(_ text: String, fill: Color, label: String, id: String,
                                    @ViewBuilder items: @escaping () -> Items) -> some View {
        LeuMenu(content: items) { patchFace(text, fill: fill, chevron: true) }
            .accessibilityLabel("\(label): \(text)")
            .accessibilityHint("Double-tap to change")
            .accessibilityIdentifier(id)
    }

    private func staticPatch(_ text: String, fill: Color) -> some View {
        patchFace(text, fill: fill, chevron: false)
    }
}

/// Lays words and patches out like a line of text: left to right, wrapping to a new line
/// when the next piece would not fit, each line centred on its tallest piece.
struct SentenceFlow: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let lines = lines(for: width, subviews: subviews)
        let height = lines.reduce(0) { $0 + $1.height } + lineSpacing * CGFloat(max(lines.count - 1, 0))
        let widest = lines.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? widest, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for line in lines(for: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for (index, size) in line.items {
                subviews[index].place(at: CGPoint(x: x, y: y + (line.height - size.height) / 2),
                                      proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += line.height + lineSpacing
        }
    }

    private struct Line { var items: [(Int, CGSize)] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func lines(for width: CGFloat, subviews: Subviews) -> [Line] {
        var lines: [Line] = [], current = Line()
        for index in subviews.indices {
            // A piece wider than the line (a long title at a large text size) wraps inside itself.
            var size = subviews[index].sizeThatFits(.unspecified)
            if size.width > width { size = subviews[index].sizeThatFits(ProposedViewSize(width: width, height: nil)) }
            let next = current.items.isEmpty ? size.width : current.width + spacing + size.width
            if !current.items.isEmpty && next > width {
                lines.append(current); current = Line()
            }
            current.width = current.items.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.items.append((index, size))
        }
        if !current.items.isEmpty { lines.append(current) }
        return lines
    }
}
