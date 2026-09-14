import Foundation

struct VoiceQualityRanker {
    func rank(_ voices: [VoiceDescriptor], preferredLanguage: String = "en-US") -> [VoiceDescriptor] {
        voices.sorted { lhs, rhs in
            if lhs.quality != rhs.quality { return lhs.quality > rhs.quality }
            let lhsPreferred = lhs.language.caseInsensitiveCompare(preferredLanguage) == .orderedSame
            let rhsPreferred = rhs.language.caseInsensitiveCompare(preferredLanguage) == .orderedSame
            if lhsPreferred != rhsPreferred { return lhsPreferred }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}
