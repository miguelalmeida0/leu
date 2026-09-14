import Foundation

public struct DeterministicQuestionEngine: Sendable {
    public init() {}

    public func generate(from analysis: DocumentAnalysis, topicIDs: Set<UUID> = []) -> [LearningQuestion] {
        let semanticIndex = SemanticCompiler().compile(analysis)
        return SemanticQuestionCompiler().compile(index: semanticIndex, topicIDs: topicIDs, analysis: analysis)
    }

    public func validate(_ question: LearningQuestion) -> Bool {
        guard FinalMCQAdmission.rejectionReason(question) == nil, question.options.count >= 3,
              let correct = question.correctOption,
              !question.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !question.source.sourceText.isEmpty else { return false }
        let normalized = question.options.map { normalize($0.text) }
        guard Set(normalized).count == normalized.count,
              normalized.allSatisfy({ !$0.isEmpty }),
              normalized.filter({ $0 == normalize(correct.text) }).count == 1 else { return false }
        if question.semanticFingerprint != nil { return question.propositionID != nil }
        return false
    }

    private struct DefinitionCandidate {
        let term: String
        let definition: String
        let source: LearningSource
        let score: Double
    }

    private func definitionPool(in analysis: DocumentAnalysis) -> [DefinitionCandidate] {
        analysis.pages.flatMap { page in
            page.segments.compactMap { segment in
                guard segment.kind == .definition || segment.kind == .paragraph,
                      let parts = definitionParts(segment.text) else { return nil }
                let source = LearningSource(documentID: analysis.documentID, pageIndex: page.pageIndex,
                                            sourceText: segment.text, sectionTitle: segment.sectionTitle)
                let complete = parts.definition.count >= 12 && parts.definition.count <= 220
                let pronounPenalty = beginsWithPronoun(parts.definition) ? 0.22 : 0
                let score = (complete ? 0.82 : 0.58) - pronounPenalty
                return DefinitionCandidate(term: parts.term, definition: parts.definition, source: source, score: score)
            }
        }
    }

    private func definitionQuestions(_ pool: [DefinitionCandidate], documentID: UUID,
                                     topicIDs: Set<UUID>) -> [LearningQuestion] {
        guard pool.count >= 3 else { return [] }
        return pool.compactMap { candidate in
            let distractors = pool.filter { $0.term != candidate.term && normalize($0.definition) != normalize(candidate.definition) }
                .sorted { a, b in comparableDistance(a.definition, candidate.definition) < comparableDistance(b.definition, candidate.definition) }
                .prefix(3)
            guard distractors.count >= 2 else { return nil }
            let optionTexts = [candidate.definition] + distractors.map(\.definition)
            return makeQuestion(
                key: "def|\(documentID)|\(candidate.source.pageIndex)|\(candidate.term.lowercased())",
                kind: .definition,
                prompt: "What best describes \(candidate.term)?",
                optionTexts: optionTexts,
                correctText: candidate.definition,
                source: candidate.source,
                topicIDs: topicIDs,
                quality: candidate.score
            )
        }
    }


    private func termMatchingQuestions(_ pool: [DefinitionCandidate], documentID: UUID,
                                       topicIDs: Set<UUID>) -> [LearningQuestion] {
        guard pool.count >= 3 else { return [] }
        return pool.compactMap { candidate in
            let distractors = pool.filter {
                normalize($0.term) != normalize(candidate.term) &&
                normalize($0.definition) != normalize(candidate.definition)
            }
            .sorted { a, b in comparableDistance(a.term, candidate.term) < comparableDistance(b.term, candidate.term) }
            .prefix(3)
            guard distractors.count >= 2 else { return nil }
            return makeQuestion(
                key: "match|\(documentID)|\(candidate.source.pageIndex)|\(candidate.term.lowercased())",
                kind: .termMatching,
                prompt: "Which term matches this source description?\n\n\"\(candidate.definition)\"",
                optionTexts: [candidate.term] + distractors.map(\.term),
                correctText: candidate.term,
                source: candidate.source,
                topicIDs: topicIDs,
                quality: max(0.6, candidate.score - 0.04)
            )
        }
    }

