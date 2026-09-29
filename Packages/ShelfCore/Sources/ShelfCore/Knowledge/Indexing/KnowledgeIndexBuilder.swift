import Foundation

public struct KnowledgeIndexBuild: Sendable {
    public var records: [KnowledgeIndexRecord]
    public var bindings: [PassageConceptBinding]
    public init(records: [KnowledgeIndexRecord], bindings: [PassageConceptBinding]) {
        self.records = records; self.bindings = bindings
    }
}

public struct KnowledgeIndexBuilder: Sendable {
    private let tokenizer = TechnicalTokenizer()
    public init() {}

    public func build(passages: [KnowledgePassage], concepts: [KnowledgeConcept], aliases: [ConceptAlias]) -> KnowledgeIndexBuild {
        let aliasMap = aliases.reduce(into: [UUID: [String]]()) { result, alias in
            result[alias.conceptID, default: []].append(alias.value)
        }
        var records: [KnowledgeIndexRecord] = []
        var bindings: [PassageConceptBinding] = []
        records.reserveCapacity(passages.count)
        for passage in passages where passage.isAvailable {
            let terms = tokenizer.termCounts(in: passage.text)
            let phrases = tokenizer.phraseCounts(in: passage.text)
            let headingTerms = Set(tokenizer.tokens(in: passage.sectionTitle ?? ""))
            let haystack = canonical(passage.text + " " + (passage.sectionTitle ?? ""))
            var conceptIDs = Set<UUID>()
            for concept in concepts {
                let candidates = aliasMap[concept.id, default: []]
                if candidates.contains(where: { aliasMatches($0, in: haystack) }) {
                    conceptIDs.insert(concept.id)
                    bindings.append(PassageConceptBinding(passageID: passage.id, conceptID: concept.id, source: .detected))
                }
            }
            records.append(KnowledgeIndexRecord(passageID: passage.id, documentID: passage.documentID,
                termCounts: terms, phraseCounts: phrases, headingTerms: headingTerms,
                conceptIDs: conceptIDs, tokenCount: max(1, tokenizer.tokens(in: passage.text).count)))
        }
        return KnowledgeIndexBuild(records: records, bindings: bindings)
    }

    private func aliasMatches(_ alias: String, in haystack: String) -> Bool {
        let needle = canonical(alias)
        guard needle.count >= 2 else { return false }
        if needle.contains(" ") || needle.contains(".") || needle.contains("/") || needle.contains("-") {
            return haystack.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
        return containsStandaloneToken(needle, in: haystack)
    }

    private func containsStandaloneToken(_ needle: String, in haystack: String) -> Bool {
        var start = haystack.startIndex
        while start < haystack.endIndex,
              let range = haystack.range(of: needle, range: start..<haystack.endIndex) {
            let leftIsToken = range.lowerBound > haystack.startIndex &&
                isTokenCharacter(haystack[haystack.index(before: range.lowerBound)])
            let rightIsToken = range.upperBound < haystack.endIndex &&
                isTokenCharacter(haystack[range.upperBound])
            if !leftIsToken && !rightIsToken { return true }
            start = range.upperBound
        }
        return false
    }

    private func isTokenCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_" || character == "$"
    }

    private func canonical(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: "\n", with: " ")
    }
}
