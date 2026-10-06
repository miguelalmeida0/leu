import SwiftUI

/// The evening nook: an arched window onto the rainy city, the daybed with its quilt, and
/// a cup of tea steaming on the floor cushion.
///
/// Everything is laid out in the composition's own 900 x 826 design space (the Blender
/// render is 900 x 560 of it) and multiplied by `scale`, so every layer is drawn at its
/// real on-screen size (crisp on every device) instead of being bitmap-scaled.
struct HomeNookScene: View {
    let scale: CGFloat

    static let designSize = CGSize(width: 900, height: 826)

    private let wood = Color(hex: 0x8A6A44)

    var body: some View {
        ZStack(alignment: .topLeading) {
            windowFrame
            glass
            mullions
            Image("Home/Nook")
                .resizable()
                .interpolation(.high)
                .frame(width: 900 * scale, height: 560 * scale)
                .offset(x: 0, y: 266 * scale)
                .allowsHitTesting(false)   // the render's transparent sky must not block the glass
                .accessibilityLabel("A mustard daybed with a patchwork quilt, cushions, and a cup of tea on a floor cushion beside it")
            TeaSteam(rim: CGPoint(x: 130 * scale, y: 212 * scale), rimRadius: 9 * scale, height: 150 * scale)
                .frame(width: 260 * scale, height: 220 * scale)
                .offset(x: (679.4 - 130) * scale, y: (654.7 - 212) * scale)
        }
        .frame(width: Self.designSize.width * scale, height: Self.designSize.height * scale, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Your reading corner")
    }

    private var windowFrame: some View {
        arch(top: 250, bottom: 22)
            .fill(wood)
            .frame(width: 500 * scale, height: 420 * scale)
            .shadow(color: LeuDesign.ink.opacity(0.32), radius: 22 * scale, x: 0, y: 20 * scale)
            .offset(x: 200 * scale, y: 0)
            .accessibilityHidden(true)
    }

    private var glass: some View {
        FoggedWindow()
            .frame(width: 464 * scale, height: 384 * scale)
            .clipShape(arch(top: 232, bottom: 10))
            .offset(x: 218 * scale, y: 18 * scale)
    }

    private var mullions: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(wood)
                .frame(width: 12 * scale, height: 384 * scale)
                .offset(x: 444 * scale, y: 18 * scale)
            Rectangle().fill(wood)
                .frame(width: 464 * scale, height: 12 * scale)
                .offset(x: 218 * scale, y: (18 + 384 * 0.42) * scale)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func arch(top: CGFloat, bottom: CGFloat) -> UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: top * scale, bottomLeadingRadius: bottom * scale,
                               bottomTrailingRadius: bottom * scale, topTrailingRadius: top * scale,
                               style: .circular)
    }
}
