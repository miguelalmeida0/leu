import SwiftUI

/// Leu's single persistent navigation level, as a floating pill.
///
/// RootView reserves its measured height below the clipped content viewport.
/// The capsule floats within that opaque reserved region, without covering scroll content.
/// Library filters and Settings stay inside Library: there is no second global nav.
@MainActor
struct PrimaryTabBar: View {
    @Binding var selection: PrimaryArea
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Namespace private var indicator

    var body: some View {
        HStack(spacing: 4) {
            ForEach(PrimaryArea.allCases) { area in
                tab(area)
            }
        }
        .padding(4)
        .background(LeuDesign.surface, in: Capsule(style: .continuous))
        .overlay { Capsule(style: .continuous).stroke(LeuDesign.line, lineWidth: LeuDesign.hairline) }
        .padding(.horizontal, LeuDesign.gutter)
        .padding(.bottom, 8)
        .padding(.top, 6)
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
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 4)) : AnyLayout(HStackLayout(spacing: 7))
            layout {
                Image(systemName: area.symbol)
                    .font(.subheadline.weight(isOn ? .semibold : .regular))
                // The label stays at every size: an icon alone is not a sufficient
                // affordance, so the row is allowed to grow instead of dropping text.
                Text(area.title)
                    .font(.subheadline.weight(isOn ? .semibold : .medium))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(isOn ? LeuDesign.onSignal : LeuDesign.secondary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: LeuDesign.touchTarget)
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
        .accessibilityIdentifier("primary-" + area.rawValue)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
