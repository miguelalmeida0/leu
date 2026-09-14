import Foundation

public struct SemanticQuestionCompiler: Sendable {
    public init() {}
    public static let qualityFloor = 0.60

    public func compile(index: SemanticIndex, topicIDs: Set<UUID> = [], analysis: DocumentAnalysis? = nil) -> [LearningQuestion] {
        // Version 4 reindexing supplies claims. Old cached templates cannot bypass realization.
        let truth = index.propositions.filter { $0.isQuizTruth && $0.claim != nil }
        var output: [LearningQuestion] = []
        #if DEBUG
        var generated = 0
        #endif
        var fingerprints = Set<String>()
        for p in truth {
            guard let claim = p.claim, let rendered = QuestionRealizer().realize(claim) else { continue }
            #if DEBUG
            generated += 1
            #endif
            let sameFamily = truth.filter { other in
                other.subjectID != p.subjectID && other.claim?.intent == claim.intent && other.relation == p.relation
            }
            let knownAnswers = Set(truth.filter { $0.subjectID == p.subjectID && $0.relation == p.relation }
                .compactMap { $0.claim.flatMap { QuestionRealizer().realize($0)?.answer } }.map(normalized))
            let alternativeAnswers = sameFamily.compactMap { $0.claim.flatMap { QuestionRealizer().realize($0)?.answer } }
                .filter { !knownAnswers.contains(normalized($0)) }
            if let question = make(p, rendered: rendered, alternatives: alternativeAnswers, topicIDs: topicIDs, reverse: false) {
                if fingerprints.insert(question.stableKey).inserted { output.append(question) }
            }
            // Definition reversal is a distinct retrieval task, not a reversed verb template.
            if claim.intent == .define {
                #if DEBUG
                generated += 1
                #endif
                let reverse = RealizedQuestion(intent: .define, prompt: "Which concept is described as \(claim.object)?",
                                               answer: claim.subject, evidence: p.evidence)
                let alternatives = sameFamily.filter { normalized($0.objectText) != normalized(claim.object) }.compactMap { $0.claim?.subject }
                if let question = make(p, rendered: reverse, alternatives: alternatives, topicIDs: topicIDs, reverse: true),
                   fingerprints.insert(question.stableKey).inserted { output.append(question) }
            }
        }
        output = output.filter { question in
            let reason = FinalMCQAdmission.rejectionReason(question, analysis: analysis)
            #if DEBUG
            if ProcessInfo.processInfo.environment["LEU_UI_DIAGNOSTICS"] == "1" {
                print("[leu-option-admission] path=semantic id=\(question.id) page=\(question.source.pageIndex) words=\(question.options.map { $0.text.split(whereSeparator: \.isWhitespace).count }) result=\(reason ?? "accepted")")
            }
            #endif
            return reason == nil
        }
        let importance = ConceptImportanceModel()
        #if DEBUG
        if ProcessInfo.processInfo.environment["LEU_UI_DIAGNOSTICS"] == "1" {
            print("[leu-integration] questions.compile document=\(index.documentID) generated=\(generated) accepted=\(output.count)")
        }
        #endif
        return output.sorted {
            let a = importance.sourceScore($0, index: index, analysis: analysis)
            let b = importance.sourceScore($1, index: index, analysis: analysis)
            return a == b ? $0.stableKey < $1.stableKey : a > b
        }
    }

    private func make(_ p: SemanticProposition, rendered: RealizedQuestion, alternatives: [String],
                      topicIDs: Set<UUID>, reverse: Bool) -> LearningQuestion? {
        guard let claim = p.claim,
              QuestionSelfContainment.rejectionReason(prompt: rendered.prompt, answer: rendered.answer, concept: claim.subject) == nil else { return nil }
        let correctKey = normalized(rendered.answer)
        var seen: Set<String> = [correctKey]
        let distractors = alternatives.filter {
            !QuestionSelfContainment.hasUnresolvedReference($0) && QuestionOptionQuality.comparable($0, to: rendered.answer) &&
                seen.insert(normalized($0)).inserted
        }
        guard distractors.count >= 2 else { return nil }
        let comparable = distractors.sorted {
            let a = abs($0.count - rendered.answer.count), b = abs($1.count - rendered.answer.count)
            return a == b ? $0 < $1 : a < b
        }
        let selected = Array(comparable.prefix(3))
        guard selected.count >= 2, QuestionOptionQuality.rejectionReason(prompt: rendered.prompt,
            answer: rendered.answer, alternatives: selected) == nil else { return nil }
        var quality = 0.46
        if p.truthClass == .verifiedSource { quality += 0.12 }
        if claim.subject.split(separator: " ").count <= 5 { quality += 0.08 }
        if rendered.answer.split(separator: " ").count >= 3 { quality += 0.08 }
        if claim.qualifier != nil { quality += 0.08 }
        if [.mechanism, .cause, .application, .debugging, .distinguish].contains(claim.intent) { quality += 0.08 }
        if distractors.count >= 3 { quality += 0.04 }
        guard quality >= Self.qualityFloor else { return nil }
        let op = reverse ? "reverseRelationship" : claim.intent.rawValue
        let fingerprint = "\(p.id)|\(op)|v4"
        let options = ([rendered.answer] + selected).sorted {
            StableIdentity.hash64(fingerprint + $0) < StableIdentity.hash64(fingerprint + $1)
        }.map { QuestionOption(id: StableIdentity.uuid(fingerprint + "|" + $0), text: $0) }
        guard let correct = options.first(where: { $0.text == rendered.answer }) else { return nil }
        return LearningQuestion(id: StableIdentity.uuid(fingerprint), stableKey: "semantic|" + fingerprint,
            kind: reverse ? .termMatching : (claim.intent == .define ? .definition : .semanticRelationship),
            prompt: rendered.prompt, options: options, correctOptionID: correct.id,
            source: p.evidence.learningSource, topicIDs: topicIDs, qualityScore: quality,
            semanticFingerprint: fingerprint, propositionID: p.id, semanticOperator: op)
    }

    private func normalized(_ text: String) -> String {
        text.lowercased().trimmingCharacters(in: .punctuationCharacters.union(.whitespacesAndNewlines))
    }
}
