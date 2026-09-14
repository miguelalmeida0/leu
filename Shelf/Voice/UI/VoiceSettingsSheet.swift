import SwiftUI
import Foundation
import ShelfCore

@MainActor
struct VoiceSettingsSheet: View {
    @Bindable var speech: ReaderSpeechController
    @State private var pronunciationDisplay = ""
    @State private var pronunciationSpoken = ""

    var body: some View {
        ShelfSheet(title: "Voice & listening") {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    intro
                    VoiceQualityNotice(compactOnly: speech.usesAppleVoices && !speech.availableVoices.contains { $0.quality != .standard })
                    voices
                    speed
                    pronunciation
                    diagnostics
                }
                .padding(ShelfTheme.gutter).frame(maxWidth: 720).frame(maxWidth: .infinity)
            }
        }
        .accessibilityIdentifier("voice-settings")
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("TECHNICAL READING").font(.caption.weight(.bold)).tracking(1.7).foregroundStyle(ShelfTheme.accent)
            Text("Leu speaks the material, not the PDF artifacts.").font(.system(.title2, design: .serif))
            Text("Your PDF stays unchanged. Leu quietly cleans extraction noise and compiles symbols, code and technical terms into a separate spoken representation.")
                .font(.callout).foregroundStyle(ShelfTheme.secondary)
        }
    }

    private var voices: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Voice").font(.headline)
            Button("Automatic · best installed voice") { speech.selectAutomaticVoice() }.frame(minHeight: 44)
            ForEach(speech.availableVoices.prefix(16)) { voice in
                HStack(spacing: 12) {
                    Button { speech.selectVoice(voice) } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(voice.name).foregroundStyle(ShelfTheme.text)
                            Text("\(voice.quality.title) · \(voice.language)").font(.caption).foregroundStyle(ShelfTheme.secondary)
                        }
                        Spacer()
                        if speech.selectedVoice?.id == voice.id { Image(systemName: "checkmark").foregroundStyle(ShelfTheme.accent) }
                    }.buttonStyle(.plain)
                    Button("Preview") { speech.previewVoice(voice) }.font(.callout).foregroundStyle(ShelfTheme.accent)
                }
                .frame(minHeight: 48)
                Divider().overlay(ShelfTheme.line)
            }
            if !speech.availableVoices.contains(where: { $0.quality != .standard }) {
                Text("Only Standard English voices are currently installed. Enhanced or Premium Apple voices, when installed in iOS, are preferred automatically.")
                    .font(.footnote).foregroundStyle(ShelfTheme.secondary)
            }
        }
    }

    private var speed: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Speed").font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach([0.8, 0.9, 1.0, 1.1, 1.25, 1.5, 1.75, 2.0], id: \.self) { value in
                        Button(speedLabel(value)) { speech.setSpeed(value) }
                            .buttonStyle(ShelfButtonStyle(filled: abs(value - speech.speed) < 0.001))
                    }
                }
            }
            Text("Dense code and formulas are automatically read slightly more deliberately than ordinary prose.")
                .font(.footnote).foregroundStyle(ShelfTheme.secondary)
        }
    }

    private var pronunciation: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pronunciation overrides").font(.headline)
            Text("Your overrides win everywhere and stay on this iPhone.").font(.footnote).foregroundStyle(ShelfTheme.secondary)
            LeuTextField("Written term, e.g. PostgreSQL", text: $pronunciationDisplay).textInputAutocapitalization(.never)
            LeuTextField("Speak as…", text: $pronunciationSpoken)
            Button("Save pronunciation") {
                speech.savePronunciation(display: pronunciationDisplay, spoken: pronunciationSpoken)
                pronunciationDisplay = ""; pronunciationSpoken = ""
            }.buttonStyle(ShelfButtonStyle()).disabled(pronunciationDisplay.count < 2 || pronunciationSpoken.isEmpty)
            ForEach(speech.pronunciationOverrides) { entry in
                HStack { Text(entry.display); Image(systemName: "arrow.right").foregroundStyle(ShelfTheme.secondary); Text(entry.spoken).foregroundStyle(ShelfTheme.secondary); Spacer()
                    Button(role: .destructive) { speech.removePronunciation(entry) } label: { Image(systemName: "trash").frame(width: 44, height: 44) }
                }
            }
        }
    }

    private var diagnostics: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Playback").font(.headline)
            if let error = speech.playbackError { Text(error).font(.callout) }
            if let latency = speech.lastStartLatencyMilliseconds {
                Text(String(format: "Last measured request → synthesizer-start: %.0f ms", latency)).font(.footnote).monospacedDigit().foregroundStyle(ShelfTheme.secondary)
            } else {
                Text("Playback-start latency is measured when speech begins on this device.").font(.footnote).foregroundStyle(ShelfTheme.secondary)
            }
            Text("No paid speech API or cloud voice service is required.").font(.footnote).foregroundStyle(ShelfTheme.secondary)
        }
    }

    private func speedLabel(_ value: Double) -> String { value == value.rounded() ? "\(Int(value))×" : String(format: "%g×", value) }
}
