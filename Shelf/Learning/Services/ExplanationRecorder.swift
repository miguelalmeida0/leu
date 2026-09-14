import AVFoundation
import Foundation
import Observation

@MainActor @Observable
final class ExplanationRecorder: NSObject, AVAudioRecorderDelegate {
    var isRecording = false
    var elapsed: TimeInterval = 0
    var errorMessage: String?
    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var startedAt: Date?

    func start(to url: URL) async -> Bool {
        let granted = await requestPermission()
        guard granted else { errorMessage = "Microphone access is required to record an explanation."; return false }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            let next = try AVAudioRecorder(url: url, settings: settings)
            next.delegate = self; next.prepareToRecord()
            guard next.record() else { throw NSError(domain: "Shelf.Recording", code: 2) }
            recorder = next; startedAt = Date(); elapsed = 0; isRecording = true
            timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.elapsed = self?.recorder?.currentTime ?? 0 }
            }
            return true
        } catch {
            errorMessage = error.localizedDescription; return false
        }
    }

    func stop() -> TimeInterval {
        let duration = recorder?.currentTime ?? startedAt.map { Date().timeIntervalSince($0) } ?? 0
        recorder?.stop(); recorder = nil; timer?.invalidate(); timer = nil
        isRecording = false; elapsed = duration; startedAt = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return duration
    }

    private func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in continuation.resume(returning: granted) }
        }
    }
}
