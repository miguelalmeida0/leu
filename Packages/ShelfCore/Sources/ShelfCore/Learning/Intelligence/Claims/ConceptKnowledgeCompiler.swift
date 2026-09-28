import Foundation

/// Builds grounded claims from verified pages. Two kinds of claim exist:
///
/// * literal — the sentence states its subject;
/// * resolved — a definitional fragment ("A constraint linking ...") or a leading
///   "It"/"They" directly under a noun-phrase heading ("Foreign key"). The heading span is
///   stored as the antecedent, so the inference is explicit and auditable.
///
/// Mnemonic, example, advice and heading regions never produce claims. Interview/summary
/// regions produce third-person *supporting* claims only. Pages that failed spatial
/// verification, legacy extractions and unresolvable sentences produce nothing.
public struct ConceptKnowledgeCompiler: Sendable {
    public init() {}

    public func compile(_ analysis: DocumentAnalysis) -> ConceptKnowledgeBase {
        guard analysis.extractionVersion == SourceExtractionVersion.current else { return .empty }
        var concepts: [ConceptEntry] = [], claims: [LearningClaim] = []
        for page in analysis.pages where page.isIntelligenceEligible && page.spatialIntegrityPassed == true {
            guard let canonical = page.canonicalText, !canonical.isEmpty else { continue }
            let result = PageCompilation(analysis: analysis, page: page, canonical: canonical).run()
            concepts += result.concepts; claims += result.claims
        }
        let base = ConceptKnowledgeBase(concepts: concepts, claims: claims)
        var canonical: [String: String] = [:]
        for page in analysis.pages { canonical["\(analysis.documentID)|\(page.pageIndex)"] = page.canonicalText }
        return ConceptKnowledgeBase(concepts: concepts, claims: claims, edges: ConceptEdgeBuilder(base: base, canonical: canonical).edges())
    }
}

private struct PageCompilation {
    let analysis: DocumentAnalysis
    let page: AnalyzedPage
    let index: CanonicalPageIndex
    let roles: SourceRoleMap

    init(analysis: DocumentAnalysis, page: AnalyzedPage, canonical: String) {
        self.analysis = analysis; self.page = page
        index = CanonicalPageIndex(canonical)
        roles = SourceRoleMap(canonicalText: canonical)
    }

    struct Topic { let name: String; let key: ConceptKey; let span: SourceSpan; let section: String? }

