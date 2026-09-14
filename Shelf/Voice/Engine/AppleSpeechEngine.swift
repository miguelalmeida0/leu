@preconcurrency import AVFoundation
import Foundation
import ShelfCore

@MainActor
final class AppleSpeechEngine: NSObject {
    private let synthesizer = AVSpeechSynthesizer()
    private var activeUtterance: AVSpeechUtterance?
    var onStarted: (() -> Void)?
    var onFinished: (() -> Void)?
    var onCancelled: (() -> Void)?
    var onWillSpeakRange: ((NSRange) -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    var isSpeaking: Bool { synthesizer.isSpeaking }
    var isPaused: Bool { synthesizer.isPaused }

    func speak(_ segment: SpeechSegment, voice: AVSpeechSynthesisVoice?, userSpeed: Double) {
        let utterance = AVSpeechUtterance(string: segment.spokenText)
        utterance.voice = voice
        let adaptive = AVSpeechUtteranceDefaultSpeechRate * Float(min(max(userSpeed, 0.8), 2.0))
        utterance.rate = min(max(adaptive, AVSpeechUtteranceMinimumSpeechRate), AVSpeechUtteranceMaximumSpeechRate)
        utterance.pitchMultiplier = 1.0
        utterance.preUtteranceDelay = 0
        utterance.postUtteranceDelay = 0
        activeUtterance = utterance
        synthesizer.speak(utterance)
    }

    @discardableResult func pause() -> Bool { synthesizer.pauseSpeaking(at: .word) }
    @discardableResult func resume() -> Bool { synthesizer.continueSpeaking() }
    @discardableResult func stop() -> Bool { activeUtterance = nil; return synthesizer.stopSpeaking(at: .immediate) }

    func speak(_ paragraph: SpokenParagraph, voice: AVSpeechSynthesisVoice?, userSpeed: Double) {
        guard var segment = paragraph.sentences.first?.segment else { return }
        segment.spokenText = paragraph.spokenText
        speak(segment, voice: voice, userSpeed: userSpeed)
    }

    fileprivate func owns(_ utterance: AVSpeechUtterance) -> Bool { activeUtterance === utterance }
}

extension AppleSpeechEngine: @preconcurrency AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) { if owns(utterance) { onStarted?() } }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) { if owns(utterance) { onFinished?() } }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) { if owns(utterance) { onCancelled?() } }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString range: NSRange, utterance: AVSpeechUtterance) {
        if owns(utterance) { onWillSpeakRange?(range) }
    }
}
