import Foundation
import SpikeKit
import SpikeFoundation

// THROWAWAY — V37 capability spike only. Prints counts and statuses only, never learner text, so
// the same commands are safe on blind sets. See spikes/v37/runner/README.md.

struct Failure: Error, CustomStringConvertible { let description: String }

let usage = """
usage: spike-runner <command> [options]
  availability                         Apple model availability (no generation)
  hash --prompts DIR                   the prompt-set SHA-256 (for the freeze manifest)
  dry-run --inputs FILE --prompts DIR [--keys FILE]
                                       render every request, check the 3,500-token budget (no model call)
  answer-keys --inputs FILE --prompts DIR --out FILE --details FILE [--model apple|fake]
  read --inputs FILE --keys FILE --prompts DIR --out FILE.jsonl --device NAME --run N
       [--model apple|fake] [--only ID,ID] [--limit N] [--overwrite]
"""

var options: [String: String] = [:]
let arguments = Array(CommandLine.arguments.dropFirst())
var index = 1
while index < arguments.count {
    let name = arguments[index]
    if name == "--overwrite" { options["overwrite"] = "1"; index += 1; continue }
    guard name.hasPrefix("--"), index + 1 < arguments.count else { print(usage); exit(2) }
    options[String(name.dropFirst(2))] = arguments[index + 1]
    index += 2
}

func option(_ name: String) throws -> String {
    guard let value = options[name] else { throw Failure(description: "missing --\(name)\n" + usage) }
    return value
}

func url(_ name: String) throws -> URL { URL(fileURLWithPath: try option(name)) }

func appleAvailability() -> String {
    #if canImport(FoundationModels)
    if #available(macOS 26.0, iOS 26.0, *) { return FoundationModelsEngine.availability() }
    return "unavailable: needs macOS 26"
    #else
    return "unavailable: Foundation Models is not part of this platform (the runner was built without it)"
    #endif
}

func model() throws -> SpikeModel {
    switch options["model"] ?? "apple" {
    case "fake": return FirstChoiceModel()
    case "apple":
        #if canImport(FoundationModels)
        if #available(macOS 26.0, iOS 26.0, *), FoundationModelsEngine.availability() == "available" { return FoundationModelsEngine() }
        #endif
        throw Failure(description: "Apple's model is not available: \(appleAvailability())")
    default: throw Failure(description: "unknown --model (apple or fake)")
    }
}

func inputs() throws -> SpikeInputFile {
    try JSONDecoder().decode(SpikeInputFile.self, from: Data(contentsOf: try url("inputs")))
}

func keys() throws -> [String: SpikeAnswerKey] {
    guard options["keys"] != nil else { return [:] }
    return try JSONDecoder().decode(SpikeAnswerKeyFile.self, from: Data(contentsOf: try url("keys"))).keys
}

func write<T: Encodable>(_ value: T, to file: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(value).write(to: file)
}

/// Every request rendered with its schema; the largest estimate per call type, and how many exceed the budget.
func dryRun() throws {
    let file = try inputs(), prompts = try PromptSet(directory: try url("prompts")), keys = try keys()
    var reading = 0, opinion = 0, answerKey = 0, over = 0, empty = 0, missingKeys = 0
    for input in file.cases {
        if input.segments.isEmpty { empty += 1; continue }
        if !keys.isEmpty, keys[input.targetKey] == nil { missingKeys += 1 }
        let key = keys[input.targetKey]
        let r = Requests.estimatedTokens(prompts.reading, Requests.reading(input, key: key), SpikeSchemas.reading(input, key: key).rendered)
        // The largest second opinion this case could need: eight pairs of its longest statements.
        let longestA = (input.claims.map(\.text) + input.neighbours.map(\.definition)).max { $0.count < $1.count } ?? ""
        let longestB = input.segments.map(\.text).max { $0.count < $1.count } ?? ""
        let pairs = Array(repeating: (a: longestA, b: "a reason the student gives for \"\(longestB)\": \"\(longestB)\""), count: 8)
        let o = Requests.estimatedTokens(prompts.secondOpinion, Requests.opinion(pairs), SpikeSchemas.opinion(items: 8).rendered)
        let k = Requests.estimatedTokens(prompts.answerKey, Requests.answerKey(input), SpikeSchemas.answerKey(input).rendered)
        reading = max(reading, r); opinion = max(opinion, o); answerKey = max(answerKey, k)
        if max(r, o, k) > Settings.promptBudget { over += 1 }
    }
    print("dry-run set=\(file.set) cases=\(file.cases.count) targets=\(Set(file.cases.map(\.targetKey)).count) empty=\(empty)"
          + " missingKeys=\(missingKeys) promptSHA=\(prompts.sha)")
    print("estimated prompt tokens (max): reading=\(reading) secondOpinion(8 pairs)=\(opinion) answerKey=\(answerKey)"
          + " budget=\(Settings.promptBudget) casesOverBudget=\(over)")
}

