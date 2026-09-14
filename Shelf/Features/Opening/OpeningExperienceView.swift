import SwiftUI

struct OpeningExperienceView: View {
    let onLibraryReveal: () -> Void
    let completion: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var timeline = OpeningTimeline()

    private var imageOpacity: Double {
        switch timeline.phase {
        case .dark, .finished: return 0
        case .visible: return 1
        case .fadingOut: return 0
        }
    }

    var body: some View {
        ZStack {
            ShelfTheme.background

            Image("OpeningScene")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .opacity(imageOpacity)
                .accessibilityHidden(true)
        }
        .ignoresSafeArea()
        .background(ShelfTheme.background)
        .task {
            timeline.start(
                reduceMotion: reduceMotion,
                onLibraryReveal: onLibraryReveal,
                completion: completion
            )
        }
        .onDisappear { timeline.cancel() }
    }
}
