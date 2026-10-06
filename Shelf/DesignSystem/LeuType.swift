import CoreText
import SwiftUI
import UIKit

/// Leu's two typefaces, bundled as data assets and registered once at launch.
///
/// Gabarito (display, UI, labels) and Literata (reading) ship under the SIL Open Font
/// License; see THIRD_PARTY_NOTICES.md. Each weight is a static instance cut from the
/// upstream variable fonts so every face resolves by PostScript name on every iOS version.
///
/// Every font here is built with `relativeTo:`, so it scales with Dynamic Type exactly like
/// the system text style it stands in for. If registration ever fails, `Font.custom` falls
/// back to the system face at the same size: layout and accessibility are never at risk.
enum LeuType {
    private static let sansFaces = ["Gabarito-Regular", "Gabarito-Medium", "Gabarito-SemiBold",
                                    "Gabarito-Bold", "Gabarito-ExtraBold", "Gabarito-Black"]
    private static let serifFaces = ["Literata-Regular", "Literata-Medium", "Literata-SemiBold", "Literata-Italic"]

    /// Registers the bundled faces for this process. Safe to call more than once.
    @MainActor static func registerFonts() {
        guard !didRegister else { return }
        didRegister = true
        for name in sansFaces + serifFaces {
            guard let asset = NSDataAsset(name: "Fonts/\(name)"),
                  let provider = CGDataProvider(data: asset.data as CFData),
                  let font = CGFont(provider) else { continue }
            var error: Unmanaged<CFError>?
            CTFontManagerRegisterGraphicsFont(font, &error)
        }
    }

    @MainActor private static var didRegister = false

    // MARK: - Faces

    static func sans(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .custom(sansFace(weight), size: size, relativeTo: textStyle(for: size))
    }

    static func serif(_ size: CGFloat, weight: Font.Weight = .regular, italic: Bool = false) -> Font {
        .custom(italic ? "Literata-Italic" : serifFace(weight), size: size, relativeTo: textStyle(for: size))
    }

    /// A face at a size that is already scaled (for example by `@ScaledMetric`).
    static func fixed(serif: Bool, size: CGFloat, weight: Font.Weight) -> Font {
        .custom(serif ? serifFace(weight) : sansFace(weight), fixedSize: size)
    }

    static func sansFace(_ weight: Font.Weight) -> String {
        switch weight {
        case .black: return "Gabarito-Black"
        case .heavy: return "Gabarito-ExtraBold"
        case .bold: return "Gabarito-Bold"
        case .semibold: return "Gabarito-SemiBold"
        case .medium: return "Gabarito-Medium"
        default: return "Gabarito-Regular"
        }
    }

    static func serifFace(_ weight: Font.Weight) -> String {
        switch weight {
        case .semibold, .bold, .heavy, .black: return "Literata-SemiBold"
        case .medium: return "Literata-Medium"
        default: return "Literata-Regular"
        }
    }

    // MARK: - Text styles

    /// Default (Large) content-size point sizes, matching Apple's text styles, so a
    /// migrated call site keeps its rhythm.
    static func size(for style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: return 34
        case .title: return 28
        case .title2: return 22
        case .title3: return 20
        case .headline, .body: return 17
        case .callout: return 16
        case .subheadline: return 15
        case .footnote: return 13
        case .caption: return 12
        case .caption2: return 11
        default: return 17
        }
    }

    /// The text style a fixed size scales alongside.
    static func textStyle(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case ..<11.5: return .caption2
        case ..<12.5: return .caption
        case ..<14: return .footnote
        case ..<15.5: return .subheadline
        case ..<16.5: return .callout
        case ..<19: return .body
        case ..<21: return .title3
        case ..<25: return .title2
        case ..<31: return .title
        default: return .largeTitle
        }
    }

    static func defaultWeight(for style: Font.TextStyle, serif: Bool) -> Font.Weight {
        switch style {
        case .largeTitle, .title: return serif ? .medium : .heavy
        case .title2, .title3: return serif ? .medium : .bold
        case .headline: return serif ? .semibold : .bold
        case .body: return serif ? .regular : .medium
        default: return .medium
        }
    }
}

extension Font {
    /// The Leu equivalent of a system text style: Gabarito by default, Literata when
    /// `serif` is set. Scales with Dynamic Type through `relativeTo:`.
    static func leu(_ style: Font.TextStyle, serif: Bool = false) -> Font {
        leu(style, serif: serif, weight: LeuType.defaultWeight(for: style, serif: serif))
    }

    /// The same, with an explicit weight resolved to a real static face (never synthesised).
    static func leu(_ style: Font.TextStyle, serif: Bool = false, weight: Font.Weight) -> Font {
        let face = serif ? LeuType.serifFace(weight) : LeuType.sansFace(weight)
        return .custom(face, size: LeuType.size(for: style), relativeTo: style)
    }
}
