import Foundation

/// Builds every defensible probe for a concept from its grounded claims, examples and
/// relations. Anything that cannot be asked without guessing or leaking the answer is skipped.
public struct ProbeGenerator: Sendable {
    public let knowledge: ConceptKnowledgeBase
    private let corpus: String
    public init(knowledge: ConceptKnowledgeBase) { self.knowledge = knowledge; corpus = PromptRealizer.corpus(knowledge) }

    private func inline(_ name: String) -> String { PromptRealizer.inline(name, usage: PromptRealizer.usage(of: name, inText: corpus)) }

    public func probes(for key: ConceptKey, documentID: UUID, misconceptions: [MisconceptionRecord] = []) -> [LearningProbe] {
        let claims = knowledge.claims(teaching: key).filter { $0.evidence.documentID == documentID }
        guard !claims.isEmpty else { return [] }
        let id = LearnerConceptID(documentID: documentID, concept: key)
        let entry = knowledge.concept(key)
        let name = entry?.name ?? claims[0].conceptName
        let definition = knowledge.definition(of: key).flatMap { $0.evidence.documentID == documentID ? $0 : nil }
        let scenario = PromptRealizer.isScenario(name)
        let inline = inline(name)
        var probes: [LearningProbe] = []

        if let definition, !scenario {
            probes.append(LearningProbe(concept: id, conceptName: name, operation: .define,
                                        prompt: "In one sentence, what \(PromptRealizer.be(name)) \(inline)?", format: .open, rubric: [definition]))
            if let body = Self.definitionBody(definition, name: name), let options = options(answer: name, around: key, documentID: documentID, avoiding: body) {
                probes.append(LearningProbe(concept: id, conceptName: name, operation: .recognizeDefinition,
                    prompt: "Which idea does your source describe as “\(body)”?",
                    format: .choice(options: options.names, answerIndex: options.answer), rubric: [definition]))
            }
        }
        // Explaining questions: a specific object question when the claim allows one, otherwise
        // a question about the claim's role (what it is for, how it works) that the claim answers.
        var askedKinds = Set<ProbeOperation>()
        for claim in claims where claim.id != definition?.id && claim.role == .core && Self.isAbout(claim, name: name, key: key) {
            let operation = FollowUps.operation(for: claim)
            guard [.purpose, .mechanism, .condition].contains(operation) else { continue }
            let specific = PromptRealizer.conditionQuestion(claim, subject: inline).flatMap { operation == .condition ? $0 : nil }
                ?? PromptRealizer.objectQuestion(claim, subject: inline)
            let general: String? = askedKinds.contains(operation) ? nil : {
                switch claim.kind {
                case .purpose: return "What \(PromptRealizer.be(name)) \(inline) for, according to your source?"
                case .mechanism, .sequence: return "How does \(inline) work, according to your source?"
                case .consequence: return "What does \(inline) lead to, according to your source?"
                case .constraint: return "What rule or limit does your source give for \(inline)?"
                default: return nil
                }
            }()
            guard let prompt = specific ?? general else { continue }
            if specific == nil { askedKinds.insert(operation) }
            probes.append(LearningProbe(concept: id, conceptName: name, operation: operation, prompt: prompt, format: .open, rubric: [claim]))
        }
        if let definition, !scenario {
            var partners = knowledge.contrasts(of: key)
            // Without an explicit contrast, the nearest sibling whose definition shares its vocabulary.
            if partners.isEmpty, let sibling = Self.closestSibling(of: key, definition: definition, documentID: documentID, in: knowledge) { partners = [sibling] }
            for other in partners {
                guard let otherDefinition = knowledge.definition(of: other), otherDefinition.evidence.documentID == documentID else { continue }
                let otherName = knowledge.concept(other)?.name ?? otherDefinition.conceptName
                probes.append(LearningProbe(concept: id, conceptName: name, operation: .contrast,
                    prompt: "How does \(inline) differ from \(self.inline(otherName))?",
                    format: .open, rubric: [definition, otherDefinition], relatedConcept: other))
            }
        }
        for example in entry?.examples ?? [] where example.documentID == documentID {
            let text = InterventionPlanner.quote(example.text)
            // A continuation fragment ("-> user 42 in a session store") is not an example a learner can read.
            guard text.split(separator: " ").count >= 4, let lead = text.first, !"-–—>,;:)]}.…".contains(lead) else { continue }
            // The card's defining claim describes the concept even when its grammatical subject
            // is something else ("Two transactions each hold resources the other needs …").
            let core = claims.filter { $0.role == .core && ($0.id == definition?.id || Self.isAbout($0, name: name, key: key)) }
            guard !core.isEmpty else { continue }
            if !scenario, !Self.names(name, in: example.text),
               let options = options(answer: name, around: key, documentID: documentID, avoiding: example.text) {
                probes.append(LearningProbe(concept: id, conceptName: name, operation: .recognizeExample,
                    prompt: "Which idea does the following example from your source show? “\(text)”",
                    format: .choice(options: options.names, answerIndex: options.answer), rubric: Array(core.prefix(2)),
                    evidence: [example] + core.prefix(2).map(\.evidence), excerpt: example))
            }
            probes.append(LearningProbe(concept: id, conceptName: name, operation: .applyExample,
                prompt: "Your source's example: “\(text)”. What does the example show about \(inline)?",
                format: .open, rubric: Array(core.prefix(3)), evidence: [example] + core.prefix(3).map(\.evidence), excerpt: example))
        }
        probes += misconceptionProbes(misconceptions, concept: id, name: name, definition: definition)
        return probes.filter { ProbeValidator.failure($0, in: knowledge) == nil }
    }

