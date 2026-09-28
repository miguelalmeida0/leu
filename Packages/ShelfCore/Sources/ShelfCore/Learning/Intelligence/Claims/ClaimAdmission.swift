import Foundation

/// Sentence-level admission for claims: declarative, self-contained, not instruction, code,
/// memory hook, first-person stance, label or diagram furniture.
enum ClaimAdmission {
    /// Long subjects are usually mis-parses; a gerund phrase ("Passing a database object
    /// through every screen") is an action and legitimately carries its object.
    static func admitsSubject(_ subject: String) -> Bool {
        let words = subject.split(whereSeparator: \.isWhitespace)
        let gerund = words.first.map { $0.count > 4 && $0.lowercased().hasSuffix("ing") } ?? false
        return words.count <= (gerund ? 9 : 6)
    }

    static func admits(_ sentence: String, supporting: Bool) -> Bool {
        let text = clean(sentence)
        let words = text.split(separator: " ")
        guard words.count >= 4, text.count <= 400, !sentence.hasSuffix("?"),
              sentence.last.map({ ".;!".contains($0) }) == true,
              !isCode(text), !InstructionalText.isMemoryContent(text), !InstructionalText.isReaderInstruction(text),
              // Explicit analogy markers only: "treated as a single unit" is not a memory hook.
              text.range(of: #"(?i)\b(?:is|are)\s+(?:just\s+)?like\b|\bthink of (?:it|this|them) as\b|\bimagine\b"#,
                         options: .regularExpression) == nil else { return false }
        if text.range(of: #"\b(I|I'm|I'd|I've|me|my|we|We|our|Our|us)\b"#, options: .regularExpression) != nil { return false }
        if text.range(of: #"(?i)\b(?:here|above|below|the (?:first|second|previous|next|following) (?:example|snippet|figure|diagram|code))\b"#,
                      options: .regularExpression) != nil { return false }
        if let colon = text.firstIndex(of: ":"), text.distance(from: text.startIndex, to: colon) < 24 {
            let rest = text[text.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            if isImperative(rest) || text[..<colon].split(separator: " ").count <= 2 { return false }
        }
        return !supporting || text.range(of: #"(?i)\b(you|your)\b"#, options: .regularExpression) == nil
    }

    static func isStatement(_ sentence: String) -> Bool {
        !isImperative(sentence) && sentence.range(of: #"^(?i:do not|don't|never|always|please|try|avoid|remember)\b"#, options: .regularExpression) == nil
    }

    /// "Trace the program", "Use patterns sparingly", "Decide what is authoritative". A noun/verb
    /// homograph ("Query parameters", "Request body", "Proxy") is only imperative when it
    /// directly governs an object or complement.
    static func isImperative(_ sentence: String) -> Bool {
        var words = sentence.split(separator: " ").map { String($0).lowercased().trimmingCharacters(in: .punctuationCharacters) }
        if let adverb = words.first, adverb.hasSuffix("ly"), ClauseLexicon.forms[adverb] == nil, words.count > 1 { words.removeFirst() }
        guard let first = words.first, ClauseLexicon.forms[first]?.form == .base, !ClauseLexicon.auxiliaries.contains(first) else { return false }
        guard ClauseLexicon.homographs.contains(first) else { return true }
        let second = words.count > 1 ? words[1] : ""
        return ClauseLexicon.determiners.contains(second) || ClauseLexicon.prepositions.contains(second) ||
            ["it", "them", "what", "how", "whether", "which", "your", "each"].contains(second)
    }

    /// "Structure relational data ...", "Automatically change compute capacity ...": a definition
    /// written as a procedure. Only used directly under a heading in an explanation region.
    static func startsWithBaseVerb(_ sentence: String) -> Bool {
        var words = sentence.split(separator: " ").map { String($0).lowercased().trimmingCharacters(in: .punctuationCharacters) }
        if let adverb = words.first, adverb.hasSuffix("ly"), ClauseLexicon.forms[adverb] == nil, words.count > 1 { words.removeFirst() }
        guard let first = words.first else { return false }
        return ClauseLexicon.forms[first]?.form == .base && !ClauseLexicon.auxiliaries.contains(first)
    }

    static func isCode(_ text: String) -> Bool {
        text.range(of: #"[{}]|=>|\(\)\s*;|\b(?:const|let|var)\s+[A-Za-z_$][\w$]*\s*=|\bfunction\s+[A-Za-z_$][\w$]*\s*\(|\breturn\s+[^.;]*;|\bimport\s+\S+\s+from\b|//|^\s*<|;\s*$|\b\w+\s*=\s*[\w\[{(\"']"#,
                   options: .regularExpression) != nil
    }

    static func isPronoun(_ subject: String) -> Bool {
        ["it", "they", "this", "these", "that", "those", "he", "she", "we", "you", "i"].contains(subject.lowercased())
    }

    static func clean(_ sentence: String) -> String {
        CanonicalWhitespaceResolver.normalize(sentence).trimmingCharacters(in: CharacterSet(charactersIn: ".;: "))
    }
}

enum ClaimKindClassifier {
    static func kind(_ parsed: ParsedClause) -> ClaimKind {
        let lemma = parsed.verbLemma, predicate = parsed.predicate.lowercased()
        let trailing = parsed.trailingQualifier?.lowercased() ?? ""
        if trailing.hasPrefix("but ") || lemma == "trade" { return .tradeoff }
        if ["differ", "contrast"].contains(lemma) || trailing.hasPrefix("while ") || trailing.hasPrefix("whereas ") { return .contrast }
        if ["help", "allow", "enable", "let", "protect", "improve", "ensure", "guarantee", "provide", "give", "lower", "reduce", "remove", "power", "support", "avoid"].contains(lemma) { return .purpose }
        if ["prevent", "limit", "restrict", "block", "need", "require", "depend"].contains(lemma) || predicate.contains("must") || predicate.contains("should") || predicate.contains("cannot") { return .constraint }
        if ["cause", "lead", "result", "destroy", "break", "preserve", "create", "make", "become"].contains(lemma) { return .consequence }
        if trailing.hasPrefix("because ") { return .cause }
        if ["be", "mean", "refer", "represent", "describe"].contains(lemma) {
            let object = parsed.object.lowercased()
            if object.hasPrefix("a ") || object.hasPrefix("an ") || object.hasPrefix("the ") { return .definition }
            return .property
        }
        if trailing.hasPrefix("before ") || trailing.hasPrefix("after ") { return .sequence }
        return .mechanism
    }
}

/// Concept names as printed in headings. "Large Language Model (LLM)" is keyed without its
/// parenthetical and keeps "LLM" as an alias; "async / await" keeps both parts as aliases.
enum ConceptNames {
    static func key(_ heading: String) -> ConceptKey {
        let base = heading.replacingOccurrences(of: #"\s*\([^)]*\)\s*$"#, with: "", options: .regularExpression)
        return ConceptKey(base.isEmpty ? heading : base)
    }
    static func aliases(_ heading: String) -> [String] {
        var result: [String] = []
        if let open = heading.lastIndex(of: "("), heading.hasSuffix(")") {
            let inner = heading[heading.index(after: open)..<heading.index(before: heading.endIndex)]
            let clean = inner.trimmingCharacters(in: .whitespaces)
            if !clean.isEmpty, !clean.hasPrefix(".") { result.append(clean) }
        }
        let parts = heading.components(separatedBy: " / ")
        if parts.count == 2 { result += parts.map { $0.trimmingCharacters(in: .whitespaces) } }
        return result
    }
}
