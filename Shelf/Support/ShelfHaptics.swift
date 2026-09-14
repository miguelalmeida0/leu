import CoreHaptics
import UIKit

@MainActor
protocol HapticProviding {
    func play(_ event: HapticEvent)
}

enum HapticEvent: String, CaseIterable {
    case selectionChanged, controlPressed, objectCaptured, objectConnected, snapToTarget
    case answerCommitted, answerCorrect, answerIncorrect, sourceRevealed, memoryStrengthened
    case studySessionStarted, studySessionCompleted, recordingStarted, recordingStopped
    case destructiveWarning, connectionRemoved, pageTurn, chapterBoundary, mark, bookFinished
}

@MainActor
final class ShelfHaptics: HapticProviding {
    typealias Event = HapticEvent
    static let shared = ShelfHaptics()
    private var engine: CHHapticEngine?
    private var supported = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    private var recording = false

    private init() { prepare() }

    func play(_ event: HapticEvent) {
        let defaults = UserDefaults.standard
        let enabled = defaults.object(forKey: "reader.hapticsEnabled") as? Bool ?? true
        let stored = defaults.double(forKey: "reader.hapticIntensity")
        let scale = stored == 0 ? 0.65 : min(max(stored, 0.1), 1)
        play(event, enabled: enabled, intensityScale: scale)
    }

    func play(_ event: HapticEvent, enabled: Bool, intensityScale: Double) {
        guard enabled, intensityScale > 0 else { return }
        if recording && event != .recordingStopped { return }

        switch event {
        case .selectionChanged:
            UISelectionFeedbackGenerator().selectionChanged()
        case .controlPressed, .answerCommitted, .sourceRevealed, .pageTurn:
            impact(.light, intensity: 0.55 * intensityScale)
        case .objectCaptured, .objectConnected, .snapToTarget, .chapterBoundary, .mark:
            impact(.medium, intensity: 0.52 * intensityScale)
        case .answerCorrect:
            impact(.light, intensity: 0.46 * intensityScale)
        case .memoryStrengthened:
            impact(.soft, intensity: 0.50 * intensityScale)
        case .answerIncorrect:
            impact(.soft, intensity: 0.42 * intensityScale)
        case .connectionRemoved:
            impact(.soft, intensity: 0.34 * intensityScale)
        case .studySessionStarted:
            impact(.soft, intensity: 0.40 * intensityScale)
        case .studySessionCompleted, .bookFinished:
            twoPartSignature(scale: intensityScale)
        case .recordingStarted:
            impact(.rigid, intensity: 0.48 * intensityScale)
            recording = true
        case .recordingStopped:
            recording = false
            impact(.soft, intensity: 0.42 * intensityScale)
        case .destructiveWarning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }


    /// Clears the recording guard when recording could not start. No tactile event is fired.
    func cancelRecordingGuard() { recording = false }

    private func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle, intensity: Double) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred(intensity: min(max(intensity, 0.1), 1))
    }

    private func twoPartSignature(scale: Double) {
        guard supported else {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return
        }
        if engine == nil { prepare() }
        guard let engine else { return }
        do {
            let s = Float(min(max(scale, 0.1), 1))
            let first = CHHapticEvent(eventType: .hapticTransient,
                parameters: parameters(intensity: 0.30 * s, sharpness: 0.42), relativeTime: 0)
            let second = CHHapticEvent(eventType: .hapticTransient,
                parameters: parameters(intensity: 0.52 * s, sharpness: 0.58), relativeTime: 0.09)
            let player = try engine.makePlayer(with: CHHapticPattern(events: [first, second], parameters: []))
            try player.start(atTime: 0)
        } catch {
            supported = false
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    private func parameters(intensity: Float, sharpness: Float) -> [CHHapticEventParameter] {
        [CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
         CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)]
    }

    private func prepare() {
        guard supported else { return }
        do {
            let next = try CHHapticEngine()
            try next.start(); engine = next
        } catch { supported = false; engine = nil }
    }
}
