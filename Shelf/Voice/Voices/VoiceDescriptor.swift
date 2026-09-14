import Foundation

struct VoiceDescriptor: Identifiable, Equatable {
    enum Quality: Int, Comparable, CaseIterable {
        case standard = 0, enhanced = 1, premium = 2
        static func < (lhs: Quality, rhs: Quality) -> Bool { lhs.rawValue < rhs.rawValue }
        var title: String {
            switch self { case .standard: return "Compact"; case .enhanced: return "Enhanced"; case .premium: return "Premium" }
        }
    }

    let id: String
    let name: String
    let language: String
    let quality: Quality
}
