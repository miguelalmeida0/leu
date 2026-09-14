@preconcurrency import MediaPlayer
import Foundation

/// Bridges Leu's local speech queue to lock-screen / Control Center transport controls.
/// It never owns reading state; ReaderSpeechController remains the single source of truth.
@MainActor
final class RemoteCommandCoordinator {
    private let commands = MPRemoteCommandCenter.shared()
    private var registrations: [(MPRemoteCommand, Any)] = []

    func configure(play: @escaping () -> Void,
                   pause: @escaping () -> Void,
                   next: @escaping () -> Void,
                   previous: @escaping () -> Void,
                   skipForward: @escaping () -> Void,
                   skipBackward: @escaping () -> Void) {
        removeRegistrations()
        commands.playCommand.isEnabled = true
        commands.pauseCommand.isEnabled = true
        commands.nextTrackCommand.isEnabled = true
        commands.previousTrackCommand.isEnabled = true
        commands.skipForwardCommand.isEnabled = true
        commands.skipBackwardCommand.isEnabled = true
        commands.skipForwardCommand.preferredIntervals = [15]
        commands.skipBackwardCommand.preferredIntervals = [15]

        register(commands.playCommand, action: play)
        register(commands.pauseCommand, action: pause)
        register(commands.nextTrackCommand, action: next)
        register(commands.previousTrackCommand, action: previous)
        register(commands.skipForwardCommand, action: skipForward)
        register(commands.skipBackwardCommand, action: skipBackward)
    }

    func update(bookTitle: String, passage: String?, isPlaying: Bool, speed: Double) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: bookTitle,
            MPMediaItemPropertyAlbumTitle: "Leu",
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: max(0.8, min(speed, 2.0))
        ]
        if let passage, !passage.isEmpty {
            info[MPMediaItemPropertyArtist] = String(passage.prefix(120))
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    func clear() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private func register(_ command: MPRemoteCommand, action: @escaping () -> Void) {
        let token = command.addTarget { _ in
            Task { @MainActor in action() }
            return .success
        }
        registrations.append((command, token))
    }

    private func removeRegistrations() {
        for (command, token) in registrations { command.removeTarget(token) }
        registrations.removeAll()
    }

    deinit {
        for (command, token) in registrations { command.removeTarget(token) }
    }
}
