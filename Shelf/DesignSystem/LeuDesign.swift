import SwiftUI

/// Leu — Felt.
///
/// The single owner of colour, type, spacing, radius, border, motion and semantic state.
/// `ShelfTheme` resolves to these values, so every existing call site inherits the system
/// without churn.
///
/// The direction: a quiet sage felt ground, cream paper, deep ink type and a small family of
/// dyed felts (butter, tomato, denim, moss, blush, oat). It should feel like a reading corner,
/// not a dashboard: soft material, slow motion, real books in the middle.
///
/// Every text pairing below is chosen to clear WCAG AA (4.5:1) for body copy, and every
/// meaning-carrying graphic clears 3:1. `scripts/check-felt.py` enforces both.
///
/// Deliberately absent: glassmorphism, aurora fields, floating orbs, sparkle icons,
/// purple-as-a-synonym-for-AI, and script or handwritten type of any kind.
enum LeuDesign {

    // MARK: - Felt palette (raw material; prefer the semantic roles below in views)

    static let felt = Color(hex: 0xB6C690)
    static let feltLight = Color(hex: 0xC3D19F)
    static let feltDeep = Color(hex: 0xA4B57E)
    static let cream = Color(hex: 0xF8F1DE)
    static let ink = Color(hex: 0x24301F)
    static let butter = Color(hex: 0xE7B843)
    static let tomato = Color(hex: 0xC65A3E)
    static let denim = Color(hex: 0x5E7FA0)
    static let moss = Color(hex: 0x6E8C57)
    static let blush = Color(hex: 0xEBB5A3)
    static let oat = Color(hex: 0xE8D9B5)
    /// The red running stitch: underlines, the selected nav item, a loose end.
    static let redThread = Color(hex: 0xB3261E)
    /// Red thread used as small text directly on felt (4.5:1 on `felt`).
    static let redThreadText = Color(hex: 0x8E1F17)

    // MARK: - Surfaces

    /// App ground.
    static let void = felt
    /// Cards, sheets, rows.
    static let surface = feltLight
    /// A surface lifted above another surface: inputs, paper cards, menus.
    static let raised = cream
    /// The soft stitched edge of a felt piece.
    static let line = Color(hex: 0x9DAF7A)

    // MARK: - Type colour

    static let text = ink
    static let secondary = Color(hex: 0x3C4A33)
    /// Metadata and timestamps. The darkest step that still reads as quiet (4.5:1 on felt).
    static let tertiary = Color(hex: 0x44533A)
    /// Small uppercase labels on cream.
    static let eyebrowOnPaper = Color(hex: 0x7A5E1C)
    /// Small uppercase labels on felt.
    static let eyebrowOnFelt = Color(hex: 0x5E4714)

    // MARK: - Signal

    /// The primary commit: a dark ink pill. Confident, never neon.
    static let signal = ink
    /// Type placed on `signal`.
    static let onSignal = cream

    // MARK: - Semantic learning state
    //
    // These are the only colours allowed to describe memory, and each one means exactly
    // one thing. A screen that uses them decoratively is a bug.

    /// Recall is slipping.
    static let fading = tomato
    /// Recall is holding.
    static let held = Color(hex: 0x4D6A3C)
    /// Never recalled yet.
    static let untested = Color(hex: 0x7D8A66)
    /// Where the learner's model and the source diverged.
    static let bend = redThread

    /// Concept identity colours: the dyed felts. Assigned by stable hash so a concept keeps
    /// its colour across sessions.
    static let conceptPalette: [Color] = [butter, tomato, denim, moss, blush, oat]

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
    static let signalPressed = Color(hex: 0x34422C)
    static let signalText = ink
    static let fieldSurface = raised
    static let fieldForeground = text
    static let fieldPlaceholder = Color(hex: 0x56653F)
    static let menuSurface = raised
    static let menuForeground = text
    static let menuSecondary = secondary
    static let separator = Color(hex: 0x5C6B47)
    static let disabledSurface = Color(hex: 0xCBD6AE)
    static let disabledForeground = Color(hex: 0x4F5E41)
    static let success = held
    static let successForeground = cream
    static let warning = butter
    static let warningForeground = ink
    static let danger = Color(hex: 0xA3342A)
    static let dangerForeground = cream
    static let readingSurface = Color(hex: 0xFBF8F2)
    static let readingForeground = Color(hex: 0x1F1E1B)
    static let readingSecondary = Color(hex: 0x56534B)

