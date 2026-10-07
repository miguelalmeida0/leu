import SwiftUI

/// Leu's single persistent navigation level on compact widths (iPhone): five places on a
/// cream felt pill, each an icon over its name. The place you are in is drawn in ink with
/// a red running stitch under its name, which slides slowly to the next place you choose.
///
/// RootView reserves its measured height below the clipped content viewport, so the pill
/// never covers scroll content. Regular widths (iPad) use `PrimaryTopBar` instead.
@MainActor
struct PrimaryTabBar: View {
    @Binding var selection: PrimaryArea
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Namespace private var stitch

    var body: some View {
        HStack(spacing: 0) {
            ForEach(PrimaryArea.compactTabs) { area in
                tab(area)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(LeuDesign.cream, in: Capsule(style: .continuous))
        .overlay { Capsule(style: .continuous).stroke(LeuDesign.line, lineWidth: LeuDesign.hairline) }
        .shadow(color: LeuDesign.ink.opacity(0.14), radius: 14, x: 0, y: 8)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private func isOn(_ area: PrimaryArea) -> Bool {
        selection == area || (area == .explore && selection == .trails)
    }

    private func tab(_ area: PrimaryArea) -> some View {
        let on = isOn(area)
        return Button {
            guard !on else { return }
            withAnimation(LeuDesign.motion(.spring(response: 0.55, dampingFraction: 0.86), reduced: reduceMotion)) {
                selection = area
            }
            ShelfHaptics.shared.play(.selectionChanged)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: area.symbol)
                    .font(.leu(.body, weight: on ? .semibold : .regular))
                    .symbolVariant(on ? .fill : .none)
                    .frame(height: 24)
                    .accessibilityHidden(true)
                Text(area.title)
                    .font(.leu(.caption2, weight: on ? .heavy : .semibold))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    .minimumScaleFactor(0.85)
                StitchUnderline()
                    .stroke(on ? LeuDesign.redThread : .clear,
                            style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                    .frame(width: 26, height: 4)
                    .matchedGeometryEffect(id: on ? "leu-tab-stitch" : "leu-tab-\(area.rawValue)", in: stitch)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(on ? LeuDesign.ink : LeuDesign.secondary)
            .padding(.top, 7)
            .padding(.bottom, 5)
            .frame(maxWidth: .infinity, minHeight: LeuDesign.touchTarget + 10)
            .contentShape([.interaction, .accessibility], Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(area.title)
        .accessibilityHint(area == .explore ? "Ideas across your books, and your trails" : "")
        .accessibilityIdentifier("primary-" + area.rawValue)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// On iPhone, Explore holds two views of the same wandering: the ideas your books share,
/// and the trails you have made of them. iPad keeps Trails in its top bar instead.
@MainActor
struct WalksSwitch: View {
    @Binding var selection: PrimaryArea
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 4) {
            segment(.explore, title: "Ideas")
            segment(.trails, title: "Trails")
        }
        .padding(4)
        .background(LeuDesign.feltLight, in: Capsule(style: .continuous))
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
        .padding(.bottom, 2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Explore")
    }

    private func segment(_ area: PrimaryArea, title: String) -> some View {
        let on = selection == area
        return Button {
            withAnimation(LeuDesign.motion(.easeInOut(duration: 0.35), reduced: reduceMotion)) { selection = area }
            ShelfHaptics.shared.play(.selectionChanged)
        } label: {
            Text(title)
                .font(.leu(.subheadline, weight: on ? .bold : .semibold))
                .foregroundStyle(on ? LeuDesign.cream : LeuDesign.ink)
                .padding(.horizontal, 22)
                .frame(minHeight: 38)
                .background(on ? LeuDesign.ink : .clear, in: Capsule(style: .continuous))
                .contentShape(Capsule(style: .continuous))
                .frame(minHeight: LeuDesign.touchTarget)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityIdentifier(area == .trails ? "primary-trails" : "explore-ideas")
    }
}
