import SwiftUI
import LeuQwenRuntime
import LeuReasoningCore

@main
@MainActor
struct ShelfApp: App {
    @State private var container = AppContainer()
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--voice-benchmark") {
                VoiceBenchmarkScreen()
            } else if ProcessInfo.processInfo.arguments.contains("--qwen-physical-probe") {
                QwenPhysicalProbeScreen()
            } else {
                application
            }
            #else
            application
            #endif
        }
    }

    private var application: some View {
            RootView(container: container)
                .preferredColorScheme(.dark)
                .tint(ShelfTheme.accent)
                .onOpenURL { container.library.receive($0) }
    }
}

#if DEBUG
/// Developer-only physical-device acceptance probe. Runs the exact production
/// EmbeddedQwen / LocalQwenProvider path against the already-verified staged
/// model, outside any XCUITest signing requirement, and prints real measured
/// metrics to the console for the certification report. Never shipped: gated
/// on DEBUG and an explicit launch argument, and not reachable from the UI.
struct QwenPhysicalProbeScreen: View {
    @State private var log: [String] = ["Starting physical Qwen probe…"]
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(log.enumerated()), id: \.offset) { Text($0.element).font(.system(.footnote, design: .monospaced)) }
        }.padding() }
        .task { await run() }
    }
    private func emit(_ line: String) { log.append(line); print("[qwen-probe] " + line) }
    private func run() async {
        emit("device_model=\(deviceModelIdentifier()) os=\(UIDevice.current.systemVersion)")
        emit("embedded_available=\(EmbeddedQwen.available)")
        emit("offline_installed=\(OfflineModelStore.shared.installed) model_path=\(OfflineModelStore.modelURL.path)")
        guard OfflineModelStore.shared.installed else { emit("ABORT: model file not staged"); return }
        do {
            try await OfflineModelStore.verify(OfflineModelStore.modelURL)
            emit("checksum_verified=true")
        } catch { emit("ABORT: checksum verification failed: \(error)"); return }
        let passage = LocalExplanationInput.Passage(
            id: "probe-1", document: "physical-probe", page: 1, version: "v1",
            title: "React keys",
            text: "In React, the key prop helps React identify which items in a list have changed, been added, or been removed. Keys should be given to the elements inside an array to give the elements a stable identity. A key only needs to be unique among its siblings, not globally.")
        let input = LocalExplanationInput(
            learner: "Keys should be given to the elements inside an array to give the elements a stable identity. A key only needs to be unique among its siblings, not globally.",
            question: nil, passages: [passage])
        // Cancellation gate: start a real generation, cancel it in-flight, and
        // measure how quickly the native worker actually tears down.
        let cancelStart = Date()
        let cancelTask = Task { try await LocalQwenProvider().assess(input, model: OfflineModelStore.modelURL, maximumFootprint: 3_000_000_000) }
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        cancelTask.cancel()
        let cancelOutcome = await cancelTask.result
        let cancelWall = Date().timeIntervalSince(cancelStart)
        switch cancelOutcome {
        case .failure(let error): emit("cancel_test: cancelled after \(cancelWall)s wall, error=\(error)")
        case .success: emit("cancel_test: completed before cancellation landed, wall=\(cancelWall)s")
        }
        for pass in ["cold", "warm"] {
            let started = Date()
            do {
                let result = try await LocalQwenProvider().assess(input, model: OfflineModelStore.modelURL, maximumFootprint: 3_000_000_000)
                let wall = Date().timeIntervalSince(started)
                let run = result.runs[0]
                emit("\(pass): wall_s=\(wall) load_ms=\(run.loadMilliseconds) prompt_ms=\(run.promptMilliseconds) first_token_ms=\(run.firstTokenMilliseconds) total_ms=\(run.totalMilliseconds) prompt_tokens=\(run.promptTokens) output_tokens=\(run.outputTokens) peak_bytes=\(run.peakObservedFootprint)")
                emit("\(pass)_claims=\(result.assessment.claims.count) coverage=\(result.assessment.coverage.count)")
                for claim in result.assessment.claims { emit("\(pass)_claim: [\(claim.support.rawValue)] \(claim.learner_quote) <- \(claim.source_quote)") }
                emit("\(pass)_raw_json=\(String(decoding: result.raw, as: UTF8.self))")
            } catch let rejection as QwenAssessmentRejection {
                let wall = Date().timeIntervalSince(started)
                let run = rejection.run
                emit("\(pass)_REJECTED after \(wall)s: load_ms=\(run.loadMilliseconds) first_token_ms=\(run.firstTokenMilliseconds) total_ms=\(run.totalMilliseconds) prompt_tokens=\(run.promptTokens) output_tokens=\(run.outputTokens)")
                emit("\(pass)_rejected_raw_json=\(String(decoding: run.json, as: UTF8.self))")
            } catch {
                let wall = Date().timeIntervalSince(started)
                emit("\(pass)_FAILED after \(wall)s: \(error)")
            }
        }
        emit("PROBE_DONE")
    }
    private func deviceModelIdentifier() -> String {
        var systemInfo = utsname(); uname(&systemInfo)
        return withUnsafeBytes(of: &systemInfo.machine) { ptr in
            String(decoding: ptr.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
    }
}
#endif
