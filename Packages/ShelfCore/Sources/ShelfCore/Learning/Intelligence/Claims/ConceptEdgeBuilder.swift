import Foundation

/// Evidence-backed relations between concepts. An edge exists only when a source sentence
/// names both concepts: `uses` when a concept's own claim mentions another known concept,
/// `contrastsWith` when one passage puts two known concepts side by side as subjects.
struct ConceptEdgeBuilder {
    let base: ConceptKnowledgeBase
    /// Canonical page text by document and page, to read what separates two sentences.
    var canonical: [String: String] = [:]

    static let contrastMarker = try! NSRegularExpression(pattern: #"^(?:but|however|in contrast|by contrast|unlike|instead|on the other hand|whereas|while)\b"#,
                                                         options: [.caseInsensitive])

    func edges() -> [ConceptEdge] {
        let index = ConceptMentionIndex(base.cards)
        guard !index.isEmpty else { return [] }
        var edges: [ConceptEdge] = [], seen = Set<String>()
        func add(_ from: ConceptKey, _ to: ConceptKey, _ relation: ConceptRelation, _ evidence: SourceSpan) {
            guard from != to, seen.insert("\(from.value)|\(to.value)|\(relation.rawValue)").inserted else { return }
            edges.append(ConceptEdge(from: from, to: to, relation: relation, evidence: evidence))
        }
        var subjectStems: [String: [String]] = [:]
        func stems(ofSubject claim: LearningClaim) -> [String] {
            if let cached = subjectStems[claim.id] { return cached }
            let value = ConceptNameMatcher.stems(claim.subject)
            subjectStems[claim.id] = value
            return value
        }
        for claim in base.claims {
            let owner = claim.topic ?? claim.concept
            guard index.contains(owner) else { continue }
            let mentioned = Set(index.mentions(in: ConceptNameMatcher.stems(CanonicalWhitespaceResolver.normalize(claim.evidence.text)))).subtracting([owner])
            // "CORS is not authentication" distinguishes; it does not depend. Other negated
            // claims ("... so they do not need full recomputation") create no edge at all.
            if claim.negated {
                let copular = claim.predicate.lowercased().hasPrefix("is") || claim.predicate.lowercased().hasPrefix("are")
                let objects = Set(index.mentions(in: ConceptNameMatcher.stems(claim.object)))
                for other in mentioned.sorted() where copular && objects.contains(other) { add(owner, other, .contrastsWith, claim.evidence) }
                continue
            }
            for other in mentioned.sorted() { add(owner, other, .uses, claim.evidence) }
        }
        // Contrast: two known concepts are subjects of clauses in one sentence group.
        let grouped = Dictionary(grouping: base.claims, by: { "\($0.evidence.documentID)|\($0.evidence.pageIndex)|\($0.topic?.value ?? "")|\($0.role.rawValue)" })
        for key in grouped.keys.sorted() {
            let group = grouped[key]!
            for claim in group {
                let named = index.mentions(in: stems(ofSubject: claim))
                guard let subject = named.first(where: { $0 != claim.topic }) ?? claim.topic.flatMap({ named.contains($0) ? $0 : nil }) else { continue }
                for other in group where other.id != claim.id && other.evidence.range.location >= claim.evidence.range.location {
                    let gap = other.evidence.range.location - (claim.evidence.range.location + claim.evidence.range.length)
                    guard gap >= 0, gap <= 3, let target = index.mentions(in: stems(ofSubject: other)).first(where: { $0 != subject }),
                          juxtaposes(claim, other, gap: gap) else { continue }
                    add(subject, target, .contrastsWith, claim.evidence)
                }
                // "X usually ..., while Y usually ..." inside one sentence: Y opens the clause.
                if let trailing = claim.qualifier, let clause = trailing.range(of: #"(?i)\b(?:while|whereas)\s+(?:the\s+|a\s+|an\s+)?"#, options: .regularExpression) {
                    let opening = ConceptNameMatcher.stems(String(trailing[clause.upperBound...]))
                    for target in index.mentions(in: Array(opening.prefix(4))).sorted() where target != subject &&
                        index.mentions(in: Array(opening.prefix(index.length(of: target)))).contains(target) {
                        add(subject, target, .contrastsWith, claim.evidence)
                    }
                }
            }
        }
        // A pair the source explicitly contrasts is a distinction, not a dependency.
        _ = subjectStems
        let contrasted = Set(edges.filter { $0.relation == .contrastsWith }.flatMap { ["\($0.from.value)|\($0.to.value)", "\($0.to.value)|\($0.from.value)"] })
        return edges.filter { $0.relation != .uses || !contrasted.contains("\($0.from.value)|\($0.to.value)") }
            .sorted { ($0.from, $0.relation.rawValue, $0.to) < ($1.from, $1.relation.rawValue, $1.to) }
    }
}

