import SwiftUI
import ShelfCore

@MainActor
struct ConnectionConstellationSheet: View {
    @Bindable var knowledge: KnowledgeModel
    let source: KnowledgePassage
    let related: [RankedKnowledgeConnection]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ShelfSheet(title: "Connections") {
            VStack(spacing: 18) {
                Text("Follow an idea").font(.system(.title2, design: .serif))
                Text(source.sectionTitle ?? String(source.text.prefix(56)))
                    .font(.callout.weight(.semibold)).foregroundStyle(ShelfTheme.accent).lineLimit(2)
                GeometryReader { proxy in
                    ZStack {
                        Canvas { context, size in
                            let center = CGPoint(x: size.width / 2, y: size.height / 2)
                            for index in related.prefix(6).indices {
                                let p = position(index: index, count: min(6, related.count), size: size)
                                var path = Path(); path.move(to: center); path.addLine(to: p)
                                context.stroke(path, with: .color(ShelfTheme.line), lineWidth: 1)
                            }
                        }
                        anchor
                        ForEach(Array(related.prefix(6).enumerated()), id: \.element.passage.id) { index, item in
                            node(item).position(position(index: index, count: min(6, related.count), size: proxy.size))
                        }
                    }
                }
                .frame(minHeight: 360)
                Text("The list in Connections remains the accessible equivalent of this view.")
                    .font(.caption).foregroundStyle(ShelfTheme.secondary)
            }
            .padding(ShelfTheme.gutter)
        }
    }

    private var anchor: some View {
        Text(source.sectionTitle ?? "Current passage")
            .font(.system(.headline, design: .serif)).multilineTextAlignment(.center).lineLimit(3)
            .padding(14).frame(width: 150).frame(minHeight: 78)
            .background(ShelfTheme.raised, in: RoundedRectangle(cornerRadius: 18))
            .overlay { RoundedRectangle(cornerRadius: 18).stroke(ShelfTheme.accent) }
    }

    private func node(_ item: RankedKnowledgeConnection) -> some View {
        Button {
            knowledge.queueNavigation(to: item.passage, from: source); dismiss()
        } label: {
            VStack(spacing: 4) {
                Text(item.passage.sectionTitle ?? knowledge.title(for: item.passage.documentID))
                    .font(.caption.weight(.semibold)).multilineTextAlignment(.center).lineLimit(2)
                Text(knowledge.title(for: item.passage.documentID)).font(.caption2).foregroundStyle(ShelfTheme.secondary).lineLimit(1)
            }
            .padding(9).frame(width: 126).frame(minHeight: 62)
            .background(ShelfTheme.surface, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .transition(reduceMotion ? .opacity : .scale(scale: 0.96).combined(with: .opacity))
    }

    private func position(index: Int, count: Int, size: CGSize) -> CGPoint {
        let count = max(1, count); let angle = (Double(index) / Double(count)) * .pi * 2 - .pi / 2
        let rx = max(80, min(size.width * 0.35, 150)); let ry = max(100, min(size.height * 0.34, 145))
        return CGPoint(x: size.width / 2 + CGFloat(cos(angle)) * rx,
                       y: size.height / 2 + CGFloat(sin(angle)) * ry)
    }
}
