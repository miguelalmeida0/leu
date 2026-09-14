@preconcurrency import AVFoundation
import Foundation
import Observation
import ShelfCore

/// Reader-facing coordinator for Shelf Voice. Source text remains canonical; only SpeechSegment.spokenText reaches TTS.
@MainActor @Observable
final class ReaderSpeechController {
    private let engine = LeuSpeechEngine()
    private let audio = AudioSessionCoordinator()
    private let remote = RemoteCommandCoordinator()
    private let compiler = SpeechCompiler()
    private let catalog = VoiceCatalog()
    private let pronunciations = PronunciationPreferenceStore()
    private let voicePreferences: VoicePreferenceStore
    private let bookTitle: String
    private var queue: [SpeechSegment] = []
    private var queueIndex = 0
    private var activeParagraph: SpokenParagraph?
    private var utteranceEndIndex = 0
    private var stopping = false
    private var requestedStartTime: TimeInterval?

    var isSpeaking = false
    var isPaused = false
    var activeSentence: String?
    var activeSpokenText: String?
    var lastStartLatencyMilliseconds: Double?
    var playbackError: String?
    var onActiveSentence: ((String?) -> Void)?
    var onFinishedPage: (() -> Void)?

    init(preferences: AppPreferences, bookTitle: String) {
        self.voicePreferences = VoicePreferenceStore(preferences: preferences)
        self.bookTitle = bookTitle
        engine.onStarted = { [weak self] in self?.speechDidStart() }
        engine.onFinished = { [weak self] in self?.speechDidFinish() }
        engine.onCancelled = { [weak self] in self?.speechDidCancel() }
        engine.onWillSpeakRange = { [weak self] range in
            guard let self, let sentence = self.activeParagraph?.sentence(atUTF16: range) else { return }
            self.queueIndex = sentence.queueIndex
            self.activeSentence = sentence.segment.source.sourceText
            self.activeSpokenText = sentence.segment.spokenText
            self.onActiveSentence?(sentence.segment.source.sourceText)
            self.updateRemoteState()
        }
        audio.onInterruptionBegan = { [weak self] in self?.pauseFromSystem() }
        audio.onInterruptionShouldResume = { [weak self] in self?.resumeFromSystem() }
        audio.onRouteLost = { [weak self] in self?.pauseFromSystem() }
        remote.configure(
            play: { [weak self] in self?.remotePlay() },
            pause: { [weak self] in self?.pause() },
            next: { [weak self] in self?.nextSentence() },
            previous: { [weak self] in self?.previousSentence() },
            skipForward: { [weak self] in self?.skipForward() },
            skipBackward: { [weak self] in self?.skipBackward() }
        )
        repairVoicePreferenceIfNeeded()
    }

    var speed: Double { voicePreferences.speed }
    var availableVoices: [VoiceDescriptor] { catalog.voices() }
    var selectedVoice: VoiceDescriptor? {
        catalog.descriptor(for: voicePreferences.voiceIdentifier) ?? availableVoices.first
    }
    var queuePosition: Int { queue.isEmpty ? 0 : min(queueIndex + 1, queue.count) }
    var queueCount: Int { queue.count }
    var voiceBackendName: String { engine.backendName }

    func toggle(blocks: [SpeechInputBlock], documentID: UUID, startAt sentence: String? = nil) {
        if isPaused { resume(); return }
        if isSpeaking { pause(); return }
        start(blocks: blocks, documentID: documentID, startAt: sentence)
    }

    func start(blocks: [SpeechInputBlock], documentID: UUID, startAt sentence: String? = nil) {
        let plan = compiler.compile(document: SpeechDocument(documentID: documentID, blocks: blocks),
                                    dictionary: pronunciations.dictionary())
        guard !plan.segments.isEmpty else { return }
        stopping = false
        playbackError = nil
        queue = plan.segments
        if let sentence, let index = queue.firstIndex(where: { sourceMatches($0.source.sourceText, sentence) }) {
            queueIndex = index
        } else { queueIndex = 0 }
        audio.activate()
        ShelfHaptics.shared.play(.controlPressed)
        speakCurrent(measureLatency: true)
    }