@MainActor func answerKeys() async throws {
    let file = try inputs(), pipeline = SpikePipeline(model: try model(), prompts: try PromptSet(directory: try url("prompts")))
    var targets: [String: SpikeInput] = [:]
    for input in file.cases where targets[input.targetKey] == nil { targets[input.targetKey] = input }
    var result: [String: SpikeAnswerKey] = [:], details: [SpikeKeyDetail] = []
    for (number, target) in targets.keys.sorted().enumerated() {
        let (key, detail) = await pipeline.compileKey(targets[target]!)
        result[target] = key; details.append(detail)
        print("answer-key \(number + 1)/\(targets.count) status=\(key.status) kept=\(key.mistakes.count) proposed=\(detail.proposed)"
              + " compile=\(detail.compileStatus) \(detail.compileLatencyMs)ms selfCheck=\(detail.selfCheckStatus)")
    }
    try write(SpikeAnswerKeyFile(keys: result), to: try url("out"))
    try write(details, to: try url("details"))
}

@MainActor func read() async throws {
    let file = try inputs(), keys = try keys(), out = try url("out")
    let pipeline = SpikePipeline(model: try model(), prompts: try PromptSet(directory: try url("prompts")))
    guard let run = Int(try option("run")) else { throw Failure(description: "--run must be a number") }
    let device = try option("device")
    // A run restarts from the beginning (PREREGISTRATION §5): never append to an earlier run.
    if FileManager.default.fileExists(atPath: out.path), options["overwrite"] == nil {
        throw Failure(description: "\(out.path) exists; a run is never resumed (pass --overwrite to restart it)")
    }
    var cases = file.cases
    if let only = options["only"] { let ids = Set(only.split(separator: ",").map(String.init)); cases = cases.filter { ids.contains($0.caseID) } }
    if let limit = options["limit"].flatMap(Int.init) { cases = Array(cases.prefix(limit)) }
    let unkeyed = cases.filter { keys[$0.targetKey] == nil && !$0.segments.isEmpty }.count
    if unkeyed > 0 { print("warning: \(unkeyed) cases have no answer key for their target (read with no likely mistakes)") }
    _ = FileManager.default.createFile(atPath: out.path, contents: nil)
    let handle = try FileHandle(forWritingTo: out)
    defer { try? handle.close() }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    var calls = 0
    for (number, input) in cases.enumerated() {
        let record = await pipeline.read(input, key: keys[input.targetKey], device: device, run: run, processCallIndex: calls,
                                         osBuild: ProcessInfo.processInfo.operatingSystemVersionString)
        calls += (record.reading.status == "empty" ? 0 : 1) + (record.secondOpinion.map { $0.status == "none" ? 0 : 1 } ?? 0)
        try handle.write(contentsOf: try encoder.encode(record) + Data("\n".utf8))
        print("read \(number + 1)/\(cases.count) reading=\(record.reading.status) opinion=\(record.secondOpinion?.status ?? "-")"
              + " total=\(record.totalLatencyMs)ms")
    }
}

do {
    switch arguments.first {
    case "availability"?: print(appleAvailability())
    case "hash"?: print(try PromptSet(directory: try url("prompts")).sha)
    case "dry-run"?: try dryRun()
    case "answer-keys"?: try await answerKeys()
    case "read"?: try await read()
    default: print(usage); exit(2)
    }
} catch {
    FileHandle.standardError.write(Data("error: \(error)\n".utf8))
    exit(1)
}
