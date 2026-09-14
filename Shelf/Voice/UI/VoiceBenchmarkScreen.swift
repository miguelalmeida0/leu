#if DEBUG
import SwiftUI
import AVFoundation
import ShelfCore

@MainActor
struct VoiceBenchmarkScreen: View {
    @State private var sampleIndex = 0
    @State private var voiceID = ""
    @State private var rate = 1.0
    @State private var status = "Choose a voice to play the selected sample."
    @State private var apple = AppleSpeechEngine()
    @State private var neural = SupertonicSpeechEngine()
    @State private var audio = AudioSessionCoordinator()
    private var voices: [VoiceDescriptor] { VoiceCatalog().voices() }
    private var synthesisSpeed: Double { max(0.82, min(1.4, rate)) }
    private var raw: String { VoiceBenchmarkCorpus.samples[sampleIndex] }
    private var paragraph: SpokenParagraph? {
        let kind: SpeechBlockKind = raw.hasPrefix("const ") || raw.hasPrefix("SELECT ") ? .code : .prose
        let plan = SpeechCompiler().compile(document: SpeechDocument(blocks: [SpeechInputBlock(pageIndex: 0, kind: kind, text: raw)]))
        return SpeechParagraphBuilder().paragraph(from: plan.segments, startingAt: 0)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Same sample · quick A/B") {
                    Picker("Backend / actual voice", selection: $voiceID) {
                        ForEach(voices) { voice in Text("Apple · \(voice.name) · \(voice.quality.title)").tag(voice.id) }
                        Text("Supertonic 3 · F1").tag("supertonic")
                    }
                    Text("Rate multiplier: \(rate, specifier: "%.2f")×")
                    Slider(value: $rate, in: 0.8...1.4, step: 0.05)
                    HStack {
                        Button("Replay") { play() }.frame(minHeight: 44)
                        Spacer()
                        Button("Stop") { stop(); status = "Stopped" }.frame(minHeight: 44)
                    }
                    Text(status).font(.footnote)
                    if voiceID == "supertonic" {
                        Text("Supertonic 3 · F1 · model-defined sample rate · actual speed \(synthesisSpeed, specifier: "%.2f")×")
                    } else if let voice = voices.first(where: { $0.id == voiceID }) {
                        Text("Apple · \(voice.name) · \(voice.quality.title) · \(voice.language)")
                        Text("AVSpeech rate: \(Double(AVSpeechUtteranceDefaultSpeechRate) * rate, specifier: "%.3f") · pitch 1.0")
                    }
                }
                Section("Raw source") { Text(raw).textSelection(.enabled) }
                Section("Normalized spoken source") { Text(paragraph?.spokenText ?? "No speakable text").textSelection(.enabled) }
                Section("\(VoiceBenchmarkCorpus.samples.count) samples · tap to switch and play") {
                    ForEach(Array(VoiceBenchmarkCorpus.samples.enumerated()), id: \.offset) { index, text in
                        Button { sampleIndex = index; play() } label: {
                            HStack { Text("\(index + 1). \(text)"); if index == sampleIndex { Image(systemName: "checkmark") } }
                        }
                    }
                }
            }
            .navigationTitle("Voice benchmark")
            .onAppear {
                voiceID = voices.first?.id ?? ""
                apple.onStarted = { status = "Playing Apple voice" }
                neural.onStarted = { status = "Playing Supertonic" }
                apple.onFinished = { status = "Finished"; audio.deactivate() }
                neural.onFinished = { status = "Finished"; audio.deactivate() }
                neural.onCancelled = { status = "Supertonic stopped or failed; no automatic backend substitution." }
            }
            .onChange(of: voiceID) { _, _ in play() }
            .onDisappear { stop() }
        }
    }

    private func stop() { _ = apple.stop(); _ = neural.stop(); audio.deactivate() }
    private func play() {
        stop()
        guard let paragraph else { status = "No speakable text"; return }
        if voiceID == "supertonic" {
            guard neural.isAvailable, var segment = paragraph.sentences.first?.segment else {
                status = "Supertonic assets are not installed. Use the existing Settings installation action first."; return
            }
            segment.spokenText = paragraph.spokenText
            status = "Synthesizing Supertonic 3 · F1…"; audio.activate(); neural.speak(segment, userSpeed: rate)
        } else {
            guard let voice = AVSpeechSynthesisVoice(identifier: voiceID) else { status = "Selected Apple voice is unavailable."; return }
            audio.activate(); apple.speak(paragraph, voice: voice, userSpeed: rate)
        }
    }
}
#endif
