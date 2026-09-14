#if canImport(OnnxRuntimeBindings)
import Accelerate
import Foundation
import OnnxRuntimeBindings

struct SupertonicConfig: Codable {
    struct AE: Codable { let sample_rate: Int; let base_chunk_size: Int }
    struct TTL: Codable { let chunk_compress_factor: Int; let latent_dim: Int }
    let ae: AE
    let ttl: TTL
}

struct SupertonicVoiceStyle: Codable {
    struct Component: Codable { let data: [[[Float]]]; let dims: [Int]; let type: String }
    let style_ttl: Component
    let style_dp: Component
}

struct SupertonicStyle { let ttl: ORTValue; let dp: ORTValue }

final class SupertonicRuntime {
    let sampleRate: Int
    private let cfg: SupertonicConfig
    private let indexer: [Int64]
    private let env: ORTEnv
    private let durationSession: ORTSession
    private let encoderSession: ORTSession
    private let vectorSession: ORTSession
    private let vocoderSession: ORTSession
    private let style: SupertonicStyle

    init(root: URL, voiceStyle: URL) throws {
        let configURL = root.appendingPathComponent("tts.json")
        cfg = try JSONDecoder().decode(SupertonicConfig.self, from: Data(contentsOf: configURL))
        indexer = try JSONDecoder().decode([Int64].self, from: Data(contentsOf: root.appendingPathComponent("unicode_indexer.json")))
        sampleRate = cfg.ae.sample_rate
        env = try ORTEnv(loggingLevel: .warning)
        let options = try ORTSessionOptions()
        try options.setIntraOpNumThreads(2)
        durationSession = try ORTSession(env: env, modelPath: root.appendingPathComponent("duration_predictor.onnx").path, sessionOptions: options)
        encoderSession = try ORTSession(env: env, modelPath: root.appendingPathComponent("text_encoder.onnx").path, sessionOptions: options)
        vectorSession = try ORTSession(env: env, modelPath: root.appendingPathComponent("vector_estimator.onnx").path, sessionOptions: options)
        vocoderSession = try ORTSession(env: env, modelPath: root.appendingPathComponent("vocoder.onnx").path, sessionOptions: options)
        style = try Self.loadStyle(voiceStyle)
    }

    func synthesize(_ rawText: String, speed: Float = 1.03, steps: Int = 8) throws -> [Float] {
        let text = preprocess(rawText)
        let scalarIDs = text.unicodeScalars.map { scalar -> Int64 in
            let i = Int(scalar.value)
            return i < indexer.count ? indexer[i] : -1
        }
        guard !scalarIDs.isEmpty else { return [] }
        let ids = try tensor(scalarIDs, type: .int64, shape: [1, NSNumber(value: scalarIDs.count)])
        let maskValues = [Float](repeating: 1, count: scalarIDs.count)
        let mask = try tensor(maskValues, type: .float, shape: [1, 1, NSNumber(value: scalarIDs.count)])

        let durationOutput = try durationSession.run(withInputs: ["text_ids": ids, "style_dp": style.dp, "text_mask": mask],
                                                     outputNames: ["duration"], runOptions: nil)
        var duration = try floats(durationOutput["duration"]!).first ?? 0.2
        duration = max(0.15, duration / max(0.72, speed))
        let encoded = try encoderSession.run(withInputs: ["text_ids": ids, "style_ttl": style.ttl, "text_mask": mask],
                                             outputNames: ["text_emb"], runOptions: nil)["text_emb"]!

        let chunkSize = cfg.ae.base_chunk_size * cfg.ttl.chunk_compress_factor
        let latentLength = max(1, Int(ceil(Double(Int(Float(sampleRate) * duration)) / Double(chunkSize))))
        let latentDim = cfg.ttl.latent_dim * cfg.ttl.chunk_compress_factor
        var latent = gaussian(count: latentDim * latentLength)
        let latentMask = [Float](repeating: 1, count: latentLength)
        let totalStep = try tensor([Float(steps)], type: .float, shape: [1])
        let maskTensor = try tensor(latentMask, type: .float, shape: [1, 1, NSNumber(value: latentLength)])

        for step in 0..<steps {
            let x = try tensor(latent, type: .float, shape: [1, NSNumber(value: latentDim), NSNumber(value: latentLength)])
            let current = try tensor([Float(step)], type: .float, shape: [1])
            let output = try vectorSession.run(withInputs: [
                "noisy_latent": x, "text_emb": encoded, "style_ttl": style.ttl,
                "latent_mask": maskTensor, "text_mask": mask,
                "current_step": current, "total_step": totalStep
            ], outputNames: ["denoised_latent"], runOptions: nil)
            latent = try floats(output["denoised_latent"]!)
        }
        let final = try tensor(latent, type: .float, shape: [1, NSNumber(value: latentDim), NSNumber(value: latentLength)])
        let output = try vocoderSession.run(withInputs: ["latent": final], outputNames: ["wav_tts"], runOptions: nil)
        let waveform = try floats(output["wav_tts"]!)
        return Array(waveform.prefix(min(waveform.count, Int(Float(sampleRate) * duration))))
    }

    private func preprocess(_ raw: String) -> String {
        var text = raw.decomposedStringWithCompatibilityMapping
        text = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.hasSuffix(".") && !text.hasSuffix("?") && !text.hasSuffix("!") { text += "." }
        return "<en>\(text)</en>"
    }

    private func gaussian(count: Int) -> [Float] {
        var result: [Float] = []; result.reserveCapacity(count)
        while result.count < count {
            let u1 = max(Float.random(in: 0...1), 0.0001)
            let u2 = Float.random(in: 0...1)
            let radius = sqrt(-2 * log(u1))
            result.append(radius * cos(2 * .pi * u2))
            if result.count < count { result.append(radius * sin(2 * .pi * u2)) }
        }
        return result
    }

    private func tensor<T>(_ values: [T], type: ORTTensorElementDataType, shape: [NSNumber]) throws -> ORTValue {
        let data = values.withUnsafeBytes { Data($0) }
        return try ORTValue(tensorData: NSMutableData(data: data), elementType: type, shape: shape)
    }

    private func floats(_ value: ORTValue) throws -> [Float] {
        let data = try value.tensorData() as Data
        return data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }

    private static func loadStyle(_ url: URL) throws -> SupertonicStyle {
        let style = try JSONDecoder().decode(SupertonicVoiceStyle.self, from: Data(contentsOf: url))
        func make(_ component: SupertonicVoiceStyle.Component) throws -> ORTValue {
            let flat = component.data.flatMap { $0.flatMap { $0 } }
            let data = flat.withUnsafeBytes { Data($0) }
            return try ORTValue(tensorData: NSMutableData(data: data), elementType: .float,
                                shape: component.dims.map { NSNumber(value: $0) })
        }
        return SupertonicStyle(ttl: try make(style.style_ttl), dp: try make(style.style_dp))
    }
}
#endif
