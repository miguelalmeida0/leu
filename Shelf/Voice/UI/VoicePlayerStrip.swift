import SwiftUI
import Foundation

@MainActor
struct VoicePlayerStrip: View {
    @Bindable var speech: ReaderSpeechController

    var body: some View {
        // The quality notice used to live here. Inside the bottom safe-area inset
        // it added ~200pt the moment playback started, which squeezed the PDF into
        // a letterboxed strip. It belongs in Voice settings, where there is room
        // for it and where the reader goes to act on it.
        HStack(spacing: 2) {
            compactButton("gobackward.15", "Back 15 seconds") { speech.skipBackward() }
            compactButton("backward.end", "Previous sentence") { speech.previousSentence() }
            speedMenu
            voiceMenu
            compactButton("forward.end", "Next sentence") { speech.nextSentence() }
            compactButton("goforward.15", "Forward 15 seconds") { speech.skipForward() }
        }
        .frame(minHeight: 46)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("voice-player-strip")
    }

    private func compactButton(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 16, weight: .medium)).frame(maxWidth: .infinity, minHeight: 44) }
            .buttonStyle(.plain).foregroundStyle(ShelfTheme.secondary).accessibilityLabel(label)
    }

    private var speedMenu: some View {
        LeuMenu {
            ForEach([0.8, 0.9, 1.0, 1.1, 1.25, 1.5, 1.75, 2.0], id: \.self) { speed in
                Button(speedLabel(speed)) { speech.setSpeed(speed) }
            }
        } label: {
            Text(speedLabel(speech.speed)).font(.caption.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
        }
        .accessibilityLabel("Reading speed")
        .accessibilityValue(speedLabel(speech.speed))
        .accessibilityIdentifier("voice-speed")
    }

    private var voiceMenu: some View {
        LeuMenu {
            ForEach(speech.availableVoices.prefix(20)) { voice in
                Button("\(voice.name) · \(voice.quality.title)") { speech.selectVoice(voice) }
            }
        } label: {
            Image(systemName: "waveform.badge.mic").font(.system(size: 16, weight: .medium)).frame(maxWidth: .infinity, minHeight: 44)
        }
        .accessibilityLabel("Voice")
        .accessibilityValue(speech.selectedVoice.map { "\($0.name), \($0.quality.title)" } ?? "Automatic")
        .accessibilityIdentifier("voice-picker-menu")
    }

    private func speedLabel(_ value: Double) -> String {
        value == value.rounded() ? "\(Int(value))×" : String(format: "%g×", value)
    }
}
