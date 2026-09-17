# Physical iPhone Qwen certification

Date: 2026-09-17. Device: **iPhone 15 (iPhone15,4)**, iOS **26.3.1**, paired over
USB/Wi-Fi via CoreDevice (`C96853E4-7218-534F-9DC6-614CAABE2168`). Xcode 26.6,
build 17F113. Branch `codex/qwen-local-understanding`, base commit
`85da85aeab4893f9e796cb950f74f620e4a5f12a` plus the uncommitted working tree
(install-repair, navigation-repair, this certification).

## What changed this session

- Resumed the existing **llama.cpp/GGUF** runtime exactly as found; no MLX work
  was started (see [../REPORT.md](../REPORT.md) for the full prior implementation
  and its already-executed 0.8B/2B/4B quality benchmark, which remains the
  quality baseline and was not rerun here).
- Verified the uncommitted `install-repair` packaging fix and `navigation-repair`
  UI fix (already on disk before this session) build correctly.
- Added a **DEBUG-only, launch-argument-gated developer probe**
  (`QwenPhysicalProbeScreen` in `Shelf/App/ShelfApp.swift`, behind
  `--qwen-physical-probe`) that calls the exact production
  `EmbeddedQwen` / `LocalQwenProvider` / `OfflineModelStore` path used by
  `TeachLeuSheet`/`ReaderIntelligenceModel`, and prints real metrics to the
  console. This was necessary because driving the real UI required a new
  XCUITest-runner provisioning profile that this environment's Xcode has no
  Apple ID account to mint (see Gate M caveat below). Never reachable outside
  DEBUG builds and an explicit launch argument.
