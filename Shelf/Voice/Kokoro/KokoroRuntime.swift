import Foundation
#if canImport(OnnxRuntimeBindings)
import OnnxRuntimeBindings
#endif

/// Kokoro's phoneme alphabet, from the model's config.json. Anything outside it is dropped.
enum KokoroVocabulary {
    static let ids: [Character: Int64] = [
        ";": 1, ":": 2, ",": 3, ".": 4, "!": 5, "?": 6, "—": 9, "…": 10, "\"": 11, "(": 12, ")": 13,
        "\u{201C}": 14, "\u{201D}": 15, " ": 16, "\u{0303}": 17, "ʣ": 18, "ʥ": 19, "ʦ": 20, "ʨ": 21, "ᵝ": 22,
        "\u{AB67}": 23, "A": 24, "I": 25, "O": 31, "Q": 33, "S": 35, "T": 36, "W": 39, "Y": 41, "ᵊ": 42,
        "a": 43, "b": 44, "c": 45, "d": 46, "e": 47, "f": 48, "h": 50, "i": 51, "j": 52, "k": 53, "l": 54,
        "m": 55, "n": 56, "o": 57, "p": 58, "q": 59, "r": 60, "s": 61, "t": 62, "u": 63, "v": 64, "w": 65,
        "x": 66, "y": 67, "z": 68, "ɑ": 69, "ɐ": 70, "ɒ": 71, "æ": 72, "β": 75, "ɔ": 76, "ɕ": 77, "ç": 78,
        "ɖ": 80, "ð": 81, "ʤ": 82, "ə": 83, "ɚ": 85, "ɛ": 86, "ɜ": 87, "ɟ": 90, "ɡ": 92, "ɥ": 99, "ɨ": 101,
        "ɪ": 102, "ʝ": 103, "ɯ": 110, "ɰ": 111, "ŋ": 112, "ɳ": 113, "ɲ": 114, "ɴ": 115, "ø": 116, "ɸ": 118,
        "θ": 119, "œ": 120, "ɹ": 123, "ɾ": 125, "ɻ": 126, "ʁ": 128, "ɽ": 129, "ʂ": 130, "ʃ": 131, "ʈ": 132,
        "ʧ": 133, "ʊ": 135, "ʋ": 136, "ʌ": 138, "ɣ": 139, "ɤ": 140, "χ": 142, "ʎ": 143, "ʒ": 147, "ʔ": 148,
        "ˈ": 156, "ˌ": 157, "ː": 158, "ʰ": 162, "ʲ": 164, "↓": 169, "→": 171, "↗": 172, "↘": 173, "ᵻ": 177,
    ]

    static func encode(_ phonemes: String) -> [Int64] {
        phonemes.unicodeScalars.compactMap { ids[Character($0)] }
    }

    /// The model reads at most 510 phonemes at a time. A passage is cut at sentence ends,
    /// then clauses, then spaces; the first piece is kept short so the voice starts quickly.
    static func chunks(_ phonemes: String, first: Int = 160, limit: Int = 400) -> [String] {
        var pieces: [String] = []
        var current = ""
        for character in phonemes {
            current.append(character)
            if ".!?;:".contains(character) { pieces.append(current); current = "" }
        }
        if !current.trimmingCharacters(in: .whitespaces).isEmpty { pieces.append(current) }
        var result: [String] = []
        var buffer = ""
        for piece in pieces.flatMap({ split($0, limit: first) }) {
            let cap = result.isEmpty ? first : limit
            if !buffer.isEmpty && encode(buffer + piece).count > cap {
                result.append(buffer.trimmingCharacters(in: .whitespaces)); buffer = ""
            }
            buffer += piece
        }
        if !buffer.trimmingCharacters(in: .whitespaces).isEmpty { result.append(buffer.trimmingCharacters(in: .whitespaces)) }
        return result
    }

    /// Splits one over-long sentence at commas, then spaces.
    private static func split(_ sentence: String, limit: Int) -> [String] {
        guard encode(sentence).count > limit else { return [sentence] }
        for separator in [",", " "] {
            let parts = sentence.components(separatedBy: separator)
            guard parts.count > 1 else { continue }
            var out: [String] = [], buffer = ""
            for (index, part) in parts.enumerated() {
                let piece = part + (index < parts.count - 1 ? separator : "")
                if !buffer.isEmpty && encode(buffer + piece).count > limit { out.append(buffer); buffer = "" }
                buffer += piece
            }
            if !buffer.isEmpty { out.append(buffer) }
            return out.flatMap { encode($0).count > limit ? hardSplit($0, limit: limit) : [$0] }
        }
        return hardSplit(sentence, limit: limit)
    }

    /// A run with no commas or spaces at all, cut evenly so nothing is dropped.
    private static func hardSplit(_ text: String, limit: Int) -> [String] {
        let characters = Array(text)
        return stride(from: 0, to: characters.count, by: limit).map {
            String(characters[$0..<min($0 + limit, characters.count)])
        }
    }
}

