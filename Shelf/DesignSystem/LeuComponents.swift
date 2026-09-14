import SwiftUI

/// Uppercase monospace section label. The only "small caps" device in the system.
struct LeuEyebrow: View {
    let text: String
    var tint: Color = LeuDesign.secondary
    init(_ text: String, tint: Color = LeuDesign.secondary) {
        self.text = text
        self.tint = tint
    }
    var body: some View {
        Text(text.uppercased())
            .leuScaledFont(11, weight: .semibold, design: .monospaced, relativeTo: .caption)
            .tracking(LeuDesign.eyebrowTracking)
            .foregroundStyle(tint)
    }
}

/// Monospace metadata: counts, page references, memory state. Numerals line up, so a
/// column of these reads as data without being wrapped in a table.
struct LeuMeta: View {
    let text: String
    var tint: Color = LeuDesign.tertiary
    init(_ text: String, tint: Color = LeuDesign.tertiary) {
        self.text = text
        self.tint = tint
    }
    var body: some View {
        Text(text).leuScaledFont(12, weight: .medium, design: .monospaced, relativeTo: .caption).foregroundStyle(tint)
    }
}

/// A ring showing how much of a source is currently held in memory.
///
/// This is the product's central visual idea: memory is a quantity you can see on the
/// object itself, so a shelf reads like a state, not a list. Colour is semantic —
/// lime holds, coral fades — and the ring is never decorative.
struct LeuMemoryRing: View {
    /// 0...1 proportion of the source currently held.
    let held: Double
    /// True when the source has items actively slipping.
    var isFading: Bool = false
    var diameter: CGFloat = 26
    var lineWidth: CGFloat = 2.5

    private var tint: Color {
        if held <= 0 { return LeuDesign.untested }
        return isFading ? LeuDesign.fading : LeuDesign.held
    }

    var body: some View {
        ZStack {
            Circle().stroke(LeuDesign.separator, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.02, min(held, 1)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
    }
}

/// A source cover generated from the document's own title and type — never stock art,
/// never an unrelated landscape. A shelf of PDFs should still read like a record
/// collection, and the type doing that work is the title itself.
struct LeuSourceCover: View {
    let title: String
    var held: Double = 0
    var isFading: Bool = false
    var height: CGFloat = 132

    private var lines: [String] {
        let words = title.split(whereSeparator: \.isWhitespace).map(String.init)
        guard words.count > 1 else { return [String(title.prefix(14))] }
        var out: [String] = []
        var current = ""
        for word in words {
            if current.isEmpty { current = word }
            else if current.count + word.count <= 11 { current += " " + word }
            else { out.append(current); current = word }
            if out.count == 2 { break }
        }
        if out.count < 3, !current.isEmpty { out.append(current) }
        return Array(out.prefix(3))
    }

    private var tint: Color { LeuDesign.conceptColor(for: title) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            LeuDiagonalField(tint: tint)
            VStack(alignment: .leading, spacing: -2) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    Text(line.uppercased())
                        .font(LeuDesign.display(index == lines.count - 1 ? 20 : 18))
                        .tracking(LeuDesign.displayTracking)
                        .foregroundStyle(index == lines.count - 1 ? tint : LeuDesign.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            LeuMemoryRing(held: held, isFading: isFading)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(10)
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: LeuDesign.smallRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LeuDesign.smallRadius, style: .continuous)
                .stroke(LeuDesign.line, lineWidth: LeuDesign.hairline)
        }
    }
}

/// Fine diagonal hatching. Gives a cover texture and depth without an image asset,
/// a gradient that means nothing, or a blurred blob.
private struct LeuDiagonalField: View {
    let tint: Color
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(LeuDesign.raised))
            var path = Path()
            var x: CGFloat = -size.height
            while x < size.width {
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                x += 7
            }
            context.stroke(path, with: .color(tint.opacity(0.10)), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}

/// Filter and scope pill.
struct LeuFilterPill: View {
    let title: String
    let isOn: Bool
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            withAnimation(LeuDesign.motion(LeuDesign.snap, reduced: reduceMotion)) { action() }
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isOn ? LeuDesign.onSignal : LeuDesign.secondary)
                .padding(.horizontal, 14)
                .frame(minHeight: LeuDesign.touchTarget)
                .background(isOn ? LeuDesign.signal : LeuDesign.surface,
                            in: Capsule(style: .continuous))
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(isOn ? Color.clear : LeuDesign.separator, lineWidth: LeuDesign.hairline)
                }
                .contentShape([.interaction, .accessibility], Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// The one high-energy action per screen.
struct LeuSignalButton: ButtonStyle {
    var isQuiet = false
    func makeBody(configuration: Configuration) -> some View {
        LeuPrimaryButtonStyle(filled: !isQuiet, pill: true).makeBody(configuration: configuration)
    }
}

/// Compact transient notice used above the primary navigation.
/// Flat Night Field treatment: semantic signal, no glass, no shadow.
@MainActor
struct NoticeBar: View {
    let text: String
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(LeuDesign.signal)
                .accessibilityHidden(true)

            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(LeuDesign.text)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LeuDesign.secondary)
                    .frame(
                        width: LeuDesign.touchTarget,
                        height: LeuDesign.touchTarget
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss notification")
        }
        .padding(.leading, 18)
        .padding(.trailing, 4)
        .padding(.vertical, 5)
        .background(LeuDesign.surface)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(LeuDesign.line)
                .frame(height: LeuDesign.hairline)
        }
    }
}