    // Study fields: colour describes the existing learning state.
    static let studyContinueSurface = Color(hex: 0x4A6A8A)
    static let studyContinueForeground = cream
    static let studyContinueSecondary = Color(hex: 0xF1EADA)
    static let studyFadingSurface = Color(hex: 0xA94B35)
    static let studyFadingForeground = cream
    static let studyFadingSecondary = Color(hex: 0xF6EBDD)
    static let studyBlindSpotSurface = blush
    static let studyBlindSpotForeground = ink
    static let studyBlindSpotSecondary = secondary
    static let studyLabsSurface = Color(hex: 0xC8D6A6)
    static let studyLabsForeground = ink
    static let studyLabsSecondary = secondary

    // MARK: - Type
    //
    // Two voices: Gabarito, a round confident sans for display, UI and labels, and Literata,
    // an editorial serif for reading. Every face scales with Dynamic Type. No script.

    /// Display headlines. Tight tracking, heavy weight, short lines.
    static func display(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        LeuType.sans(size, weight: weight)
    }

    /// Long-form reading only.
    static func editorial(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        LeuType.serif(size, weight: weight)
    }

    /// Metadata, page references, counts, state. Lining figures keep numbers aligned.
    static func meta(_ size: CGFloat = 13, weight: Font.Weight = .medium) -> Font {
        LeuType.sans(size, weight: weight).monospacedDigit()
    }

    /// Small uppercase section label. Always paired with `eyebrowTracking`.
    static func eyebrow(_ size: CGFloat = 11) -> Font {
        LeuType.sans(size, weight: .bold)
    }

    static let eyebrowTracking: CGFloat = 1.6
    static let displayTracking: CGFloat = -1.1

    // MARK: - Space and shape

    static let gutter: CGFloat = 22
    static let rowSpacing: CGFloat = 14
    static let sectionSpacing: CGFloat = 30

    /// Felt pieces: generous, soft corners.
    static let radius: CGFloat = 22
    static let smallRadius: CGFloat = 12
    /// Pills: tab bar, filters, primary actions.
    static let pillRadius: CGFloat = 100
    static let hairline: CGFloat = 1

    /// Minimum effective touch target. Nothing interactive goes below this.
    static let touchTarget: CGFloat = 44

    // MARK: - Motion
    //
    // Felt moves slowly. Motion explains state, continuity or causality, and nothing here
    // moves reading text.

    /// Selection and filter changes.
    static let snap = Animation.spring(response: 0.42, dampingFraction: 0.86)
    /// Content appearing or resolving.
    static let settle = Animation.easeOut(duration: 0.32)
    /// Memory state changing after a session.
    static let drift = Animation.easeInOut(duration: 0.8)

    /// Honours Reduce Motion by collapsing to an instant change rather than a slow one.
    static func motion(_ animation: Animation, reduced: Bool) -> Animation? {
        reduced ? nil : animation
    }
}

extension View {
    /// Standard felt container: a soft piece of felt with a stitched edge and a low,
    /// diffuse shadow, as if it were lying on the table. No blur, no glass.
    func leuSurface(_ radius: CGFloat = LeuDesign.radius, fill: Color = LeuDesign.surface) -> some View {
        background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(LeuDesign.line, lineWidth: LeuDesign.hairline)
            }
            .shadow(color: LeuDesign.ink.opacity(0.10), radius: 14, x: 0, y: 10)
    }

    /// Guarantees the locked 44pt minimum and makes the whole area hittable, including
    /// for assistive technology, which reads the accessibility shape rather than the frame.
    func leuTapTarget() -> some View {
        frame(minWidth: LeuDesign.touchTarget, minHeight: LeuDesign.touchTarget)
            .contentShape([.interaction, .accessibility], Rectangle())
    }
}
