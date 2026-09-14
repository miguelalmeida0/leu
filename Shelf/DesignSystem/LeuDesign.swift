import SwiftUI

/// Leu — Night Field.
///
/// The single owner of colour, type, spacing, radius, border, motion and semantic state.
/// `ShelfTheme` now resolves to these values, so every existing call site inherits the
/// system without churn.
///
/// The direction: graphite and near-black surfaces, one high-energy signal colour, severe
/// typographic hierarchy, and learning state expressed as shape and colour rather than as
/// dashboard cards. Colour carries meaning here — a lime ring is memory held, a coral ring
/// is memory fading — so it is never decorative.
///
/// Deliberately absent: glassmorphism, aurora fields, floating orbs, sparkle icons,
/// purple-as-a-synonym-for-AI, and script or handwritten type of any kind.
enum LeuDesign {

    // MARK: - Surfaces

    /// App ground. Not pure black: pure black crushes the covers and kills depth.
    static let void = Color(hex: 0x0B0B0C)
    /// Cards, sheets, rows.
    static let surface = Color(hex: 0x141416)
    /// A surface lifted above another surface.
    static let raised = Color(hex: 0x1D1D20)
    /// Hairlines. Low contrast on purpose: structure comes from spacing and type.
    static let line = Color(hex: 0x2B2B30)

    // MARK: - Type colour

    static let text = Color(hex: 0xF3F2EE)
    static let secondary = Color(hex: 0xB9B9B2)
    /// Metadata and timestamps. Quiet enough to scan past.
    static let tertiary = Color(hex: 0xA2A29C)

    // MARK: - Signal

    /// The one high-energy accent. Held memory, confirmed steps, primary commit.
    static let signal = Color(hex: 0xC8F135)
    /// Type placed on `signal`. Never white — it vibrates.
    static let onSignal = Color(hex: 0x0B0B0C)

    // MARK: - Semantic learning state
    //
    // These are the only colours allowed to describe memory, and each one means exactly
    // one thing. A screen that uses coral decoratively is a bug.

    /// Recall is slipping.
    static let fading = Color(hex: 0xE8734A)
    /// Recall is holding.
    static let held = signal
    /// Never recalled yet.
    static let untested = Color(hex: 0x929298)
    /// Where the learner's model and the source diverged.
    static let bend = Color(hex: 0xE05C42)

    /// Concept identity colours. Assigned by stable hash so a concept keeps its colour
    /// across sessions, which is what makes the field readable at a glance.
    static let conceptPalette: [Color] = [
        Color(hex: 0xC8F135), Color(hex: 0xE8734A), Color(hex: 0x4FA8E8),
        Color(hex: 0x8B7FE8), Color(hex: 0xE8B54A), Color(hex: 0x4FD8A8)
    ]

    static func conceptColor(for key: String) -> Color {
        let hash = key.unicodeScalars.reduce(UInt64(5_381)) { ($0 &* 33) &+ UInt64($1.value) }
        return conceptPalette[Int(hash % UInt64(conceptPalette.count))]
    }

    // Opaque semantic pairings. Fill and foreground roles are intentionally separate.
    static let surfacePrimary = void
    static let surfaceSecondary = surface
    static let surfaceRaised = raised
    static let textPrimary = text
    static let textSecondary = secondary
    static let textTertiary = tertiary
    static let signalForeground = onSignal
    static let signalPressed = Color(hex: 0xB4D92F)
    static let signalText = Color(hex: 0x365500)
    static let fieldSurface = raised
    static let fieldForeground = text
    static let fieldPlaceholder = secondary
    static let menuSurface = raised
    static let menuForeground = text
    static let menuSecondary = secondary
    static let separator = Color(hex: 0x81817C)
    static let disabledSurface = raised
    static let disabledForeground = secondary
    static let success = Color(hex: 0x58D69B)
    static let successForeground = onSignal
    static let warning = Color(hex: 0xE8B54A)
    static let warningForeground = onSignal
    static let danger = Color(hex: 0xF18B79)
    static let dangerForeground = onSignal
    static let readingSurface = Color(hex: 0xFBF8F2)
    static let readingForeground = Color(hex: 0x1F1E1B)
    static let readingSecondary = Color(hex: 0x56534B)

    // Study fields: color describes the existing learning state.
    static let studyContinueSurface = Color(hex: 0x183EAA)
    static let studyContinueForeground = Color(hex: 0xF6F5EF)
    static let studyContinueSecondary = Color(hex: 0xD7E0FF)
    static let studyFadingSurface = fading
    static let studyFadingForeground = onSignal
    static let studyFadingSecondary = Color(hex: 0x352019)
    static let studyBlindSpotSurface = Color(hex: 0x49386F)
    static let studyBlindSpotForeground = Color(hex: 0xF4F0F8)
    static let studyBlindSpotSecondary = Color(hex: 0xDAD1E7)
    static let studyLabsSurface = Color(hex: 0x242B25)
    static let studyLabsForeground = textPrimary
    static let studyLabsSecondary = Color(hex: 0xC4C9BC)

    // MARK: - Type
    //
    // Three voices only: a strong sans for display and UI, an editorial serif for reading,
    // and a monospace for metadata and source coordinates. No fourth voice, no script.

    /// Display headlines. Tight tracking, heavy weight, short lines.
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    /// Long-form reading only.
    static func editorial(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// Metadata, page references, counts, state. Monospace makes numerals line up and
    /// gives the product its own voice without decoration.
    static func meta(_ size: CGFloat = 12, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// Small uppercase section label. Always paired with `eyebrowTracking`.
    static func eyebrow(_ size: CGFloat = 11) -> Font {
        .system(size: size, weight: .semibold, design: .monospaced)
    }

    static let eyebrowTracking: CGFloat = 1.4
    static let displayTracking: CGFloat = -0.6

    // MARK: - Space and shape

    static let gutter: CGFloat = 22
    static let rowSpacing: CGFloat = 14
    static let sectionSpacing: CGFloat = 30

    static let radius: CGFloat = 14
    static let smallRadius: CGFloat = 9
    /// Pills: tab bar, filters, primary actions.
    static let pillRadius: CGFloat = 100
    static let hairline: CGFloat = 0.75

    /// Minimum effective touch target. Nothing interactive goes below this.
    static let touchTarget: CGFloat = 44

    // MARK: - Motion
    //
    // Motion explains state, continuity or causality. Nothing here moves reading text.

    /// Selection and filter changes.
    static let snap = Animation.spring(response: 0.32, dampingFraction: 0.82)
    /// Content appearing or resolving.
    static let settle = Animation.easeOut(duration: 0.22)
    /// Memory state changing after a session.
    static let drift = Animation.easeInOut(duration: 0.55)

    /// Honours Reduce Motion by collapsing to an instant change rather than a slow one.
    static func motion(_ animation: Animation, reduced: Bool) -> Animation? {
        reduced ? nil : animation
    }
}

extension View {
    /// Standard Night Field container: a surface with a hairline, no shadow, no blur.
    func leuSurface(_ radius: CGFloat = LeuDesign.radius, fill: Color = LeuDesign.surface) -> some View {
        background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(LeuDesign.line, lineWidth: LeuDesign.hairline)
            }
    }

    /// Guarantees the locked 44pt minimum and makes the whole area hittable, including
    /// for assistive technology, which reads the accessibility shape rather than the frame.
    func leuTapTarget() -> some View {
        frame(minWidth: LeuDesign.touchTarget, minHeight: LeuDesign.touchTarget)
            .contentShape([.interaction, .accessibility], Rectangle())
    }
}
