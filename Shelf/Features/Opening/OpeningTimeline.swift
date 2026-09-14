import SwiftUI

enum OpeningPhase: Equatable {
    case dark
    case visible
    case fadingOut
    case finished
}

@MainActor
final class OpeningTimeline: ObservableObject {
    @Published private(set) var phase: OpeningPhase = .dark
    private var task: Task<Void, Never>?

    func start(
        reduceMotion: Bool,
        onLibraryReveal: @escaping @MainActor () -> Void,
        completion: @escaping @MainActor () -> Void
    ) {
        task?.cancel()
        task = Task { @MainActor in
            if reduceMotion {
                phase = .visible
                try? await Task.sleep(for: .milliseconds(850))
                guard !Task.isCancelled else { return }
                onLibraryReveal()
                withAnimation(.easeInOut(duration: 0.35)) { phase = .fadingOut }
                try? await Task.sleep(for: .milliseconds(380))
                guard !Task.isCancelled else { return }
                phase = .finished
                completion()
                return
            }

            phase = .dark
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }

            withAnimation(.easeInOut(duration: 0.72)) {
                phase = .visible
            }

            // The image is fully visible for roughly 2.3 seconds after the fade-in settles.
            try? await Task.sleep(for: .milliseconds(3_000))
            guard !Task.isCancelled else { return }

            onLibraryReveal()
            withAnimation(.easeInOut(duration: 0.85)) {
                phase = .fadingOut
            }

            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }

            phase = .finished
            completion()
        }
    }

    func cancel() {
        task?.cancel()
    }
}
