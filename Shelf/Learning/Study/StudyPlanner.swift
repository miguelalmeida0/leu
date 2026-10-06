import ShelfCore
import SwiftUI

/// The top of Study (09b): finish the sentence, or pick another way to spend the minutes,
/// read what will happen next, and start. "Explain it my way" opens In your own words on
/// a passage the reader has been near, with the snow globe waiting.
@MainActor
struct StudyPlanner: View {
    @Bindable var model: LearningModel
    @State private var way: StudyWay = .learn
    @State private var topicID: UUID?
    @State private var minutes = 10
    @State private var passageID: String?
    @State private var passages: [StudyPassage] = []
    @State private var teaching: ReaderIntelligenceModel?
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var typeSize

    private var wide: Bool { sizeClass == .regular && !typeSize.isAccessibilitySize }
    private var passage: StudyPassage? { passages.first { $0.id == passageID } ?? passages.first }

    var body: some View {
        VStack(alignment: .leading, spacing: wide ? 34 : 24) {
            VStack(alignment: .leading, spacing: wide ? 18 : 12) {
                eyebrow("Study, any way you like")
                StudySentence(way: $way, topicID: $topicID, minutes: $minutes, passageID: $passageID,
                              topics: model.visibleTopics, passages: passages, large: wide)
            }
            VStack(alignment: .leading, spacing: 12) {
                eyebrow("Or spend these minutes another way")
                StudyWaysStrip(way: $way, ways: availableWays, minutes: minutes, wide: wide)
            }
            StudyNextPanel(way: way, steps: steps, startTitle: startTitle, ready: ready, reason: reason,
                           wide: wide, globe: way == .explain, start: start)
        }
        .task(id: model.snapshot.timeline.count + model.snapshot.analyses.count) { passages = StudyPassage.recent(in: model) }
        .onChange(of: passages.isEmpty) { _, empty in if empty && way == .explain { way = .learn } }
        .sheet(item: $teaching) { teach in TeachLeuSheet(model: teach) }
    }

    private var availableWays: [StudyWay] { StudyWay.allCases.filter { $0 != .explain || !passages.isEmpty } }

    private func eyebrow(_ text: String) -> some View {
        Text(text.uppercased())
            .font(LeuDesign.eyebrow(11))
            .tracking(LeuDesign.eyebrowTracking)
            .foregroundStyle(LeuDesign.eyebrowOnFelt)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: What happens next, in plain words

    private var subject: String { model.visibleTopics.first { $0.id == topicID }?.name ?? "everything you've read" }

    private var steps: [String] {
        switch way {
        case .learn:
            ["Leu picks questions from \(subject), a few at a time.",
             "Answer from memory. A wrong answer opens the page that settles it.",
             "What you get right comes back later, spaced out so it sticks."]
        case .recall:
            ["You see a prompt and bring the answer back before looking.",
             "Then the page itself, so you can check what you remembered.",
             "Whatever slipped comes back sooner."]
        case .interview:
            ["Leu asks \(StudyWay.interviewQuestions(minutes: minutes)) open questions about \(subject).",
             "Answer at your own pace, in your own words.",
             "Every question links to the line it came from."]
        case .explain:
            ["You explain the bit about \(passage?.bit ?? "this page") in your own words.",
             passage.map { "Leu listens for the \(TeachGlobeProgress.ideaWord($0.ideaCount)) page \($0.page) makes, and lights a window for each." }
                ?? "Leu listens for the ideas the page makes, and lights a window for each.",
             "Anything you skipped is shown in the page's own words, a tap from the exact line."]
        }
    }

    private var startTitle: String {
        switch way {
        case .learn, .interview: "Start, about \(minutes) minutes"
        case .recall: "Start remembering"
        case .explain: "Start explaining"
        }
    }

    private var hasMaterial: Bool {
        model.snapshot.studyObjects.contains { object in topicID.map { object.topicIDs.contains($0) } ?? true }
    }

    private var ready: Bool { way == .explain ? passage != nil : hasMaterial }

    private var reason: String? {
        guard !ready else { return nil }
        if model.isIndexing { return "Preparing study material from your books…" }
        return way == .explain ? "Read a page or two first, so there is something to explain." : "Nothing to study on this subject yet. Try anything you've read."
    }

    private func start() {
        ShelfHaptics.shared.play(.selectionChanged)
        StudyInteractionTrace.record("study.planner.start way=\(way.rawValue)")
        switch way {
        case .learn: model.startSession(topicID: topicID, minutes: minutes, mode: .learn)
        case .recall: model.startActiveRecall(topicID: topicID)
        case .interview: model.startInterview(topicID: topicID, questionCount: StudyWay.interviewQuestions(minutes: minutes))
        case .explain:
            if let passage { teaching = ReaderIntelligenceModel(learning: model, source: passage.source) }
        }
    }
}

extension ReaderIntelligenceModel: Identifiable {
    var id: ObjectIdentifier { ObjectIdentifier(self) }
}
