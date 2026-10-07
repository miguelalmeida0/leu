import Foundation
import NaturalLanguage

/// Text → Kokoro phonemes. Splits the sentence into words and punctuation, tags parts of
/// speech with NaturalLanguage (so "read" and "live" take the right sound), spells out
/// numbers, then reads each word from the Misaki lexicon right to left, the way Misaki does,
/// so "the" and "to" can hear whether a vowel follows. Unknown words are split on case and
/// hyphens, initialisms are spelled, and anything left is sounded out by rule.
final class KokoroPhonemizer: @unchecked Sendable {
    private let lexicon: KokoroLexicon

    init(lexicon: KokoroLexicon) { self.lexicon = lexicon }

    struct Token: Equatable {
        enum Kind: Equatable { case word, punctuation }
        var text: String
        var kind: Kind
        var tag: String?
        var spaceAfter: Bool
    }

    static let punctuation: Set<Character> = Set(";:,.!?—…\"“”()")
    private static let pausing: Set<Character> = Set(";:,.!?—…()")

    func phonemize(_ text: String) -> String {
        var tokens = Self.tokenize(Self.normalize(text))
        Self.tag(&tokens)
        var output: [String] = Array(repeating: "", count: tokens.count)
        var context = KokoroLexicon.Context()
        for index in tokens.indices.reversed() {
            let token = tokens[index]
            if token.kind == .punctuation {
                output[index] = token.text
                if token.text.contains(where: { Self.pausing.contains($0) }) { context = KokoroLexicon.Context() }
                continue
            }
            let phonemes = word(token.text, tag: token.tag, context: context)
            output[index] = phonemes
            context = KokoroLexicon.Context(futureVowel: Self.startsWithVowel(phonemes) ?? context.futureVowel,
                                            futureTo: token.text.lowercased() == "to")
        }
        var result = ""
        for (index, token) in tokens.enumerated() {
            result += output[index]
            if token.spaceAfter && !output[index].isEmpty { result += " " }
        }
        // Kokoro v1.0 was trained with flaps written as T and glottal stops as t.
        return result.replacingOccurrences(of: "ɾ", with: "T").replacingOccurrences(of: "ʔ", with: "t")
            .trimmingCharacters(in: .whitespaces)
    }

    // MARK: Words

    private func word(_ text: String, tag: String?, context: KokoroLexicon.Context) -> String {
        if let known = lexicon.phonemes(for: text, tag: tag, context: context) { return known }
        if !text.isEmpty, text.allSatisfy(\.isNumber), let value = Int(text) { return phonemize(Self.cardinal(value)) }
        // camelCase, snake_case and hyphenated words are read as their parts.
        let parts = Self.split(text)
        if parts.count > 1 {
            return parts.map { word($0, tag: nil, context: KokoroLexicon.Context(futureVowel: nil)) }.joined(separator: " ")
        }
        if text.count <= 4, text == text.uppercased(), let spelled = lexicon.spell(text) { return spelled }
        return KokoroLetterSounds.sound(text)
    }

