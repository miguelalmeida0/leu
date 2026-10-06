import Foundation

extension LearningRepository {
    func mergeTopics(_ topics: [LearningTopic], into snapshot: inout LearningSnapshot) {
        for topic in topics where !snapshot.topics.contains(where: { $0.id == topic.id }) { snapshot.topics.append(topic) }
    }

    func ensureObjects(for analysis: DocumentAnalysis, topicIDs: Set<UUID>, in snapshot: inout LearningSnapshot) {
        let currentTexts = Set(analysis.pages.filter(\.isIntelligenceEligible).flatMap { $0.segments.filter { !InstructionalText.excludesFromStudy($0) }.map { "\($0.pageIndex)|\($0.text)" } })
        for index in snapshot.learningObjects.indices where
            snapshot.learningObjects[index].source.documentID == analysis.documentID &&
            snapshot.learningObjects[index].origin == .documentAnalysis {
            let source = snapshot.learningObjects[index].source
            snapshot.learningObjects[index].sourceIsStale = true
            if currentTexts.contains("\(source.pageIndex)|\(source.sourceText)") {
                snapshot.learningObjects[index].sourceIsStale = false
            }
        }
        let existing = Set(snapshot.learningObjects.filter {
            $0.source.documentID == analysis.documentID && $0.origin == .documentAnalysis
        }.map { "\($0.source.pageIndex)|\($0.source.sourceText)" })

        for page in analysis.pages where page.isIntelligenceEligible {
            let primary = page.segments.filter { segment in
                guard !InstructionalText.excludesFromStudy(segment) else { return false }
                return segment.kind == .definition ||
                    (segment.kind == .heading && segment.importance >= 0.78) ||
                    (segment.kind == .paragraph && segment.importance >= 0.54)
            }
            .sorted { lhs, rhs in
                lhs.importance == rhs.importance ? lhs.text.count < rhs.text.count : lhs.importance > rhs.importance
            }
            .prefix(3)

            for segment in primary {
                let key = "\(segment.pageIndex)|\(segment.text)"
                guard !existing.contains(key) else { continue }
                let source = LearningSource(documentID: analysis.documentID, pageIndex: segment.pageIndex,
                                            sourceText: segment.text, sectionTitle: segment.sectionTitle)
                let type: LearningObjectType = segment.kind == .definition ? .definition : .passage
                let title = segment.kind == .heading ? segment.text : conciseTitle(segment)
                let object = LearningObject(id: StableIdentity.uuid("object|\(analysis.documentID)|\(key)"), type: type,
                                            source: source, topicIDs: topicIDs, title: title,
                                            importance: segment.importance, origin: .documentAnalysis)
                snapshot.learningObjects.append(object)
                snapshot.reviewStates[object.id] = ReviewState(learningObjectID: object.id, importance: object.importance)
            }
        }
    }

    func conciseTitle(_ segment: SourceSegment) -> String {
        if let section = segment.sectionTitle, !section.isEmpty { return String(section.prefix(72)) }
        let firstSentence = segment.text.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: true).first.map(String.init) ?? segment.text
        return String(firstSentence.prefix(72))
    }
}
