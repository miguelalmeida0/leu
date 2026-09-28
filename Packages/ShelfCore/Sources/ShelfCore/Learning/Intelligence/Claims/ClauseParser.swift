import Foundation

/// A declarative clause split into subject, verb group, complement and qualifiers.
public struct ParsedClause: Equatable, Sendable {
    public var leadingQualifier: String?
    public var subject: String
    public var predicate: String
    public var object: String
    public var trailingQualifier: String?
    public var negated: Bool
    /// Lemma of the main verb ("helps" -> "help", "is" -> "be").
    public var verbLemma: String
    public var qualifier: String? {
        let parts = [leadingQualifier, trailingQualifier].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: "; ")
    }
}

/// Finds the main verb with a small scoring model over closed word lists, then splits the
/// sentence around it. Deterministic; unknown words are never promoted to verbs.
enum ClauseParser {
    private static let sentencePattern = try! NSRegularExpression(pattern: #"[^.!?;]+(?:[.!?](?!\s|$)[^.!?;]+)*[.!?;]?(?:\s|$)"#)
    private static let leadingQualifierWords: Set<String> = [
        "with", "without", "in", "for", "when", "if", "after", "before", "unlike", "because", "although", "once",
        "during", "on", "by", "since", "while", "as", "given", "inside", "outside", "under"
    ]
    private static let trailingBoundaries: Set<String> = [
        "when", "if", "unless", "because", "while", "although", "though", "whereas", "until", "so", "but"
    ]

    /// Sentence split identical to the V2/V3 extractors ("Promise.all" and decimals do not split).
    static func sentences(_ text: String) -> [String] {
        let ns = text as NSString
        return sentencePattern.matches(in: text, range: NSRange(location: 0, length: ns.length)).map {
            ns.substring(with: $0.range).trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }
    }

    static func tokens(_ sentence: String) -> [String] {
        sentence.trimmingCharacters(in: CharacterSet(charactersIn: ".!?;: \n\t"))
            .split(whereSeparator: \.isWhitespace).map(String.init)
    }

    private static func bare(_ token: String) -> String {
        token.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ",.;:!?\"“”()[]"))
    }

    /// Index of the main verb (first token of the verb group), or nil.
    /// `requireClear` demands an unambiguous finite verb (score >= 2). Verbs inside
    /// subordinate or relative clauses ("that uniquely identifies", "how ... may perform")
    /// are skipped, including verbs coordinated with them ("allows ... but rejects").
    static func mainVerbIndex(_ tokens: [String], requireClear: Bool = false) -> Int? {
        let words = tokens.map(bare)
        guard words.count >= 2 else { return nil }
        let singular = ["a", "an", "this", "each", "every", "one"].contains(words[0])
        var weak: Int?
        // A sentence opening with a subordinator ("How strongly ...", "When X happens, ...")
        // starts inside the subordinate clause.
        var subordinate = ClauseLexicon.subordinators.contains(words[0]) && words[0] != "that",
            subordinateVerbSeen = false, coordinated = false
        var i = 1
        while i < words.count {
            let word = words[i]
            if isSubordinator(at: i, words), !(subordinate && !subordinateVerbSeen) {
                subordinate = true; subordinateVerbSeen = false; coordinated = false; i += 1; continue
            }
            if subordinate && subordinateVerbSeen && ["and", "or", "but"].contains(word) { coordinated = true }
            // "A message a client sends …", "The structure the runtime uses …": a second noun phrase
            // before any verb opens a relative clause without "that"; its verb is not the main verb.
            if !subordinate, weak == nil, i >= 2, ["a", "an", "the"].contains(word), isNoun(words[i - 1]), !tokens[i - 1].hasSuffix(",") {
                subordinate = true; subordinateVerbSeen = false; coordinated = false; i += 1; continue
            }
            let score = candidateScore(at: i, words: words, tokens: tokens, singular: singular && weak == nil)
            if subordinate {
                if let score, score >= 1 {
                    let endsSubordinate = subordinateVerbSeen && !coordinated &&
                        (ClauseLexicon.auxiliaries.contains(word) || score >= 2)
                    if !endsSubordinate {
                        subordinateVerbSeen = true; coordinated = false
                        i = verbGroupEnd(from: i, words)
                        continue
                    }
                    subordinate = false
                } else { i += 1; continue }
            }
            // The first clear finite verb is the main verb; earlier homographs belong to the subject.
            if let score, score >= 2 { return i }
            if let score, score >= 1, weak == nil { weak = i }
            i += 1
        }
        return requireClear ? nil : weak
    }

    /// Index just past a verb group: auxiliaries, negation, adverbs and the verbs they govern.
    private static func verbGroupEnd(from start: Int, _ words: [String]) -> Int {
        var i = start + 1
        while i < words.count {
            let word = words[i], previous = words[i - 1]
            let governed = ClauseLexicon.auxiliaries.contains(previous) || ClauseLexicon.adverbs.contains(previous) ||
                Lexicon.negations.contains(previous)
            // An auxiliary after a lexical verb starts the next verb group: in "the request the
            // server receives is logged", "receives" ends the relative clause and "is" is the main verb.
            let auxiliaryContinues = ClauseLexicon.auxiliaries.contains(word) && (governed || ClauseLexicon.auxiliaries.contains(words[start]))
            if auxiliaryContinues || ClauseLexicon.adverbs.contains(word) || Lexicon.negations.contains(word) ||
                (ClauseLexicon.forms[word] != nil && (governed || ClauseLexicon.forms[word]!.form != .base)) { i += 1; continue }
            break
        }
        return i
    }

    /// A word that can end a noun phrase: not a function word, verb form, adverb or number.
    private static func isNoun(_ word: String) -> Bool {
        !word.isEmpty && !Lexicon.stopwords.contains(word) && !ClauseLexicon.determiners.contains(word) &&
            !ClauseLexicon.prepositions.contains(word) && !ClauseLexicon.auxiliaries.contains(word) &&
            !ClauseLexicon.adverbs.contains(word) && !ClauseLexicon.subordinators.contains(word) &&
            !word.hasSuffix("ly") && !word.allSatisfy(\.isNumber) &&
            ClauseLexicon.forms[word].map { $0.form == .base && ClauseLexicon.homographs.contains($0.lemma) } ?? true
    }

    private static func isSubordinator(at i: Int, _ words: [String]) -> Bool {
        let word = words[i]
        guard ClauseLexicon.subordinators.contains(word) else { return false }
        guard word == "that" else { return true }
        let next = i + 1 < words.count ? words[i + 1] : ""
        // "that environment" is a determiner; "that uniquely identifies", "that a row points" are clauses.
        return ClauseLexicon.auxiliaries.contains(next) || ClauseLexicon.adverbs.contains(next) ||
            ClauseLexicon.determiners.contains(next) || ["it", "they", "we", "you", "he", "she"].contains(next) ||
            ClauseLexicon.forms[next] != nil || next.hasSuffix("ly")
    }

    private static func candidateScore(at i: Int, words: [String], tokens: [String], singular: Bool) -> Int? {
        let word = words[i], previous = words[i - 1]
        let next = i + 1 < words.count ? words[i + 1] : ""
        let nextIsClause = i + 1 < words.count && isSubordinator(at: i + 1, words)
        // Capitalised mid-sentence words are names ("Pick", "Omit", "React"), never verbs.
        if let first = tokens[i].first, first.isUppercase, !ClauseLexicon.auxiliaries.contains(word) { return nil }
        var score: Int
        if ClauseLexicon.auxiliaries.contains(word) { score = 3 }
        else if let form = ClauseLexicon.forms[word] {
            let homograph = ClauseLexicon.homographs.contains(form.lemma)
            // "Indexes trade ...", "Keys describe ...": a homograph right after a plural subject noun.
            let afterPluralNoun = i <= 4 && previous.count > 3 && previous.hasSuffix("s") && !previous.hasSuffix("ss") &&
                ClauseLexicon.forms[previous] == nil && !ClauseLexicon.determiners.contains(previous) && !Lexicon.stopwords.contains(previous)
            switch form.form {
            case .gerund: return nil
            case .base:
                score = homograph && !afterPluralNoun ? 1 : 2; if singular { score -= 2 }
                // "The stack data structure the runtime uses": a base form cannot agree with a singular
                // noun ("data structure"), so the homograph is a noun here; "Developers structure" is a
                // verb. Only in a plain noun phrase: in "Arrow functions with a block body return", the
                // noun before the verb is not its subject.
                if homograph && !afterPluralNoun && isNoun(previous) &&
                    !words[..<i].contains(where: { ["and", "or"].contains($0) || ClauseLexicon.prepositions.contains($0) }) { score -= 2 }
            case .thirdPerson: score = homograph ? 1 : 2; if singular { score += 1 }
            case .past, .participle:
                score = 1
                if ClauseLexicon.prepositions.contains(next) || next == "as" { score -= 2 } // reduced relative
                if previous.hasSuffix("ly") { score -= 2 }
            }
            if homograph && (next == "to" || next == "of" || ClauseLexicon.auxiliaries.contains(next) ||
                             ClauseLexicon.prepositions.contains(next) || tokens[i].hasSuffix(",")) { score -= 2 }
            // Noun readings of noun/verb homographs: "… shared by application requests." (sentence-final),
            // "repeatable checks such as …", "reusable connections": after an adjective or before "such as".
            if homograph && form.form != .base {
                let adjective = ["able", "ible", "ive", "ous", "ful", "less", "ical", "ic"].contains { previous.hasSuffix($0) } && previous.count > 5
                if next.isEmpty || next == "such" || adjective { score -= 2 }
            }
            if (ClauseLexicon.determiners.contains(next) && !nextIsClause) || ["it", "they", "them", "this", "these"].contains(next) { score += 1 }
        } else { return nil }
        let floatingQuantifier = ["each", "both", "all"].contains(previous) && i >= 2
        let relative = ["that", "which", "who"].contains(previous)
        // "These are", "That is": a demonstrative before an auxiliary is a pronoun subject.
        let pronounSubject = ClauseLexicon.auxiliaries.contains(word) && ["this", "that", "these", "those"].contains(previous)
        let example = previous == "as" && i >= 2 && words[i - 2] == "such"
        if (ClauseLexicon.determiners.contains(previous) && !floatingQuantifier && !relative && !pronounSubject) || previous == "to" ||
            (ClauseLexicon.prepositions.contains(previous) && previous != "as") || example { score -= 3 }
        return score
    }

    /// "A constraint linking a value ..." — a noun phrase with no finite main verb.
    static func isDefinitionalFragment(_ sentence: String) -> Bool {
        let tokens = tokens(sentence)
        guard tokens.count >= 3, let first = tokens.first.map(bare) else { return false }
        guard !ClauseLexicon.pronounSubjects.contains(first), !["if", "when", "because", "although", "unless", "while", "since", "once", "so"].contains(first) else { return false }
        return mainVerbIndex(tokens, requireClear: true) == nil
    }

    /// "It protects ..." / "They are ..." -> ("It", "protects ...").
    static func leadingPronoun(_ sentence: String) -> (pronoun: String, remainder: String)? {
        let tokens = tokens(sentence)
        guard tokens.count >= 3, let first = tokens.first, ["It", "They"].contains(first) else { return nil }
        let second = bare(tokens[1])
        guard ClauseLexicon.auxiliaries.contains(second) || ClauseLexicon.forms[second] != nil ||
              ClauseLexicon.adverbs.contains(second) else { return nil }
        return (first, tokens.dropFirst().joined(separator: " "))
    }

    static func parse(_ sentence: String) -> ParsedClause? {
        var body = sentence.trimmingCharacters(in: CharacterSet(charactersIn: ".!?;: \n\t"))
        var leading: String?
        if let firstWord = body.split(separator: " ").first.map({ bare(String($0)) }),
           leadingQualifierWords.contains(firstWord), let comma = body.firstIndex(of: ","),
           body.distance(from: body.startIndex, to: comma) <= 90 {
            leading = String(body[..<comma]).trimmingCharacters(in: .whitespaces)
            body = String(body[body.index(after: comma)...]).trimmingCharacters(in: .whitespaces)
        }
        let tokens = tokens(body)
        guard var verb = mainVerbIndex(tokens), verb >= 1, verb <= 14 else { return nil }
        let words = tokens.map(bare)
        var end = verb
        // "A random key also destroys", "Path parameters usually identify": adverbs join the verb group.
        while verb > 1, ClauseLexicon.adverbs.contains(words[verb - 1]) || words[verb - 1].hasSuffix("ly") && ClauseLexicon.forms[words[verb - 1]] == nil && words[verb - 1] != "only" {
            verb -= 1
        }
        var negated = false
        // Verb group: auxiliaries, negation and adverbs, then the lexical verb (+ participle).
        while end < tokens.count {
            let word = words[end]
            if Lexicon.negations.contains(word) { negated = true; end += 1; continue }
            if ClauseLexicon.auxiliaries.contains(word) || ClauseLexicon.adverbs.contains(word) { end += 1; continue }
            if let form = ClauseLexicon.forms[word], end == verb || form.form != .base || ClauseLexicon.auxiliaries.contains(words[end - 1]) || ClauseLexicon.adverbs.contains(words[end - 1]) || Lexicon.negations.contains(words[end - 1]) {
                end += 1
                if tokens[end - 1].hasSuffix(",") { break }
                if end < tokens.count, let next = ClauseLexicon.forms[words[end]], next.form == .participle || next.form == .past,
                   ["be", "become"].contains(form.lemma) || ClauseLexicon.auxiliaries.contains(word) { continue }
                break
            }
            break
        }
        guard end > verb else { return nil }
        let lemmaWord = words[verb..<end].last { ClauseLexicon.forms[$0] != nil || ClauseLexicon.auxiliaries.contains($0) } ?? words[verb]
        let lemma = ClauseLexicon.forms[lemmaWord]?.lemma ?? (["is", "are", "was", "were", "be", "been", "am"].contains(lemmaWord) ? "be" : lemmaWord)
        let subject = tokens[..<verb].joined(separator: " ").trimmingCharacters(in: CharacterSet(charactersIn: ", "))
        let predicate = tokens[verb..<end].joined(separator: " ").trimmingCharacters(in: CharacterSet(charactersIn: ", "))
        var objectTokens = Array(tokens[end...]), trailing: String?
        for (offset, token) in objectTokens.enumerated() where offset > 0 {
            let word = bare(token)
            let afterComma = objectTokens[offset - 1].hasSuffix(",")
            if trailingBoundaries.contains(word) && (word != "so" && word != "but" || afterComma) {
                trailing = objectTokens[offset...].joined(separator: " ")
                objectTokens = Array(objectTokens[..<offset]); break
            }
        }
        let object = objectTokens.joined(separator: " ").trimmingCharacters(in: CharacterSet(charactersIn: ", "))
        guard !subject.isEmpty else { return nil }
        return ParsedClause(leadingQualifier: leading, subject: subject, predicate: predicate, object: object,
                            trailingQualifier: trailing, negated: negated, verbLemma: lemma)
    }
}
