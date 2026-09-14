import SwiftUI

struct VoiceQualityNotice: View {
    let compactOnly: Bool
    @AppStorage("voice.qualityNotice.dismissed") private var dismissed = false

    var body: some View {
        if compactOnly && !dismissed {
            VStack(alignment: .leading, spacing: 8) {
                Text("A more natural reading voice").font(.headline)
                Text("Only Compact English voices are installed. Download an Enhanced or Premium voice in iPhone Settings → Accessibility → Read & Speak (or Spoken Content) → Voices. Leu can use it after the download finishes.")
                    .font(.callout)
                Button("Got it") { dismissed = true }.frame(minHeight: 44)
            }
            .padding(.vertical, 10)
            .accessibilityIdentifier("voice-quality-notice")
        }
    }
}
