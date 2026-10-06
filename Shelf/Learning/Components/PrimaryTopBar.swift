import SwiftUI

/// Leu's single persistent navigation level on regular widths (iPad): the wordmark on the
/// left takes you home, the places sit centred with a red running stitch under the one
/// you are in, and search waits on the right.
///
/// Compact widths use `PrimaryTabBar` instead; the two never appear together.
@MainActor
struct PrimaryTopBar: View {
    @Binding var selection: PrimaryArea
    /// Opens the book you were last in. Nil when the library is empty.
    let readingTitle: String?
    let openReading: () -> Void
    let openSearch: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var stitch

    var body: some View {
        ZStack {
            HStack {
                wordmark
                Spacer(minLength: 24)
                searchPill
            }
            HStack(spacing: 30) {
                item(.shelf)
                readingItem
                item(.learn)
                item(.trails)
            }
        }
        .padding(.horizontal, 44)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .accessibilityElement(children: .contain)
    }

    private var wordmark: some View {
        Button { select(.home) } label: {
            Text("leu")
                .font(LeuType.sans(31, weight: .black))
                .tracking(-1.2)
                .foregroundStyle(LeuDesign.ink)
                .leuTapTarget()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Leu, Home")
        .accessibilityIdentifier("primary-home")
        .accessibilityAddTraits(selection == .home ? .isSelected : [])
    }

    private func item(_ area: PrimaryArea) -> some View {
        let isOn = selection == area
        return Button { select(area) } label: {
            label(area.title, isOn: isOn)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("primary-" + area.rawValue)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    @ViewBuilder private var readingItem: some View {
        Button(action: openReading) { label("Reading", isOn: false) }
            .buttonStyle(.plain)
            .disabled(readingTitle == nil)
            .accessibilityHint(readingTitle.map { "Opens \($0) where you left it" } ?? "Bring a PDF first")
            .accessibilityIdentifier("primary-reading")
    }

    private func label(_ title: String, isOn: Bool) -> some View {
        Text(title)
            .font(.leu(.subheadline, weight: isOn ? .bold : .semibold))
            .foregroundStyle(isOn ? LeuDesign.ink : LeuDesign.secondary)
            .padding(.vertical, 6)
            .overlay(alignment: .bottom) {
                if isOn {
                    StitchUnderline()
                        .stroke(LeuDesign.redThread, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .frame(height: 6)
                        .offset(y: 6)
                        .matchedGeometryEffect(id: "leu-nav-stitch", in: stitch)
                }
            }
            .leuTapTarget()
    }

    private var searchPill: some View {
        Button(action: openSearch) {
            HStack(spacing: 14) {
                Text("Search your books")
                    .font(.leu(.subheadline, weight: .medium))
                    .foregroundStyle(LeuDesign.secondary)
                Text("⌘K")
                    .font(.leu(.caption, weight: .bold))
                    .foregroundStyle(LeuDesign.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 18)
            .frame(minHeight: LeuDesign.touchTarget)
            .background(LeuDesign.feltLight, in: Capsule(style: .continuous))
            .overlay { Capsule(style: .continuous).stroke(LeuDesign.line, lineWidth: LeuDesign.hairline) }
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .keyboardShortcut("k", modifiers: .command)
        .accessibilityLabel("Search your books")
        .accessibilityIdentifier("primary-search")
    }

    private func select(_ area: PrimaryArea) {
        guard selection != area else { return }
        withAnimation(LeuDesign.motion(LeuDesign.snap, reduced: reduceMotion)) { selection = area }
        ShelfHaptics.shared.play(.selectionChanged)
    }
}

/// A short, soft running stitch: the felt equivalent of an underline.
struct StitchUnderline: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let waves = max(2, Int(rect.width / 9))
        let step = rect.width / CGFloat(waves * 2)
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        for index in 0..<(waves * 2) {
            let x = rect.minX + step * CGFloat(index + 1)
            let control = CGPoint(x: x - step / 2, y: index.isMultiple(of: 2) ? rect.minY : rect.maxY)
            path.addQuadCurve(to: CGPoint(x: x, y: rect.midY), control: control)
        }
        return path
    }
}
