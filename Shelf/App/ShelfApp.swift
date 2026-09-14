import SwiftUI

@main
@MainActor
struct ShelfApp: App {
    @State private var container = AppContainer()
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
    }

    private var application: some View {
            RootView(container: container)
                .preferredColorScheme(.dark)
                .tint(ShelfTheme.accent)
                .onOpenURL { container.library.receive($0) }
    }
}
