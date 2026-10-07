import Foundation

/// A Kokoro voice Leu offers. Kokoro-82M ships 54; these are the English ones that read
/// long passages best, by the model authors' own grading.
struct KokoroVoice: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let detail: String
    /// British voices read from the British lexicon.
    let british: Bool

    static let all: [KokoroVoice] = [
        KokoroVoice(id: "af_heart", name: "Heart", detail: "Warm and unhurried · American", british: false),
        KokoroVoice(id: "af_bella", name: "Bella", detail: "Bright and clear · American", british: false),
        KokoroVoice(id: "af_nicole", name: "Nicole", detail: "Soft, close to the ear · American", british: false),
        KokoroVoice(id: "am_michael", name: "Michael", detail: "Calm and even · American", british: false),
        KokoroVoice(id: "am_fenrir", name: "Fenrir", detail: "Low and steady · American", british: false),
        KokoroVoice(id: "bf_emma", name: "Emma", detail: "Gentle · British", british: true),
        KokoroVoice(id: "bm_george", name: "George", detail: "Measured · British", british: true),
    ]

    static let standard = all[0]

    private static let key = "voice.kokoro"

    /// The voice the reader chose, kept on this device.
    static var selected: KokoroVoice {
        get { all.first { $0.id == UserDefaults.standard.string(forKey: key) } ?? standard }
        set { UserDefaults.standard.set(newValue.id, forKey: key) }
    }
}

/// Kokoro-82M (Apache-2.0) as ONNX, its voice packs, and Misaki's pronunciation
/// dictionaries (Apache-2.0). Downloaded once from pinned revisions, then everything runs
/// on this device with ONNX Runtime on the CPU.
enum KokoroAssets {
    static let modelRevision = "1939ad2a8e416c0acfeecc08a694d14ef25f2231"
    static let misakiRevision = "fba1236595f2d2bf21d414ba6e57d25256afada3"
    static let modelFile = "model_quantized.onnx"
    static let approximateMegabytes = 110
    static let lexicons = ["us_gold.json", "us_silver.json", "gb_gold.json", "gb_silver.json"]

    static var root: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("Leu/Kokoro", isDirectory: true)
    }

    static var modelURL: URL { root.appendingPathComponent(modelFile) }
    static func lexiconURL(_ name: String) -> URL { root.appendingPathComponent("lexicon/\(name)") }
    static func voiceURL(_ id: String) -> URL { root.appendingPathComponent("voices/\(id).bin") }

    static var isInstalled: Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: modelURL.path)
            && lexicons.allSatisfy { fm.fileExists(atPath: lexiconURL($0).path) }
            && KokoroVoice.all.allSatisfy { fm.fileExists(atPath: voiceURL($0.id).path) }
    }

    private struct Download {
        let remote: URL
        let local: URL
        /// Share of the whole download, so progress moves at an honest pace.
        let weight: Double
    }

    private static var downloads: [Download] {
        let model = "https://huggingface.co/onnx-community/Kokoro-82M-v1.0-ONNX/resolve/\(modelRevision)"
        let misaki = "https://raw.githubusercontent.com/hexgrad/misaki/\(misakiRevision)/misaki/data"
        return [Download(remote: URL(string: "\(model)/onnx/\(modelFile)")!, local: modelURL, weight: 92)]
            + lexicons.map { Download(remote: URL(string: "\(misaki)/\($0)")!, local: lexiconURL($0), weight: 3) }
            + KokoroVoice.all.map { Download(remote: URL(string: "\(model)/voices/\($0.id).bin")!, local: voiceURL($0.id), weight: 0.5) }
    }

    /// Downloads whatever is missing. Safe to call again after a failure: finished files are kept.
    static func install(progress: @escaping @Sendable (Double) -> Void = { _ in }) async throws {
        let fm = FileManager.default
        var rootURL = root
        try fm.createDirectory(at: rootURL, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? rootURL.setResourceValues(values)
        let total = downloads.reduce(0) { $0 + $1.weight }
        var done = 0.0
        for item in downloads {
            try Task.checkCancellation()
            if !fm.fileExists(atPath: item.local.path) {
                try fm.createDirectory(at: item.local.deletingLastPathComponent(), withIntermediateDirectories: true)
                let (temporary, response) = try await URLSession.shared.download(from: item.remote)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                try? fm.removeItem(at: item.local)
                try fm.moveItem(at: temporary, to: item.local)
            }
            done += item.weight
            progress(done / total)
        }
    }

    static func remove() throws {
        if FileManager.default.fileExists(atPath: root.path) { try FileManager.default.removeItem(at: root) }
    }
}
