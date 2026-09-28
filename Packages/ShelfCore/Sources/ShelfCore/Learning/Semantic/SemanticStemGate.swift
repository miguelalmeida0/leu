import Foundation

/// Surface gates for the legacy semantic question bank. They only remove questions: anything
/// they admit is exactly what the compiler produced before.
///
/// * "What does <subject> <verb>?" where the subject is not a noun phrase — a relative clause
///   ("an array method that"), a quantifier or modifier whose noun was read as the verb
///   ("What does Two request?", "What does an HTTP request?").
/// * "Which concept is described as <description>?" whose description is too thin to identify
///   anything ("… described as retrieved?") or whose options are sentence fragments rather
///   than concepts ("to alter how a resource", "Do not add repositories that").
/// * The same prompt with different answers: the learner cannot know which one is meant.
public enum SemanticStemGate {
    static let clauseWords: Set<String> = ["that", "which", "who", "whom", "whose", "where", "when", "what", "how", "why",
                                           "then", "is", "are", "was", "were", "if", "because", "whether"]
    static let modifierSubjects: Set<String> = ["two", "three", "four", "many", "several", "some", "most", "few", "both", "each",
                                                "all", "every", "multiple", "concurrent", "failed", "scenario", "trace", "bad", "good",
                                                "example", "note", "tip", "then", "how"]
    static let fragmentEdges: Set<String> = ["that", "which", "who", "where", "when", "what", "how", "why", "and", "or", "but",
                                             "so", "to", "of", "if", "because", "than", "as", "is", "are", "do", "does", "not",
                                             "each", "every", "zero", "itself", "whether", "while"]

    public static func rejectionReason(_ question: LearningQuestion) -> String? {
        guard question.stableKey.hasPrefix("semantic|") else { return nil }
        let prompt = CanonicalWhitespaceResolver.normalize(question.prompt)
        if let match = prompt.range(of: #"^What (?:does|do) (.+) (\S+)\?$"#, options: .regularExpression), match.lowerBound == prompt.startIndex {
            let words = prompt.dropFirst(prompt.hasPrefix("What does ") ? 10 : 8).dropLast().split(separator: " ").map(String.init)
            let subject = Array(words.dropLast())
            if subject.contains(where: { clauseWords.contains($0.lowercased()) }) { return "stem_subject_clause" }
            let bare = subject.first.map { ["a", "an", "the"].contains($0.lowercased()) } == true ? Array(subject.dropFirst()) : subject
            if bare.count == 1, let only = bare.first {
                let lower = only.lowercased()
                if modifierSubjects.contains(lower) || (lower.hasSuffix("ed") && lower.count > 4) { return "stem_subject_modifier" }
                if subject.count == 2, only.count >= 2, only.allSatisfy({ $0.isUppercase || $0.isNumber }) { return "stem_subject_modifier" }
            }
        }
        if prompt.hasPrefix("Which concept is described as "), prompt.hasSuffix("?") {
            let description = String(prompt.dropFirst("Which concept is described as ".count).dropLast())
            if LexicalProfile(description).terms.count < 2 || description == description.uppercased() { return "thin_description" }
            if !question.options.allSatisfy({ isConceptLike($0.text) }) { return "fragment_option" }
        }
        return nil
    }

    /// A short name, not a sentence fragment.
    static func isConceptLike(_ text: String) -> Bool {
        let words = CanonicalWhitespaceResolver.normalize(text).split(separator: " ").map { $0.lowercased() }
        guard let first = words.first, let last = words.last, (1...5).contains(words.count) else { return false }
        if fragmentEdges.contains(first) || fragmentEdges.contains(last) { return false }
        if words.dropFirst().dropLast().contains(where: { clauseWords.contains($0) }) { return false }
        return text.range(of: #"[=;{}]|=>"#, options: .regularExpression) == nil
    }

    /// Prompts that appear more than once with different answers.
    public static func ambiguousPrompts(_ questions: [LearningQuestion]) -> Set<String> {
        var answers: [String: Set<String>] = [:]
        for question in questions {
            let prompt = CanonicalWhitespaceResolver.normalize(question.prompt).lowercased()
            answers[prompt, default: []].insert(CanonicalWhitespaceResolver.normalize(question.correctOption?.text ?? "").lowercased())
        }
        return Set(answers.filter { $0.value.count > 1 }.keys)
    }
}
