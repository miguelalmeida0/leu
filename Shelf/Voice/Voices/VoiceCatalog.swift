@preconcurrency import AVFoundation
import Foundation

struct VoiceCatalog {
    func voices(languagePrefix: String = "en") -> [VoiceDescriptor] {
        let descriptors = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.lowercased().hasPrefix(languagePrefix.lowercased()) }
            .map { voice in
                VoiceDescriptor(id: voice.identifier, name: voice.name, language: voice.language,
                                quality: quality(voice.quality))
            }
        return VoiceQualityRanker().rank(descriptors)
    }

    func bestVoice(identifier: String?, languagePrefix: String = "en") -> AVSpeechSynthesisVoice? {
        if let identifier, let voice = AVSpeechSynthesisVoice(identifier: identifier),
           voice.language.lowercased().hasPrefix(languagePrefix.lowercased()) { return voice }
        let ranked = voices(languagePrefix: languagePrefix)
        return ranked.first.flatMap { AVSpeechSynthesisVoice(identifier: $0.id) }
            ?? AVSpeechSynthesisVoice(language: "en-US")
    }

    func descriptor(for identifier: String?) -> VoiceDescriptor? {
        guard let identifier else { return nil }
        return voices().first(where: { $0.id == identifier })
    }

    private func quality(_ quality: AVSpeechSynthesisVoiceQuality) -> VoiceDescriptor.Quality {
        switch quality {
        case .premium: return .premium
        case .enhanced: return .enhanced
        default: return .standard
        }
    }
}
