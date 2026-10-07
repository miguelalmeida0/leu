@preconcurrency import AVFoundation
import Foundation
import ShelfCore
#if canImport(UIKit)
import UIKit
#endif
#if canImport(OnnxRuntimeBindings)
import OnnxRuntimeBindings
#endif

enum SupertonicAssets {
    static let revision = "aafc6e32416a594460b32413efc49d7fe4ce6d46"
    static let modelFiles = [
        "onnx/tts.json", "onnx/unicode_indexer.json", "onnx/duration_predictor.onnx",
        "onnx/text_encoder.onnx", "onnx/vector_estimator.onnx", "onnx/vocoder.onnx",
        "voice_styles/F1.json"
    ]

    static var root: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("Leu/Supertonic", isDirectory: true)
    }

    static var isInstalled: Bool {
        modelFiles.allSatisfy { FileManager.default.fileExists(atPath: root.appendingPathComponent($0).path) }
    }

    static func resourceURLs() -> (modelRoot: URL, voiceStyle: URL)? {
        if isInstalled {
            return (root.appendingPathComponent("onnx", isDirectory: true),
                    root.appendingPathComponent("voice_styles/F1.json"))
        }
        guard let bundle = Bundle.main.resourceURL else { return nil }
        let bundled = bundle.appendingPathComponent("Supertonic", isDirectory: true)
        let model = bundled.appendingPathComponent("onnx", isDirectory: true)
        let voice = bundled.appendingPathComponent("voice_styles/F1.json")
        guard FileManager.default.fileExists(atPath: model.appendingPathComponent("vocoder.onnx").path),
              FileManager.default.fileExists(atPath: voice.path) else { return nil }
        return (model, voice)
    }

    static func install(progress: @escaping @Sendable (Double) -> Void = { _ in }) async throws {
        let fm = FileManager.default
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        for (index, path) in modelFiles.enumerated() {
            let destination = root.appendingPathComponent(path)
            if fm.fileExists(atPath: destination.path) { progress(Double(index + 1) / Double(modelFiles.count)); continue }
            try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encodedPath = path.split(separator: "/").map { String($0).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)! }.joined(separator: "/")
            let url = URL(string: "https://huggingface.co/supertone-oss-archive/supertonic-3/resolve/\(revision)/\(encodedPath)?download=true")!
            let (temporary, response) = try await URLSession.shared.download(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
            try fm.moveItem(at: temporary, to: destination)
            progress(Double(index + 1) / Double(modelFiles.count))
        }
    }
}


#if canImport(OnnxRuntimeBindings)
/// Opening the four ONNX sessions costs far more than running them. Building a
/// runtime inside every speak() made each sentence pay a full model load before
/// any audio started. One runtime is kept alive and reused across utterances.
actor SupertonicRuntimeCache {
    static let shared = SupertonicRuntimeCache()
    private var runtime: SupertonicRuntime?
    private var loadedRoot: URL?
    private var loadedVoiceStyle: URL?
    private var loads = 0
    private var utterances = 0

    func synthesize(_ text: String, speed: Float, root: URL,
                    voiceStyle: URL) throws -> (samples: [Float], sampleRate: Int) {
        let reused = runtime != nil && loadedRoot == root && loadedVoiceStyle == voiceStyle
        if !reused {
            runtime = try SupertonicRuntime(root: root, voiceStyle: voiceStyle)
            loadedRoot = root; loadedVoiceStyle = voiceStyle; loads += 1
        }
        guard let runtime else { throw URLError(.cannotOpenFile) }
        let start = Date()
        let samples = try runtime.synthesize(text, speed: speed)
        utterances += 1
        StudyInteractionTrace.record("voice.runtime backend=supertonic reused=\(reused) loads=\(loads) utterances=\(utterances) synthesisMs=\(Date().timeIntervalSince(start) * 1000)")
        return (samples, runtime.sampleRate)
    }

    /// Playback is allowed in background. Keep this runtime across scene transitions.
    /// Memory-pressure eviction runs on the same actor, after any active inference;
    /// AVAudioPlayer owns its PCM independently, so playback is not interrupted.
    func discard() { runtime = nil; loadedRoot = nil; loadedVoiceStyle = nil }
}
#endif

@MainActor
final class SupertonicSpeechEngine: NSObject, AVAudioPlayerDelegate {
    var onStarted: (() -> Void)?
    var onFinished: (() -> Void)?
    var onCancelled: (() -> Void)?
    private var player: AVAudioPlayer?
    private var generation = UUID()
    private var synthesizing = false
    private var pauseRequested = false
    private var memoryObserver: NSObjectProtocol?

