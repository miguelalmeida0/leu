import Foundation

/// Opposites, so that an embedding never counts a word's opposite as its paraphrase: in any
/// distributional space "fast" sits closer to "slow" than "retain" does to "keep". Two sources,
/// both keyed by Leu's stems: WordNet 3.0 antonyms (Copyright 2006 by Princeton University; see
/// THIRD_PARTY_NOTICES.md) and the opposite poles of Leu's own lexicon dimensions.
enum SemanticAntonyms {
    static let wordNet: [String: Set<String>] = {
        guard let url = Bundle.module.url(forResource: "wordnet-antonyms", withExtension: "txt", subdirectory: "SemanticSpace"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [:] }
        var result: [String: Set<String>] = [:]
        for line in text.split(separator: "\n") where !line.hasPrefix("#") {
            let parts = line.split(separator: " ")
            guard parts.count == 2 else { continue }
            let a = Lexicon.stem(String(parts[0])), b = Lexicon.stem(String(parts[1]))
            guard a != b else { continue }
            result[a, default: []].insert(b)
            result[b, default: []].insert(a)
        }
        return result
    }()

    /// Stems that name opposite ends of one meaning.
    static func opposed(_ a: String, _ b: String) -> Bool {
        if wordNet[a]?.contains(b) == true { return true }
        guard let poles = Lexicon.dimensionIndex[a], let others = Lexicon.dimensionIndex[b] else { return false }
        return poles.contains { pole in others.contains { $0.0 == pole.0 && $0.1 != pole.1 } }
    }
}
