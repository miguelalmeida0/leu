import SwiftUI

@MainActor
struct ReaderSettingsSheet: View {
    @Bindable var preferences: AppPreferences
    @State private var brightness = Double(UIScreen.main.brightness)
    @State private var textSize: Double
    @State private var editingSlider = false

    init(preferences: AppPreferences) {
        self.preferences = preferences
        _textSize = State(initialValue: preferences.readTextScale)
    }

    var body: some View {
        ShelfSheet(title: "Reading Settings") {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    pageMovement
                    readingSurface
                    typography
                    comfort
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 24)
            }
        }
        .interactiveDismissDisabled(editingSlider)
        .onDisappear { preferences.readTextScale = textSize }
    }

    private var pageMovement: some View {
        settingGroup("PAGE MOVEMENT", note: "Vertical continues through the document. Horizontal settles one page at a time.") {
            Picker("Direction", selection: $preferences.pageFlow) {
                Text("Vertical").tag(PageFlow.vertical)
                Text("Horizontal").tag(PageFlow.horizontal)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("reader-page-flow")
        }
    }

    private var readingSurface: some View {
        settingGroup("ORIGINAL PDF", note: "The source page stays untouched; only the space around it changes.") {
            HStack(spacing: 10) {
                surroundChoice(.paper, swatch: .white)
                surroundChoice(.warm, swatch: ShelfTheme.paper)
                surroundChoice(.dark, swatch: Color(red: 0.12, green: 0.12, blue: 0.11))
            }
        }
    }

    private var typography: some View {
        settingGroup("READ MODE TEXT", note: "Read text size is independent from Original PDF zoom.") {
            HStack(alignment: .center, spacing: 10) {
                Text("Aa").font(.system(size: 15, design: .serif)).foregroundStyle(ShelfTheme.secondary)
                ReaderTrackingSlider(value: $textSize, range: 0.8...1.6, step: 0.1,
                    label: "Read text size", identifier: "settings-read-text-slider",
                    valueDescription: { "\(Int(($0 * 100).rounded()))%" }) { editing in
                        editingSlider = editing
                        if !editing { preferences.readTextScale = textSize }
                    }
                Text("Aa").font(.system(size: 23, design: .serif)).foregroundStyle(ShelfTheme.text)
            }
            HStack {
                Text("Text size").font(.system(.subheadline, design: .serif))
                Spacer()
                Text("\(Int((textSize * 100).rounded()))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(ShelfTheme.secondary)
                    .accessibilityIdentifier("settings-read-text-value")
            }
        }
    }

    private var comfort: some View {
        settingGroup("COMFORT", note: "Brightness changes affect the current screen, including other apps.") {
            HStack(spacing: 12) {
                Image(systemName: "sun.min").foregroundStyle(ShelfTheme.secondary).accessibilityHidden(true)
                ReaderTrackingSlider(value: $brightness, range: 0.1...1,
                    label: "Screen brightness", identifier: "settings-brightness-slider",
                    valueDescription: { "\(Int(($0 * 100).rounded()))%" }) { editing in
                        editingSlider = editing
                    }
                Image(systemName: "sun.max").foregroundStyle(ShelfTheme.secondary).accessibilityHidden(true)
            }
            .onChange(of: brightness) { _, value in UIScreen.main.brightness = value }

            Divider().overlay(ShelfTheme.line)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Keep screen awake").font(.system(.body, design: .serif))
                    Text("Useful during long reading sessions.").font(.caption).foregroundStyle(ShelfTheme.secondary)
                }
                Spacer(minLength: 12)
                ShelfSwitch(isOn: $preferences.keepAwake, identifier: "settings-keep-awake", label: "Keep screen awake") { value in
                    UIApplication.shared.isIdleTimerDisabled = value
                }
                .fixedSize()
            }
        }
    }

    private func surroundChoice(_ surround: ReaderSurround, swatch: Color) -> some View {
        Button { preferences.readerSurround = surround } label: {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(swatch)
                    .frame(height: 54)
                    .overlay { RoundedRectangle(cornerRadius: 5).stroke(preferences.readerSurround == surround ? ShelfTheme.accent : ShelfTheme.line, lineWidth: preferences.readerSurround == surround ? 1.5 : 0.7) }
                    .overlay(alignment: .topTrailing) {
                        if preferences.readerSurround == surround {
                            Image(systemName: "checkmark.circle.fill").font(.caption).foregroundStyle(ShelfTheme.accent).padding(6)
                        }
                    }
                Text(surround.title.replacingOccurrences(of: " surround", with: ""))
                    .font(.caption)
                    .foregroundStyle(preferences.readerSurround == surround ? ShelfTheme.text : ShelfTheme.secondary)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("settings-surround-\(surround.rawValue)")
    }

    private func settingGroup<Content: View>(_ title: String, note: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(title).font(ShelfTheme.eyebrow()).tracking(1.8).foregroundStyle(ShelfTheme.secondary)
            content()
            Text(note).font(.caption).foregroundStyle(ShelfTheme.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 22)
        .overlay(alignment: .bottom) { ShelfTheme.line.frame(height: 0.5) }
    }
}
