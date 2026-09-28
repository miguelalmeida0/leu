import Foundation

/// The cognitive operation a question asks for. Internal: the learner sees a question, never
/// this taxonomy. Levels order a progression from recognising to transferring an idea.
public enum ProbeOperation: String, Codable, CaseIterable, Sendable {
    /// Say what the concept is (open recall).
    case define
    /// Pick the concept a source definition describes.
    case recognizeDefinition
    /// Why it exists / what it protects, enables or avoids.
    case purpose
    /// How it works.
    case mechanism
    /// When the claim holds.
    case condition
    /// How it differs from a concept the source contrasts it with.
    case contrast
    /// Re-test a specific misunderstanding.
    case misconceptionCheck
    /// Recognise the concept in the source's own example.
    case recognizeExample
    /// Explain what a source example demonstrates.
    case applyExample
    /// An existing admitted source question (V3 / semantic bank).
    case sourceQuestion

    /// 1 recognise, 2 explain, 3 connect, 4 transfer.
    public var level: Int {
        switch self {
        case .define, .recognizeDefinition, .sourceQuestion: return 1
        case .purpose, .mechanism, .condition: return 2
        case .contrast, .misconceptionCheck: return 3
        case .recognizeExample, .applyExample: return 4
        }
    }

    /// Questions that ask *why/how* rather than *what*.
    public var isExplanatory: Bool { [.purpose, .mechanism, .condition, .contrast, .applyExample].contains(self) }
}

/// Builds questions from grounded claims without disclosing the answer. Every prompt is
/// template text plus source words; `nil` means no defensible question exists.
enum PromptRealizer {
    /// How the source itself refers to a name: with "a"/"an" (or in the plural) it is countable.
    enum ArticleUsage: Sendable { case countable, bare, unknown }

    static func usage(of name: String, in knowledge: ConceptKnowledgeBase) -> ArticleUsage {
        usage(of: name, inText: corpus(knowledge))
    }

    /// Every claim sentence of a knowledge base, as one searchable text.
    static func corpus(_ knowledge: ConceptKnowledgeBase) -> String {
        knowledge.claims.map { CanonicalWhitespaceResolver.normalize($0.evidence.text) }.joined(separator: " \n ")
    }

