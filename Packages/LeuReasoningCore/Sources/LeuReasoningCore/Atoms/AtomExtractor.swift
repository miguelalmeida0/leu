import Foundation

/// Why a sentence produced no atom. Silence is never acceptable: every sentence
/// the engine drops is recorded, so extraction gaps are measurable.
public struct SkippedSentence: Codable, Equatable, Sendable {
    public enum Reason: String, Codable, Sendable {
        case roleDoesNotYieldClaims
        case noRelationCue
        case emptySubjectOrObject
        case belowParsingConfidence
    }

    public var sentence: String
    public var reason: Reason
    public var span: SourceSpan

    public init(sentence: String, reason: Reason, span: SourceSpan) {
        self.sentence = sentence
        self.reason = reason
        self.span = span
    }
}

public struct AtomExtractionResult: Codable, Equatable, Sendable {
    public var atoms: [KnowledgeAtom]
    public var skipped: [SkippedSentence]

    public init(atoms: [KnowledgeAtom], skipped: [SkippedSentence]) {
        self.atoms = atoms
        self.skipped = skipped
    }
}

/// Turns role-classified blocks into grounded atoms.
///
/// Everything here is deterministic and conservative. The extractor prefers to
/// skip a sentence over guessing its structure, because a malformed atom
/// silently corrupts every downstream reasoning step.
public struct AtomExtractor: Sendable {
    public var minimumParsingConfidence: Double

    public init(minimumParsingConfidence: Double = 0.45) {
        self.minimumParsingConfidence = minimumParsingConfidence
    }

    public func extract(from assignments: [SourceRoleAssignment]) -> AtomExtractionResult {
        var atoms: [KnowledgeAtom] = []
        var skipped: [SkippedSentence] = []
        for assignment in assignments {
            let block = assignment.block
            for sentence in TextScanning.sentences(in: block.text) {
                let span = SourceSpan(documentID: block.documentID,
                                      page: block.page,
                                      canonicalSpan: sentence,
                                      sourceRole: assignment.role)
                guard assignment.role.yieldsFactualClaims else {
                    skipped.append(SkippedSentence(sentence: sentence, reason: .roleDoesNotYieldClaims, span: span))
                    continue
                }
                switch extract(sentence: sentence, span: span) {
                case .success(let produced):
                    for atom in produced where !atoms.contains(atom) { atoms.append(atom) }
                case .failure(let reason):
                    skipped.append(SkippedSentence(sentence: sentence, reason: reason, span: span))
                }
            }
        }
        return AtomExtractionResult(atoms: atoms, skipped: skipped)
    }

    public enum Outcome {
        case success([KnowledgeAtom])
        case failure(SkippedSentence.Reason)
    }

    public func extract(sentence: String, span: SourceSpan) -> Outcome {
        let prepared = Decomposition(sentence: sentence)
        guard let cue = RelationLexicon.firstCue(in: prepared.mainClause) else {
            return .failure(.noRelationCue)
        }

        let before = String(prepared.mainClause[prepared.mainClause.startIndex..<cue.range.lowerBound])
        let after = String(prepared.mainClause[cue.range.upperBound...])
        var subject = Cleaner.clean(before)
        var object = Cleaner.clean(after)
        if cue.cue.inverts { swap(&subject, &object) }

        guard !subject.isEmpty, !object.isEmpty else { return .failure(.emptySubjectOrObject) }

        var qualifiers = prepared.qualifiers
        qualifiers.append(contentsOf: Cleaner.modalityQualifiers(in: prepared.mainClause))
        let negated = prepared.isNegated || Cleaner.isNegated(prepared.mainClause)

        let confidence = parsingConfidence(subject: subject,
                                           object: object,
                                           sentence: sentence,
                                           cue: cue.cue,
                                           conditions: prepared.conditions)
        guard confidence >= minimumParsingConfidence else { return .failure(.belowParsingConfidence) }

        let claimType = resolveClaimType(cue: cue.cue, role: span.sourceRole, conditions: prepared.conditions)
        let integrity: SourceIntegrity = (sentence.contains(subject) && sentence.contains(object)) ? .verbatim : .normalized

        var produced: [KnowledgeAtom] = []
        let atom = KnowledgeAtom(claimType: claimType,
                                 subject: subject,
                                 relation: cue.cue.kind.rawValue,
                                 object: object,
                                 concepts: concepts(subject: subject, object: object),
                                 qualifiers: qualifiers,
                                 isNegated: negated,
                                 numbers: TextScanning.numbers(in: sentence),
                                 identifiers: TextScanning.identifiers(in: sentence),
                                 conditions: prepared.conditions,
                                 sourceIntegrity: integrity,
                                 provenance: Provenance.stated(span, confidenceInParsing: confidence))
        produced.append(atom)

        // "Y because X" asserts a second, explicit causal claim.
        if let reason = prepared.becauseClause {
            let cause = Cleaner.clean(reason)
            if !cause.isEmpty {
                produced.append(KnowledgeAtom(claimType: .cause,
                                              subject: cause,
                                              relation: RelationKind.causes.rawValue,
                                              object: subject,
                                              concepts: concepts(subject: cause, object: subject),
                                              qualifiers: [],
                                              isNegated: false,
                                              conditions: prepared.conditions,
                                              sourceIntegrity: .normalized,
                                              provenance: Provenance.stated(span, confidenceInParsing: confidence * 0.9)))
            }
        }
        return .success(produced)
    }

