import Foundation

extension DeterministicQuestionEngine {
    func makeQuestion(key: String, kind: QuestionKind, prompt: String,
                              optionTexts: [String], correctText: String, source: LearningSource,
                              topicIDs: Set<UUID>, quality: Double) -> LearningQuestion? {
        let unique = Array(NSOrderedSet(array: optionTexts.map(cleanOption))) as? [String] ?? optionTexts.map(cleanOption)
        guard unique.count >= 3, let correctIndex = unique.firstIndex(where: { normalize($0) == normalize(correctText) }) else { return nil }
        let order = deterministicOrder(count: unique.count, seed: StableIdentity.hash64(key))
        let orderedTexts = order.map { unique[$0] }
        let options = orderedTexts.enumerated().map { index, text in
            QuestionOption(id: StableIdentity.uuid("option|\(key)|\(index)|\(text)"), text: text)
        }
        guard let orderedCorrect = orderedTexts.firstIndex(where: { normalize($0) == normalize(unique[correctIndex]) }) else { return nil }
        return LearningQuestion(id: StableIdentity.uuid("question|" + key), stableKey: key, kind: kind,
                                prompt: prompt, options: options, correctOptionID: options[orderedCorrect].id,
                                source: source, topicIDs: topicIDs, qualityScore: quality)
    }

    func salientTerms(in analysis: DocumentAnalysis) -> [String] {
        var counts: [String: Int] = [:]
        var display: [String: String] = [:]
        let stop = Set(["that","this","with","from","into","when","then","than","your","have","will","would","should","which","where","what","does","using","used","also","only","more","most","some","each","they","them","their","there","about","after","before","between","through","because","while","been","being"])
        for page in analysis.pages {
            for raw in page.normalizedText.split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "+" && $0 != "#" }) {
                let token = String(raw)
                let key = normalize(token)
                guard key.count >= 4, !stop.contains(key), !key.allSatisfy(\.isNumber) else { continue }
                counts[key, default: 0] += 1
                if display[key] == nil { display[key] = token }
            }
        }
        return counts.filter { $0.value >= 2 }.sorted { a, b in
            a.value == b.value ? a.key < b.key : a.value > b.value
        }.prefix(60).compactMap { display[$0.key] }
    }

    func definitionParts(_ text: String) -> (term: String, definition: String)? {
        for separator in [" is defined as ", " refers to ", " means ", " describes ", " is "] {
            if let range = text.range(of: separator, options: .caseInsensitive) {
                let term = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                let definition = String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                if term.count >= 2, term.count <= 72, definition.count >= 8 { return (term, definition) }
            }
        }
        return nil
    }

    func sourceContainsAnswer(_ question: LearningQuestion) -> Bool {
        guard let correct = question.correctOption else { return false }
        return question.source.sourceText.range(of: correct.text, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    func beginsWithPronoun(_ text: String) -> Bool {
        let first = normalize(text.split(separator: " ").first.map(String.init) ?? "")
        return ["it","this","that","they","these","those","he","she"].contains(first)
    }

    func comparableDistance(_ lhs: String, _ rhs: String) -> Int { abs(lhs.count - rhs.count) }

    func containsWord(_ text: String, _ word: String) -> Bool { occurrenceCount(word, in: text) > 0 }

    func occurrenceCount(_ word: String, in text: String) -> Int {
        wholeWordRanges(word, in: text).count
    }

    func replaceFirstWord(_ word: String, in text: String, with replacement: String) -> String {
        guard let range = wholeWordRanges(word, in: text).first else { return text }
        var copy = text
        copy.replaceSubrange(range, with: replacement)
        return copy
    }

    private func wholeWordRanges(_ word: String, in text: String) -> [Range<String.Index>] {
        guard !word.isEmpty else { return [] }

        var ranges: [Range<String.Index>] = []
        var searchStart = text.startIndex

        while searchStart < text.endIndex,
              let range = text.range(
                of: word,
                options: .caseInsensitive,
                range: searchStart..<text.endIndex
              ) {
            let leftIsWord: Bool
            if range.lowerBound == text.startIndex {
                leftIsWord = false
            } else {
                let character = text[text.index(before: range.lowerBound)]
                leftIsWord = character.isLetter || character.isNumber
            }

            let rightIsWord: Bool
            if range.upperBound == text.endIndex {
                rightIsWord = false
            } else {
                let character = text[range.upperBound]
                rightIsWord = character.isLetter || character.isNumber
            }

            if !leftIsWord && !rightIsWord {
                ranges.append(range)
            }

            searchStart = range.upperBound
        }

        return ranges
    }

    func deterministicOrder(count: Int, seed: UInt64) -> [Int] {
        var values = Array(0..<count)
        guard count > 1 else { return values }
        var state = seed == 0 ? 0x9e3779b97f4a7c15 : seed
        for i in stride(from: count - 1, through: 1, by: -1) {
            state ^= state << 13; state ^= state >> 7; state ^= state << 17
            let j = Int(state % UInt64(i + 1)); values.swapAt(i, j)
        }
        return values
    }

    func cleanListItem(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
    }
    func cleanOption(_ text: String) -> String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
