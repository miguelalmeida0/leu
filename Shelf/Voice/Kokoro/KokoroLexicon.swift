import Foundation

/// English pronunciation lexicon for Kokoro, ported from Misaki (hexgrad/misaki, Apache-2.0):
/// the gold and silver dictionaries, part-of-speech variants (read/read, live/live), stress
/// rules for capitalised words, and the -s / -ed / -ing suffix rules. Produces phonemes in
/// Misaki's alphabet, which is the alphabet Kokoro-82M was trained on.
///
/// Pure and synchronous so it can be tested without a model.
final class KokoroLexicon: @unchecked Sendable {
    /// A dictionary value: one pronunciation, or one per part of speech ("DEFAULT", "VERB"…).
    enum Entry {
        case word(String)
        case tagged([String: String?])
    }

    struct Context {
        /// Whether the next spoken word starts with a vowel (nil: a pause comes first).
        var futureVowel: Bool?
        var futureTo = false
    }

    let british: Bool
    private let golds: [String: Entry]
    private let silvers: [String: Entry]

    init(golds: [String: Entry], silvers: [String: Entry], british: Bool) {
        self.golds = Self.grow(golds)
        self.silvers = Self.grow(silvers)
        self.british = british
    }

    /// Loads Misaki's `*_gold.json` and `*_silver.json`.
    convenience init(gold: URL, silver: URL, british: Bool) throws {
        self.init(golds: try Self.parse(Data(contentsOf: gold)), silvers: try Self.parse(Data(contentsOf: silver)),
                  british: british)
    }

    static func parse(_ data: Data) throws -> [String: Entry] {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        var result: [String: Entry] = [:]
        result.reserveCapacity(object.count)
        for (key, value) in object {
            if let text = value as? String {
                result[key] = .word(text)
            } else if let tagged = value as? [String: Any] {
                result[key] = .tagged(tagged.mapValues { $0 as? String })
            }
        }
        return result
    }

    /// Misaki's grow_dictionary: "apple" also answers "Apple", and "Paris" also "paris".
    private static func grow(_ dictionary: [String: Entry]) -> [String: Entry] {
        var grown: [String: Entry] = [:]
        for (key, value) in dictionary where key.count >= 2 {
            if key == key.lowercased() {
                let capital = key.prefix(1).uppercased() + key.dropFirst()
                if capital != key { grown[capital] = value }
            } else if key == key.lowercased().prefix(1).uppercased() + key.lowercased().dropFirst() {
                grown[key.lowercased()] = value
            }
        }
        return grown.merging(dictionary) { _, original in original }
    }

    // MARK: Lookup

    func contains(_ word: String) -> Bool { golds[word] != nil || silvers[word] != nil }

    /// The pronunciation of one word, or nil when the lexicon cannot say it.
    func phonemes(for raw: String, tag: String?, context: Context) -> String? {
        let word = raw.replacingOccurrences(of: "\u{2019}", with: "'").replacingOccurrences(of: "\u{2018}", with: "'")
        let stress: Double? = word == word.lowercased() ? nil : (word == word.uppercased() ? 2 : 0.5)
        return wordPhonemes(word, tag: tag, stress: stress, context: context)
    }

    private func wordPhonemes(_ input: String, tag: String?, stress: Double?, context: Context) -> String? {
        if let special = specialCase(input, tag: tag, stress: stress, context: context) { return special }
        var word = input
        let lower = word.lowercased()
        if word.count > 1, word.replacingOccurrences(of: "'", with: "").allSatisfy(\.isLetter), word != lower,
           tag != "NNP" || word.count > 7, !contains(word),
           word == word.uppercased() || word.dropFirst() == word.dropFirst().lowercased(),
           contains(lower) || stemS(lower, tag, stress, context) != nil || stemEd(lower, tag, stress, context) != nil
            || stemIng(lower, tag, stress, context) != nil {
            word = lower
        }
        if isKnown(word) { return lookup(word, tag: tag, stress: stress, context: context) }
        if word.hasSuffix("s'"), isKnown(String(word.dropLast(2)) + "'s") {
            return lookup(String(word.dropLast(2)) + "'s", tag: tag, stress: stress, context: context)
        }
        if word.hasSuffix("'"), isKnown(String(word.dropLast())) {
            return lookup(String(word.dropLast()), tag: tag, stress: stress, context: context)
        }
        return stemS(word, tag, stress, context) ?? stemEd(word, tag, stress, context)
            ?? stemIng(word, tag, stress ?? 0.5, context)
    }

