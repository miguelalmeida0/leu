import SwiftUI

/// A focused surface, not an expanding canvas inside the scrolling session summary.
/// The drawing gesture cannot consume a drag needed to reach the pinned controls.
@MainActor
struct ReleaseSurface: View {
    let onRelease: () -> Void
    let onContinue: () -> Void
    let onEnd: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var interaction = ReleaseInteractionState()

    var body: some View {
        ScrollView {
            content
                .frame(maxWidth: 640, alignment: .leading)
                .padding(ShelfTheme.gutter)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { controls }
        .background(ShelfTheme.background)
        .background { UITestFrameProbe(identifier: "release-surface") }
        .onDisappear { interaction.erase() }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("OPTIONAL PAUSE")
                .font(ShelfTheme.eyebrow()).tracking(2)
                .foregroundStyle(ShelfTheme.olive)
            Text(interaction.phase == .released ? "Better?" : "Get it out?")
                .leuScaledFont(32, weight: .regular, design: .serif)
                .accessibilityIdentifier("release-heading")
            if interaction.phase == .released {
                Text("The surface is clear. Your study record is unchanged.")
                    .font(.body).foregroundStyle(ShelfTheme.secondary)
                    .accessibilityIdentifier("release-completed-message")
            } else {
                Text("Scribble here, or use Release without drawing. You can leave at any time.")
                    .font(.body).foregroundStyle(ShelfTheme.secondary)
                drawingArea
                Text("Nothing you draw is saved.")
                    .font(.caption).foregroundStyle(ShelfTheme.secondary)
            }
        }
    }

    private var drawingArea: some View {
        GeometryReader { geometry in
            Canvas { context, _ in
                for stroke in interaction.strokes where !stroke.isEmpty {
                    var path = Path()
                    path.move(to: stroke[0])
                    for point in stroke.dropFirst() { path.addLine(to: point) }
                    context.stroke(path, with: .color(ShelfTheme.accent), lineWidth: 4)
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { interaction.append($0.location, in: geometry.size) }
                .onEnded { _ in interaction.endStroke() })
            .accessibilityLabel("Scribble area")
            .accessibilityValue(Text(interaction.hasDrawing ? "Drawing present" : "Empty"))
            .accessibilityHint("Use the Release button for the same action without drawing.")
            .accessibilityIdentifier("release-canvas")
        }
        .frame(height: 160)
        .background(ShelfTheme.raised, in: RoundedRectangle(cornerRadius: 14))
        .clipped()
    }

    private var controls: some View {
        VStack(spacing: 10) {
            if interaction.phase != .released {
                Button(action: releaseDrawing) {
                    Text("Release")
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape([.interaction, .accessibility], Rectangle())
                }
                .buttonStyle(ShelfButtonStyle(filled: true))
                .accessibilityIdentifier("release-accessible-action")
            }
            secondaryActions
        }
        .font(.body)
        .foregroundStyle(ShelfTheme.text)
        .padding(.horizontal, ShelfTheme.gutter)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity)
        .background(ShelfTheme.background)
        .overlay(alignment: .top) { Divider().overlay(ShelfTheme.line) }
        .background { UITestFrameProbe(identifier: "release-controls-frame") }
    }

    @ViewBuilder
    private var secondaryActions: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 4) { continueButton; endButton }
        } else {
            HStack(spacing: 12) { continueButton; endButton }
        }
    }

    private var continueButton: some View {
        Button(action: onContinue) {
            secondaryLabel("Continue")
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("release-continue")
    }

    private var endButton: some View {
        Button(action: onEnd) {
            secondaryLabel("I'm done")
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("release-done")
    }

    /// The measured surface of a secondary action.
    ///
    /// A bare `Text` label exports its glyph box as the button's accessibility frame — one
    /// 20.33pt line — even when the layout frame around it is 44pt. Drawing a real surface
    /// across the whole target and declaring the accessibility shape explicitly makes the
    /// control VoiceOver and XCUI measure the same size as the one a finger reaches.
    private func secondaryLabel(_ title: String) -> some View {
        Text(title)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(ShelfTheme.surface, in: RoundedRectangle(cornerRadius: ShelfTheme.smallRadius))
            .overlay { RoundedRectangle(cornerRadius: ShelfTheme.smallRadius).stroke(LeuDesign.separator, lineWidth: 0.8) }
            .contentShape([.interaction, .accessibility], Rectangle())
    }

    private func releaseDrawing() {
        if interaction.release() { onRelease() }
    }
}