    func pause() {
        guard isSpeaking, !isPaused, engine.pause() else { return }
        isPaused = true
        updateRemoteState()
        ShelfHaptics.shared.play(.controlPressed)
    }

    func resume() {
        guard isPaused, engine.resume() else { return }
        isPaused = false; isSpeaking = true
        updateRemoteState()
        ShelfHaptics.shared.play(.controlPressed)
    }

    func stop() {
        stopping = true
        _ = engine.stop()
        queue = []; queueIndex = 0
        activeParagraph = nil
        isSpeaking = false; isPaused = false
        activeSentence = nil; activeSpokenText = nil
        onActiveSentence?(nil)
        remote.clear()
        audio.deactivate()
    }

    func previousSentence() { move(by: -1) }
    func nextSentence() { move(by: 1) }
    func skipBackward(seconds: Int = 15) { jumpByApproximateWords(-max(1, seconds) * 3) }
    func skipForward(seconds: Int = 15) { jumpByApproximateWords(max(1, seconds) * 3) }

    func setSpeed(_ speed: Double) {
        voicePreferences.speed = speed
        updateRemoteState()
        ShelfHaptics.shared.play(.selectionChanged)
        restartCurrentIfActive()
    }

    func selectVoice(_ descriptor: VoiceDescriptor) {
        voicePreferences.voiceWasChosen = true
        voicePreferences.voiceIdentifier = descriptor.id
        ShelfHaptics.shared.play(.selectionChanged)
        restartCurrentIfActive()
    }

    func previewVoice(_ descriptor: VoiceDescriptor) {
        stop()
        stopping = false
        let mapping = SpeechSourceMapping(documentID: nil, pageIndex: 0, sourceRange: nil,
                                          sourceText: "Leu reads technical material naturally.")
        let segment = SpeechSegment(source: mapping,
            spokenText: "Use effect runs after rendering. H T T P requests are asynchronous.",
            kind: .prose, prosody: SpeechProsody())
        audio.activate(); requestedStartTime = ProcessInfo.processInfo.systemUptime
        engine.speak(segment, voice: AVSpeechSynthesisVoice(identifier: descriptor.id), userSpeed: voicePreferences.speed)
    }

    func savePronunciation(display: String, spoken: String) {
        pronunciations.save(display: display, spoken: spoken)
        ShelfHaptics.shared.play(.objectCaptured)
    }

    var pronunciationOverrides: [PronunciationEntry] { pronunciations.entries() }
    func removePronunciation(_ entry: PronunciationEntry) { pronunciations.remove(entry) }

    private func speakCurrent(measureLatency: Bool = false) {
        guard queue.indices.contains(queueIndex) else { finishPage(); return }
        let segment = queue[queueIndex]
        activeSentence = segment.source.sourceText
        activeSpokenText = segment.spokenText
        onActiveSentence?(segment.source.sourceText)
        isSpeaking = true; isPaused = false
        updateRemoteState()
        if measureLatency { requestedStartTime = ProcessInfo.processInfo.systemUptime }
        guard let paragraph = SpeechParagraphBuilder().paragraph(from: queue, startingAt: queueIndex,
                                                                 mergeProse: engine.supportsSentenceRanges) else { return }
        activeParagraph = paragraph
        utteranceEndIndex = paragraph.sentences.last?.queueIndex ?? queueIndex
        engine.speak(paragraph, voice: catalog.bestVoice(identifier: voicePreferences.voiceIdentifier), userSpeed: voicePreferences.speed)
    }