    private func specialCase(_ word: String, tag: String?, stress: Double?, context: Context) -> String? {
        switch word {
        case "a", "A": return tag == "DT" ? "ɐ" : "ˈA"
        case "an", "An": return "ɐn"
        case "I" where tag == "PRP": return "ˌI"
        case "to", "To": return context.futureVowel.map { $0 ? "tʊ" : "tə" } ?? goldWord("to")
        case "the", "The": return context.futureVowel == true ? "ði" : "ðə"
        case "in", "In": return (context.futureVowel == nil || tag != "IN" ? "ˈ" : "") + "ɪn"
        default: break
        }
        if let symbol = Self.symbols[word] { return lookup(symbol, tag: nil, stress: nil, context: context) }
        return nil
    }

    private static let symbols = ["%": "percent", "&": "and", "+": "plus", "@": "at"]

    private func goldWord(_ word: String) -> String? {
        if case .word(let text)? = golds[word] { return text }
        return nil
    }

    private func isKnown(_ word: String) -> Bool {
        if contains(word) || Self.symbols[word] != nil { return true }
        guard !word.isEmpty, word.allSatisfy({ $0.isASCII && $0.isLetter }) else { return false }
        if word.count == 1 { return true }
        if word == word.uppercased() && golds[word.lowercased()] != nil { return true }
        return word.dropFirst() == word.dropFirst().uppercased()
    }

    private func lookup(_ input: String, tag: String?, stress: Double?, context: Context?) -> String? {
        var word = input
        var properNoun = false
        if word == word.uppercased() && golds[word] == nil {
            word = word.lowercased()
            properNoun = tag == "NNP"
        }
        var entry = golds[word]
        if entry == nil && !properNoun { entry = silvers[word] }
        var phonemes: String?
        switch entry {
        case .word(let text)?: phonemes = text
        case .tagged(let variants)?:
            var key = tag ?? "DEFAULT"
            if let context, context.futureVowel == nil, variants["None"] != nil { key = "None" }
            else if variants[key] == nil { key = Self.parentTag(key) ?? "DEFAULT" }
            phonemes = (variants[key] ?? nil) ?? (variants["DEFAULT"] ?? nil)
        case nil: phonemes = nil
        }
        if phonemes == nil || (properNoun && !(phonemes ?? "").contains("ˈ")) {
            if let spelled = spell(word) { return spelled }
        }
        return phonemes.map { Self.applyStress($0, stress) }
    }

    /// Initialisms are read letter by letter: "NASA" when unknown, "U.S.".
    func spell(_ word: String) -> String? {
        var letters: [String] = []
        for character in word where character.isLetter {
            guard let name = goldWord(character.uppercased()) else { return nil }
            letters.append(name)
        }
        guard !letters.isEmpty else { return nil }
        let joined = Self.applyStress(letters.joined(), 0)
        guard let last = joined.range(of: "ˌ", options: .backwards) else { return joined }
        return joined.replacingCharacters(in: last, with: "ˈ")
    }

    static func parentTag(_ tag: String?) -> String? {
        guard let tag else { return nil }
        if tag.hasPrefix("VB") { return "VERB" }
        if tag.hasPrefix("NN") { return "NOUN" }
        if tag.hasPrefix("ADV") || tag.hasPrefix("RB") { return "ADV" }
        if tag.hasPrefix("ADJ") || tag.hasPrefix("JJ") { return "ADJ" }
        return tag
    }

    // MARK: Suffixes

    private func stemS(_ word: String, _ tag: String?, _ stress: Double?, _ context: Context?) -> String? {
        guard word.count >= 3, word.hasSuffix("s") else { return nil }
        let stem: String
        if !word.hasSuffix("ss"), isKnown(String(word.dropLast())) { stem = String(word.dropLast()) }
        else if (word.hasSuffix("'s") || (word.count > 4 && word.hasSuffix("es") && !word.hasSuffix("ies"))),
                isKnown(String(word.dropLast(2))) { stem = String(word.dropLast(2)) }
        else if word.count > 4, word.hasSuffix("ies"), isKnown(String(word.dropLast(3)) + "y") { stem = String(word.dropLast(3)) + "y" }
        else { return nil }
        guard let base = lookup(stem, tag: tag, stress: stress, context: context), let last = base.last else { return nil }
        if "ptkfθ".contains(last) { return base + "s" }
        if "szʃʒʧʤ".contains(last) { return base + (british ? "ɪ" : "ᵻ") + "z" }
        return base + "z"
    }