    // MARK: - Scoring

    func parsingConfidence(subject: String,
                           object: String,
                           sentence: String,
                           cue: RelationLexicon.Cue,
                           conditions: [ClaimCondition]) -> Double {
        var confidence = 1.0
        let subjectWords = TextScanning.words(subject).count
        let objectWords = TextScanning.words(object).count
        if subjectWords > 8 { confidence -= 0.2 }
        if objectWords > 14 { confidence -= 0.2 }
        if subjectWords == 0 || objectWords == 0 { confidence -= 0.6 }
        // A bare copula carries far less structure than a real verb.
        if cue.phrase == "is" || cue.phrase == "are" { confidence -= 0.15 }
        // Several cues in one sentence means the split point is ambiguous.
        let cueCount = RelationLexicon.cues.filter { sentence.lowercased().contains(" \($0.phrase) ") }.count
        if cueCount > 2 { confidence -= 0.1 }
        if !conditions.isEmpty { confidence -= 0.05 }
        if sentence.contains(";") { confidence -= 0.05 }
        return max(0, min(1, confidence))
    }

    func resolveClaimType(cue: RelationLexicon.Cue, role: SourceRole, conditions: [ClaimCondition]) -> ClaimType {
        if role == .example { return .example }
        if role == .caution && cue.claimType == .cause { return .failureMode }
        if !conditions.isEmpty && cue.claimType == .definition { return .constraint }
        return cue.claimType
    }

    func concepts(subject: String, object: String) -> [String] {
        var slugs: [String] = []
        for slug in [TextScanning.conceptSlug(subject), TextScanning.conceptSlug(object)]
        where !slug.isEmpty && !slugs.contains(slug) {
            slugs.append(slug)
        }
        return slugs
    }
}

/// Splits a sentence into its main clause, its conditions and its scope.
struct Decomposition {
    var mainClause: String
    var conditions: [ClaimCondition]
    var qualifiers: [Qualifier]
    var becauseClause: String?
    var isNegated: Bool

