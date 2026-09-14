@preconcurrency import AVFoundation
import Foundation

@MainActor
final class AudioSessionCoordinator {
    var onInterruptionBegan: (() -> Void)?
    var onInterruptionShouldResume: (() -> Void)?
    var onRouteLost: (() -> Void)?
    private var observers: [NSObjectProtocol] = []

    init() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification,
                                            object: AVAudioSession.sharedInstance(), queue: .main) { [weak self] note in
            Task { @MainActor in self?.handleInterruption(note) }
        })
        observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification,
                                            object: AVAudioSession.sharedInstance(), queue: .main) { [weak self] note in
            Task { @MainActor in self?.handleRouteChange(note) }
        })
    }

    deinit { observers.forEach(NotificationCenter.default.removeObserver) }

    func activate() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .allowBluetoothA2DP])
            try session.setActive(true)
        } catch {
            // Core reading remains functional even when the current system audio route refuses reconfiguration.
        }
    }

    func deactivate() { try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation]) }

    private func handleInterruption(_ note: Notification) {
        guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        if type == .began { onInterruptionBegan?(); return }
        let rawOptions = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
        if AVAudioSession.InterruptionOptions(rawValue: rawOptions).contains(.shouldResume) { onInterruptionShouldResume?() }
    }

    private func handleRouteChange(_ note: Notification) {
        guard let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable else { return }
        onRouteLost?()
    }
}