    func run() -> (concepts: [ConceptEntry], claims: [LearningClaim]) {
        var claims: [LearningClaim] = [], examples: [SourceSpan] = [], expandedAliases: [String] = []
        var topic: Topic?, topicConfirmed = false, paragraphsSinceTopic = 0, lastSubjectIsTopic = false
        var definingClaimID: String?
        // The previous literal sentence in the same paragraph, for "It"/"They" outside a card.
        var section: String?
        for (position, segment) in page.segments.enumerated() {
            let text = CanonicalWhitespaceResolver.normalize(segment.text)
            if SourceRoleMap.headingRole(text) != nil { continue }
            if topic == nil, isTopicHeading(segment, next: Array(page.segments.dropFirst(position + 1).prefix(3))),
               let span = index.headingSpan(text, documentID: analysis.documentID, pageIndex: page.pageIndex) {
                topic = Topic(name: text, key: ConceptNames.key(text), span: span, section: section)
                paragraphsSinceTopic = 0; lastSubjectIsTopic = false; continue
            }
            if segment.kind == .heading { if topic == nil { section = Self.sectionName(text) }; continue }
            // Sentence-level admission handles analogies; excluding a whole segment because one
            // phrase reads like "treated as" would drop real definitions.
            guard !InstructionalText.isStudyFurniture(text), !InstructionalText.isReaderInstruction(segment.sectionTitle ?? "") else { continue }
            let segmentRole = role(of: text)
            // Examples are kept even when they are code: "const fullName = …" is the example.
            if segmentRole == .supportingExample {
                if let span = index.span(text, documentID: analysis.documentID, pageIndex: page.pageIndex) { examples.append(span) }
                continue
            }
            guard !ClaimAdmission.isCode(text) else { continue }
            guard claimRole(for: segmentRole) != nil else { continue }
            // The source's own structure ("IN ONE BREATH" under a heading) confirms a card
            // even when its definition is a full sentence ("Two transactions each hold ...").
            let explainsTopic = topic != nil && paragraphsSinceTopic == 0 && segmentRole == .factualExplanation
            if explainsTopic { topicConfirmed = true }
            for (offset, whole) in ClaimSentenceSplitter.sentences(text).enumerated() {
                // "Continuous Integration: automatically integrating …" under the "CI" heading: the
                // expansion is another name for the card and the fragment after it is the definition.
                var sentence = whole
                if let topic, paragraphsSinceTopic == 0, offset == 0, let expansion = Self.expansion(whole, of: topic.name) {
                    sentence = expansion.rest
                    if !expandedAliases.contains(expansion.name) { expandedAliases.append(expansion.name) }
                }
                guard let span = index.span(sentence, documentID: analysis.documentID, pageIndex: page.pageIndex),
                      let role = claimRole(for: roles.role(for: NSRange(location: span.range.location, length: span.range.length)) ?? segmentRole),
                      ClaimAdmission.admits(sentence, supporting: role == .supporting) else { continue }
                var made: LearningClaim?
                let definitionSlot = paragraphsSinceTopic == 0 && offset == 0 && role == .core &&
                    !claims.contains { $0.grounding.isInferred && $0.kind == .definition }
                let imperativeForm = ClaimAdmission.startsWithBaseVerb(sentence)
                if let topic, definitionSlot,
                   (ClauseParser.isDefinitionalFragment(sentence) && (segmentRole == .factualExplanation || !ClaimAdmission.isImperative(sentence))) ||
                    (segmentRole == .factualExplanation && imperativeForm) {
                    made = LearningClaim(concept: topic.key, conceptName: topic.name, kind: .definition, subject: topic.name,
                        predicate: ConceptText.isPlural(topic.name) ? "are" : "is", object: ConceptText.lowercasingLead(ClaimAdmission.clean(sentence)),
                        qualifier: nil, negated: false, evidence: span,
                        grounding: .resolvedSubject(antecedent: topic.span, via: .definitionFragment), role: role, topic: topic.key)
                } else if let topic, lastSubjectIsTopic, let pronoun = ClauseParser.leadingPronoun(sentence),
                          (pronoun.pronoun == "They") == ConceptText.isPlural(topic.name),
                          let parsed = ClauseParser.parse(sentence) {
                    made = claim(parsed, span: span, concept: topic.key, name: topic.name, subject: topic.name, role: role,
                                 grounding: .resolvedSubject(antecedent: topic.span, via: .leadingPronoun), topic: topic.key)
                } else if ClaimAdmission.isStatement(sentence), let parsed = ClauseParser.parse(sentence),
                          !ClaimAdmission.isPronoun(parsed.subject) {
                    let subjectKey = ConceptKey(parsed.subject)
                    if let topic, subjectKey == topic.key || ConceptNameMatcher.stems(parsed.subject) == ConceptNameMatcher.stems(topic.name) {
                        made = claim(parsed, span: span, concept: topic.key, name: topic.name, subject: parsed.subject,
                                     role: role, grounding: .literal, topic: topic.key)
                    } else if ClaimAdmission.admitsSubject(parsed.subject) {
                        made = claim(parsed, span: span, concept: subjectKey, name: GeneralClaimExtractor.canonical(parsed.subject),
                                     subject: parsed.subject, role: role, grounding: .literal, topic: topic?.key)
                    }
                }
                // An "It"/"They" that does not follow the heading's own subject stays unresolved: after
                // "A client sends a token to the API." it may be the client, the token or the API.
                guard let claim = made, !claims.contains(where: { $0.id == claim.id }) else { continue }
                if claim.concept == topic?.key { topicConfirmed = true }
                if definingClaimID == nil, topic != nil, claim.role == .core,
                   claim.kind == .definition && claim.concept == topic?.key || (explainsTopic && offset == 0) {
                    definingClaimID = claim.id
                }
                lastSubjectIsTopic = topic.map { claim.concept == $0.key } ?? false
                claims.append(claim)
            }
            paragraphsSinceTopic += 1
        }
        // A heading only becomes a concept card when the source itself bound a sentence to it.
        guard let topic, topicConfirmed else {
            // Without a confirmed card, claims resolved to that heading are withdrawn.
            let kept = claims.filter { !($0.grounding.isInferred && $0.concept == topic?.key) }
                .map { claim -> LearningClaim in var copy = claim; copy.topic = nil; return copy }
            return (subjectConcepts(kept), kept)
        }
        var card = ConceptEntry(key: topic.key, name: topic.name, origin: .heading, documentID: analysis.documentID,
                                pageIndex: page.pageIndex, heading: topic.span, section: topic.section, examples: examples)
        card.definingClaimID = definingClaimID
        card.aliases = ConceptNames.aliases(topic.name) + expandedAliases.filter { ConceptKey($0) != topic.key }
        return ([card] + subjectConcepts(claims).filter { $0.key != topic.key }, claims)
    }