    init(sentence: String) {
        var working = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        while let last = working.last, last == "." || last == "!" || last == "?" {
            working = String(working.dropLast())
        }
        var conditions: [ClaimCondition] = []
        var qualifiers: [Qualifier] = []
        var because: String?

        // Trailing "because ..." is a stated cause, not a condition.
        if let range = working.range(of: " because ", options: [.caseInsensitive]) {
            because = String(working[range.upperBound...])
            working = String(working[working.startIndex..<range.lowerBound])
        }
        // Trailing purpose clauses.
        for marker in [" so that ", " in order to "] {
            if let range = working.range(of: marker, options: [.caseInsensitive]) {
                qualifiers.append(Qualifier(kind: .purpose, text: String(working[range.upperBound...])))
                working = String(working[working.startIndex..<range.lowerBound])
            }
        }
        // Leading and trailing conditionals.
        for marker in ["if", "when", "unless", "whenever", "once"] {
            let positive = marker != "unless"
            if let leading = Decomposition.leadingClause(marker: marker, in: working) {
                conditions.append(ClaimCondition(text: leading.clause,
                                                 isPositive: positive,
                                                 concepts: [TextScanning.conceptSlug(leading.clause)]))
                working = leading.remainder
            } else if let trailing = Decomposition.trailingClause(marker: marker, in: working) {
                conditions.append(ClaimCondition(text: trailing.clause,
                                                 isPositive: positive,
                                                 concepts: [TextScanning.conceptSlug(trailing.clause)]))
                working = trailing.remainder
            }
        }
        // Leading scope ("For transient failures, ...").
        if let scope = Decomposition.leadingClause(marker: "for", in: working), scope.clause.split(separator: " ").count <= 8 {
            qualifiers.append(Qualifier(kind: .scope, text: scope.clause))
            working = scope.remainder
        }

        self.mainClause = working.trimmingCharacters(in: .whitespacesAndNewlines)
        self.conditions = conditions
        self.qualifiers = qualifiers
        self.becauseClause = because
        self.isNegated = Cleaner.isNegated(working)
    }

    /// "If X, Y" -> clause X, remainder Y. Requires the comma: without it the
    /// clause boundary is guesswork.
    static func leadingClause(marker: String, in text: String) -> (clause: String, remainder: String)? {
        let lowered = text.lowercased()
        guard lowered.hasPrefix("\(marker) ") else { return nil }
        guard let comma = text.firstIndex(of: ",") else { return nil }
        let clause = String(text[text.index(text.startIndex, offsetBy: marker.count + 1)..<comma])
        let remainder = String(text[text.index(after: comma)...])
        let trimmedRemainder = remainder.trimmingCharacters(in: .whitespaces)
        guard !clause.isEmpty, !trimmedRemainder.isEmpty else { return nil }
        return (clause.trimmingCharacters(in: .whitespaces), trimmedRemainder)
    }

    /// "Y if X" -> clause X, remainder Y.
    static func trailingClause(marker: String, in text: String) -> (clause: String, remainder: String)? {
        guard let range = text.range(of: " \(marker) ", options: [.caseInsensitive, .backwards]) else { return nil }
        let clause = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        let remainder = String(text[text.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        guard !clause.isEmpty, !remainder.isEmpty else { return nil }
        return (clause, remainder)
    }
}

/// Normalises clause fragments into subject/object phrases.
enum Cleaner {
    static let leadingNoise: Set<String> = ["a", "an", "the", "this", "that", "these", "those", "it", "they"]
    static let modality: [(String, Qualifier.Kind)] = [
        ("may", .modality), ("might", .modality), ("must", .modality), ("should", .modality),
        ("can", .modality), ("could", .modality), ("will", .modality),
        ("usually", .frequency), ("often", .frequency), ("sometimes", .frequency),
        ("rarely", .frequency), ("always", .frequency), ("never", .frequency), ("typically", .frequency),
        ("significantly", .degree), ("slightly", .degree), ("greatly", .degree)
    ]
    static let negators: Set<String> = ["not", "never", "cannot", "n't", "doesn't", "don't", "won't", "no"]

    static func clean(_ fragment: String) -> String {
        var words = TextScanning.words(fragment)
        words.removeAll { word in
            let lowered = word.lowercased()
            return negators.contains(lowered) || modality.contains { $0.0 == lowered }
        }
        while let first = words.first, leadingNoise.contains(first.lowercased()) {
            words.removeFirst()
        }
        return words.joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: " ,.;:"))
    }

    static func modalityQualifiers(in clause: String) -> [Qualifier] {
        let tokens = Set(TextScanning.normalizedTokens(clause))
        var found: [Qualifier] = []
        for (word, kind) in modality where tokens.contains(word) {
            let qualifier = Qualifier(kind: kind, text: word)
            if !found.contains(qualifier) { found.append(qualifier) }
        }
        return found
    }

    static func isNegated(_ clause: String) -> Bool {
        let tokens = Set(TextScanning.normalizedTokens(clause))
        if tokens.contains("never") || tokens.contains("not") || tokens.contains("cannot") { return true }
        return clause.lowercased().contains("n't")
    }
}
