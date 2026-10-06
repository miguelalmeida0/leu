import SwiftUI

/// A trail drawn as a walk: each stop is a felt patch, joined to the next by thread. The
/// part already walked is sewn in solid red thread; the way ahead is tacked in dashes.
/// Wide screens wander left to right and back; narrow screens walk down the page.
///
/// VoiceOver reads the stops in order with where you are; the thread is decoration.
struct TrailWalkMap: View {
    struct Stop: Identifiable {
        let id: UUID
        let title: String
        let caption: String
        let available: Bool
    }

    let stops: [Stop]
    let currentIndex: Int?
    let onOpen: (Int) -> Void
    @State private var width: CGFloat = 0

    var body: some View {
        let geometry = TrailWalkGeometry(count: stops.count, width: width)
        ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                for index in stops.indices.dropLast() {
                    let path = geometry.thread(from: index)
                    if let currentIndex, index < currentIndex {
                        context.stroke(path, with: .color(LeuDesign.redThread), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                    } else {
                        context.stroke(path, with: .color(LeuDesign.tomato), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [7, 6]))
                    }
                }
            }
            .accessibilityHidden(true)
            ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                card(stop, index: index)
                    .frame(width: geometry.cardSize.width, height: geometry.cardSize.height)
                    .position(geometry.centre(of: index))
            }
        }
        .frame(height: geometry.height)
        .frame(maxWidth: .infinity)
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { width = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, value in width = value }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("The walk, \(stops.count) stops")
    }

    private func status(_ index: Int) -> String {
        guard stops[index].available else { return "Source unavailable" }
        guard let currentIndex else { return index == 0 ? "Start here" : "Stop \(index + 1)" }
        if index < currentIndex { return "Walked" }
        if index == currentIndex { return "You are here" }
        if index == currentIndex + 1 { return "Next" }
        return index == stops.count - 1 ? "The end of the walk" : "Further on"
    }

    private func card(_ stop: Stop, index: Int) -> some View {
        let here = index == currentIndex
        let dye = here ? Dye(fill: LeuDesign.butter, text: LeuDesign.ink) : Dye.cycle[index % Dye.cycle.count]
        return Button { onOpen(index) } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(index + 1)")
                    .font(.leu(.caption, weight: .bold).monospacedDigit())
                    .foregroundStyle(here ? LeuDesign.cream : LeuDesign.ink)
                    .frame(width: 26, height: 26)
                    .background(here ? LeuDesign.redThread : LeuDesign.cream, in: Circle())
                Text(stop.title)
                    .font(.leu(.headline, weight: .heavy))
                    .foregroundStyle(dye.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(stop.caption)
                    .font(.leu(.caption, weight: .medium))
                    .foregroundStyle(dye.text)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(status(index).uppercased())
                    .font(LeuDesign.eyebrow(10))
                    .tracking(1.2)
                    .foregroundStyle(dye.text)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(dye.fill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(dye.text.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .padding(6)
            }
            .overlay {
                if here {
                    RoundedRectangle(cornerRadius: 21, style: .continuous).stroke(LeuDesign.ink, lineWidth: 2.5).padding(-4)
                }
            }
            .shadow(color: LeuDesign.ink.opacity(0.14), radius: 12, x: 0, y: 7)
        }
        .buttonStyle(FeltPressStyle())
        .accessibilityLabel("Stop \(index + 1) of \(stops.count): \(stop.title), \(stop.caption). \(status(index)).")
        .accessibilityHint(stop.available ? "Opens this stop" : "")
        .accessibilityAddTraits(here ? .isSelected : [])
    }

    private struct Dye {
        let fill: Color
        let text: Color
        static let cycle = [Dye(fill: Color(hex: 0xDCD3A8), text: LeuDesign.ink),
                            Dye(fill: LeuDesign.blush, text: LeuDesign.ink),
                            Dye(fill: LeuDesign.held, text: LeuDesign.cream),
                            Dye(fill: Color(hex: 0xA9C1D6), text: LeuDesign.ink)]
    }
}

/// Where each stop sits. Pure, so the wandering stays the same on every redraw.
struct TrailWalkGeometry {
    let count: Int
    let width: CGFloat

    var columns: Int { width >= 900 ? 4 : width >= 560 ? 2 : 1 }
    var cardSize: CGSize {
        guard columns > 1 else { return CGSize(width: max(width - 36, 120), height: 132) }
        return CGSize(width: min(270, (width - 28 * CGFloat(columns - 1)) / CGFloat(columns) + 20), height: 150)
    }
    private static let wander: [CGFloat] = [0, 110, 0, 140]
    private var rowHeight: CGFloat { columns == 1 ? cardSize.height + 34 : cardSize.height + 170 }
    var height: CGFloat {
        guard count > 0, width > 0 else { return 0 }
        let rows = (count + columns - 1) / columns
        let deepest = columns == 1 ? 0 : (Self.wander.prefix(min(columns, count)).max() ?? 0)
        return CGFloat(rows - 1) * rowHeight + cardSize.height + deepest + 24
    }

    func centre(of index: Int) -> CGPoint {
        let size = cardSize
        let row = index / columns, column = index % columns
        // Rows snake: left to right, then right to left, so the thread never jumps back.
        let slot = row % 2 == 0 ? column : columns - 1 - column
        if columns == 1 {
            let indent: CGFloat = index % 2 == 0 ? 0 : 36
            return CGPoint(x: size.width / 2 + indent, y: CGFloat(index) * rowHeight + size.height / 2)
        }
        let span = width - size.width
        let x = size.width / 2 + span * CGFloat(slot) / CGFloat(columns - 1)
        return CGPoint(x: x, y: CGFloat(row) * rowHeight + size.height / 2 + Self.wander[slot % Self.wander.count] + 6)
    }

    /// A soft curve from one stop to the next, leaving each card from its nearer edge.
    func thread(from index: Int) -> Path {
        let a = centre(of: index), b = centre(of: index + 1)
        var path = Path()
        path.move(to: a)
        if columns == 1 || abs(a.x - b.x) < 1 {
            path.addCurve(to: b, control1: CGPoint(x: a.x - 40, y: (a.y + b.y) / 2), control2: CGPoint(x: b.x + 40, y: (a.y + b.y) / 2))
        } else {
            let mid = (a.x + b.x) / 2
            path.addCurve(to: b, control1: CGPoint(x: mid, y: a.y + 30), control2: CGPoint(x: mid, y: b.y - 30))
        }
        return path
    }
}