    /// "Continuous Integration: automatically …" for the heading "CI": the Title Case words before
    /// the colon spell the acronym (or repeat the name), and a definitional fragment follows.
    static func expansion(_ sentence: String, of name: String) -> (name: String, rest: String)? {
        guard let colon = sentence.firstIndex(of: ":") else { return nil }
        let head = sentence[..<colon].trimmingCharacters(in: .whitespaces)
        let rest = sentence[sentence.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        let words = head.split(whereSeparator: { $0 == " " || $0 == "-" })
        guard (2...6).contains(words.count), words.allSatisfy({ $0.first?.isUppercase == true || ["of", "and", "to", "the", "for"].contains($0) }),
              rest.split(separator: " ").count >= 4 else { return nil }
        let initials = String(words.filter { $0.first?.isUppercase == true }.compactMap(\.first))
        let acronym = name.filter { $0.isLetter }.uppercased()
        guard initials == acronym || ConceptKey(head) == ConceptKey(name) else { return nil }
        guard ClauseParser.isDefinitionalFragment(rest) || ClaimAdmission.startsWithBaseVerb(rest) ||
              rest.split(separator: " ").prefix(2).contains(where: { $0.lowercased().hasSuffix("ing") }) else { return nil }
        return (head, rest)
    }

    static func sectionName(_ text: String) -> String {
        text.replacingOccurrences(of: #"^\d+\s+|\s+\d+(?:\s*/\s*\d+)?$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    private func subjectConcepts(_ claims: [LearningClaim]) -> [ConceptEntry] {
        var seen = Set<ConceptKey>()
        return claims.filter { !$0.grounding.isInferred && $0.role == .core }.compactMap { claim in
            guard seen.insert(claim.concept).inserted, claim.concept.value.split(separator: " ").count <= 4 else { return nil }
            return ConceptEntry(key: claim.concept, name: claim.conceptName, origin: .subject, documentID: analysis.documentID,
                                pageIndex: page.pageIndex, heading: nil, section: nil, examples: [])
        }
    }

    private func claim(_ parsed: ParsedClause, span: SourceSpan, concept: ConceptKey, name: String, subject: String,
                       role: ClaimRole, grounding: ClaimGrounding, topic: ConceptKey?) -> LearningClaim? {
        guard !concept.isEmpty, parsed.object.count >= 2 || parsed.qualifier != nil else { return nil }
        return LearningClaim(concept: concept, conceptName: name, kind: ClaimKindClassifier.kind(parsed), subject: subject,
                             predicate: parsed.predicate, object: parsed.object, qualifier: parsed.qualifier,
                             negated: parsed.negated, evidence: span, grounding: grounding, role: role, topic: topic)
    }

    private func role(of text: String) -> IntelligenceSourceRole {
        guard let span = index.span(text, documentID: analysis.documentID, pageIndex: page.pageIndex) else { return .unclassified }
        return roles.role(for: NSRange(location: span.range.location, length: span.range.length)) ?? .unclassified
    }

    private func claimRole(for role: IntelligenceSourceRole) -> ClaimRole? {
        switch role {
        case .factualExplanation, .unclassified: return .core
        case .interviewInstruction: return .supporting
        case .supportingExample, .mnemonic, .advice, .heading: return nil
        }
    }

    /// A noun-phrase heading directly followed by explanatory prose ("Foreign key", "HTTPS").
    private func isTopicHeading(_ segment: SourceSegment, next: [SourceSegment]) -> Bool {
        let text = CanonicalWhitespaceResolver.normalize(segment.text)
        // Names may carry identifiers and acronyms: "Array.map", "async / await", "Large Language Model (LLM)".
        guard (1...7).contains(DocumentAnalyzer.spokenWordCount(text)), text.count <= 64, text.first.map({ $0.isLetter || $0 == "." }) == true,
              text.rangeOfCharacter(from: CharacterSet(charactersIn: "!?;:&{}[]<>=\"“”")) == nil,
              !text.hasSuffix("."), !text.hasSuffix(","),
              SourceRoleMap.headingRole(text) == nil, !InstructionalText.isSectionLabel(text) else { return false }
        let letters = text.filter(\.isLetter)
        let upper = letters.filter(\.isUppercase).count
        if letters.count > 10 && Double(upper) / Double(max(1, letters.count)) > 0.72 { return false } // section banner
        let tokens = text.split(separator: " ").map(String.init)
        let words = tokens.map { $0.lowercased() }
        // Only a sentence-like heading disqualifies ("Keys describe identity", "State is a snapshot").
        // Two-word names are names: "Cache miss", "Reverse proxy", "SQL JOIN", "Refresh token".
        let hasAuxiliary = words.contains { ClauseLexicon.auxiliaries.contains($0) }
        let sentenceLike = words.count >= 3 && !text.contains(" / ") && ClauseParser.mainVerbIndex(tokens, requireClear: true) != nil
        let governs = words.count > 1 && (ClauseLexicon.determiners.contains(words[1]) || ClauseLexicon.prepositions.contains(words[1]))
        guard !hasAuxiliary, !sentenceLike, !(ClaimAdmission.isImperative(text) && governs) else { return false }
        return next.contains { ($0.kind != .heading && $0.kind != .code) || SourceRoleMap.headingRole($0.text) != nil }
    }
}
