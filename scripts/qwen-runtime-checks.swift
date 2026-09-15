import Foundation
import Darwin
import LeuReasoningCore
import LeuQwenRuntime

@main struct RuntimeChecks {
    static func footprint() -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? info.phys_footprint : 0
    }
    @MainActor static func main() async throws {
        let args = CommandLine.arguments
        guard args.count == 3 else { fatalError("qwen-runtime-checks MODEL OUTPUT.json") }
        let model = URL(fileURLWithPath: args[1])
        let output = URL(fileURLWithPath: args[2])
        guard !FileManager.default.fileExists(atPath: output.path) else { fatalError("Refusing to overwrite measurements") }
        let input = LocalExplanationInput(learner: "The cleanup removes the old listener.", question: "What does cleanup remove?", passages: [
            .init(id: "s1", document: "fixture", page: 1, version: "runtime-check-v1", title: "Cleanup",
                text: "The cleanup removes the old listener before the next effect runs.")])
        let payload = String(decoding: try JSONEncoder().encode(input), as: UTF8.self)
        let schema = try LocalExplanationContract.schema(for: input)
        var checks: [[String: Any]] = []
        let before = footprint()
        do {
            _ = try await EmbeddedQwen.shared.run(model: model, system: LocalExplanationContract.prompt,
                input: payload, schema: schema, maximumFootprint: 1, developmentCPUOnly: true)
            checks.append(["name":"memory budget rejects before load","passed":false])
        } catch QwenRuntimeError.memoryBudget { checks.append(["name":"memory budget rejects before load","passed":true]) }
        var ticks = 0
        let heartbeat = Task { @MainActor in
            while !Task.isCancelled { try? await Task.sleep(nanoseconds: 25_000_000); ticks += 1 }
        }
        let active = Task {
            try await EmbeddedQwen.shared.run(model: model, system: LocalExplanationContract.prompt,
                input: payload, schema: schema, maximumFootprint: 7_000_000_000, developmentCPUOnly: true)
        }
        try await Task.sleep(nanoseconds: 150_000_000)
        let busyStart = Date()
        do {
            _ = try await EmbeddedQwen.shared.run(model: model, system: LocalExplanationContract.prompt,
                input: payload, schema: schema, maximumFootprint: 7_000_000_000, developmentCPUOnly: true)
            checks.append(["name":"second request rejected rather than queued","passed":false])
        } catch QwenRuntimeError.busy {
            checks.append(["name":"second request rejected rather than queued","passed":true,"ms":Date().timeIntervalSince(busyStart)*1000])
        }
        try await Task.sleep(nanoseconds: 4_850_000_000)
        let cancelStart = Date(); active.cancel()
        do {
            _ = try await active.value
            checks.append(["name":"ongoing request cancelled","passed":false,"reason":"Completed before cancellation; no cancellation proof" ])
        } catch {
            var cancelled = error is CancellationError
            if let runtime = error as? QwenRuntimeError, case .cancelled = runtime { cancelled = true }
            checks.append(["name":"ongoing request cancelled","passed":cancelled,"error":String(describing:error),"ms":Date().timeIntervalSince(cancelStart)*1000])
        }
        heartbeat.cancel()
        checks.append(["name":"host main actor serviced heartbeat during native work","passed":ticks>100,"ticks":ticks,"note":"Not a rendered-reader interaction test" ])
        let afterCancel = footprint()
        var peak: UInt64 = 0
        do {
            let completed = try await EmbeddedQwen.shared.run(model: model, system: LocalExplanationContract.prompt,
                input: payload, schema: schema, maximumFootprint: 7_000_000_000, developmentCPUOnly: true)
            _ = try JSONSerialization.jsonObject(with: completed.json)
            peak = completed.peakObservedFootprint
            checks.append(["name":"new native request completes after cancellation teardown","passed":true,
                "prompt_tokens":completed.promptTokens,"output_tokens":completed.outputTokens,"ms":completed.totalMilliseconds])
        } catch {
            checks.append(["name":"new native request completes after cancellation teardown","passed":false,"error":String(describing:error)])
        }
        let afterComplete = footprint()
        let longSource = String(repeating: "The ledger has routine entries. ", count: 260) + "Unlocking requires a green flag."
        let long = LocalExplanationInput(learner: "Unlocking requires a green flag.", question: "What does unlocking require?", passages:[
            .init(id:"s1",document:"fixture",page:1,version:"long-context-v1",title:"Ledger",text:longSource)])
        let longPayload = String(decoding: try JSONEncoder().encode(long), as: UTF8.self)
        let longSchema = try LocalExplanationContract.schema(for: long)
        do {
            _ = try await EmbeddedQwen.shared.run(model:model,system:LocalExplanationContract.prompt,input:longPayload,
                schema:longSchema,context:2048,maximumFootprint:7_000_000_000,developmentCPUOnly:true)
            checks.append(["name":"2048 budget refuses full long input","passed":false])
        } catch QwenRuntimeError.inputTooLong { checks.append(["name":"2048 budget refuses full long input","passed":true]) }
        do {
            let large = try await EmbeddedQwen.shared.run(model:model,system:LocalExplanationContract.prompt,input:longPayload,
                schema:longSchema,context:4096,maximumFootprint:7_000_000_000,developmentCPUOnly:true)
            let assessed = try LocalExplanationContract.validate(large.json,for:long)
            checks.append(["name":"4096 preserves the final source condition","passed":assessed.claims.contains{$0.source_quote.contains("green flag")},
                "prompt_tokens":large.promptTokens,"output_tokens":large.outputTokens,"ms":large.totalMilliseconds])
        } catch {
            checks.append(["name":"4096 preserves the final source condition","passed":false,"error":String(describing:error)])
        }
        let report: [String:Any] = ["backend":"Mac CPU","checks":checks,
            "footprint_before":before,"footprint_after_cancel":afterCancel,"footprint_after_completed_teardown":afterComplete,
            "peak_observed_footprint":peak,"device_certification":false,
            "cancellation_phase":"Ongoing request after five seconds; no per-token callback used to identify exact internal phase"]
        try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:output)
        if checks.contains(where: { ($0["passed"] as? Bool) != true }) { exit(1) }
    }
}
