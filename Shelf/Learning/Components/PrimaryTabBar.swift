import SwiftUI

/// Leu's single persistent navigation level on compact widths (iPhone), as a felt pill.
///
/// RootView reserves its measured height below the clipped content viewport.
/// The capsule floats within that opaque reserved region, without covering scroll content.
/// Regular widths (iPad) use `PrimaryTopBar` instead; there is never a second global nav.
@MainActor
struct PrimaryTabBar: View {
    @Binding var selection: PrimaryArea
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Namespace private var indicator

    var body: some View {
        HStack(spacing: 2) {
            ForEach(PrimaryArea.allCases) { area in
                tab(area)
            }
        }
        .padding(5)
        .background(LeuDesign.cream, in: Capsule(style: .continuous))
        .overlay { Capsule(style: .continuous).stroke(LeuDesign.line, lineWidth: LeuDesign.hairline) }
        .shadow(color: LeuDesign.ink.opacity(0.14), radius: 16, x: 0, y: 10)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .padding(.top, 8)
    }

    private func tab(_ area: PrimaryArea) -> some View {
        let isOn = selection == area
        return Button {
            guard !isOn else { return }
            withAnimation(LeuDesign.motion(LeuDesign.snap, reduced: reduceMotion)) {
                selection = area
            }
            ShelfHaptics.shared.play(.selectionChanged)
        } label: {
            // Four places fit a 320pt iPhone only with the icon above the word. The label
            // stays at every size: an icon alone is not a sufficient affordance.
            VStack(spacing: 2) {
                Image(systemName: area.symbol)
                    .font(.leu(.footnote, weight: isOn ? .bold : .medium))
                    .imageScale(.medium)
                    .accessibilityHidden(true)
                Text(area.title)
                    .font(.leu(.caption, weight: isOn ? .bold : .semibold))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(isOn ? LeuDesign.onSignal : LeuDesign.secondary)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .frame(minHeight: LeuDesign.touchTarget + 6)
            .background {
                if isOn {
                    Capsule(style: .continuous)
                        .fill(LeuDesign.signal)
                        .matchedGeometryEffect(id: "leu-tab-indicator", in: indicator)
                }
            }
            .contentShape([.interaction, .accessibility], Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(area.title)
        .accessibilityIdentifier("primary-" + area.rawValue)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