    override init() {
        super.init()
        #if canImport(UIKit) && canImport(OnnxRuntimeBindings)
        memoryObserver = NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil, queue: .main) { _ in
            Task { await SupertonicRuntimeCache.shared.discard() }
        }
        #endif
    }
    deinit { if let memoryObserver { NotificationCenter.default.removeObserver(memoryObserver) } }

    var isAvailable: Bool { KokoroAssets.isSupported && Self.resources != nil }
    var isSpeaking: Bool { player?.isPlaying == true || (synthesizing && !pauseRequested) }
    var isPaused: Bool { pauseRequested || (player != nil && player?.isPlaying == false) }

    func speak(_ segment: SpeechSegment, userSpeed: Double) {
        guard let resources = Self.resources else { onCancelled?(); return }
        generation = UUID(); let token = generation
        synthesizing = true; pauseRequested = false
        let text = segment.spokenText
        Task.detached(priority: .userInitiated) {
            #if canImport(OnnxRuntimeBindings)
            do {
                let output = try await SupertonicRuntimeCache.shared.synthesize(
                    text, speed: Float(min(max(userSpeed, 0.82), 1.4)),
                    root: resources.modelRoot, voiceStyle: resources.voiceStyle)
                let url = try Self.writeWAV(output.samples, sampleRate: output.sampleRate)
                await MainActor.run {
                    guard token == self.generation else { try? FileManager.default.removeItem(at: url); return }
                    self.synthesizing = false
                    do {
                        defer { try? FileManager.default.removeItem(at: url) }
                        let player = try AVAudioPlayer(data: Data(contentsOf: url))
                        player.delegate = self; self.player = player
                        player.prepareToPlay()
                        if !self.pauseRequested { player.play(); self.onStarted?() }
                    } catch { self.onCancelled?() }
                }
            } catch { await MainActor.run { if token == self.generation { self.synthesizing = false; self.onCancelled?() } } }
            #else
            await MainActor.run { if token == self.generation { self.synthesizing = false; self.onCancelled?() } }
            #endif
        }
    }

    @discardableResult func pause() -> Bool {
        if synthesizing { pauseRequested = true; return true }
        guard let player, player.isPlaying else { return false }; pauseRequested = true; player.pause(); return true
    }
    @discardableResult func resume() -> Bool {
        if synthesizing && pauseRequested { pauseRequested = false; return true }
        guard let player, !player.isPlaying else { return false }; pauseRequested = false; player.play(); return true
    }
    @discardableResult func stop() -> Bool {
        generation = UUID(); let had = player != nil || synthesizing; player?.stop(); player = nil
        synthesizing = false; pauseRequested = false
        if had { onCancelled?() }; return had
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let finishedID = ObjectIdentifier(player)
        Task { @MainActor [weak self] in
            guard let self, let active = self.player, ObjectIdentifier(active) == finishedID else { return }
            self.player = nil
            flag ? self.onFinished?() : self.onCancelled?()
        }
    }

    private struct Resources: Sendable { let modelRoot: URL; let voiceStyle: URL }
    private static var resources: Resources? {
        guard let urls = SupertonicAssets.resourceURLs() else { return nil }
        return Resources(modelRoot: urls.modelRoot, voiceStyle: urls.voiceStyle)
    }

    nonisolated private static func writeWAV(_ samples: [Float], sampleRate: Int) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("leu-supertonic-\(UUID().uuidString).wav")
        let pcm = samples.map { Int16(max(-1, min(1, $0)) * 32767) }
        let dataSize = UInt32(pcm.count * 2); let channels: UInt16 = 1; let bits: UInt16 = 16
        var data = Data(); data.append(Data("RIFF".utf8)); append(UInt32(36 + dataSize), to: &data)
        data.append(Data("WAVEfmt ".utf8)); append(UInt32(16), to: &data); append(UInt16(1), to: &data)
        append(channels, to: &data); append(UInt32(sampleRate), to: &data)
        append(UInt32(sampleRate) * UInt32(channels) * UInt32(bits) / 8, to: &data)
        append(channels * bits / 8, to: &data); append(bits, to: &data)
        data.append(Data("data".utf8)); append(dataSize, to: &data)
        pcm.withUnsafeBytes { data.append(contentsOf: $0) }; try data.write(to: url, options: .atomic); return url
    }

    nonisolated private static func append<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        var little = value.littleEndian; withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
    }
}

