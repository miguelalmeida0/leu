import AVFoundation
import Observation

/// Soft rain against the window, synthesised on the device (no audio file, no network).
///
/// Three slow noise integrators make the body of the rain; now and then a short, bright
/// tick lands like a drop on glass. It is off until asked, fades in and out over about
/// half a second, and mixes with whatever else is playing rather than interrupting it.
@MainActor
@Observable
final class RainSound {
    private(set) var isPlaying = false
    @ObservationIgnored private var engine: AVAudioEngine?
    @ObservationIgnored private let voice = RainVoice()

    func toggle() { isPlaying ? stop() : start() }

    func start() {
        guard !isPlaying else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            let engine = engine ?? makeEngine()
            self.engine = engine
            if !engine.isRunning { try engine.start() }
            voice.target = 0.55
            isPlaying = true
        } catch {
            isPlaying = false
        }
    }

    func stop() {
        guard isPlaying else { return }
        voice.target = 0
        isPlaying = false
        let engine = engine
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(900))
            guard let self, !self.isPlaying else { return }
            engine?.stop()
        }
    }

    private func makeEngine() -> AVAudioEngine {
        let engine = AVAudioEngine()
        let format = engine.outputNode.inputFormat(forBus: 0)
        let sampleRate = format.sampleRate > 0 ? format.sampleRate : 44_100
        let mono = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) ?? format
        let voice = voice
        voice.sampleRate = sampleRate
        let source = AVAudioSourceNode(format: mono) { _, _, frameCount, bufferList in
            let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
            guard let channel = buffers.first?.mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            for frame in 0..<Int(frameCount) { channel[frame] = voice.nextSample() }
            return noErr
        }
        engine.attach(source)
        engine.connect(source, to: engine.mainMixerNode, format: mono)
        return engine
    }
}

/// The render-thread half. Plain stored numbers only, written once per toggle from the
/// main thread; a torn read of `target` can only make a fade a sample early or late.
final class RainVoice: @unchecked Sendable {
    var target: Float = 0
    var sampleRate: Double = 44_100
    private var gain: Float = 0
    private var b0: Float = 0, b1: Float = 0, b2: Float = 0
    private var tick: Float = 0, tickDecay: Float = 0, lastWhite: Float = 0
    private var untilTick = 0

    func nextSample() -> Float {
        let white = Float.random(in: -1...1)
        b0 = 0.997 * b0 + white * 0.029
        b1 = 0.985 * b1 + white * 0.032
        b2 = 0.95 * b2 + white * 0.048
        var sample = (b0 + b1 + b2 + white * 0.02) * 0.35
        // A drop on the glass: high-passed noise with a fast exponential decay.
        untilTick -= 1
        if untilTick <= 0 {
            untilTick = Int(Double.random(in: 0.08...0.45) * sampleRate)
            tick = Float.random(in: 0.05...0.12)
            tickDecay = Float(exp(-1 / (0.025 * sampleRate)))
        }
        sample += (white - lastWhite) * tick
        tick *= tickDecay
        lastWhite = white
        gain += (target - gain) * Float(1 / (0.6 * sampleRate))
        return sample * gain
    }
}
