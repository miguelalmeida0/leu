import SwiftUI
import Observation

enum ReaderSurround: String, CaseIterable {
    case paper, warm, dark
    var title: String {
        switch self { case .paper: return "Paper"; case .warm: return "Warm surround"; case .dark: return "Dark surround" }
    }
    /// The space around an Original PDF page. The page itself is never recoloured.
    var color: Color {
        switch self {
        case .paper: return .white
        case .warm: return ShelfTheme.paper
        case .dark: return ShelfTheme.nightSurface
        }
    }

    /// Read Mode surfaces, where Leu owns both background and type.
    var readingBackground: Color {
        switch self {
        case .paper: return LeuDesign.readingSurface
        case .warm: return ShelfTheme.paper
        case .dark: return ShelfTheme.nightSurface
        }
    }

    var readingText: Color {
        switch self {
        case .paper, .warm: return LeuDesign.readingForeground
        case .dark: return ShelfTheme.nightText
        }
    }
}

enum PageFlow: String, CaseIterable { case vertical, horizontal }

@MainActor @Observable
final class AppPreferences {
    private let defaults: UserDefaults
    var pageFlow: PageFlow { didSet { defaults.set(pageFlow.rawValue, forKey: "reader.flow") } }
    var readerSurround: ReaderSurround { didSet { defaults.set(readerSurround.rawValue, forKey: "reader.surround") } }
    var usePDFCovers: Bool { didSet { defaults.set(usePDFCovers, forKey: "library.pdfCovers") } }
    var keepAwake: Bool { didSet { defaults.set(keepAwake, forKey: "reader.keepAwake") } }
    var compactLibrary: Bool { didSet { defaults.set(compactLibrary, forKey: "library.compact") } }

    /// Reflowed reading typography. This never changes Original/PDF magnification.
    var readTextScale: Double { didSet { defaults.set(readTextScale, forKey: "reader.readTextScale") } }

    /// Original/PDF magnification relative to PDFKit's fit-to-page scale.
    var pdfZoomScale: Double { didSet { defaults.set(pdfZoomScale, forKey: "reader.pdfZoomScale") } }

    var hapticsEnabled: Bool { didSet { defaults.set(hapticsEnabled, forKey: "reader.hapticsEnabled") } }
    var hapticIntensity: Double { didSet { defaults.set(hapticIntensity, forKey: "reader.hapticIntensity") } }
    var blindPagePromptsEnabled: Bool { didSet { defaults.set(blindPagePromptsEnabled, forKey: "learning.blindPagePrompts") } }

    /// Preferred native Apple speech voice. A missing/removed identifier falls back through VoiceCatalog.
    var speechVoiceIdentifier: String? { didSet {
        if let speechVoiceIdentifier { defaults.set(speechVoiceIdentifier, forKey: "voice.identifier") }
        else { defaults.removeObject(forKey: "voice.identifier") }
    } }

    /// User listening-speed multiplier. Content-specific prosody can still slow dense code/formulas.
    var speechSpeed: Double { didSet { defaults.set(speechSpeed, forKey: "voice.speed") } }
    var speechVoiceWasChosen: Bool { didSet { defaults.set(speechVoiceWasChosen, forKey: "voice.explicitChoice") } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        pageFlow = PageFlow(rawValue: defaults.string(forKey: "reader.flow") ?? "") ?? .horizontal
        readerSurround = ReaderSurround(rawValue: defaults.string(forKey: "reader.surround") ?? "") ?? .warm
        usePDFCovers = defaults.bool(forKey: "library.pdfCovers")
        keepAwake = defaults.bool(forKey: "reader.keepAwake")
        compactLibrary = defaults.bool(forKey: "library.compact")

        // Migrate the old shared text/page-scale preference only into Read mode. Original mode
        // deliberately returns to fit-to-page so an old 120% value cannot reopen between pages.
        let legacyScale = defaults.double(forKey: "reader.textScale")
        let storedReadScale = defaults.double(forKey: "reader.readTextScale")
        let initialReadScale = storedReadScale == 0 ? (legacyScale == 0 ? 1.0 : legacyScale) : storedReadScale
        readTextScale = min(max(initialReadScale, 0.8), 1.6)

        let storedPDFScale = defaults.double(forKey: "reader.pdfZoomScale")
        pdfZoomScale = storedPDFScale == 0 ? 1.0 : min(max(storedPDFScale, 0.75), 3.0)

        hapticsEnabled = defaults.object(forKey: "reader.hapticsEnabled") as? Bool ?? true
        let storedHapticIntensity = defaults.double(forKey: "reader.hapticIntensity")
        hapticIntensity = storedHapticIntensity == 0 ? 0.65 : min(max(storedHapticIntensity, 0.1), 1.0)
        blindPagePromptsEnabled = defaults.bool(forKey: "learning.blindPagePrompts")
        speechVoiceIdentifier = defaults.string(forKey: "voice.identifier")
        speechVoiceWasChosen = defaults.bool(forKey: "voice.explicitChoice")
        let storedSpeechSpeed = defaults.double(forKey: "voice.speed")
        speechSpeed = storedSpeechSpeed == 0 ? 1.0 : min(max(storedSpeechSpeed, 0.8), 2.0)
    }
}