extension ConceptEdgeBuilder {
    /// Two adjacent statements set their subjects side by side when one sentence holds both
    /// ("Authentication proves identity; authorization ..."), when the second opens with a
    /// contrast marker, or when both use the same verb ("... protects resources. ... protect data.").
    /// Merely consecutive sentences about related concepts are not a contrast.
    func juxtaposes(_ first: LearningClaim, _ second: LearningClaim, gap: Int) -> Bool {
        let separator = canonical["\(first.evidence.documentID)|\(first.evidence.pageIndex)"].map { text -> String in
            let ns = text as NSString
            let start = first.evidence.range.location + first.evidence.range.length
            guard start + gap <= ns.length else { return "" }
            return ns.substring(with: NSRange(location: start, length: gap))
        } ?? ""
        if separator.contains(";") || first.evidence.text.hasSuffix(";") { return true }
        let opening = CanonicalWhitespaceResolver.normalize(second.evidence.text)
        if Self.contrastMarker.firstMatch(in: opening, range: NSRange(opening.startIndex..., in: opening)) != nil { return true }
        let verbs = [first, second].map { claim in
            ClauseParser.parse(claim.statement).map { $0.verbLemma } ?? ""
        }
        return !verbs[0].isEmpty && verbs[0] == verbs[1] && !["be", "have", "do"].contains(verbs[0])
    }
}

/// Finds concept-card names in stemmed text. Deterministic: the most specific (longest) name
/// wins, and a name nested inside a longer mention ("cookie" in "HttpOnly cookie") is not a
/// separate mention.
struct ConceptMentionIndex {
    private let names: [(key: ConceptKey, stems: [String])]
    private let byFirstStem: [String: [Int]]
    private let derivationalBuckets: [String: [Int]]

    init(_ cards: [ConceptEntry]) {
        var unique: [ConceptKey: [String]] = [:]
        for card in cards where unique[card.key] == nil {
            let stems = ConceptNameMatcher.stems(card.name)
            if !stems.isEmpty { unique[card.key] = stems }
        }
        names = unique.map { (key: $0.key, stems: $0.value) }.sorted { ($1.stems.count, $0.key) < ($0.stems.count, $1.key) }
        var first: [String: [Int]] = [:], buckets: [String: [Int]] = [:]
        for (index, name) in names.enumerated() {
            first[name.stems[0], default: []].append(index)
            if name.stems.count == 1, name.stems[0].count >= 6 { buckets[String(name.stems[0].prefix(4)), default: []].append(index) }
        }
        byFirstStem = first; derivationalBuckets = buckets
    }

    var isEmpty: Bool { names.isEmpty }
    func contains(_ key: ConceptKey) -> Bool { names.contains { $0.key == key } }
    /// Words in the concept's name (after stemming).
    func length(of key: ConceptKey) -> Int { names.first { $0.key == key }?.stems.count ?? 0 }

    /// Mentioned concepts, most specific first, each once.
    func mentions(in words: [String]) -> [ConceptKey] {
        var found: [(index: Int, range: Range<Int>)] = []
        for (position, word) in words.enumerated() {
            for index in byFirstStem[word] ?? [] {
                let stems = names[index].stems
                if position + stems.count <= words.count, words[position..<(position + stems.count)].elementsEqual(stems) {
                    found.append((index, position..<(position + stems.count)))
                }
            }
            // Single-word names also accept close derivations ("throttle" for "Throttling").
            if word.count >= 6, let bucket = derivationalBuckets[String(word.prefix(4))] {
                for index in bucket where names[index].stems[0] != word {
                    let target = names[index].stems[0]
                    if abs(word.count - target.count) <= 4 && Lexicon.derivationallyRelated(word, target) { found.append((index, position..<(position + 1))) }
                }
            }
        }
        let kept = found.filter { candidate in
            !found.contains { other in
                other.range.count > candidate.range.count && other.range.lowerBound <= candidate.range.lowerBound &&
                    candidate.range.upperBound <= other.range.upperBound
            }
        }
        var seen = Set<Int>()
        return kept.map(\.index).sorted().filter { seen.insert($0).inserted }.map { names[$0].key }
    }
}

/// Word-boundary concept mention matching over stems. Single-word names also accept close
/// derivations ("throttle" for "Throttling"), never bare prefixes of short words.
enum ConceptNameMatcher {
    static func stems(_ text: String) -> [String] {
        // Acronyms keep their final letter, as in ConceptKey: "HTTPS" is not "HTTP" plus a plural.
        let acronyms = Set(acronym.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap {
            Range($0.range, in: text).map { text[$0].lowercased() }
        })
        return Lexicon.words(Lexicon.normalizePhrases(text)).filter { !Lexicon.stopwords.contains($0) }
            .map { acronyms.contains($0) ? $0 : Lexicon.stem($0) }
    }
    private static let acronym = try! NSRegularExpression(pattern: #"\b[A-Z][A-Z0-9]+\b"#)
    static func contains(_ words: [String], _ name: [String]) -> Bool {
        guard !name.isEmpty, words.count >= name.count else { return false }
        if name.count == 1 {
            let target = name[0]
            return words.contains { word in
                word == target || (min(word.count, target.count) >= 6 && abs(word.count - target.count) <= 4 &&
                    Lexicon.derivationallyRelated(word, target))
            }
        }
        for start in 0...(words.count - name.count) where zip(words[start...], name).allSatisfy({ $0 == $1 }) { return true }
        return false
    }
}