    /// A sibling that is easy to confuse with the concept: its definition names the same kind of
    /// thing ("a type that …" / "a type operator that …") and shares vocabulary beyond that.
    static func closestSibling(of key: ConceptKey, definition: LearningClaim, documentID: UUID, in knowledge: ConceptKnowledgeBase) -> ConceptKey? {
        guard let genus = Self.genus(definition) else { return nil }
        let own = Set(LexicalProfile(definition.statement).terms.filter { $0.weight == 1 }.map(\.stem))
            .subtracting(ConceptNameMatcher.stems(definition.conceptName))
        return knowledge.siblings(of: key, limit: 8).compactMap { sibling -> (ConceptKey, Int)? in
            guard let other = knowledge.definition(of: sibling.key), other.evidence.documentID == documentID,
                  Self.genus(other) == genus, !Self.overlaps(sibling.name, definition.conceptName) else { return nil }
            let shared = own.intersection(LexicalProfile(other.statement).terms.filter { $0.weight == 1 }.map(\.stem))
                .subtracting(ConceptNameMatcher.stems(sibling.name)).count
            return shared >= 2 ? (sibling.key, shared) : nil
        }.max { ($0.1, $1.0) < ($1.1, $0.0) }?.0
    }

    /// The kind of thing a definition says the concept is: the head of "a retry strategy where …".
    static func genus(_ definition: LearningClaim) -> String? {
        let body = definition.grounding.isInferred ? definition.evidence.text : definition.object
        let words = LexicalProfile(body).terms.prefix(4)
        let stop: Set<String> = ["that", "which", "where", "when", "used", "whose", "for", "of", "to", "in", "from"]
        let raw = Lexicon.words(Lexicon.normalizePhrases(body)).prefix(6)
        guard let cut = raw.firstIndex(where: { stop.contains($0) }) ?? (raw.count > 0 ? raw.endIndex : nil) else { return nil }
        let phrase = raw[raw.startIndex..<cut].filter { !["a", "an", "the"].contains($0) }
        guard let head = phrase.last, words.contains(where: { $0.stem == Lexicon.stem(head) }) else { return nil }
        return Lexicon.stem(head)
    }

    /// Re-tests a specific wrong idea: the learner judges their own earlier words against the source.
    func misconceptionProbes(_ records: [MisconceptionRecord], concept: LearnerConceptID, name: String, definition: LearningClaim?) -> [LearningProbe] {
        records.filter { $0.concept == concept && $0.status != .resolved }.compactMap { record in
            if record.kind == .confusion, let related = record.relatedConcept, let definition,
               let otherDefinition = knowledge.definition(of: related), otherDefinition.evidence.documentID == concept.documentID {
                let otherName = knowledge.concept(related)?.name ?? otherDefinition.conceptName
                return LearningProbe(concept: concept, conceptName: name, operation: .contrast,
                    prompt: "How does \(inline(name)) differ from \(inline(otherName))?",
                    format: .open, rubric: [definition, otherDefinition], relatedConcept: related)
            }
            guard let claimID = record.claimID, let claim = knowledge.claims.first(where: { $0.id == claimID }) else { return nil }
            let wording = InterventionPlanner.quote(record.learnerWording)
            guard wording.split(separator: " ").count >= 3 else { return nil }
            return LearningProbe(concept: concept, conceptName: name, operation: .misconceptionCheck,
                // "answered": the wording may be an option the learner chose rather than typed.
                prompt: "Earlier you answered “\(wording)”. Compare your answer with your source: what does your source say about \(inline(name))?",
                format: .open, rubric: [claim])
        }
    }

