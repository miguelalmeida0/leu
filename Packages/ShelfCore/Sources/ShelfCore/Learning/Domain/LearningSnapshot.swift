import Foundation

public struct LearningSnapshot: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var analyses: [UUID: DocumentAnalysis]
    public var semanticIndexes: [UUID: SemanticIndex]
    public var topics: [LearningTopic]
    public var manualDocumentTopics: [UUID: Set<UUID>]
    public var learningObjects: [LearningObject]
    public var questions: [LearningQuestion]
    public var reviewStates: [UUID: ReviewState]
    public var attempts: [LearningAttempt]
    public var confidenceRecords: [ConfidenceRecord]
    public var relationships: [LearningRelationship]
    public var trails: [LearningTrail]
    public var masks: [DiagramMask]
    public var recordings: [ExplanationRecording]
    public var sessions: [StudySession]
    public var timeline: [LearningTimelineEvent]
    public var emotionalCheckIns: [EmotionalCheckIn]
    public var emotionalCheckInPreference: EmotionalCheckInPreference
    public var resumeStudyContext: ResumeStudyContext?
    public var lensUsage: [String: Int]
    public var understandingAttempts: [UnderstandingAttempt] = []
    public var understandingEvents: [UnderstandingEvent] = []
    public var studyObjects: [LearningObject] {
        learningObjects.filter { object in
            guard object.sourceIsStale != true else { return false }
            guard let analysis = analyses[object.source.documentID] else { return true }
            if let version = analysis.extractionVersion, version < SourceExtractionVersion.current { return false }
            guard analysis.pages.first(where: { $0.pageIndex == object.source.pageIndex })?.isIntelligenceEligible != false else { return false }
            guard let canonical = analysis.pages.first(where: { $0.pageIndex == object.source.pageIndex })?.canonicalText else { return true }
            let quote = object.source.sourceText.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            return !quote.isEmpty && canonical.split(whereSeparator: \.isWhitespace).joined(separator: " ").contains(quote)
        }
    }

    public init(schemaVersion: Int = 1, analyses: [UUID: DocumentAnalysis] = [:],
                semanticIndexes: [UUID: SemanticIndex] = [:],
                topics: [LearningTopic] = [], manualDocumentTopics: [UUID: Set<UUID>] = [:],
                learningObjects: [LearningObject] = [], questions: [LearningQuestion] = [],
                reviewStates: [UUID: ReviewState] = [:], attempts: [LearningAttempt] = [],
                confidenceRecords: [ConfidenceRecord] = [],
                relationships: [LearningRelationship] = [], trails: [LearningTrail] = [],
                masks: [DiagramMask] = [], recordings: [ExplanationRecording] = [],
                sessions: [StudySession] = [], timeline: [LearningTimelineEvent] = [],
                emotionalCheckIns: [EmotionalCheckIn] = [],
                emotionalCheckInPreference: EmotionalCheckInPreference = .on,
                resumeStudyContext: ResumeStudyContext? = nil, lensUsage: [String: Int] = [:]) {
        self.schemaVersion = schemaVersion; self.analyses = analyses; self.semanticIndexes = semanticIndexes
        self.topics = topics; self.manualDocumentTopics = manualDocumentTopics; self.learningObjects = learningObjects
        self.questions = questions; self.reviewStates = reviewStates; self.attempts = attempts
        self.confidenceRecords = confidenceRecords; self.relationships = relationships; self.trails = trails
        self.masks = masks; self.recordings = recordings; self.sessions = sessions; self.timeline = timeline
        self.emotionalCheckIns = emotionalCheckIns; self.emotionalCheckInPreference = emotionalCheckInPreference
        self.resumeStudyContext = resumeStudyContext
        self.lensUsage = lensUsage
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, analyses, semanticIndexes, topics, manualDocumentTopics, learningObjects, questions
        case reviewStates, attempts, confidenceRecords, relationships, trails, masks, recordings, sessions, timeline
        case emotionalCheckIns, emotionalCheckInPreference, resumeStudyContext, lensUsage
        case understandingAttempts, understandingEvents
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        analyses = try c.decodeIfPresent([UUID: DocumentAnalysis].self, forKey: .analyses) ?? [:]
        semanticIndexes = try c.decodeIfPresent([UUID: SemanticIndex].self, forKey: .semanticIndexes) ?? [:]
        topics = try c.decodeIfPresent([LearningTopic].self, forKey: .topics) ?? []
        manualDocumentTopics = try c.decodeIfPresent([UUID: Set<UUID>].self, forKey: .manualDocumentTopics) ?? [:]
        learningObjects = try c.decodeIfPresent([LearningObject].self, forKey: .learningObjects) ?? []
        questions = try c.decodeIfPresent([LearningQuestion].self, forKey: .questions) ?? []
        reviewStates = try c.decodeIfPresent([UUID: ReviewState].self, forKey: .reviewStates) ?? [:]
        attempts = try c.decodeIfPresent([LearningAttempt].self, forKey: .attempts) ?? []
        confidenceRecords = try c.decodeIfPresent([ConfidenceRecord].self, forKey: .confidenceRecords) ?? []
        relationships = try c.decodeIfPresent([LearningRelationship].self, forKey: .relationships) ?? []
        trails = try c.decodeIfPresent([LearningTrail].self, forKey: .trails) ?? []
        masks = try c.decodeIfPresent([DiagramMask].self, forKey: .masks) ?? []
        recordings = try c.decodeIfPresent([ExplanationRecording].self, forKey: .recordings) ?? []
        sessions = try c.decodeIfPresent([StudySession].self, forKey: .sessions) ?? []
        timeline = try c.decodeIfPresent([LearningTimelineEvent].self, forKey: .timeline) ?? []
        emotionalCheckIns = try c.decodeIfPresent([EmotionalCheckIn].self, forKey: .emotionalCheckIns) ?? []
        emotionalCheckInPreference = try c.decodeIfPresent(EmotionalCheckInPreference.self, forKey: .emotionalCheckInPreference) ?? .on
        resumeStudyContext = try c.decodeIfPresent(ResumeStudyContext.self, forKey: .resumeStudyContext)
        lensUsage = try c.decodeIfPresent([String: Int].self, forKey: .lensUsage) ?? [:]
        understandingAttempts = try c.decodeIfPresent([UnderstandingAttempt].self, forKey: .understandingAttempts) ?? []
        understandingEvents = try c.decodeIfPresent([UnderstandingEvent].self, forKey: .understandingEvents) ?? []
    }
}
