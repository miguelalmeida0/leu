@preconcurrency import AVFoundation
import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Reads a passage aloud with a Kokoro voice. The passage is phonemized once, cut into short
/// pieces, and each piece is synthesized while the one before it plays, so the first words
/// come quickly and the rest follow without gaps.
@MainActor
final class KokoroSpeechEngine: NSObject, AVAudioPlayerDelegate {
    var onStarted: (() -> Void)?
    var onFinished: (() -> Void)?
    var onCancelled: (() -> Void)?

    private var player: AVAudioPlayer?
    private var ready: [Data] = []
    private var producing = false
    private var paused = false
    private var started = false
    private var generation = UUID()
    private var work: Task<Void, Never>?
    private var memoryObserver: NSObjectProtocol?

    override init() {
        super.init()
        #if canImport(UIKit)
        memoryObserver = NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification,
                                                                object: nil, queue: .main) { _ in
            Task { await KokoroVoiceRuntime.shared.discard() }
        }
        #endif
    }

    deinit { if let memoryObserver { NotificationCenter.default.removeObserver(memoryObserver) } }

    var isAvailable: Bool { KokoroAssets.isSupported && KokoroAssets.isInstalled }
    var isSpeaking: Bool { !paused && (player?.isPlaying == true || producing) }
    var isPaused: Bool { paused }

    func speak(_ text: String, voice: KokoroVoice = .selected, userSpeed: Double) {
        cancelWork()
        let token = UUID()
        generation = token
        producing = true; paused = false; started = false
        let speed = Float(min(max(userSpeed, 0.8), 1.6))
        work = Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let pieces = try await KokoroVoiceRuntime.shared.phonemeChunks(text, british: voice.british)
                for piece in pieces {
                    try Task.checkCancellation()
                    let samples = try await KokoroVoiceRuntime.shared.render(piece, voice: voice.id, speed: speed)
                    guard !samples.isEmpty else { continue }
                    let wav = KokoroSpeechEngine.wav(samples, sampleRate: 24_000)
                    await self?.enqueue(wav, token: token)
                }
                await self?.finishProducing(token: token)
            } catch is CancellationError {
            } catch {
                await self?.failed(token: token)
            }
        }
    }

    @discardableResult func pause() -> Bool {
        guard player != nil || producing, !paused else { return false }
        paused = true
        player?.pause()
        return true
    }

    @discardableResult func resume() -> Bool {
        guard paused else { return false }
        paused = false
        if let player { player.play() } else { playNext() }
        return true
    }

    @discardableResult func stop() -> Bool {
        let had = player != nil || producing
        cancelWork()
        if had { onCancelled?() }
        return had
    }

    // MARK: Queue

    private func cancelWork() {
        generation = UUID()
        work?.cancel(); work = nil
        player?.stop(); player = nil
        ready = []; producing = false; paused = false
    }

    private func enqueue(_ wav: Data, token: UUID) {
        guard token == generation else { return }
        ready.append(wav)
        if player == nil && !paused { playNext() }
    }

    private func finishProducing(token: UUID) {
        guard token == generation else { return }
        producing = false
        if player == nil && ready.isEmpty { onFinished?() }
    }

    private func failed(token: UUID) {
        guard token == generation else { return }
        producing = false
        if player == nil && ready.isEmpty { started ? onFinished?() : onCancelled?() }
    }

    private func playNext() {
        guard !ready.isEmpty else { return }
        let data = ready.removeFirst()
        do {
            let next = try AVAudioPlayer(data: data)
            next.delegate = self
            next.prepareToPlay()
            player = next
            next.play()
            if !started { started = true; onStarted?() }
        } catch {
            playNext()
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let finished = ObjectIdentifier(player)
        Task { @MainActor [weak self] in
            guard let self, let active = self.player, ObjectIdentifier(active) == finished else { return }
            self.player = nil
            if !self.ready.isEmpty { self.playNext() }
            else if !self.producing { self.onFinished?() }
        }
    }

    // MARK: Audio

    /// 16-bit mono PCM WAV in memory, with a few milliseconds of fade at each end so pieces
    /// join without clicks.
    nonisolated static func wav(_ samples: [Float], sampleRate: Int) -> Data {
        let fade = min(120, samples.count / 4)
        var pcm = [Int16](repeating: 0, count: samples.count)
        for index in samples.indices {
            var value = max(-1, min(1, samples[index]))
            if index < fade { value *= Float(index) / Float(fade) }
            if index >= samples.count - fade { value *= Float(samples.count - 1 - index) / Float(fade) }
            pcm[index] = Int16(value * 32_767)
        }
        var data = Data()
        func put<T: FixedWidthInteger>(_ value: T) { var little = value.littleEndian; withUnsafeBytes(of: &little) { data.append(contentsOf: $0) } }
        let bytes = UInt32(pcm.count * 2)
        data.append(Data("RIFF".utf8)); put(UInt32(36) + bytes); data.append(Data("WAVEfmt ".utf8))
        put(UInt32(16)); put(UInt16(1)); put(UInt16(1)); put(UInt32(sampleRate)); put(UInt32(sampleRate * 2))
        put(UInt16(2)); put(UInt16(16)); data.append(Data("data".utf8)); put(bytes)
        pcm.withUnsafeBytes { data.append(contentsOf: $0) }
        return data
    }
}
