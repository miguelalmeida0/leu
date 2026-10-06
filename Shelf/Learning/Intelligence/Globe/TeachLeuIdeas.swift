import SwiftUI

/// The ideas under the globe, each with a small window that is lit once the idea got across.
/// State is always said in words too, never by colour alone.
struct TeachLeuIdeas: View {
    let ideas: [TeachIdea]
    /// Side by side under the globe on wide screens; a list on narrow ones.
    var columns: Bool
    private let limit = 6

    var body: some View {
        let shown = Array(ideas.prefix(limit))
        VStack(alignment: .leading, spacing: 10) {
            if columns {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 18, alignment: .top)], spacing: 18) {
                    ForEach(shown) { idea in cell(idea, centred: true) }
                }
            } else {
                ForEach(shown) { idea in cell(idea, centred: false) }
            }
            if ideas.count > limit {
                Text("and \(ideas.count - limit) more on this page")
                    .font(.leu(.footnote))
                    .foregroundStyle(LeuDesign.tertiary)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Ideas Leu is listening for")
        .accessibilityIdentifier("teach-leu-ideas")
    }

    @ViewBuilder private func cell(_ idea: TeachIdea, centred: Bool) -> some View {
        let label = VStack(alignment: centred ? .center : .leading, spacing: 3) {
            Text(idea.label)
                .font(.leu(.subheadline, weight: .semibold))
                .foregroundStyle(idea.state == .loose ? LeuDesign.redThreadText : LeuDesign.ink)
                .multilineTextAlignment(centred ? .center : .leading)
                .lineLimit(3)
            Text(idea.status)
                .font(.leu(.caption, weight: .medium))
                .foregroundStyle(LeuDesign.secondary)
        }
        Group {
            if centred {
                VStack(spacing: 8) { WindowGlyph(lit: idea.state == .across); label }
                    .frame(maxWidth: .infinity)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    WindowGlyph(lit: idea.state == .across).alignmentGuide(.firstTextBaseline) { $0[.bottom] - 2 }
                    label
                    Spacer(minLength: 0)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(idea.label), \(idea.status)")
        .animation(.easeInOut(duration: 0.8), value: idea.state)
    }
}

/// A tiny cottage window: warm when lit, dark glass when not.
private struct WindowGlyph: View {
    let lit: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(lit ? LeuDesign.butter : Color(hex: 0x2C2A2D))
            Path { path in
                path.move(to: CGPoint(x: 7, y: 1)); path.addLine(to: CGPoint(x: 7, y: 15))
                path.move(to: CGPoint(x: 1, y: 8)); path.addLine(to: CGPoint(x: 13, y: 8))
            }
            .stroke(LeuDesign.cream, lineWidth: 1.5)
        }
        .frame(width: 14, height: 16)
        .padding(2)
        .background(LeuDesign.cream, in: RoundedRectangle(cornerRadius: 3.5, style: .continuous))
        .shadow(color: lit ? LeuDesign.butter.opacity(0.7) : .clear, radius: 5)
        .accessibilityHidden(true)
    }
}
