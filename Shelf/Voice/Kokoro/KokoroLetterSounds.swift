import Foundation

/// The last resort for a word no lexicon knows (a made-up name, a rare term): sound it out
/// from its spelling with common English letter patterns, longest pattern first, stress on
/// the first vowel. Never perfect, always speakable, and never a spelled-out letter soup.
enum KokoroLetterSounds {
    /// Grapheme → Misaki phoneme, checked longest first.
    private static let patterns: [(String, String)] = [
        ("tion", "ʃən"), ("sion", "ʒən"), ("ture", "ʧəɹ"), ("ough", "ʌf"), ("augh", "ɔ"),
        ("igh", "I"), ("tch", "ʧ"), ("dge", "ʤ"), ("sch", "sk"),
        ("ph", "f"), ("th", "θ"), ("sh", "ʃ"), ("ch", "ʧ"), ("ck", "k"), ("qu", "kw"), ("ng", "ŋ"),
        ("wh", "w"), ("kn", "n"), ("wr", "ɹ"), ("gh", "ɡ"),
        ("ee", "i"), ("ea", "i"), ("oo", "u"), ("ou", "W"), ("ow", "O"), ("ai", "A"), ("ay", "A"),
        ("oi", "Y"), ("oy", "Y"), ("au", "ɔ"), ("aw", "ɔ"), ("ew", "ju"), ("ie", "i"), ("ei", "A"),
        ("oa", "O"), ("ue", "u"), ("er", "əɹ"), ("ar", "ɑɹ"), ("or", "ɔɹ"), ("ir", "ɜɹ"), ("ur", "ɜɹ"),
        ("a", "æ"), ("e", "ɛ"), ("i", "ɪ"), ("o", "ɑ"), ("u", "ʌ"),
        ("b", "b"), ("d", "d"), ("f", "f"), ("h", "h"), ("j", "ʤ"), ("k", "k"), ("l", "l"), ("m", "m"),
        ("n", "n"), ("p", "p"), ("r", "ɹ"), ("s", "s"), ("t", "t"), ("v", "v"), ("w", "w"),
        ("x", "ks"), ("z", "z"),
    ]

    static func sound(_ word: String) -> String {
        let letters = Array(word.lowercased().filter { $0.isASCII && $0.isLetter })
        guard !letters.isEmpty else { return "" }
        var phonemes = ""
        var index = 0
        while index < letters.count {
            let rest = String(letters[index...])
            let next: Character? = index + 1 < letters.count ? letters[index + 1] : nil
            // A final silent e ("name"), soft c and g before e, i, y, and y as a vowel.
            if letters[index] == "e", index == letters.count - 1, letters.count > 2 { break }
            if letters[index] == "c" {
                phonemes += next.map { "eiy".contains($0) } == true ? "s" : "k"; index += 1; continue
            }
            if letters[index] == "g", next.map({ "eiy".contains($0) }) == true, index > 0 {
                phonemes += "ʤ"; index += 1; continue
            }
            if letters[index] == "g" { phonemes += "ɡ"; index += 1; continue }
            if letters[index] == "y" {
                phonemes += index == 0 ? "j" : (index == letters.count - 1 ? "i" : "ɪ"); index += 1; continue
            }
            if let match = patterns.first(where: { rest.hasPrefix($0.0) }) {
                phonemes += match.1
                index += match.0.count
            } else {
                index += 1
            }
        }
        return KokoroLexicon.applyStress(phonemes, 2)
    }
}
