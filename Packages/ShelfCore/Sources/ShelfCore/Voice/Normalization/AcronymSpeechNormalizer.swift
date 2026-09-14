import Foundation

public struct AcronymSpeechNormalizer: Sendable {
    private let forms: [(String, String)] = [
        ("HTTPS", "H T T P S"), ("HTML", "H T M L"), ("HTTP", "H T T P"),
        ("CSS", "C S S"), ("API", "A P I"), ("CLI", "C L I"),
        ("JWT", "J W T"), ("TLS", "T L S"), ("CDN", "C D N"),
        ("MVCC", "M V C C"), ("REST", "rest"), ("DOM", "dom"),
        ("JSON", "Jason"), ("SQL", "S Q L"), ("OAuth", "oh auth"),
        ("npm", "N P M"), ("URL", "U R L"), ("UUID", "U U I D"),
        ("JWTs", "J W T's"), ("APIs", "A P I's")
    ]

    public init() {}

    public func normalize(_ input: String) -> String {
        forms.reduce(input) { current, pair in
            SpeechRegex.escapedBoundaryReplace(pair.0, in: current, with: pair.1)
        }
    }
}