    /// Three or four real concept names from the same document: the answer, the concepts the
    /// source contrasts it with, then its nearest siblings. Only concepts with a definition count.
    func options(answer: String, around key: ConceptKey, documentID: UUID, avoiding shown: String = "") -> (names: [String], answer: Int)? {
        let answerKey = ConceptKey(answer)
        var names: [String] = []
        var seen: Set<ConceptKey> = [answerKey]
        let aliases = Set((knowledge.concept(key)?.names ?? []).map { ConceptKey($0) })
        for other in knowledge.contrasts(of: key) + knowledge.siblings(of: key, limit: 8).map(\.key) {
            // A distractor named in the quoted text would look right ("LRU removes …" / "LRU cache").
            guard names.count < 3, !seen.contains(other), !aliases.contains(other), let entry = knowledge.concept(other),
                  entry.documentID == documentID, knowledge.definition(of: other) != nil,
                  !Self.overlaps(entry.name, answer), !Self.names(entry.name, in: shown) else { continue }
            seen.insert(other); names.append(entry.name)
        }
        guard names.count >= 2 else { return nil }
        let all = ([answer] + names).sorted { StableIdentity.hash64(key.value + "|" + $0) < StableIdentity.hash64(key.value + "|" + $1) }
        return (all, all.firstIndex(of: answer)!)
    }

    /// The definition without the concept's name ("delaying an action until …"), or nil when the
    /// name cannot be kept out of it.
    static func definitionBody(_ definition: LearningClaim, name: String) -> String? {
        let body: String
        if definition.grounding.isInferred { body = CanonicalWhitespaceResolver.normalize(definition.evidence.text) }
        else if ["is", "are"].contains(definition.predicate.lowercased()) { body = CanonicalWhitespaceResolver.normalize(definition.object) }
        else { return nil }
        let clean = ConceptText.lowercasingLead(body.trimmingCharacters(in: CharacterSet(charactersIn: ".;:, ")))
        guard clean.split(separator: " ").count >= 4, clean.count <= 220, !names(name, in: clean), !spellsAcronym(name, in: clean) else { return nil }
        return clean
    }

    /// "Time To Live: how long …" gives away "TTL".
    static func spellsAcronym(_ name: String, in text: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2, trimmed.count <= 6, trimmed.allSatisfy({ $0.isUppercase || $0.isNumber }) else { return false }
        let initials = String(text.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).compactMap(\.first)).uppercased()
        return initials.contains(trimmed)
    }

    /// A claim a question about the concept can be graded against: it says something about the
    /// concept itself, not about another subject that happens to sit in its card.
    static func isAbout(_ claim: LearningClaim, name: String, key: ConceptKey) -> Bool {
        if claim.grounding.isInferred { return true }
        let subject = ConceptNameMatcher.stems(claim.subject)
        return ConceptKey(claim.subject) == key || ConceptNameMatcher.contains(subject, ConceptNameMatcher.stems(name))
    }

    /// True when the text mentions the name (or a close derivation of a one-word name).
    static func names(_ name: String, in text: String) -> Bool {
        let stems = ConceptNameMatcher.stems(name)
        return ConceptNameMatcher.contains(ConceptNameMatcher.stems(text), stems)
    }

    /// Words that would point a learner to a name: its content words, raw and stemmed, or, for
    /// a name made only of common words ("never", "any"), those words themselves.
    static func cueWords(_ name: String) -> Set<String> {
        let tokens = cueTokens(name)
        let content = tokens.filter { !Lexicon.stopwords.contains($0) }
        return Set((content.isEmpty ? tokens : content).flatMap { [$0, Lexicon.stem($0)] })
    }

    static func textWords(_ text: String) -> Set<String> { Set(cueTokens(text).flatMap { [$0, Lexicon.stem($0)] }) }

    /// "React.memo(Row)" -> react, memo, row; "Set-Cookie" -> set, cookie.
    private static func cueTokens(_ text: String) -> [String] {
        Lexicon.words(text).flatMap { $0.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init) }
    }

    /// True when quoted source text singles the answer out among the options: it contains a word
    /// of one of the answer's names that no distractor shares ("a union whose members …" beside a
    /// single union option), or spells its acronym ("least recently used" for "LRU"). A word a
    /// distractor shares ("key" beside "Foreign key" and "Primary key") leaves the real choice open.
    static func singlesOut(_ answerNames: [String], among distractors: [String], in text: String) -> Bool {
        let words = textWords(text), shared = distractors.map(cueWords)
        return answerNames.contains { name in
            // "LRU cache": its acronym spelled out gives it away as surely as the name itself.
            spellsAcronym(name, in: text) || name.split(separator: " ").contains { $0.count >= 3 && spellsAcronym(String($0), in: text) } ||
                cueWords(name).contains { word in words.contains(word) && !shared.contains { $0.contains(word) } }
        }
    }

    static func overlaps(_ a: String, _ b: String) -> Bool {
        let x = Set(ConceptNameMatcher.stems(a)), y = Set(ConceptNameMatcher.stems(b))
        return !x.isEmpty && !y.isEmpty && (x.isSubset(of: y) || y.isSubset(of: x))
    }
}
