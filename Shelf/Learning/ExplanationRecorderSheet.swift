import SwiftUI
import AVFoundation
import ShelfCore

@MainActor
struct ExplanationRecorderSheet: View {
    @Bindable var model: LearningModel
    let object: LearningObject
    @Environment(\.dismiss) private var dismiss
    @State private var recorder = ExplanationRecorder()
    @State private var currentURL: URL?
    @State private var completedDuration: TimeInterval?
    @State private var selfRating: ExplanationRecording.SelfRating?
    @State private var player: AVAudioPlayer?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Explain this concept in your own words.")
                        .font(LearningTokens.Typography.title)
                    Text(object.title).foregroundStyle(ShelfTheme.secondary)
                    recordingControl
                    if let completedDuration { ratingSection(duration: completedDuration) }
                    previousRecordings
                }.padding(ShelfTheme.gutter)
            }
            .background(ShelfTheme.background).navigationTitle("Explain").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { if recorder.isRecording { _ = recorder.stop() }; dismiss() } } }
        }.preferredColorScheme(.dark).tint(ShelfTheme.accent)
            .leuDialog("Recording", isPresented: Binding(get: { recorder.errorMessage != nil }, set: { if !$0 { recorder.errorMessage = nil } })) {
                Button("OK") { recorder.errorMessage = nil }
            } message: { Text(recorder.errorMessage ?? "") }
    }

    private var recordingControl: some View {
        VStack(spacing: 16) {
            Text(format(recorder.isRecording ? recorder.elapsed : (completedDuration ?? 0)))
                .font(.system(size: 42, weight: .light, design: .monospaced))
            Button {
                Task { await toggleRecording() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: recorder.isRecording ? "stop.fill" : "record.circle")
                    Text(recorder.isRecording ? "Stop recording" : "Start recording")
                }.frame(maxWidth: .infinity)
            }.buttonStyle(ShelfButtonStyle(filled: !recorder.isRecording))
                .accessibilityIdentifier("explanation-record-control")
        }.padding(.vertical, 12)
    }

    private func ratingSection(duration: TimeInterval) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How did that explanation feel?").font(.headline)
            HStack(spacing: 8) {
                ForEach(ExplanationRecording.SelfRating.allCases, id: \.self) { rating in
                    Button(rating.rawValue.capitalized) { selfRating = rating }
                        .buttonStyle(ShelfButtonStyle(filled: selfRating == rating)).frame(maxWidth: .infinity)
                }
            }
            Button("Save explanation") { save(duration: duration) }
                .buttonStyle(ShelfButtonStyle(filled: true)).disabled(selfRating == nil)
        }
    }

    @ViewBuilder
    private var previousRecordings: some View {
        let recordings = model.snapshot.recordings.filter { $0.learningObjectID == object.id }.sorted { $0.createdAt > $1.createdAt }
        if !recordings.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Previous explanations").font(LearningTokens.Typography.compactTitle)
                ForEach(recordings) { recording in
                    Button { play(recording) } label: {
                        HStack { Image(systemName: "play.circle"); VStack(alignment: .leading) { Text(recording.createdAt.formatted(date: .abbreviated, time: .shortened)); Text("\(format(recording.duration)) · \(recording.selfRating?.rawValue.capitalized ?? "Unrated")").font(.caption).foregroundStyle(ShelfTheme.secondary) }; Spacer() }
                            .foregroundStyle(ShelfTheme.text).padding(.vertical, 7)
                    }.buttonStyle(.plain)
                    Divider().overlay(ShelfTheme.line)
                }
            }
        }
    }

    private func toggleRecording() async {
        if recorder.isRecording {
            completedDuration = recorder.stop(); model.play(.recordingStopped)
        } else {
            let url = model.newRecordingURL()
            currentURL = url
            // Confirm before AVAudioRecorder begins so the phone never injects a haptic into captured audio.
            model.play(.recordingStarted)
            if !(await recorder.start(to: url)) {
                ShelfHaptics.shared.cancelRecordingGuard()
                currentURL = nil
            }
        }
    }
    private func save(duration: TimeInterval) {
        guard let url = currentURL else { return }
        Task {
            do {
                try await model.saveRecording(object: object, url: url, duration: duration, rating: selfRating)
                completedDuration = nil; selfRating = nil; currentURL = nil
            } catch { model.errorMessage = error.localizedDescription }
        }
    }
    private func play(_ recording: ExplanationRecording) {
        let url = model.recordingURL(filename: recording.filename)
        player = try? AVAudioPlayer(contentsOf: url); player?.play()
    }
    private func format(_ seconds: TimeInterval) -> String {
        String(format: "%02d:%02d", Int(seconds) / 60, Int(seconds) % 60)
    }
}
