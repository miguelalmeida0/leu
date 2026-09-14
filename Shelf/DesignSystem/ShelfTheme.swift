import SwiftUI
import ShelfCore

/// Compatibility names resolved by the semantic Night Field system.
enum ShelfTheme {
    static let background = LeuDesign.void
    static let surface = LeuDesign.surface
    static let raised = LeuDesign.raised
    static let line = LeuDesign.line
    static let text = LeuDesign.text
    static let secondary = LeuDesign.secondary

    /// Reader appearance stays a reader decision. Night Field is the product shell;
    /// a book is still allowed to be paper. Reading wins over shell consistency.
    static let nightSurface = LeuDesign.surfaceSecondary
    static let nightText = LeuDesign.textPrimary
    static let nightSecondary = LeuDesign.textSecondary

    /// Provenance, selection and reading marks — the signal colour.
    static let accent = LeuDesign.signal
    /// Primary commit actions.
    static let action = LeuDesign.signal
    /// Durable recall and progress.
    static let olive = LeuDesign.held
    static let danger = LeuDesign.danger

    /// Paper tokens remain warm: they are used by reading surfaces, not by the shell.
    static let paper = LeuDesign.readingSurface
    static let ink = LeuDesign.readingForeground
    static let paperSecondary = LeuDesign.readingSecondary

    static let importantBackground = Color(hex: 0x241F12)
    static let importantAccent = LeuDesign.signal
    static let reviewBackground = Color(hex: 0x14201A)
    static let reviewAccent = LeuDesign.held
    static let confusingBackground = Color(hex: 0x241612)
    static let confusingAccent = LeuDesign.fading
    static let spokenHighlight = LeuDesign.signal

    static let gutter = LeuDesign.gutter
    static let radius = LeuDesign.radius
    static let smallRadius = LeuDesign.smallRadius

    /// Long-form reading keeps the editorial serif.
    static func editorial(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        LeuDesign.editorial(size, weight: weight)
    }

    /// Section labels are monospace and uppercase in Night Field.
    static func eyebrow(_ size: CGFloat = 11) -> Font {
        LeuDesign.eyebrow(size)
    }

    static func cardStroke(_ opacity: Double = 1) -> Color {
        line.opacity(opacity)
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255,
                  blue: Double(hex & 255) / 255, opacity: opacity)
    }
}

struct CoverColors {
    let background: Color
    let foreground: Color
    let muted: Color
    let light: Color
    let shadow: Color
    init(_ palette: CoverPalette) {
        switch palette {
        case .ocean:
            background = Color(hex: 0xB7C2C2); foreground = Color(hex: 0x203033)
            muted = Color(hex: 0x334746); light = Color(hex: 0xDCE3E1); shadow = Color(hex: 0x819497)
        case .graphite:
            background = Color(hex: 0x4B4A46); foreground = Color(hex: 0xF5F1E8)
            muted = Color(hex: 0xD3CEC3); light = Color(hex: 0x85827B); shadow = Color(hex: 0x343330)
        case .ivory:
            background = Color(hex: 0xE9E4D9); foreground = Color(hex: 0x26241F)
            muted = Color(hex: 0x59544C); light = Color(hex: 0xF9F6EF); shadow = Color(hex: 0xBFB8AA)
        case .forest:
            background = Color(hex: 0x4A503D); foreground = Color(hex: 0xFAF6ED)
            muted = Color(hex: 0xDFE2D7); light = Color(hex: 0x9AA08B); shadow = Color(hex: 0x4E5543)
        case .sand:
            background = Color(hex: 0xD8C4A4); foreground = Color(hex: 0x332A22)
            muted = Color(hex: 0x4D4033); light = Color(hex: 0xF2E7D4); shadow = Color(hex: 0xAE9470)
        case .slate:
            background = Color(hex: 0x54534E); foreground = Color(hex: 0xFAF7F0)
            muted = Color(hex: 0xE0DDD4); light = Color(hex: 0xA7A49D); shadow = Color(hex: 0x57564F)
        }
    }
}