    private func clozeQuestions(_ analysis: DocumentAnalysis, terms: [String],
                                topicIDs: Set<UUID>) -> [LearningQuestion] {
        guard terms.count >= 3 else { return [] }
        var result: [LearningQuestion] = []
        for page in analysis.pages {
            for segment in page.segments where segment.kind == .paragraph || segment.kind == .definition {
                guard segment.text.count >= 35 && segment.text.count <= 240 else { continue }
                guard let answer = terms.first(where: { containsWord(segment.text, $0) }) else { continue }
                guard occurrenceCount(answer, in: segment.text) == 1 else { continue }
                let alternatives = terms.filter { normalize($0) != normalize(answer) && !containsWord(segment.text, $0) }.prefix(3)
                guard alternatives.count >= 2 else { continue }
                let cloze = replaceFirstWord(answer, in: segment.text, with: "_____" )
                let source = LearningSource(documentID: analysis.documentID, pageIndex: page.pageIndex,
                                            sourceText: segment.text, sectionTitle: segment.sectionTitle)
                if let question = makeQuestion(
                    key: "cloze|\(analysis.documentID)|\(page.pageIndex)|\(answer.lowercased())|\(StableIdentity.hash64(segment.text))",
                    kind: segment.kind == .definition ? .fillKeyConcept : .cloze,
                    prompt: "Which term correctly completes the source statement?\n\n\"\(cloze)\"",
                    optionTexts: [answer] + Array(alternatives), correctText: answer,
                    source: source, topicIDs: topicIDs,
                    quality: segment.importance * 0.65 + 0.25
                ) { result.append(question) }
                if result.count >= 40 { return result }
            }
        }
        return result
    }

    private func listQuestions(_ analysis: DocumentAnalysis, terms: [String],
                               topicIDs: Set<UUID>) -> [LearningQuestion] {
        var result: [LearningQuestion] = []
        let corpusTerms = Set(terms.map(normalize))
        for page in analysis.pages {
            for segment in page.segments where segment.text.contains(",") {
                let chunks = segment.text.split(separator: ",").map { cleanListItem(String($0)) }.filter { $0.count >= 2 && $0.count <= 42 }
                guard chunks.count >= 3, let correct = chunks.first else { continue }
                let distractors = terms.filter { term in
                    !chunks.contains(where: { normalize($0) == normalize(term) }) && corpusTerms.contains(normalize(term))
                }.prefix(2)
                guard distractors.count >= 2 else { continue }
                let source = LearningSource(documentID: analysis.documentID, pageIndex: page.pageIndex,
                                            sourceText: segment.text, sectionTitle: segment.sectionTitle)
                if let question = makeQuestion(
                    key: "list|\(analysis.documentID)|\(page.pageIndex)|\(StableIdentity.hash64(segment.text))",
                    kind: .listMembership,
                    prompt: "Which item is explicitly identified in this source list?",
                    optionTexts: [correct] + Array(distractors), correctText: correct,
                    source: source, topicIDs: topicIDs, quality: 0.66
                ) { result.append(question) }
            }
        }
        return result
    }


    private func sourceStatementQuestions(_ analysis: DocumentAnalysis, topicIDs: Set<UUID>) -> [LearningQuestion] {
        let candidates = analysis.pages.flatMap(\.segments).filter { segment in
            (segment.kind == .paragraph || segment.kind == .definition) &&
            segment.text.count >= 32 && segment.text.count <= 190 &&
            !beginsWithPronoun(segment.text)
        }
        guard candidates.count >= 3 else { return [] }
        var result: [LearningQuestion] = []
        for sourceSegment in candidates.prefix(24) {
            let distractors = candidates.filter {
                $0.id != sourceSegment.id && normalize($0.text) != normalize(sourceSegment.text)
            }
            .sorted { a, b in comparableDistance(a.text, sourceSegment.text) < comparableDistance(b.text, sourceSegment.text) }
            .prefix(2)
            guard distractors.count == 2 else { continue }
            let source = LearningSource(documentID: analysis.documentID, pageIndex: sourceSegment.pageIndex,
                                        sourceText: sourceSegment.text, sectionTitle: sourceSegment.sectionTitle)
            let section = sourceSegment.sectionTitle.map { " \"\($0)\"" } ?? ""
            if let question = makeQuestion(
                key: "statement|\(analysis.documentID)|\(sourceSegment.pageIndex)|\(StableIdentity.hash64(sourceSegment.text))",
                kind: .sourceStatement,
                prompt: "Which statement appears in the source section\(section)?",
                optionTexts: [sourceSegment.text] + distractors.map(\.text),
                correctText: sourceSegment.text, source: source, topicIDs: topicIDs,
                quality: min(0.76, 0.58 + sourceSegment.importance * 0.18)
            ) { result.append(question) }
        }
        return result
    }
}