    private func stemEd(_ word: String, _ tag: String?, _ stress: Double?, _ context: Context?) -> String? {
        guard word.count >= 4, word.hasSuffix("d") else { return nil }
        let stem: String
        if !word.hasSuffix("dd"), isKnown(String(word.dropLast())) { stem = String(word.dropLast()) }
        else if word.count > 4, word.hasSuffix("ed"), !word.hasSuffix("eed"), isKnown(String(word.dropLast(2))) { stem = String(word.dropLast(2)) }
        else { return nil }
        guard let base = lookup(stem, tag: tag, stress: stress, context: context), let last = base.last else { return nil }
        if "pkfθʃsʧ".contains(last) { return base + "t" }
        if last == "d" { return base + (british ? "ɪ" : "ᵻ") + "d" }
        if last != "t" { return base + "d" }
        if british || base.count < 2 { return base + "ɪd" }
        let previous = base[base.index(base.endIndex, offsetBy: -2)]
        return Self.taus.contains(previous) ? String(base.dropLast()) + "ɾᵻd" : base + "ᵻd"
    }

    private func stemIng(_ word: String, _ tag: String?, _ stress: Double?, _ context: Context?) -> String? {
        guard word.count >= 5, word.hasSuffix("ing") else { return nil }
        let root = String(word.dropLast(3))
        let stem: String
        if word.count > 5, isKnown(root) { stem = root }
        else if isKnown(root + "e") { stem = root + "e" }
        else if word.count > 5, word.range(of: #"([bcdgklmnprstvxz])\1ing$|cking$"#, options: .regularExpression) != nil,
                isKnown(String(word.dropLast(4))) { stem = String(word.dropLast(4)) }
        else { return nil }
        guard let base = lookup(stem, tag: tag, stress: stress, context: context) else { return nil }
        if british, let last = base.last, "əː".contains(last) { return nil }
        if !british, base.count > 1, base.last == "t", Self.taus.contains(base[base.index(base.endIndex, offsetBy: -2)]) {
            return String(base.dropLast()) + "ɾɪŋ"
        }
        return base + "ɪŋ"
    }

    private static let taus: Set<Character> = Set("AIOWYiuæɑəɛɪɹʊʌ")

    // MARK: Stress

    static let vowels: Set<Character> = Set("AIOQWYaiuæɑɒɔəɛɜɪʊʌᵻ")

    /// Misaki's apply_stress: demote, remove, or add stress on a pronunciation.
    static func applyStress(_ phonemes: String, _ stress: Double?) -> String {
        guard let stress else { return phonemes }
        let hasPrimary = phonemes.contains("ˈ"), hasSecondary = phonemes.contains("ˌ")
        let hasVowel = phonemes.contains { vowels.contains($0) }
        if stress < -1 { return phonemes.replacingOccurrences(of: "ˈ", with: "").replacingOccurrences(of: "ˌ", with: "") }
        if stress == -1 || ((stress == 0 || stress == -0.5) && hasPrimary) {
            return phonemes.replacingOccurrences(of: "ˌ", with: "").replacingOccurrences(of: "ˈ", with: "ˌ")
        }
        if [0, 0.5, 1].contains(stress) && !hasPrimary && !hasSecondary {
            return hasVowel ? restress("ˌ" + phonemes) : phonemes
        }
        if stress >= 1 && !hasPrimary && hasSecondary { return phonemes.replacingOccurrences(of: "ˌ", with: "ˈ") }
        if stress > 1 && !hasPrimary && !hasSecondary { return hasVowel ? restress("ˈ" + phonemes) : phonemes }
        return phonemes
    }

    /// Moves each stress mark to sit just before the vowel it belongs to.
    private static func restress(_ phonemes: String) -> String {
        let characters = Array(phonemes)
        var positioned: [(Double, Character)] = characters.enumerated().map { (Double($0.offset), $0.element) }
        for (index, character) in characters.enumerated() where character == "ˈ" || character == "ˌ" {
            if let vowel = characters[index...].firstIndex(where: { vowels.contains($0) }) {
                positioned[index].0 = Double(vowel) - 0.5
            }
        }
        return String(positioned.sorted { $0.0 < $1.0 }.map { $0.1 })
    }
}