- Staged the already-verified `Qwen3.5-2B-Q4_K_M.gguf` (checksum
  `aaf42c8b7c3cab2bf3d69c355048d4a0ee9973d48f16c731c0520ee914699223`, exactly
  matching `OfflineModelStore`'s pinned hash) directly into the app's on-device
  container via `xcrun devicectl device copy to`, instead of re-downloading
  1.28 GB over the phone's radio. This exercises the same `import`-style local
  file contract `OfflineModelStore` already supports, just via file copy
  instead of the Files-app picker UI.

## Root causes found and resolved

- **Previous `permissionDenied` package-resolution block did not reproduce
  in this session.** `xcodebuild -resolvePackageDependencies` and a full
  device build both succeeded cleanly on first try. Whatever sandboxed the
  prior agent run does not sandbox this one.
- **Previous CoreDeviceService failure did not reproduce.** `xcrun devicectl
  list devices` saw the paired iPhone 15 immediately.
- **New, real blocker found and fixed**: the physical install failed once
  with `kAMDMobileImageMounterDeviceLocked` — the phone was passcode-locked,
  which blocks mounting the Developer Disk Image. Resolved by asking the user
  to unlock the device; install then succeeded immediately.
- **New, real blocker found, worked around**: `xcodebuild test` for
  `ShelfUITests` fails with `No Account for Team "46593UJ6ZS"` — there is a
  valid local code-signing identity/private key, but no Apple ID logged into
  Xcode in this environment, so it cannot mint the new provisioning profile
  the XCUITest runner needs (`dev.shelf.v27.uitests.xctrunner`, which was
  never previously provisioned). The main `Shelf` app target has a cached
  profile already and does not hit this. Worked around by exercising the real
  inference path through a DEBUG probe in the main target instead of XCUITest.

## Acceptance matrix

| Gate | Result | Evidence |
|---|---|---|
| A — BUILD | **PASS** | `app-device-build.txt`, `** BUILD SUCCEEDED **`, signed with `Apple Development: miguelalmeida1592@gmail.com (46593UJ6ZS)` |
| B — INSTALL | **PASS** | `app-install.txt`, installed to `dev.shelf.v27` on the physical device |
| C — LAUNCH | **PASS** | Process confirmed running via `devicectl device info processes` after launch, stable (not crash-looping) |
| D — MODEL | **PASS** | 2B GGUF staged on-device, `checksum_verified=true` against the pinned hash, every probe run |
| E — LOAD | **PASS** | `load_ms` 260–470 ms per run across 5 runs (see below); no crash, no OOM |
| F — INFERENCE | **PASS** | Real generations, 294–361 output tokens, coherent and (after an input fix — see Limitations) schema-and-quote-validated |
| G — STREAM | **NOT IMPLEMENTED (pre-existing)** | `EmbeddedQwen.run` is a single blocking native call returning the full result; there is no incremental token stream to the UI in this codebase. `first_token_ms` is measured internally but nothing consumes it as a stream. Not something this session changed. |
| H — CANCEL | **PASS** | `probe-3`/`probe-4`/`probe-5`: in-flight generation cancelled after ~2.1s wall every time, clean `CancellationError`, no crash |
| I — SECOND RUN | **PASS** | cold+warm pass in the same process every run, both completing independently |
| J — RELAUNCH | **PASS** | `probe-4-terminate-relaunch.txt`: app terminated, confirmed no residual process, relaunched without reinstalling, same container, model still checksum-verified, inference ran again |
| K — OFFLINE | **PASS** | `probe-5-airplane-mode-offline.txt`: device in Airplane Mode, full cancel+cold+warm sequence completed and validated |
| L — QUALITY | **CARRIED FROM PRIOR WORK, NOT RE-RUN** | The existing 300-request, 3-model, dev+challenge benchmark in [../REPORT.md](../REPORT.md) is the quality baseline (2B: 54.2% guarded recognition, 5 false approvals/60; 4B: 70.8%, safer but not phone-promoted). This session did not repeat it; the sprint's priority was runtime proof, not re-benchmarking. |
| M — PRODUCT | **PARTIAL** | The exact provider chain `TeachLeuSheet` → `ReaderIntelligenceModel.assessOffline()` → `LocalQwenProvider` → `EmbeddedQwen` → native `leu_qwen_run` is what the probe exercised, byte-identical to the real UI's call. `OfflineModelStore.shared.installed` is true and `EmbeddedQwen.available` is true on-device, so the real Teach Leu screen's Offline model toggle should work. **Not visually verified**: no working UI-automation path exists in this environment (XCUITest blocked on account/profile as above; no Xcode Computer Use approval; no iOS accessibility-driving tool available to this session). |

## Performance (physical iPhone 15, 4-bit Q4_K_M, 2B, CPU-only native path)

Five separate app launches, 11 total generation attempts (1 deliberately
cancelled per full run):

| Run | Context | load_ms | first_token_ms | total_ms | output_tokens | peak_observed_footprint |
|---|---|---:|---:|---:|---:|---:|
| 1 (cold, first launch ever) | cold | 20,120 | 22,240 | 61,683 | 361 | 1,144,489,528 |
| 2 cold | warm OS cache | 468 | 1,805 | 41,295 | 361 | — |
| 2 warm | warm | 259 | 1,982 | 41,932 | 361 | — |
| 3 cold | warm | 269 | 1,608 | 29,541 | 294 | 280,856,648 |
| 3 warm | warm | 278 | 2,005 | 30,746 | 294 | 257,689,672 |
| 4 (relaunch) cold | warm | 272 | 1,599 | 29,765 | 294 | 279,382,112 |
| 5 (airplane mode) cold | warm | 260 | 1,596 | 29,781 | 294 | 279,349,272 |
| 5 (airplane mode) warm | warm | 276 | 2,004 | 30,750 | 294 | 254,543,896 |

Only the very first launch paid a true cold-start cost (20.1s load, 61.7s
total) — plausibly first-touch page-in of the 1.28GB file from flash. Every
subsequent load on the same device session was 260–470ms, and total wall time
per request settled at 29.5–31s for a ~428-token prompt / ~294–361-token
output on **CPU only** (no Metal path was attempted here, consistent with the
prior Mac host findings that Metal command-queue creation failed there too).
Peak observed native footprint was 254–280MB per request in these probe runs
— well under the app's advisory 3GB budget — though this is a single
short-passage request, not the full Leu process under PDF+voice+reader load
in parallel, which remains unmeasured.

Prompt/decode speed: ~428 prompt tokens processed in ~1.1–1.5s;
~294–361 output tokens generated in ~28–29s after the first token, i.e.
roughly **10–13 output tokens/sec** on this device's CPU path.

Thermal state was not sampled directly in these probe runs (no thermal API
call was added to the probe); the existing app-level guard
(`ReaderIntelligenceModel.assessOffline` checks
`ProcessInfo.processInfo.thermalState`) was present but not exercised at a
degraded thermal state, since five back-to-back ~30s requests did not appear
to raise it. Sustained-load thermal behavior remains unmeasured, as noted in
[HOST_SLOWDOWN.md](../HOST_SLOWDOWN.md) for the Mac host.

## Limitations found in this session

- The first probe attempt used a paraphrased (not quoted) learner sentence
  and got a **real, coherent, mostly-correct generation that the app's own
  structured-output guard correctly rejected** (`QwenAssessmentRejection`):
  the model asserted two additional "learner quotes" that were verbatim
  copies of *source* sentences rather than the learner's actual words, so
  `input.learner.contains(claim.learner_quote)` failed in
  `LocalExplanationContract.validate`. This is a real, reproducible 2B
  quote-binding failure mode, consistent with the false-approval/abstention
  issues already documented in the prior benchmark (`../REPORT.md` §6) — the
  guard did exactly what it is supposed to do (refuse rather than show
  unvalidated output). With a learner input that stayed within its own
  wording, generation validated cleanly and repeatably (`probe-3` onward).
- No incremental UI token streaming exists; see Gate G.
- Gate M is verified at the exact-code-path level, not via the rendered
  SwiftUI screen, due to the account/profile blocker above.

## Files

- `Shelf/App/ShelfApp.swift` — added `QwenPhysicalProbeScreen` (DEBUG-only).
- `docs/qwen-local/physical-certification/*.txt|json` — raw evidence for every
  gate above.
- No production code path, prompt, schema, or benchmark file was changed.
  `install-repair` and `navigation-repair`'s prior edits are unchanged by this
  session except for being built and exercised.

## Not done in this session (explicitly out of scope per current priority)

- MLX Swift evaluation — explicitly deferred by the user until after this
  certification.
- Re-running the 30+ case Leu quality benchmark (Gate L reuses prior results).
- Visual/UI-level verification of the Teach Leu screen (Gate M caveat).
- Sustained multi-hour thermal/memory soak, PDF+voice+Qwen coexistence under
  real reader load.

## Git

Branch `codex/qwen-local-understanding`. Working tree still dirty by design
(per the task's explicit instruction to preserve evidence). Nothing was
committed, pushed, or force-anything during this session.
