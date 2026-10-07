import SwiftUI

@main
@MainActor
struct ShelfApp: App {
    @State private var container = AppContainer()

    init() {
        // Gabarito and Literata must exist before the first frame resolves a font.
        LeuType.registerFonts()
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--voice-benchmark") {
                VoiceBenchmarkScreen()
            } else {
                application
            }
            #else
            application
            #endif
        }
        .commands { LeuCommands() }
    }

    private var application: some View {
            RootView(container: container)
                .preferredColorScheme(.light)
                .font(.leu(.body))
                .tint(ShelfTheme.accent)
                .onOpenURL { container.library.receive($0) }
    }
}
