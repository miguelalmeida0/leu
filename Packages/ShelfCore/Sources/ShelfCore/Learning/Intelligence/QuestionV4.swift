import Foundation

public struct QuestionV4: Codable, Equatable, Sendable, Identifiable {
    public struct Choice: Codable, Equatable, Sendable {
        public let text: String
        public let sourceClaimID: String
        public let sourceTitle: String
        public let sourceDocumentID: UUID
        public let sourcePage: Int
        public let span: CanonicalWhitespaceResolver.Span
        public let role: String
    }
    public let id: String
    public let prompt: String
    public let choices: [Choice]
    public let correctChoice: Int
    public let operation: String
    public let claim: ContextualFactualClaim
    public let explanation: String
    public let generation: String
    public let admissionProof: [String]
}

/// No inference and no invented distractor facts. Each alternative remains a
/// complete statement from a different verified card, with its own citation.
public struct QuestionV4Compiler: Sendable {
    private struct Prepared: Sendable {
        let choice: QuestionV4.Choice
        let words: Int
        let tokens: Set<String>
        let title: String
        let exclusions: Set<String>
        let section: String
    }
    private let prepared: [String: Prepared]
    public init() { prepared = [:] }
    init(claims: [ContextualFactualClaim]) {
        prepared = Dictionary(uniqueKeysWithValues: claims.compactMap { claim in
            guard let first = claim.sentences.first else { return nil }
            return (claim.id, Self.prepare(first, claim: claim))
        })
    }
    private static func prepare(_ span: CanonicalWhitespaceResolver.Span, claim: ContextualFactualClaim) -> Prepared {
        let choice = option(span, claim: claim)
        return Prepared(choice: choice, words: words(choice.text).count, tokens: tokens(choice.text),
            title: TechnicalConceptCatalog.titleKey(claim.card.title),
            exclusions: TechnicalConceptCatalog.questionExclusions(claim.card.title), section: sectionKey(claim.card.section))
    }
    private func item(_ claim: ContextualFactualClaim) -> Prepared? {
        prepared[claim.id] ?? claim.sentences.first.map { Self.prepare($0, claim: claim) }
    }
    public func compile(_ claim: ContextualFactualClaim, neighbors: [ContextualFactualClaim]) -> QuestionV4? {
        guard claim.sentences.count >= 2, let first = claim.sentences.first,
              let question = Self.realize(claim) else { return nil }
        // A list of helper names does not explain how the transformation works.
        guard !first.text.hasPrefix("Built-in helpers such as") else { return nil }
        guard let answerItem = item(claim) else { return nil }
        let answer = answerItem.choice
        guard (7...38).contains(answerItem.words) else { return nil }
        let candidates = neighbors.compactMap { other -> (ContextualFactualClaim, QuestionV4.Choice, Double, Int)? in
            guard other.card.id != claim.card.id, let entry = item(other),
                  !answerItem.exclusions.contains(entry.title) else { return nil }
            let choice = entry.choice, a = answerItem.words, b = entry.words
            let similarity = Self.similarity(answerItem.tokens, entry.tokens)
            guard b >= 7, b <= 38, Double(max(a, b)) / Double(min(a, b)) <= 1.65,
                  similarity < 0.40,
                  !choice.text.lowercased().contains(claim.card.title.lowercased()),
                  !answer.text.lowercased().contains(other.card.title.lowercased()),
                  !choice.text.hasPrefix("It "), !choice.text.hasPrefix("They ") else { return nil }
            return (other, choice, similarity, entry.section == answerItem.section ? 1 : 0)
        }.sorted {
            if $0.3 != $1.3 { return $0.3 > $1.3 }
            return $0.2 == $1.2 ? $0.0.id < $1.0.id : $0.2 > $1.2
        }
        guard let firstOther = candidates.first,
              let secondOther = candidates.dropFirst().first(where: { Self.similarity(firstOther.1.text, $0.1.text) < 0.40 }) else { return nil }
        let choices = [answer, firstOther.1, secondOther.1].sorted {
            StableIdentity.hash64(claim.id + $0.sourceClaimID) < StableIdentity.hash64(claim.id + $1.sourceClaimID)
        }
        let candidate = QuestionV4(id: "v4|" + claim.id, prompt: question, choices: choices,
            correctChoice: choices.firstIndex(of: answer)!, operation: claim.families.contains("tradeoff") ? "tradeoff" : "mechanism",
            claim: claim, explanation: claim.card.title + ": " + CanonicalWhitespaceResolver.normalize(claim.original.text),
            generation: "deterministic-contextual-v4; no-model-inference",
            admissionProof: ["title_and_rule_from_same_verified_card", "outcome_from_adjacent_factual_sentence",
                "answer_is_exact_primary_factual_sentence", "each_distractor_has_independent_primary_factual_provenance",
                "source_specific_question; different_card_mechanisms", "roles_and_scope_preserved"])
        return Self.surfaceFailure(candidate) == nil ? candidate : nil
    }
    public func validate(_ candidate: QuestionV4, claims: [ContextualFactualClaim], analyses: [UUID: DocumentAnalysis]) -> String? {
        guard let current = claims.first(where: { $0.id == candidate.claim.id }), current == candidate.claim,
              let analysis = analyses[current.card.documentID], current.card.isCurrent(in: analysis),
              ContextualClaimComposer().compose(analysis: analysis, page: analysis.pages.first { $0.pageIndex == current.card.pageIndex }!).claims.contains(current) else { return "stale_or_unbound_claim" }
        for choice in candidate.choices {
            guard let other = claims.first(where: { $0.id == choice.sourceClaimID }),
                  let analysis = analyses[other.card.documentID], other.card.isCurrent(in: analysis),
                  other.sentences.first == choice.span, choice.text == CanonicalWhitespaceResolver.normalize(choice.span.text),
                  choice.sourceTitle == other.card.title, choice.sourceDocumentID == other.card.documentID,
                  choice.sourcePage == other.card.pageIndex + 1, choice.role == "primary_factual" else { return "unbound_option_or_role" }
        }
        guard compile(current, neighbors: claims) == candidate else { return "v4_contract_mismatch" }
        return Self.surfaceFailure(candidate)
    }
    public static func surfaceFailure(_ question: QuestionV4) -> String? {
        guard question.choices.count == 3, question.choices.indices.contains(question.correctChoice),
              question.choices.filter({ $0.sourceClaimID == question.claim.id }).count == 1,
              question.choices[question.correctChoice].sourceClaimID == question.claim.id else { return "ambiguous_source_answer" }
        guard question.prompt.hasSuffix("?"), question.prompt.filter({ $0 == "?" }).count == 1,
              question.prompt.count <= 260 else { return "malformed_stem" }
        let sizes = question.choices.map { words($0.text).count }
        guard sizes.min()! >= 7, sizes.max()! <= 38,
              Double(sizes.max()!) / Double(sizes.min()!) <= 1.8 else { return "option_length_imbalance" }
        for i in question.choices.indices { for j in question.choices.indices where j > i {
            if similarity(question.choices[i].text, question.choices[j].text) >= 0.40 { return "overlapping_option_mechanisms" }
        } }
        let surfaces = [question.prompt] + question.choices.map(\.text)
        if surfaces.contains(where: { $0.range(of: #"(?i)MAKE\s*IT\s*STICK|IN\s*ONE\s*BREATH|SAY THIS IN|WATCH /|Explain it aloud"#, options: .regularExpression) != nil }) { return "role_leakage" }
        return nil
    }
    private static func option(_ span: CanonicalWhitespaceResolver.Span, claim: ContextualFactualClaim) -> QuestionV4.Choice {
        .init(text: CanonicalWhitespaceResolver.normalize(span.text), sourceClaimID: claim.id, sourceTitle: claim.card.title,
            sourceDocumentID: claim.card.documentID, sourcePage: claim.card.pageIndex + 1, span: span, role: "primary_factual")
    }
    static func realize(_ claim: ContextualFactualClaim) -> String? {
        // Only an explicit adjacent benefit/constraint is transformed. Copulas
        // and claims requiring an unstated causal bridge do not get a question.
        let sentence = CanonicalWhitespaceResolver.normalize(claim.sentences[1].text)
        let pattern = #"^(It|They) (?:(can|may) )?([a-z]+) (.+)\.$"#
        guard let re = try? NSRegularExpression(pattern: pattern),
              let match = re.firstMatch(in: sentence, range: NSRange(sentence.startIndex..., in: sentence)) else { return nil }
        let ns = sentence as NSString
        func part(_ i: Int) -> String { match.range(at: i).location == NSNotFound ? "" : ns.substring(with: match.range(at: i)) }
        let originalVerb = part(3)
        guard let verb = verbs[originalVerb] else { return nil }
        var object = part(4)
        // Mixed modal clauses cannot share one interrogative auxiliary without
        // changing qualifier scope. Keep the claim, withhold that question form.
        guard !object.contains(" and can "), !object.contains(" and may "), !object.contains(", but "),
              !claim.card.title.contains(" vs "), !claim.card.title.contains(", "), !claim.card.title.contains(" and ") else { return nil }
        object = object.replacingOccurrences(of: #"(?<=[a-z])-\s+(?=[a-z])"#, with: "-", options: .regularExpression)
        for (inflected, base) in verbs where inflected != base {
            object = object.replacingOccurrences(of: " and " + inflected + " ", with: " and " + base + " ")
        }
        guard object.count >= 15, !claim.card.title.contains(" / ") || claim.card.title == "try / catch" else { return nil }
        let plural = part(1) == "They", modal = part(2)
        let auxiliary = modal.isEmpty ? (plural ? "do" : "does") : modal
        return "According to the source, how \(auxiliary) \(subject(claim.card.title, plural: plural)) \(verb) \(object)?"
    }
    private static let verbs = ["make":"make", "makes":"make", "create":"create", "creates":"create", "reduce":"reduce", "reduces":"reduce",
        "prevent":"prevent", "prevents":"prevent", "give":"give", "gives":"give", "keep":"keep", "keeps":"keep",
        "support":"support", "supports":"support", "enable":"enable", "enables":"enable", "replace":"replace", "replaces":"replace",
        "balance":"balance", "balances":"balance", "let":"let", "lets":"let", "compute":"compute", "computes":"compute",
        "decouple":"decouple", "decouples":"decouple", "smooth":"smooth", "smooths":"smooth", "model":"model", "models":"model",
        "centralize":"centralize", "centralizes":"centralize", "improve":"improve", "improves":"improve", "derive":"derive", "derives":"derive",
        "separate":"separate", "separates":"separate", "trade":"trade", "trades":"trade", "catch":"catch", "catches":"catch",
        "documents":"document", "avoids":"avoid", "allows":"allow", "standardizes":"standardize"]
    private static func subject(_ title: String, plural: Bool) -> String {
        if title.contains(".") || title == "Docker" || title == "try / catch" { return title }
        let first = title.split(separator: " ").first.map(String.init) ?? title
        let acronym = first == first.uppercased()
        let identifier = first.dropFirst().contains(where: \.isUppercase)
        let lowered = acronym || identifier ? title : title.prefix(1).lowercased() + title.dropFirst()
        if plural { return lowered }
        if title.hasSuffix("Principle") { return "the " + title }
        let head = title.lowercased().split(separator: " ").last.map(String.init) ?? ""
        let countNouns: Set<String> = ["token", "cache", "hit", "test", "guard", "component", "machine", "queue", "module", "system", "database", "constraint", "index", "request", "server", "function", "budget", "protocol", "webhook", "parameter", "api", "proxy", "cookie", "jwt", "transaction", "promise", "interface", "type", "spa", "variable", "union", "reducer", "boundary", "flag", "level", "breaker", "loop", "pyramid"]
        if countNouns.contains(head) {
            if acronym { return "the " + lowered }
            if first.hasPrefix("Http") { return "an " + lowered }
            let consonantU = ["unit", "unique", "user", "uniform", "universal"].contains { lowered.hasPrefix($0) }
            return (!consonantU && "aeiou".contains(lowered.prefix(1).lowercased()) ? "an " : "a ") + lowered
        }
        return lowered
    }
    static func words(_ text: String) -> [String] { text.split(whereSeparator: \.isWhitespace).map(String.init) }
    private static func sectionKey(_ value: String?) -> String { (value ?? "").uppercased().filter(\.isLetter) }
    static func similarity(_ a: String, _ b: String) -> Double {
        similarity(tokens(a), tokens(b))
    }
    private static func tokens(_ value: String) -> Set<String> {
        let stop: Set<String> = ["the","and","that","for","with","from","into","when","before","after","its","can","are","has","have","this","not","without"]
        return Set(HybridLocalIndex.tokens(value)).subtracting(stop)
    }
    private static func similarity(_ x: Set<String>, _ y: Set<String>) -> Double {
        Double(x.intersection(y).count) / Double(max(1, x.union(y).count))
    }
}
