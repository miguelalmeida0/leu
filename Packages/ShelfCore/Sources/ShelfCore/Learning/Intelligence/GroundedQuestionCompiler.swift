import Foundation

/// V2 source-assertion questions. Distractors are other complete, independently grounded
/// assertions with different named subjects; no false technical statements are invented.
public struct GroundedQuestionCompiler: Sendable {
    public init() {}

    public func compile(_ packet: LearningSourcePacket) -> QuestionRepresentability {
        var claims: [GroundedQuestionClaim] = []
        let roles = SourceRoleMap(canonicalText: packet.sourceText)
        for segment in packet.claimSegments ?? [] {
            for sentence in sentences(CanonicalWhitespaceResolver.normalize(segment)) {
                guard let span = CanonicalWhitespaceResolver.resolve(sentence, in: packet.sourceText),
                      roles.role(for: NSRange(location: span.range.location, length: span.range.length))?.admitsCanonicalFact == true,
                      let claim = claim(sentence, span: span, packet: packet),
                      !claims.contains(where: { $0.id == claim.id }) else { continue }
                claims.append(claim)
            }
        }
        claims.sort { $0.id < $1.id }
        var questions: [LearningModelCandidate] = []
        var selectable: [GroundedQuestionClaim] = []
        for claim in claims {
            let answer = claim.canonicalAnswer
            let alternatives = claims.filter {
                $0.id != claim.id && normalized($0.concept) != normalized(claim.concept) &&
                !normalized($0.concept).contains(normalized(claim.concept)) &&
                !normalized(claim.concept).contains(normalized($0.concept)) &&
                !claim.evidence.text.contains($0.canonicalAnswer) &&
                !$0.evidence.text.contains(answer) &&
                QuestionOptionQuality.comparable($0.canonicalAnswer, to: answer)
            }
            // Try source-attested pairs deterministically. Merely padding options never qualifies.
            var pair: [String]?
            if alternatives.count >= 2 {
                outer: for i in 0..<(alternatives.count - 1) {
                    for j in (i + 1)..<alternatives.count {
                        let proposed = [alternatives[i].canonicalAnswer, alternatives[j].canonicalAnswer]
                        if Set(proposed).count == 2,
                           QuestionOptionQuality.rejectionReason(prompt: claim.prompt, answer: answer, alternatives: proposed) == nil {
                            pair = proposed; break outer
                        }
                    }
                }
            }
            guard let pair else { continue }
            let choices = ([answer] + pair).sorted {
                StableIdentity.hash64(claim.id + $0) < StableIdentity.hash64(claim.id + $1)
            }
            guard let correct = choices.firstIndex(of: answer) else { continue }
            var candidate = LearningModelCandidate(prompt: claim.prompt, choices: choices, correctChoice: correct,
                explanation: claim.evidence.text, supportingQuote: claim.evidence.text,
                concept: claim.concept, skill: claim.cognitiveOperation)
            candidate.selection = GroundedQuestionSelection(claimID: claim.id, cognitiveOperation: claim.cognitiveOperation)
            questions.append(candidate); selectable.append(claim)
        }
        return QuestionRepresentability(status: !questions.isEmpty ? .representable :
            (claims.isEmpty ? .noRepresentableQuestion : .noDefensibleChoices),
            meaningfulClaims: claims, selectableClaims: selectable, questions: questions)
    }

