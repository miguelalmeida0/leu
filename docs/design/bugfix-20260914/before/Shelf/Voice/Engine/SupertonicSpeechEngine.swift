@preconcurrency import AVFoundation
import Foundation
import ShelfCore
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


@MainActor
final class SupertonicSpeechEngine: NSObject, AVAudioPlayerDelegate {
    var onStarted: (() -> Void)?
    var onFinished: (() -> Void)?
    var onCancelled: (() -> Void)?
    private var player: AVAudioPlayer?
    private var generation = UUID()
    private var synthesizing = false
    private var pauseRequested = false

    var isAvailable: Bool { Self.resources != nil }
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
                let runtime = try SupertonicRuntime(root: resources.modelRoot, voiceStyle: resources.voiceStyle)
                let waveform = try runtime.synthesize(text, speed: Float(min(max(userSpeed, 0.82), 1.4)))
                let url = try Self.writeWAV(waveform, sampleRate: runtime.sampleRate)
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

    private struct Resources { let modelRoot: URL; let voiceStyle: URL }
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

@MainActor
final class LeuSpeechEngine {
    private let apple = AppleSpeechEngine()
    private let neural = SupertonicSpeechEngine()
    private var activeNeural = false
    var onStarted: (() -> Void)? { didSet { wire() } }
    var onFinished: (() -> Void)? { didSet { wire() } }
    var onCancelled: (() -> Void)? { didSet { wire() } }
    var onWillSpeakRange: ((NSRange) -> Void)? { didSet { wire() } }
    var supportsSentenceRanges: Bool { !neural.isAvailable }
    var backendName: String { neural.isAvailable ? "Leu Neural · Supertonic 3" : "Apple fallback" }
    var isSpeaking: Bool { activeNeural ? neural.isSpeaking : apple.isSpeaking }
    var isPaused: Bool { activeNeural ? neural.isPaused : apple.isPaused }

    init() { wire() }
    func speak(_ segment: SpeechSegment, voice: AVSpeechSynthesisVoice?, userSpeed: Double) {
        activeNeural = neural.isAvailable
        activeNeural ? neural.speak(segment, userSpeed: userSpeed) : apple.speak(segment, voice: voice, userSpeed: userSpeed)
    }
    func speak(_ paragraph: SpokenParagraph, voice: AVSpeechSynthesisVoice?, userSpeed: Double) {
        activeNeural = neural.isAvailable
        if activeNeural, var segment = paragraph.sentences.first?.segment {
            segment.spokenText = paragraph.spokenText
            neural.speak(segment, userSpeed: userSpeed)
        } else { apple.speak(paragraph, voice: voice, userSpeed: userSpeed) }
    }
    @discardableResult func pause() -> Bool { activeNeural ? neural.pause() : apple.pause() }
    @discardableResult func resume() -> Bool { activeNeural ? neural.resume() : apple.resume() }
    @discardableResult func stop() -> Bool { activeNeural ? neural.stop() : apple.stop() }
    private func wire() {
        apple.onWillSpeakRange = { [weak self] in self?.onWillSpeakRange?($0) }
        apple.onStarted = { [weak self] in self?.onStarted?() }; neural.onStarted = { [weak self] in self?.onStarted?() }
        apple.onFinished = { [weak self] in self?.onFinished?() }; neural.onFinished = { [weak self] in self?.onFinished?() }
        apple.onCancelled = { [weak self] in self?.onCancelled?() }; neural.onCancelled = { [weak self] in self?.onCancelled?() }
    }
}
