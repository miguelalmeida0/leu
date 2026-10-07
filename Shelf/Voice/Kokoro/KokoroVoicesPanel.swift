import SwiftUI

/// Install and choose a Kokoro voice. Before the download: what it is, how big, one button.
/// After: the voices as a list, each with a short preview in its own voice.
@MainActor
struct KokoroVoicesPanel: View {
    @State private var installed = KokoroAssets.isInstalled
    @State private var installing = false
    @State private var progress = 0.0
    @State private var failure: String?
    @State private var selected = KokoroVoice.selected
    @State private var previewing: String?
    @State private var player = KokoroSpeechEngine()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("NATURAL VOICES")
                .font(LeuDesign.eyebrow(11)).tracking(LeuDesign.eyebrowTracking)
                .foregroundStyle(LeuDesign.eyebrowOnFelt)
                .accessibilityAddTraits(.isHeader)
            if installed { voices } else { install }
        }
        .onAppear {
            player.onFinished = { previewing = nil }
            player.onCancelled = { previewing = nil }
        }
        .onDisappear { _ = player.stop() }
    }

    private var install: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Kokoro reads like a person, not a machine.")
                .font(.leu(.title3, weight: .bold)).foregroundStyle(LeuDesign.ink)
            Text("Seven voices, about \(KokoroAssets.approximateMegabytes) MB, downloaded once. After that they run on this device, offline, with nothing sent anywhere.")
                .font(.leu(.subheadline)).foregroundStyle(LeuDesign.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if installing {
                ProgressView(value: progress)
                    .tint(LeuDesign.ink)
                    .accessibilityLabel("Downloading voices")
                    .accessibilityValue("\(Int(progress * 100)) percent")
            }
            Button(installing ? "Downloading… \(Int(progress * 100))%" : "Download the voices") { startInstall() }
                .buttonStyle(LeuPrimaryButtonStyle(filled: true, pill: true))
                .disabled(installing)
                .accessibilityIdentifier("kokoro-install")
            if let failure {
                Text(failure).font(.leu(.footnote)).foregroundStyle(LeuDesign.danger)
            }
        }
        .padding(18)
        .background(LeuDesign.cream, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var voices: some View {
        VStack(spacing: 0) {
            ForEach(KokoroVoice.all) { voice in
                HStack(spacing: 12) {
                    Button {
                        selected = voice
                        KokoroVoice.selected = voice
                        ShelfHaptics.shared.play(.selectionChanged)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: selected == voice ? "largecircle.fill.circle" : "circle")
                                .font(.leu(.body)).foregroundStyle(LeuDesign.ink)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(voice.name).font(.leu(.body, weight: .bold)).foregroundStyle(LeuDesign.ink)
                                Text(voice.detail).font(.leu(.footnote)).foregroundStyle(LeuDesign.secondary)
                            }
                            Spacer(minLength: 8)
                        }
                        .frame(minHeight: 56)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(voice.name), \(voice.detail)")
                    .accessibilityAddTraits(selected == voice ? .isSelected : [])
                    Button(previewing == voice.id ? "Stop" : "Listen") { preview(voice) }
                        .buttonStyle(LeuPrimaryButtonStyle(filled: false, pill: true))
                        .accessibilityLabel(previewing == voice.id ? "Stop preview" : "Listen to \(voice.name)")
                }
                .padding(.horizontal, 16)
                if voice != KokoroVoice.all.last { StitchDivider().padding(.horizontal, 16) }
            }
        }
        .padding(.vertical, 6)
        .background(LeuDesign.cream, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("kokoro-voices")
    }

    private func preview(_ voice: KokoroVoice) {
        if previewing == voice.id { _ = player.stop(); previewing = nil; return }
        _ = player.stop()
        previewing = voice.id
        player.speak("Hello, I'm \(voice.name). We kept your spot warm; shall we pick up where you left off?",
                     voice: voice, userSpeed: 1.0)
    }

    private func startInstall() {
        installing = true; failure = nil; progress = 0
        Task {
            do {
                try await KokoroAssets.install { value in Task { @MainActor in progress = value } }
                installed = KokoroAssets.isInstalled
            } catch {
                failure = "The download stopped. Check your connection and try again; finished parts are kept."
            }
            installing = false
        }
    }
}