#if canImport(OnnxRuntimeBindings)
/// One Kokoro-82M ONNX session, run on the CPU. Phoneme ids in, 24 kHz mono samples out.
final class KokoroRuntime {
    static let sampleRate = 24_000
    private let env: ORTEnv
    private let session: ORTSession
    private let outputName: String

    init(model: URL) throws {
        env = try ORTEnv(loggingLevel: .warning)
        let options = try ORTSessionOptions()
        try options.setIntraOpNumThreads(Int32(min(max(ProcessInfo.processInfo.activeProcessorCount - 2, 2), 4)))
        try options.setGraphOptimizationLevel(.all)
        session = try ORTSession(env: env, modelPath: model.path, sessionOptions: options)
        outputName = try session.outputNames().first ?? "waveform"
    }

    /// - Parameters:
    ///   - ids: phoneme ids without the padding tokens.
    ///   - pack: the voice's 510 × 256 style table; the row is chosen by length.
    func synthesize(ids: [Int64], pack: [Float], speed: Float) throws -> [Float] {
        guard !ids.isEmpty, pack.count >= 510 * 256 else { return [] }
        let row = min(ids.count, 509) * 256
        let style = Array(pack[row..<(row + 256)])
        let padded: [Int64] = [0] + ids + [0]
        let output = try session.run(withInputs: [
            "input_ids": tensor(padded, type: .int64, shape: [1, NSNumber(value: padded.count)]),
            "style": tensor(style, type: .float, shape: [1, 256]),
            "speed": tensor([speed], type: .float, shape: [1]),
        ], outputNames: [outputName], runOptions: nil)
        guard let value = output[outputName] else { return [] }
        let data = try value.tensorData() as Data
        return data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }

    private func tensor<T>(_ values: [T], type: ORTTensorElementDataType, shape: [NSNumber]) throws -> ORTValue {
        let data = values.withUnsafeBytes { Data($0) }
        return try ORTValue(tensorData: NSMutableData(data: data), elementType: type, shape: shape)
    }
}
#endif

/// Keeps the model, the lexicons and the voice packs loaded across sentences. Loading costs
/// far more than speaking, so it happens once, on first use, off the main thread.
actor KokoroVoiceRuntime {
    static let shared = KokoroVoiceRuntime()
    #if canImport(OnnxRuntimeBindings)
    private var runtime: KokoroRuntime?
    #endif
    private var phonemizers: [Bool: KokoroPhonemizer] = [:]
    private var packs: [String: [Float]] = [:]

    func phonemeChunks(_ text: String, british: Bool) throws -> [String] {
        KokoroVocabulary.chunks(try phonemizer(british: british).phonemize(text))
    }

    func render(_ phonemes: String, voice: String, speed: Float) throws -> [Float] {
        #if canImport(OnnxRuntimeBindings)
        if runtime == nil { runtime = try KokoroRuntime(model: KokoroAssets.modelURL) }
        let start = Date()
        let samples = try runtime?.synthesize(ids: KokoroVocabulary.encode(phonemes), pack: try pack(voice), speed: speed) ?? []
        StudyInteractionTrace.record("voice.runtime backend=kokoro voice=\(voice) phonemes=\(phonemes.count) synthesisMs=\(Int(Date().timeIntervalSince(start) * 1000)) audioMs=\(samples.count * 1000 / KokoroRuntime.sampleRate)")
        return samples
        #else
        throw URLError(.unsupportedURL)
        #endif
    }

    /// Loads the lexicon, the model and the voice ahead of the first sentence.
    func prewarm(_ voice: KokoroVoice) {
        _ = try? phonemizer(british: voice.british)
        _ = try? pack(voice.id)
        #if canImport(OnnxRuntimeBindings)
        if runtime == nil { runtime = try? KokoroRuntime(model: KokoroAssets.modelURL) }
        #endif
    }

    /// Frees the model under memory pressure; it reloads on the next sentence.
    func discard() {
        #if canImport(OnnxRuntimeBindings)
        runtime = nil
        #endif
        packs = [:]
    }

    private func phonemizer(british: Bool) throws -> KokoroPhonemizer {
        if let existing = phonemizers[british] { return existing }
        let prefix = british ? "gb" : "us"
        let lexicon = try KokoroLexicon(gold: KokoroAssets.lexiconURL("\(prefix)_gold.json"),
                                        silver: KokoroAssets.lexiconURL("\(prefix)_silver.json"), british: british)
        let made = KokoroPhonemizer(lexicon: lexicon)
        phonemizers[british] = made
        return made
    }

    private func pack(_ voice: String) throws -> [Float] {
        if let cached = packs[voice] { return cached }
        let data = try Data(contentsOf: KokoroAssets.voiceURL(voice))
        let floats = data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        packs[voice] = floats
        return floats
    }
}
