import SwiftUI
import ShelfCore

@MainActor
struct LearnTodayScreen: View {
    @Bindable var model: LearningModel
    @Bindable var knowledge: KnowledgeModel
    @State private var selectedTopicID: UUID?
    @State private var selectedMinutes = 10
    @State private var composerExpanded = false
    @State var showingRecallSetup = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let onOpenProgress: () -> Void

    var body: some View {
        Group {
            if model.sessionSummaryPresented { SessionCompleteView(model: model) }
            else if model.activeSession != nil { StudySessionScreen(model: model) }
            else { landing }
        }
        .task { await model.bootstrap() }
        .sheet(isPresented: $showingRecallSetup) { ActiveRecallSetupSheet(model: model) }
        .leuDialog("Leu needs your attention", isPresented: Binding(
            get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
                Button("OK") { model.errorMessage = nil }
            } message: { Text(model.errorMessage ?? "") }
    }

    private var landing: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                LearnSecondaryModes(model: model, knowledge: knowledge) {
                    onOpenProgress()
                    ShelfHaptics.shared.play(.selectionChanged)
                }
                VStack(alignment: .leading, spacing: 16) {
                    continueField
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(spacing: 12) { fadingSection; blindSpotsSection }
                    } else {
                        HStack(alignment: .top, spacing: 12) {
                            fadingSection
                            blindSpotsSection.padding(.top, 28)
                        }
                    }
                }
                labsSection
                if model.isIndexing { indexingStatus }
                if let notice = model.notice {
                    Text(notice).font(.callout).foregroundStyle(ShelfTheme.secondary)
                        .accessibilityIdentifier("learning-index-notice")
                }
            }
            .padding(.horizontal, ShelfTheme.gutter)
            .padding(.top, 24).padding(.bottom, 42)
            .frame(maxWidth: 760).frame(maxWidth: .infinity)
        }
        .clipped()
        .background(ShelfTheme.background)
        .background { UITestFrameProbe(identifier: "learn-screen-frame") }
        .accessibilityIdentifier("learn-screen")
        .onAppear { StudyInteractionTrace.record("surface.study-landing.appeared") }
    }

    private var header: some View {
        Text("Study")
            .leuScaledFont(34, weight: .bold, relativeTo: .largeTitle)
            .foregroundStyle(LeuDesign.textPrimary)
            .accessibilityAddTraits(.isHeader)
    }

    private var continueField: some View {
        VStack(alignment: .leading, spacing: 20) {
            continueSection
            Rectangle().fill(LeuDesign.studyContinueSecondary).frame(height: 1)
            Button { composerExpanded.toggle() } label: {
                HStack {
                    Label("Build a study session", systemImage: "slider.horizontal.3")
                    Spacer(minLength: 8)
                    Image(systemName: composerExpanded ? "chevron.up" : "chevron.down")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LeuDesign.studyContinueForeground)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("study-session-options")
            .accessibilityValue(composerExpanded ? "Expanded" : "Collapsed")
            if composerExpanded { sessionComposer }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LeuDesign.studyContinueSurface, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("study-continue-field")
    }

    private var sessionComposer: some View {
        VStack(alignment: .leading, spacing: 22) {
            topicPicker
            VStack(alignment: .leading, spacing: 22) {
                timePicker
                startButton
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("study-time-and-start")
        }
    }

    private var topicPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SUBJECT")
                .font(.caption.weight(.semibold)).tracking(1.8).foregroundStyle(LeuDesign.studyContinueSecondary)
            LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(model.visibleTopics) { topic in topicButton(topic) }
                Button {
                    selectedTopicID = nil
                    ShelfHaptics.shared.play(.selectionChanged)
                } label: {
                    topicLabel("Other", subtitle: nil, selected: selectedTopicID == nil)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("learn-topic-other")
            }
        }
    }

    private func topicButton(_ topic: LearningTopic) -> some View {
        Button {
            selectedTopicID = topic.id
            ShelfHaptics.shared.play(.selectionChanged)
        } label: {
            let state = model.mastery(topic: topic).state
            topicLabel(topic.name, subtitle: masteryLabel(state), selected: selectedTopicID == topic.id)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("learn-topic-\(topic.name.lowercased())")
    }

    private func topicLabel(_ title: String, subtitle: String?, selected: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.medium))
                if let subtitle {
                    Text(subtitle.uppercased()).font(.caption2.weight(.semibold)).tracking(1.1)
                        
                }
            }
            Spacer(minLength: 8)
            if selected { Image(systemName: "checkmark").font(.caption.weight(.bold)) }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 55)
        .foregroundStyle(selected ? LeuDesign.onSignal : LeuDesign.textPrimary)
        .background(selected ? ShelfTheme.olive : ShelfTheme.surface, in: RoundedRectangle(cornerRadius: ShelfTheme.smallRadius))
        .overlay { RoundedRectangle(cornerRadius: ShelfTheme.smallRadius).stroke(selected ? ShelfTheme.olive : LeuDesign.separator, lineWidth: 0.7) }
    }

    private func masteryLabel(_ state: MasteryState) -> String {
        switch state {
        case .new: return "New"
        case .learning: return "Learning"
        case .strengthening: return "Strengthening"
        case .durable: return "Durable"
        case .due: return "Due"
        case .fading: return "Fading"
        }
    }

    private var timePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TIME")
                .font(.caption.weight(.semibold)).tracking(1.8).foregroundStyle(LeuDesign.studyContinueSecondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: dynamicTypeSize.isAccessibilitySize ? 2 : 4), spacing: 8) {
                ForEach([5, 10, 20, 30], id: \.self) { minutes in
                    let selected = selectedMinutes == minutes
                    Button {
                        selectedMinutes = minutes
                        ShelfHaptics.shared.play(.selectionChanged)
                    } label: {
                        VStack(spacing: 1) {
                            Text("\(minutes)").leuScaledFont(21, weight: .medium, design: .serif).monospacedDigit()
                            Text("MIN").font(.caption2.weight(.semibold)).tracking(1.2)
                        }
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .foregroundStyle(selected ? LeuDesign.onSignal : LeuDesign.textPrimary)
                        .background(selected ? ShelfTheme.action : ShelfTheme.surface,
                                    in: RoundedRectangle(cornerRadius: ShelfTheme.smallRadius))
                        .overlay { RoundedRectangle(cornerRadius: ShelfTheme.smallRadius).stroke(selected ? ShelfTheme.action : LeuDesign.separator, lineWidth: 0.7) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(minutes) minutes")
                }
            }
        }
    }

    private var startButton: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                model.startSession(topicID: selectedTopicID, minutes: selectedMinutes, mode: .learn)
            } label: {
                HStack {
                    Text("Start study session").fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    if !dynamicTypeSize.isAccessibilitySize { Text("~\(selectedMinutes) min").font(.callout.monospacedDigit()) }
                    Image(systemName: "arrow.right")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(ShelfButtonStyle(filled: true))
            .accessibilityIdentifier("start-learning-session")
            .disabled(!hasStudyMaterial)

            if !hasStudyMaterial {
                Text(model.isIndexing ? "Preparing source-bound study material…" : "No reliable study material matches this subject yet.")
                    .font(.footnote).foregroundStyle(LeuDesign.studyContinueSecondary)
            }
        }
    }

    private var hasStudyMaterial: Bool {
        model.snapshot.studyObjects.contains { object in
            selectedTopicID.map { object.topicIDs.contains($0) } ?? true
        }
    }

    private var indexingStatus: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(model.indexingLabel ?? "Preparing study material").font(.callout)
                Spacer()
                Text("\(Int(model.indexingProgress * 100))%").monospacedDigit()
            }
            ProgressView(value: model.indexingProgress).tint(ShelfTheme.olive)
        }
        .foregroundStyle(ShelfTheme.secondary)
    }

    private var labsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("RECONSTRUCTION LABS")
                .font(.caption.weight(.bold)).tracking(1.4)
                .foregroundStyle(LeuDesign.studyLabsSecondary)
            Text("Rebuild a system from memory.")
                .font(.title2.weight(.bold))
                .foregroundStyle(LeuDesign.studyLabsForeground)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 0) {
                ForEach(Array(LabCatalog.all().enumerated()), id: \.element.id) { index, lab in
                    Button { model.activeLab = lab } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(String(format: "%02d", index + 1))
                                .font(.callout.monospacedDigit().weight(.semibold))
                                .foregroundStyle(LeuDesign.signal)
                            Text(lab.title).font(.body.weight(.medium))
                                .foregroundStyle(LeuDesign.studyLabsForeground)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.right").font(.callout)
                                .foregroundStyle(LeuDesign.studyLabsSecondary)
                        }
                        .padding(.vertical, 15)
                        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("study-lab-" + lab.id.uuidString)
                    if index < LabCatalog.all().count - 1 {
                        Rectangle().fill(LeuDesign.separator).frame(height: 0.75)
                    }
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LeuDesign.studyLabsSurface, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("study-labs-field")
        .sheet(item: $model.activeLab) { lab in LabScreen(lab: lab) }
    }
}