/// Chooses who reads: a Kokoro voice when installed (the default), then Supertonic, then
/// Apple's synthesizer as the fallback that is always there.
@MainActor
final class LeuSpeechEngine {
    private enum Backend { case apple, supertonic, kokoro }
    private let apple = AppleSpeechEngine()
    private let neural = SupertonicSpeechEngine()
    private let kokoro = KokoroSpeechEngine()
    private var active: Backend = .apple
    var onStarted: (() -> Void)? { didSet { wire() } }
    var onFinished: (() -> Void)? { didSet { wire() } }
    var onCancelled: (() -> Void)? { didSet { wire() } }
    var onWillSpeakRange: ((NSRange) -> Void)? { didSet { wire() } }
    private var preferred: Backend { kokoro.isAvailable ? .kokoro : neural.isAvailable ? .supertonic : .apple }
    private var current: Backend { isSpeaking || isPaused ? active : preferred }
    var usesAppleVoices: Bool { current == .apple }
    var supportsSentenceRanges: Bool { usesAppleVoices }
    var backendName: String {
        switch current {
        case .kokoro: "Kokoro · \(KokoroVoice.selected.name)"
        case .supertonic: "Leu Neural · Supertonic 3"
        case .apple: "Apple fallback"
        }
    }
    var isSpeaking: Bool {
        switch active {
        case .kokoro: return kokoro.isSpeaking
        case .supertonic: return neural.isSpeaking
        case .apple: return apple.isSpeaking
        }
    }
    var isPaused: Bool {
        switch active {
        case .kokoro: return kokoro.isPaused
        case .supertonic: return neural.isPaused
        case .apple: return apple.isPaused
        }
    }

    init() {
        wire()
        // Opening a book warms the voice, so the first sentence does not wait for loading.
        if kokoro.isAvailable {
            let voice = KokoroVoice.selected
            Task.detached(priority: .utility) { await KokoroVoiceRuntime.shared.prewarm(voice) }
        }
    }
    func speak(_ segment: SpeechSegment, voice: AVSpeechSynthesisVoice?, userSpeed: Double) {
        active = preferred
        switch active {
        case .kokoro: kokoro.speak(segment.spokenText, userSpeed: userSpeed)
        case .supertonic: neural.speak(segment, userSpeed: userSpeed)
        case .apple: apple.speak(segment, voice: voice, userSpeed: userSpeed)
        }
    }
    func speak(_ paragraph: SpokenParagraph, voice: AVSpeechSynthesisVoice?, userSpeed: Double) {
        active = preferred
        guard active != .apple, var segment = paragraph.sentences.first?.segment else {
            apple.speak(paragraph, voice: voice, userSpeed: userSpeed); return
        }
        segment.spokenText = paragraph.spokenText
        if active == .kokoro { kokoro.speak(segment.spokenText, userSpeed: userSpeed) } else { neural.speak(segment, userSpeed: userSpeed) }
    }
    @discardableResult func pause() -> Bool {
        switch active {
        case .kokoro: return kokoro.pause()
        case .supertonic: return neural.pause()
        case .apple: return apple.pause()
        }
    }
    @discardableResult func resume() -> Bool {
        switch active {
        case .kokoro: return kokoro.resume()
        case .supertonic: return neural.resume()
        case .apple: return apple.resume()
        }
    }
    @discardableResult func stop() -> Bool {
        switch active {
        case .kokoro: return kokoro.stop()
        case .supertonic: return neural.stop()
        case .apple: return apple.stop()
        }
    }
    private func wire() {
        apple.onWillSpeakRange = { [weak self] in self?.onWillSpeakRange?($0) }
        apple.onStarted = { [weak self] in self?.onStarted?() }
        neural.onStarted = { [weak self] in self?.onStarted?() }
        kokoro.onStarted = { [weak self] in self?.onStarted?() }
        apple.onFinished = { [weak self] in self?.onFinished?() }
        neural.onFinished = { [weak self] in self?.onFinished?() }
        kokoro.onFinished = { [weak self] in self?.onFinished?() }
        apple.onCancelled = { [weak self] in self?.onCancelled?() }
        neural.onCancelled = { [weak self] in self?.onCancelled?() }
        kokoro.onCancelled = { [weak self] in self?.onCancelled?() }
    }
}