    static func usage(of name: String, inText text: String) -> ArticleUsage {
        let clean = CanonicalWhitespaceResolver.normalize(name)
        let escaped = NSRegularExpression.escapedPattern(for: clean)
        guard !escaped.isEmpty else { return .unknown }
        let range = NSRange(text.startIndex..., in: text)
        func found(_ pattern: String, caseSensitive: Bool = false) -> Bool {
            (try? NSRegularExpression(pattern: pattern, options: caseSensitive ? [] : [.caseInsensitive]))?.firstMatch(in: text, range: range) != nil
        }
        // An acronym is counted by its own plural ("APIs", "JWTs"): in "an HTTP request" the article
        // counts requests, and "HTTPS" is another acronym, not HTTP in the plural.
        if clean.count >= 2, clean.allSatisfy({ $0.isUppercase || $0.isNumber }) {
            if found(#"\b"# + escaped + #"s\b"#, caseSensitive: true) { return .countable }
        } else if found(#"\b(?:a|an|each|every|one)\s+"# + escaped + #"\b|\b"# + escaped + #"s\b"#) {
            return .countable
        }
        return found(#"\b"# + escaped + #"\b"#) ? .bare : .unknown
    }

    /// "a foreign key", "HTTPS", "query parameters", "encryption", "AbortController".
    static func inline(_ name: String, usage: ArticleUsage = .unknown) -> String {
        let clean = CanonicalWhitespaceResolver.normalize(name)
        guard let first = clean.split(separator: " ").first.map(String.init) else { return clean }
        // Acronyms: "HTTPS", "JSON", but "a REST API" when the source counts it.
        if first.count >= 2 && first.allSatisfy({ $0.isUppercase || $0.isNumber || !$0.isLetter }) {
            return usage == .countable && !ConceptText.isPlural(clean) ? article(for: clean) + " " + clean : clean
        }
        if ["a", "an", "the"].contains(first.lowercased()) { return ConceptText.lowercasingLead(clean) }
        let words = clean.split(separator: " ").map(String.init)
        // A code keyword written in lower case ("never", "any", "keyof") is quoted, not given an article.
        if words.count == 1, first.first?.isLowercase == true, first.allSatisfy(\.isLetter) { return "“" + clean + "”" }
        // A title-cased name is a proper name: "the Single Responsibility Principle".
        let content = words.filter { !["of", "and", "or", "in", "for", "to", "the", "a", "an"].contains($0.lowercased()) }
        if words.count >= 2, !words.contains("vs"), content.allSatisfy({ $0.first(where: \.isLetter)?.isUppercase == true }) {
            if ConceptText.isPlural(clean) { return clean }
            return usage == .countable ? article(for: clean) + " " + clean : "the " + clean
        }
        // Gerund phrases are activities: "lifting state up", "prop drilling".
        if first.count > 4, first.lowercased().hasSuffix("ing") { return ConceptText.lowercasingLead(clean) }
        // Identifiers keep their spelling and take no article: useEffect, AbortController, array.filter.
        if first.dropFirst().contains(where: \.isUppercase) || first.contains(".") || first.contains("(") { return clean }
        let lowered = ConceptText.lowercasingLead(clean)
        if ConceptText.isPlural(clean) { return lowered }
        switch usage {
        case .bare: return lowered
        case .countable: break
        case .unknown: if isMass(clean) { return lowered }
        }
        return article(for: lowered) + " " + lowered
    }

    /// "a union", "a user", "an hour", "an API", "an SQL join".
    static func article(for phrase: String) -> String {
        let word = phrase.split(separator: " ").first.map(String.init) ?? phrase
        let lower = word.lowercased()
        if word.count >= 2, word.allSatisfy({ $0.isUppercase || $0.isNumber }) {
            // Said as a word ("REST", "JSON", "CORS") or letter by letter ("API", "HTTP", "SQL").
            let spoken = word.count >= 4 && word.prefix(3).contains { "AEIOU".contains($0) }
            if spoken { return "AEIOU".contains(word.first!) && !word.hasPrefix("U") ? "an" : "a" }
            return "FHLMNRSX".contains(word.first!) || "AEIO".contains(word.first!) ? "an" : "a"
        }
        if ["uni", "use", "usu", "uti", "eu", "one", "once"].contains(where: { lower.hasPrefix($0) }) { return "a" }
        if ["hour", "honest", "honor", "heir"].contains(where: { lower.hasPrefix($0) }) { return "an" }
        return "aeiou".contains(lower.first ?? "x") ? "an" : "a"
    }

    /// "is" or "are" for a concept name.
    static func be(_ name: String) -> String { ConceptText.isPlural(name) ? "are" : "is" }

    static let particles: Set<String> = ["back", "to", "into", "onto", "on", "off", "up", "out", "down", "over", "through", "from",
                                         "with", "in", "at", "for", "about", "of", "away", "around", "by", "across", "after", "before",
                                         "per", "via", "within", "without", "under", "between", "among", "during", "until", "while",
                                         "as", "than", "like", "because", "when", "if", "where", "only", "also", "still", "not"]

    static func isMass(_ name: String) -> Bool {
        let head = name.split(separator: " ").last.map { String($0).lowercased() } ?? ""
        return ["ing", "tion", "sion", "ment", "ity", "ness", "ism", "ure", "ance", "ence", "cy", "ics", "ogy"].contains { head.hasSuffix($0) }
            || head.contains(".") || head.contains("(")
    }

    static func does(_ subject: String) -> String {
        subject.hasPrefix("a ") || subject.hasPrefix("an ") || !ConceptText.isPlural(subject) ? "does" : "do"
    }

    /// A name that reads as a scenario or task title ("AI support assistant with private docs")
    /// rather than a concept: asking "what is …" about it is not a meaningful question.
    static func isScenario(_ name: String) -> Bool {
        let words = name.split(separator: " ").map { $0.lowercased() }
        return words.count >= 5 || words.contains { ["that", "which", "with", "for", "when", "calls", "using", "without"].contains($0) }
    }

    /// A question whose answer is the claim's object: "What does a foreign key protect?"
    /// `subject` is how the concept reads inline ("a foreign key"), when the caller knows the
    /// source's usage; otherwise it is inferred from the name.
    static func objectQuestion(_ claim: LearningClaim, subject named: String? = nil) -> String? {
        guard !claim.negated, let parsed = ClauseParser.parse(claim.statement),
              let form = ClauseLexicon.forms[parsed.verbLemma], form.form == .base,
              !["be", "have", "do", "become", "make", "seem", "mean"].contains(parsed.verbLemma),
              parsed.predicate.split(separator: " ").count <= 2,
              !parsed.object.isEmpty else { return nil }
        // "falls back to …" is not a direct object: "What does the system fall?" is not a question.
        let objectLead = parsed.object.split(separator: " ").first.map { $0.lowercased() } ?? ""
        guard !particles.contains(objectLead) else { return nil }
        let subject = claim.grounding.isInferred ? named ?? inline(claim.conceptName) : ConceptText.lowercasingLead(CanonicalWhitespaceResolver.normalize(parsed.subject))
        // "a message a client …" is a mis-split reduced relative clause; "a browser API used to
        // cancel" carries a clause of its own. Neither reads as "What does … <verb>?".
        let subjectWords = subject.split(separator: " ").map { $0.lowercased() }
        let articles = subjectWords.dropFirst().filter { ["a", "an", "the"].contains($0) }.count
        let clausal = !claim.grounding.isInferred && subjectWords.indices.contains { i in
            let word = subjectWords[i], next = i + 1 < subjectWords.count ? subjectWords[i + 1] : ""
            let participle = ClauseLexicon.forms[word].map { $0.form == .past || $0.form == .participle } ?? false
            // "a distributed cache" is fine; "a token signed by …" is a clause.
            return ["to", "that", "which", "who", "whose"].contains(word) || (participle && ClauseLexicon.prepositions.contains(next))
        }
        guard subjectWords.count <= 7, articles == 0, !clausal else { return nil }
        let prompt = "What \(does(subject)) \(subject) \(parsed.verbLemma)?"
        return leaks(prompt, answer: parsed.object) ? nil : prompt
    }

    /// A question whose answer is the claim's condition: "When can an array index be a poor key?"
    static func conditionQuestion(_ claim: LearningClaim, subject named: String? = nil) -> String? {
        guard let parsed = ClauseParser.parse(claim.statement), let trailing = parsed.trailingQualifier,
              trailing.lowercased().hasPrefix("when ") || trailing.lowercased().hasPrefix("if ") || trailing.lowercased().hasPrefix("unless "),
              !parsed.negated else { return nil }
        let subject = claim.grounding.isInferred ? named ?? inline(claim.conceptName) : ConceptText.lowercasingLead(CanonicalWhitespaceResolver.normalize(parsed.subject))
        let words = parsed.predicate.split(separator: " ").map(String.init)
        let object = CanonicalWhitespaceResolver.normalize(parsed.object)
        let prompt: String
        if let modal = words.first, ["can", "may", "might", "should", "must", "will", "is", "are"].contains(modal.lowercased()) {
            prompt = "When \(modal.lowercased()) \(subject) \(words.dropFirst().joined(separator: " ")) \(object)?"
        } else if ClauseLexicon.forms[parsed.verbLemma] != nil, words.count == 1 {
            prompt = "When \(does(subject)) \(subject) \(parsed.verbLemma) \(object)?"
        } else { return nil }
        let clean = CanonicalWhitespaceResolver.normalize(prompt)
        return leaks(clean, answer: trailing) || clean.count > 200 ? nil : clean
    }

    /// True when the answer's distinctive words appear in the prompt.
    static func leaks(_ prompt: String, answer: String) -> Bool {
        let promptStems = Set(LexicalProfile(prompt).terms.map(\.stem))
        let answerTerms = LexicalProfile(answer).terms.filter { $0.weight == 1 }
        guard !answerTerms.isEmpty else { return true }
        let shared = answerTerms.filter { promptStems.contains($0.stem) }.count
        return Double(shared) / Double(answerTerms.count) > 0.34
    }
}