    static func split(_ word: String) -> [String] {
        let spaced = word
            .replacingOccurrences(of: #"([a-z])([A-Z])"#, with: "$1 $2", options: .regularExpression)
            .replacingOccurrences(of: #"([A-Z]+)([A-Z][a-z])"#, with: "$1 $2", options: .regularExpression)
            .replacingOccurrences(of: #"([A-Za-z])([0-9])|([0-9])([A-Za-z])"#, with: "$1$3 $2$4", options: .regularExpression)
        return spaced.split(whereSeparator: { $0 == " " || $0 == "-" || $0 == "_" || $0 == "/" || $0 == "." }).map(String.init)
    }

    private static func startsWithVowel(_ phonemes: String) -> Bool? {
        for character in phonemes where character != "ˈ" && character != "ˌ" {
            if KokoroLexicon.vowels.contains(character) { return true }
            if pausing.contains(character) { return nil }
            if character.isLetter || "ðŋɡɹɾʃʒʤʧθ".contains(character) { return false }
        }
        return nil
    }

    // MARK: Tokens

    static func tokenize(_ text: String) -> [Token] {
        var tokens: [Token] = []
        var current = ""
        func flush(space: Bool) {
            guard !current.isEmpty else { return }
            tokens.append(Token(text: current, kind: .word, tag: nil, spaceAfter: space))
            current = ""
        }
        let characters = Array(text)
        for (index, character) in characters.enumerated() {
            let next = index + 1 < characters.count ? characters[index + 1] : nil
            // "React.memo", "e.g", "3.14": a dot between letters or digits stays inside the word.
            if character == ".", !current.isEmpty, next?.isLetter == true || next?.isNumber == true {
                current.append(character); continue
            }
            if character.isWhitespace {
                flush(space: true)
                if let last = tokens.indices.last { tokens[last].spaceAfter = true }
            } else if punctuation.contains(character) {
                flush(space: false)
                tokens.append(Token(text: String(character), kind: .punctuation, tag: nil, spaceAfter: false))
            } else if (character == "'" || character == "\u{2019}") && (current.isEmpty || !(next?.isLetter ?? false)) {
                flush(space: false) // a quote mark, not an apostrophe inside a word
            } else if character.isLetter || character.isNumber || "'\u{2019}-_./".contains(character) {
                if character == ".", !(next?.isLetter ?? false), !(next?.isNumber ?? false) {
                    flush(space: false)
                    tokens.append(Token(text: ".", kind: .punctuation, tag: nil, spaceAfter: false))
                } else {
                    current.append(character)
                }
            } else {
                flush(space: false)
            }
        }
        flush(space: false)
        return tokens
    }

    /// Part-of-speech tags in the Penn style Misaki's lexicon keys use. Each word takes the
    /// tag of the first tagger token that starts inside it ("don't" is tagged by "do").
    static func tag(_ tokens: inout [Token]) {
        let words = tokens.indices.filter { tokens[$0].kind == .word }
        guard !words.isEmpty else { return }
        var sentence = ""
        var starts: [(offset: Int, token: Int)] = []
        for index in words {
            starts.append((sentence.utf16.count, index))
            sentence += tokens[index].text + " "
        }
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = sentence
        var assigned = Set<Int>()
        var position = 0
        tagger.enumerateTags(in: sentence.startIndex..<sentence.endIndex, unit: .word, scheme: .lexicalClass,
                             options: [.omitWhitespace]) { tag, range in
            let offset = NSRange(range, in: sentence).location
            while position + 1 < starts.count && starts[position + 1].offset <= offset { position += 1 }
            let index = starts[position].token
            if !assigned.contains(index) {
                assigned.insert(index)
                var penn = Self.penn(tag)
                if penn == "NN", let first = tokens[index].text.first, first.isUppercase, position > 0 { penn = "NNP" }
                if tokens[index].text.lowercased() == "to", penn == "IN" || penn == "RP" { penn = "TO" }
                tokens[index].tag = penn
            }
            return true
        }
    }

    private static func penn(_ tag: NLTag?) -> String {
        switch tag {
        case .noun?: "NN"
        case .verb?: "VB"
        case .adjective?: "JJ"
        case .adverb?: "RB"
        case .pronoun?: "PRP"
        case .determiner?: "DT"
        case .preposition?: "IN"
        case .particle?: "RP"
        case .conjunction?: "CC"
        case .number?: "CD"
        default: "NN"
        }
    }

    // MARK: Numbers and symbols

    static func normalize(_ text: String) -> String {
        var result = text
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "–", with: "—")
            .replacingOccurrences(of: " - ", with: " — ")
        result = replace(#"\$(\d+(?:\.\d\d)?)"#, in: result) { match in
            let value = Double(match[1]) ?? 0
            guard value < 1e15 else { return match[0] } // Int(Double) traps past Int.max
            let dollars = Int(value), cents = Int(((value - Double(dollars)) * 100).rounded())
            var spoken = cardinal(dollars) + (dollars == 1 ? " dollar" : " dollars")
            if cents > 0 { spoken += " and " + cardinal(cents) + (cents == 1 ? " cent" : " cents") }
            return spoken
        }
        result = replace(#"\b(\d+)(st|nd|rd|th)\b"#, in: result) { ordinal(Int($0[1]) ?? 0) }
        result = replace(#"(\d+)%"#, in: result) { cardinal(Int($0[1]) ?? 0) + " percent" }
        result = replace(#"\b(\d+)\.(\d+)\b"#, in: result) { match in
            cardinal(Int(match[1]) ?? 0) + " point " + match[2].map { cardinal(Int(String($0)) ?? 0) }.joined(separator: " ")
        }
        result = replace(#"\b\d{1,3}(?:,\d{3})+\b|\b\d+\b"#, in: result) { match in
            let digits = match[0].replacingOccurrences(of: ",", with: "")
            guard let value = Int(digits) else { return match[0] }
            if digits.count == 4, !match[0].contains(","), (1100...2099).contains(value) { return year(value) }
            return cardinal(value)
        }
        return result
    }

    private static func replace(_ pattern: String, in text: String, with transform: ([String]) -> String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        var output = text
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            let groups = (0..<match.numberOfRanges).map { index -> String in
                Range(match.range(at: index), in: text).map { String(text[$0]) } ?? ""
            }
            if let range = Range(match.range, in: output) { output.replaceSubrange(range, with: transform(groups)) }
        }
        return output
    }

    static func cardinal(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .spellOut
        return (formatter.string(from: NSNumber(value: value)) ?? String(value)).replacingOccurrences(of: "-", with: " ")
    }

    static func year(_ value: Int) -> String {
        if (2000...2009).contains(value) { return cardinal(value) }
        let high = value / 100, low = value % 100
        if low == 0 { return cardinal(high) + " hundred" }
        return cardinal(high) + (low < 10 ? " oh " : " ") + cardinal(low)
    }

    static func ordinal(_ value: Int) -> String {
        var words = cardinal(value).split(separator: " ").map(String.init)
        guard let last = words.popLast() else { return String(value) }
        let irregular = ["one": "first", "two": "second", "three": "third", "five": "fifth", "eight": "eighth",
                         "nine": "ninth", "twelve": "twelfth"]
        let spoken = irregular[last] ?? (last.hasSuffix("y") ? String(last.dropLast()) + "ieth" : last + "th")
        return (words + [spoken]).joined(separator: " ")
    }
}
