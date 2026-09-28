import Foundation

/// Deterministic English term analysis shared by claim rubrics and learner explanations.
/// Both sides pass through the same normalisation, so a family or stem always matches
/// consistently. Nothing here claims semantic entailment.
enum Lexicon {
    static let stopwords: Set<String> = [
        "a", "an", "the", "and", "or", "but", "of", "to", "in", "on", "for", "from", "with", "by", "at", "as", "into",
        "onto", "than", "then", "so", "that", "this", "these", "those", "it", "its", "they", "them", "their", "there",
        "here", "be", "am", "do", "have", "can", "could", "may", "might", "must", "shall", "should", "will", "would",
        "which", "who", "whom", "whose", "what", "when", "where", "why", "how", "if", "unless", "while", "although",
        "though", "because", "since", "until", "about", "also", "just", "only", "even", "very", "really", "actually",
        "basically", "you", "your", "we", "our", "i", "my", "me", "he", "she", "his", "her", "such", "some", "any",
        "all", "every", "both", "either", "each", "whether", "whereas", "yet", "still", "often", "usually", "sometimes",
        "typically", "generally", "always", "never", "not", "no", "nor", "within", "without", "via", "per", "like",
        "etc", "eg", "ie", "s", "t", "up", "out", "down", "over", "under", "through", "between", "against", "among",
        "upon", "around", "after", "before", "during", "further", "too"
    ]
    /// Content words that carry little distinguishing information (half weight).
    static let generic: Set<String> = Set([
        "thing", "stuff", "way", "kind", "type", "something", "anything", "lot", "use", "make", "get", "give", "go",
        "work", "happen", "part", "able", "process", "value", "information", "system", "object", "code", "number",
        "time", "place", "case", "example", "instead", "much", "many", "well", "one", "two", "new", "certain",
        "particular", "specific", "mean", "called", "call", "used", "need", "want", "know", "put", "keep", "another",
        "other", "certain", "extra", "various", "thing", "stuff", "yourself"
    ].map(stem))

    /// Everyday English used to tell an explanation from keyboard noise.
    static let common: Set<String> = Set((
        ["people", "person", "user", "app", "page", "list", "item", "word", "file", "name", "good", "new", "old", "first",
         "last", "long", "great", "little", "right", "big", "high", "small", "large", "next", "early", "important",
         "few", "public", "bad", "same", "able", "true", "false", "yes", "idea", "because", "think", "say", "said",
         "want", "look", "find", "give", "tell", "ask", "seem", "feel", "try", "leave", "call", "back", "also",
         "well", "just", "now", "even", "way", "thing", "man", "day", "year", "world", "life", "hand", "part",
         "place", "week", "point", "home", "water", "room", "fact", "story", "lot", "study", "book", "eye", "job",
         "number", "night", "money", "side", "kind", "head", "house", "service", "friend", "power", "hour", "game",
         "line", "end", "member", "law", "car", "city", "team", "minute", "reason", "change", "health", "war",
         "history", "party", "result", "morning", "girl", "guy", "moment", "air", "teacher", "force", "education",
         "code", "program", "computer", "phone", "table", "value", "screen", "browser", "network", "server", "database",
         "request", "response", "function", "variable", "state", "render", "react", "javascript", "type", "memory",
         "fast", "slow", "happen", "work", "run", "make", "get", "go", "know", "see", "come", "take", "use", "show"]
        + LexiconTables.families.flatMap { $0 } + Array(stopwords)).map(stem))

    static func normalizePhrases(_ text: String) -> String {
        // camelCase boundaries must be marked before lowercasing ("setState" -> "set-state").
        var value = " " + splitCamelCase(text).lowercased().replacingOccurrences(of: "’", with: "'") + " "
        value = replace(lineBreaks, in: value, with: " ")
        for (index, (phrase, _)) in LexiconTables.phrases.enumerated() where value.contains(phrase) {
            value = replace(phrasePatterns[index], in: value, with: phraseTemplates[index])
        }
        return value.trimmingCharacters(in: .whitespaces)
    }