    private func claim(_ sentence: String, span: CanonicalWhitespaceResolver.Span,
                       packet: LearningSourcePacket) -> GroundedQuestionClaim? {
        // Imperatives, embedded instructions, hypothetical/quoted material and code do not
        // become asserted facts. Reject the complete sentence rather than trimming qualifiers.
        guard !InstructionalText.isReaderInstruction(sentence),
              !InstructionalText.isMemoryHook(subject: sentence, sentence: sentence),
              sentence.count >= 35, span.text.utf16.count <= 800,
              sentence.range(of: #"(?i)\b(ignore|instruction|instructions|assistant|system prompt|imagine|suppose|practice|exercise|example)\b|^(?:explain|describe|remember|consider|compare|ask|decide)\b|[\"“”<>={}?!]"#, options: .regularExpression) == nil,
              !QuestionSelfContainment.hasUnresolvedReference(sentence) else { return nil }
        var subject: String, predicate: String, object: String, operation: String, prompt: String
        var qualifier: String?
        var negated = false
        let body = sentence.trimmingCharacters(in: CharacterSet(charactersIn: ".; \n\r\t"))
        if let parts = captures(#"^(.+?) (should not|must not|cannot|can not) (.+)$"#, body) {
            subject = parts[0]; predicate = parts[1]; object = parts[2]
            operation = "constraint"; negated = true
            prompt = "Which restriction applies to \(GeneralClaimExtractor.inline(subject))?"
        } else if let parts = captures(#"^(.+?) (can be|may be) (.+?) when (.+)$"#, body) {
            subject = parts[0]; predicate = parts[1]; object = parts[2]; qualifier = parts[3]
            operation = "constraint"
            prompt = "Under what condition \(parts[1].hasPrefix("can") ? "can" : "may") \(GeneralClaimExtractor.inline(subject)) be \(object)?"
        } else if let parts = captures(#"^(.+?) (avoids|avoid) (.+), but (.+)$"#, body) {
            subject = parts[0]; predicate = parts[1]; object = parts[2] + ", but " + parts[3]
            operation = "tradeoff"
            prompt = "Which trade-off accompanies the use of \(GeneralClaimExtractor.inline(subject))?"
        } else if let parts = captures(#"^(.+?) (helps|help) (.+)$"#, body) {
            subject = parts[0]; predicate = parts[1]; object = parts[2]; operation = "mechanism"
            prompt = "Which effect does \(GeneralClaimExtractor.inline(subject)) help achieve?"
        } else if let parts = captures(#"^(.+?) ((?:also )?(?:destroys|destroy|breaks|break|invalidates|invalidate|preserves|preserve|retains|retain)) (.+)$"#, body) {
            subject = parts[0]; predicate = parts[1]; object = parts[2]; operation = "consequence"
            prompt = "Which consequence follows from \(GeneralClaimExtractor.inline(subject))?"
        } else if let parts = captures(#"^(.+?) (limits|limit) (.+)$"#, body) {
            subject = parts[0]; predicate = parts[1]; object = parts[2]; operation = "constraint"
            prompt = "Which limit does \(GeneralClaimExtractor.inline(subject)) impose?"
        } else {
            let evidence = SemanticEvidenceSpan(documentID: packet.documentID, pageIndex: packet.pageIndex,
                sectionTitle: packet.sectionTitle, sourceText: sentence)
            guard let extracted = GeneralClaimExtractor().extract(sentence, evidence: evidence).first,
                  extracted.intent != .define, extracted.intent != .reconstruction,
                  (extracted.object.split(whereSeparator: \.isWhitespace).count >= 3 ||
                    (extracted.object.split(whereSeparator: \.isWhitespace).count >= 2 && extracted.qualifier != nil)),
                  let realized = QuestionRealizer().realize(extracted) else { return nil }
            subject = extracted.subjectPhrase; predicate = extracted.predicate; object = extracted.object
            qualifier = extracted.qualifier; operation = extracted.intent.rawValue
            prompt = realized.prompt
        }
        let concept = GeneralClaimExtractor.canonical(subject)
        guard QuestionSelfContainment.validConcept(concept),
              subject.split(whereSeparator: \.isWhitespace).count <= 8,
              (object.split(whereSeparator: \.isWhitespace).count >= 3 ||
                (object.split(whereSeparator: \.isWhitespace).count >= 2 && qualifier != nil)),
              subject.range(of: #"(?i)\b(can|may|might|must|should|not|never|no|unless|if|when)\b"#, options: .regularExpression) == nil,
              prompt.count >= 30, prompt.count <= 240,
              QuestionSelfContainment.rejectionReason(prompt: prompt, answer: span.text, concept: concept) == nil else { return nil }
        // Qualifiers remain in the full canonical answer even when a grammar-specific
        // qualifier was not split into a separate field. Negation is never removed.
        if qualifier == nil, let match = captures(#"^.+?\b(when|unless|only if|if|because|provided that|before|after|until)\b (.+)$"#, body) {
            qualifier = match.joined(separator: " ")
        }
        negated = negated || body.range(of: #"(?i)\b(not|never|cannot|without)\b"#, options: .regularExpression) != nil
        let id = StableIdentity.uuid("grounded-v2|\(packet.documentID)|\(packet.fingerprint)|\(packet.pageIndex)|\(span.range.location)|\(span.text)|\(operation)").uuidString
        return GroundedQuestionClaim(id: id, concept: concept, cognitiveOperation: operation,
            relation: operation, predicate: predicate, object: object, qualifier: qualifier, negated: negated,
            documentID: packet.documentID, pageIndex: packet.pageIndex, evidence: span, prompt: prompt)
    }

    private func sentences(_ text: String) -> [String] {
        let pattern = #"[^.!?;]+(?:[.!?](?!\s|$)[^.!?;]+)*[.!?;]?(?:\s|$)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map {
            ns.substring(with: $0.range).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    private func captures(_ pattern: String, _ text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        return (1..<match.numberOfRanges).map { (text as NSString).substring(with: match.range(at: $0)) }
    }
    private func normalized(_ text: String) -> String { CanonicalWhitespaceResolver.normalize(text).lowercased() }
}
