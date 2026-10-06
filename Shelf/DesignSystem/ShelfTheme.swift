import SwiftUI
import ShelfCore

/// Compatibility names resolved by the semantic Felt system (`LeuDesign`).
enum ShelfTheme {
    static let background = LeuDesign.void
    static let surface = LeuDesign.surface
    static let raised = LeuDesign.raised
    static let line = LeuDesign.line
    static let text = LeuDesign.text
    static let secondary = LeuDesign.secondary

    /// Reader appearance stays a reader decision. Felt is the product shell;
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

    static let importantBackground = Color(hex: 0xF3E3B4)
    static let importantAccent = LeuDesign.eyebrowOnPaper
    static let reviewBackground = Color(hex: 0xD6E2BC)
    static let reviewAccent = LeuDesign.held
    static let confusingBackground = Color(hex: 0xF4D2C4)
    static let confusingAccent = LeuDesign.danger
    static let spokenHighlight = LeuDesign.butter

    static let gutter = LeuDesign.gutter
    static let radius = LeuDesign.radius
    static let smallRadius = LeuDesign.smallRadius

    /// Long-form reading keeps the editorial serif.
    static func editorial(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        LeuDesign.editorial(size, weight: weight)
    }

    /// Section labels are small, bold and uppercase in Felt.
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

/// A book's dyed felt. Each palette keeps its stored name (they are persisted on `Book`)
/// but now resolves to one of Leu's felts; foreground and muted type clear 4.5:1 on it.
struct CoverColors {
    let background: Color
    let foreground: Color
    let muted: Color
    let light: Color
    let shadow: Color
    init(_ palette: CoverPalette) {
        switch palette {
        case .ocean:    // denim
            background = Color(hex: 0x4A6A8A); foreground = Color(hex: 0xF8F1DE)
            muted = Color(hex: 0xF0E8D6); light = Color(hex: 0x7E9AB6); shadow = Color(hex: 0x34506B)
        case .graphite: // moss
            background = Color(hex: 0x4D6A3C); foreground = Color(hex: 0xF8F1DE)
            muted = Color(hex: 0xEDE6D2); light = Color(hex: 0x7E9A68); shadow = Color(hex: 0x36502A)
        case .ivory:    // oat
            background = Color(hex: 0xECDFBF); foreground = Color(hex: 0x24301F)
            muted = Color(hex: 0x4F5E41); light = Color(hex: 0xF8F1DE); shadow = Color(hex: 0xC9B98F)
        case .forest:   // teal
            background = Color(hex: 0x35706A); foreground = Color(hex: 0xF8F1DE)
            muted = Color(hex: 0xEDE8D8); light = Color(hex: 0x6E9F98); shadow = Color(hex: 0x24534E)
        case .sand:     // butter
            background = Color(hex: 0xE7B843); foreground = Color(hex: 0x24301F)
            muted = Color(hex: 0x4A3A12); light = Color(hex: 0xF3D88E); shadow = Color(hex: 0xB98D24)
        case .slate:    // tomato
            background = Color(hex: 0xA94B35); foreground = Color(hex: 0xF8F1DE)
            muted = Color(hex: 0xF6EBDD); light = Color(hex: 0xD27A5F); shadow = Color(hex: 0x7E3424)
        }
    }
}