    // Compiled once: building a regular expression per call dominated profiling (identical results).
    private static let lineBreaks = try! NSRegularExpression(pattern: #"[\t\n\r]+"#)
    private static let camelBoundary = try! NSRegularExpression(pattern: #"(?<=[a-z0-9])(?=[A-Z][a-z])"#)
    private static let phrasePatterns = LexiconTables.phrases.map { phrase, _ in
        try! NSRegularExpression(pattern: #"(?<![a-z0-9])"# + NSRegularExpression.escapedPattern(for: phrase) + #"(?![a-z0-9])"#)
    }
    private static let phraseTemplates = LexiconTables.phrases.map { NSRegularExpression.escapedTemplate(for: $0.1) }

    private static func replace(_ expression: NSRegularExpression, in text: String, with template: String) -> String {
        expression.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: template)
    }

    /// Words in order. Compounds keep their joined form and add their parts:
    /// "fixed-length" -> fixed-length, fixed, length, fixedlength; "setState" -> setstate, set, state.
    static func words(_ text: String) -> [String] {
        let prepared = splitCamelCase(text.replacingOccurrences(of: "’", with: "'"))
        var raw: [String] = [], current = ""
        for character in prepared {
            if character.isLetter || character.isNumber || "'_-./=+#".contains(character) { current.append(character) }
            else if !current.isEmpty { raw.append(current); current = "" }
        }
        if !current.isEmpty { raw.append(current) }
        var result: [String] = []
        for token in raw {
            let trimmed = token.trimmingCharacters(in: CharacterSet(charactersIn: ".-/'=+_"))
            guard !trimmed.isEmpty else { continue }
            let lower = trimmed.lowercased()
            if lower.hasSuffix("'s") { result.append(String(lower.dropLast(2))); continue }
            result.append(lower)
            let parts = lower.split(whereSeparator: { "-/._=".contains($0) }).map(String.init).filter { !$0.isEmpty }
            if parts.count > 1 && !lower.allSatisfy({ $0.isNumber || $0 == "." }) {
                result.append(contentsOf: parts)
                if lower.contains("-") { result.append(parts.joined()) }
            }
        }
        return result
    }

    private static func splitCamelCase(_ text: String) -> String {
        // "setState" stays as one token plus its parts; mark the boundary with a hyphen so
        // `words` keeps both. Acronym runs ("HTTPRequest") are left alone.
        replace(camelBoundary, in: text, with: "-")
    }

    static func stem(_ word: String) -> String {
        var w = word.lowercased()
        if let irregular = LexiconTables.irregulars[w] { w = irregular }
        guard w.count > 3, w.allSatisfy({ $0.isLetter || $0 == "-" || $0 == "'" }) else { return w }
        if w.hasSuffix("ies") && w.count > 4 { w = String(w.dropLast(3)) + "y" }
        else if w.hasSuffix("ied") && w.count > 4 { w = String(w.dropLast(3)) + "y" }
        else if w.hasSuffix("ing") && w.count > 5 { w = undouble(String(w.dropLast(3))) }
        else if w.hasSuffix("ed") && w.count > 4 && !w.hasSuffix("eed") { w = undouble(String(w.dropLast(2))) }
        else if w.hasSuffix("sses") || w.hasSuffix("xes") || w.hasSuffix("ches") || w.hasSuffix("shes") || w.hasSuffix("zes") {
            w = String(w.dropLast(2))
        } else if w.hasSuffix("s") && !w.hasSuffix("ss") && !w.hasSuffix("us") && !w.hasSuffix("is") { w = String(w.dropLast()) }
        else if w.hasSuffix("ly") && w.count > 5 && !LexiconTables.lyExceptions.contains(w) {
            w = String(w.dropLast(2)); if w.hasSuffix("i") { w = String(w.dropLast()) + "y" }
        }
        if w.count > 3 && w.hasSuffix("e") && !w.hasSuffix("ee") { w = String(w.dropLast()) }
        return w
    }

    private static func undouble(_ base: String) -> String {
        guard base.count >= 3, let last = base.last, let previous = base.dropLast().last,
              last == previous, !"lsz".contains(last), !"aeiou".contains(last) else { return base }
        return String(base.dropLast())
    }

    /// Derivational relatives ("verify"/"verification", "distributed"/"distribution").
    static func derivationallyRelated(_ a: String, _ b: String) -> Bool {
        let (short, long) = a.count <= b.count ? (a, b) : (b, a)
        guard short.count >= 5, long.count - short.count <= 7, short != long else { return false }
        return long.hasPrefix(String(short.dropLast()))
    }

    static let familyIndex: [String: Set<Int>] = {
        var index: [String: Set<Int>] = [:]
        for (id, family) in LexiconTables.families.enumerated() {
            for word in family { index[stem(word), default: []].insert(id) }
        }
        return index
    }()

    /// stem -> [(dimension, pole)]
    static let dimensionIndex: [String: [(Int, Int)]] = {
        var index: [String: [(Int, Int)]] = [:]
        for (id, dimension) in LexiconTables.dimensions.enumerated() {
            for word in dimension.1 { index[stem(word), default: []].append((id, 0)) }
            for word in dimension.2 { index[stem(word), default: []].append((id, 1)) }
        }
        return index
    }()

    static let negations = LexiconTables.negations
    static let universals = Set(LexiconTables.universals)
    static let hedges = Set(LexiconTables.hedges)
}

/// A content word with the evidence needed to compare it.
struct LexicalTerm: Hashable, Sendable {
    let surface: String
    let stem: String
    var families: Set<Int> { Lexicon.familyIndex[stem] ?? [] }
    var weight: Double { Lexicon.generic.contains(stem) ? 0.5 : 1 }
}

/// An analysed span of text: content terms, polarity cues, quantifiers and dimension poles.
struct LexicalProfile: Sendable {
    let words: [String]
    let terms: [LexicalTerm]
    /// Index into `words` of each term.
    let termPositions: [Int]
    let negationCount: Int
    let universals: Set<String>
    let hedges: Set<String>
    /// dimension -> poles present (both poles present makes a dimension ambiguous)
    let poles: [Int: Set<Int>]
    let stems: Set<String>

    init(_ text: String) {
        let prepared = Lexicon.normalizePhrases(text)
        let words = Lexicon.words(prepared)
        self.words = words
        var terms: [LexicalTerm] = [], positions: [Int] = [], negations = 0, universals = Set<String>(), hedges = Set<String>()
        var poles: [Int: Set<Int>] = [:]
        for (position, word) in words.enumerated() {
            if Lexicon.universals.contains(word) { universals.insert(word) }
            if Lexicon.negations.contains(word) { negations += 1; continue }
            if Lexicon.hedges.contains(word) { hedges.insert(word) }
            let stem = Lexicon.stem(word)
            for (dimension, pole) in Lexicon.dimensionIndex[stem] ?? [] { poles[dimension, default: []].insert(pole) }
            guard !Lexicon.stopwords.contains(word), !Lexicon.stopwords.contains(stem), word.count > 1 || word.first?.isNumber == true else { continue }
            terms.append(LexicalTerm(surface: word, stem: stem)); positions.append(position)
        }
        self.terms = terms; termPositions = positions; negationCount = negations; self.universals = universals; self.hedges = hedges
        self.poles = poles; stems = Set(terms.map(\.stem))
    }

    var isNegative: Bool { negationCount % 2 == 1 }

    /// 1 exact stem, 0.85 paraphrase family, 0.6 derivational relative, else 0.
    func match(_ term: LexicalTerm) -> Double {
        if stems.contains(term.stem) { return 1 }
        let families = term.families
        if !families.isEmpty, terms.contains(where: { !$0.families.isDisjoint(with: families) }) { return 0.85 }
        if terms.contains(where: { Lexicon.derivationallyRelated($0.stem, term.stem) }) { return 0.6 }
        return 0
    }

    func unambiguousPole(_ dimension: Int) -> Int? {
        guard let set = poles[dimension], set.count == 1 else { return nil }
        return set.first
    }
}