    private func move(by delta: Int) {
        guard !queue.isEmpty else { return }
        let next = min(max(queueIndex + delta, 0), queue.count - 1)
        guard next != queueIndex else { return }
        stopping = true; _ = engine.stop(); stopping = false
        queueIndex = next
        ShelfHaptics.shared.play(.selectionChanged)
        speakCurrent()
    }

    private func jumpByApproximateWords(_ wordDelta: Int) {
        guard !queue.isEmpty, wordDelta != 0 else { return }
        var target = queueIndex
        var remaining = abs(wordDelta)
        let direction = wordDelta > 0 ? 1 : -1
        while remaining > 0 {
            let next = target + direction
            guard queue.indices.contains(next) else { break }
            target = next
            remaining -= max(1, queue[target].spokenText.split(whereSeparator: \.isWhitespace).count)
        }
        guard target != queueIndex else { return }
        stopping = true; _ = engine.stop(); stopping = false
        queueIndex = target
        ShelfHaptics.shared.play(.selectionChanged)
        speakCurrent()
    }

    private func restartCurrentIfActive() {
        guard !queue.isEmpty, isSpeaking || isPaused else { return }
        let shouldPause = isPaused
        stopping = true; _ = engine.stop(); stopping = false
        speakCurrent()
        if shouldPause { DispatchQueue.main.async { [weak self] in self?.pause() } }
    }

    private func speechDidStart() {
        if let requestedStartTime {
            lastStartLatencyMilliseconds = max(0, (ProcessInfo.processInfo.systemUptime - requestedStartTime) * 1000)
            self.requestedStartTime = nil
        }
        isSpeaking = true
        updateRemoteState()
    }

    private func speechDidFinish() {
        guard !stopping else { return }
        // Voice preview doesn't own a queue and must not advance the page.
        guard !queue.isEmpty else { isSpeaking = false; isPaused = false; remote.clear(); audio.deactivate(); return }
        queueIndex = utteranceEndIndex + 1
        if queueIndex < queue.count { speakCurrent() } else { finishPage() }
    }

    private func speechDidCancel() {
        if stopping { stopping = false; return }
        isSpeaking = false; isPaused = false; activeSentence = nil; activeParagraph = nil
        onActiveSentence?(nil); remote.clear(); audio.deactivate()
        playbackError = "Speech could not continue. Try replaying the passage or choose another voice."
    }

    private func finishPage() {
        isSpeaking = false; isPaused = false
        activeSentence = nil; activeSpokenText = nil
        onActiveSentence?(nil); remote.clear(); audio.deactivate(); onFinishedPage?()
    }

    private func pauseFromSystem() {
        guard isSpeaking, !isPaused else { return }
        _ = engine.pause(); isPaused = true
        updateRemoteState()
    }

    private func resumeFromSystem() {
        guard isPaused else { return }
        audio.activate()
        if engine.resume() { isPaused = false; isSpeaking = true; updateRemoteState() }
    }

    private func remotePlay() {
        if isPaused { resume(); return }
        guard !queue.isEmpty else { return }
        speakCurrent(measureLatency: true)
    }

    private func updateRemoteState() {
        remote.update(bookTitle: bookTitle, passage: activeSentence,
                      isPlaying: isSpeaking && !isPaused, speed: voicePreferences.speed)
    }

    private func repairVoicePreferenceIfNeeded() {
        if voicePreferences.voiceWasChosen, let id = voicePreferences.voiceIdentifier,
           AVSpeechSynthesisVoice(identifier: id) != nil { return }
        voicePreferences.voiceIdentifier = nil
        voicePreferences.voiceWasChosen = false
    }

    func selectAutomaticVoice() {
        voicePreferences.voiceIdentifier = nil; voicePreferences.voiceWasChosen = false
        restartCurrentIfActive()
    }

    private func sourceMatches(_ lhs: String, _ rhs: String) -> Bool {
        let a = normalize(lhs), b = normalize(rhs)
        return a == b || a.contains(b) || b.contains(a)
    }

    private func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline }).joined(separator: " ")
    }
}
