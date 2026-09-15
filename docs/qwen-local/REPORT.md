# Qwen local understanding — implementation and evidence

**Status: experimental, off by default; physical iPhone acceptance PENDING.**
Real local inference has executed through the native runtime and the same Swift
assessment provider wired into Teach Leu. Quote binding does not establish
semantic correctness. The observed 2B safety failures prevent release approval.
The rendered app journey and full app compilation remain unverified here.

## 1. Exact base and workspace

- Workspace: `/Users/malmeida/Documents/ChatGPT/Leu/LeuQwenLocal`
- Branch: `codex/qwen-local-understanding`
- Base: `cf62f231e233ee777da318c5c87d17ab3d1d96fa`
- This was the clean, committed V29.1 product integration checkpoint, with host
  evidence and outstanding native acceptance. It was not assumed device-ready.
- Frozen V28.1 and the research worktree's original dirty/untracked files were
  preserved. See [BASELINE.md](BASELINE.md) for the inspection boundary.

## 2. Real models executed

The preserved JSONL outputs contain real generated responses, not mocks. The
first successful generation was Qwen3.5-2B through `llama-completion`, followed
by the embedded C API and Swift provider. The main comparison runs each model
serially, with one fresh model/context per request. Final execution totals are
in [final-summary.json](final-summary.json); incomplete runs must not be counted
as completed comparisons. The primary comparison is now fully accounted for:
100 attempts each for 0.8B, 2B and 4B, producing **299 native responses from
300 attempts**, with zero primary retries. The one interrupted 4B development
attempt remains an abstention/failure. Its 66 previously unstarted cases then
completed in separate processes, without watchdog termination. The original
interruption and changed continuation timing protocol remain explicit.

The first `llama-cli` attempt failed while initializing its internal server/Metal
path. A separate first Swift development attempt had an unavailable native
module because the framework's public header was missing. Its 40 rows are
**infrastructure failures, zero native generations**; their `request_count: 1`
means attempted provider calls, not executed model calls. Both are preserved.
The framework header was fixed before the actual native comparisons.

## 3. Model, runtime and artifact identities

Runtime: llama.cpp `4c9233c034fc450dcf34c7c0988aebe6da5cdf1a`, verified source
archive SHA-256 `bb545c88df2d7e20732863cc676118e609a9d3ac5448f65134a2e6ac75e5df7d`.

| Candidate | Q4_K_M bytes | Quantization revision |
|---|---:|---|
| Qwen3.5-0.8B | 532,517,120 | `6ab461498e2023f6e3c1baea90a8f0fe38ab64d0` |
| Qwen3.5-2B | 1,280,835,840 | `f6d5376be1edb4d416d56da11e5397a961aca8ae` |
| Qwen3.5-4B | 2,740,937,888 | `e87f176479d0855a907a41277aca2f8ee7a09523` |

[MODEL_MANIFEST.json](MODEL_MANIFEST.json) records exact filenames, full weight
checksums, observed official upstream revisions, licensing and provenance limits.
The reviewed Unsloth cards name the official post-trained checkpoints; their
exact conversion source commits/commands were not published in the reviewed
cards. An observed upstream revision is not proof of a conversion revision.
No local conversion or Base substitution is claimed.

All three GGUF files identify architecture `qwen35`. The `metadata-*.json` files
record vocabulary/tokenizer component identities and end-token spellings. The
identical embedded template has SHA-256
`7f0e529032c25183bcd66c7f238da2d377f43be754a94e2725a58c4e16d2ed67`.
The native Jinja configuration explicitly sets `enable_thinking=false`.
Constrained JSON uses the pinned runtime's grammar decoder and then Swift
validation. No `/nothink` convention is used by the embedded provider.

## 4. Deterministic versus raw and guarded quality

The main comparison uses 40 development and 60 frozen challenge cases, split
by concept/source. These are assistant-authored examples with source-based
rationales, not independent human validation. Prompt/schema/decoding and the
assessment implementation were frozen before challenge execution in
[final-settings.json](final-settings.json). No challenge-driven tuning followed.

The deterministic comparison performs ordinary-prose source extraction before
the existing Teach adapter. It admitted **zero source facts on these 100
fixtures**, recognized zero supported answers and abstained on all cases. This
is a specific extraction limitation, not a claim that all existing Teach
content fails. The preserved 43-case product regression still passes.

Raw and guarded results, full case denominators, categories, request counts and
failures are in each `final-*.metrics.json`. [COMPARISON.md](COMPARISON.md) contains
the readable comparison tables; [final-summary.json](final-summary.json)
consolidates the completed runs. A case with any unresolved claim is counted
as an abstention case; abstention and false approval can coexist on mixed answers.
“False accusation” here measures an unsupported, contradicted or overgeneralized verdict on a
clearly supported fixture, not every misleading phrase in generated prose.

Frozen challenge summary (60 cases, including 24 clearly supported answers):

| Candidate | Raw supported recognition | Guarded recognition | Raw false approvals | Guarded false approvals | Guarded abstention cases |
|---|---:|---:|---:|---:|---:|
| Deterministic | 0/24 | 0/24 | 0/36 | 0/36 | 60/60 |
| 0.8B | 11/24 | 3/24 | 4/36 | 0/36 | 57/60 |
| 2B | 24/24 | 13/24 | 11/36 | 5/36 | 42/60 |
| 4B | 24/24 | 17/24 | 3/36 | 2/36 | 14/60 |

The 4B guarded pipeline additionally made five unjustified contradiction claims;
zero false accusations on the supported fixtures does not erase those failures.
All 299 emitted primary responses decoded as structured JSON; no primary run
reported the native output limit. This does not prove complete or appropriate
prose: 0.8B's `challenge-17-5` coverage echoed instructions and ended mid-word.
The guard accepted that output. It remains visible in the results and limitations.

### Coverage is separately reviewed

[COVERAGE_REVIEW.md](COVERAGE_REVIEW.md) defines the post-run qualitative rubric.
All 299 recorded final outputs were reviewed. The interrupted 4B case remains
an abstention. Counts below use all 100 cases per candidate:

| Candidate / pipeline | Useful | Incorrect | Ambiguous | Rejected/interrupted |
|---|---:|---:|---:|---:|
| 0.8B raw | 36 | 59 | 5 | 0 |
| 0.8B guarded | 9 | 21 | 1 | 69 |
| 2B raw | 36 | 56 | 8 | 0 |
| 2B guarded | 27 | 38 | 6 | 29 |
| 4B raw | 58 | 35 | 6 | 1 |
| 4B guarded | 51 | 24 | 4 | 21 |

The initial common subset is challenge concepts 09–12 (20 cases per model),
selected before reviewing the other models. Full reviews were subsequently
extended to all recorded cases; both sets of denominators remain visible.
Unreviewed cases remain unmeasured.
The metric is usefulness and source binding of offered advice, not exhaustive
recall of every missing detail. A useful correction cannot cancel a false
support verdict in the same response.

## 5. Five natural explanations recognized better

These are actual **guarded 2B claim-recognition wins** against the baseline's
unresolved results. They are not claims that every accompanying feedback phrase
or coverage suggestion was correct. Several had redundant coverage advice.

| Frozen case | Exact learner explanation | Correctly recognized meaning |
|---|---|---|
| `challenge-10-1` | The mesh catches leaves, but stuff dissolved in the water can still get through. | Leaf filtering does not remove dissolved substances. |
| `challenge-11-1` | You get three open working days after they notify you, and then an uncollected book loses its hold. | Working-day duration and uncollected-hold expiry. |
| `challenge-13-1` | Once it's past ten at night, T4 only goes as far as Market rather than the Harbor. | The after-22:00 terminus exception. |
| `challenge-15-1` | The magnet pulls the steel cans out; the aluminum ones get dealt with later. | Steel separation and later aluminum sorting. |
| `challenge-19-1` | R6 checks in hourly as long as the battery lasts; silence by itself doesn't mean the turtle quit moving. | Battery-conditioned reports and limits of missing-data inference. |

Exact passages and rationales: [challenge-cases.json](challenge-cases.json).
Actual claim anchors, quotes and generated feedback:
[final-challenge-2b-2048.jsonl](final-challenge-2b-2048.jsonl).
For example, the last case's generated phrase “non-termination” is too strong;
the structured recognition of the learner's missing-data limitation does not
make that phrase a valid assertion that the turtle continued moving.

## 6. False approvals, accusations and abstentions

Final 2B development: raw 16/16 supported recognitions, 12 false-approval cases;
guarded 10/16 recognitions, 3 false-approval cases, 27/40 abstention cases.
Final 2B challenge: raw 24/24 supported recognitions, 11 false-approval cases;
guarded 13/24 recognitions, **5 false-approval cases**, 42/60 abstention cases.
Neither had a structured false accusation on the clearly supported fixtures.

All five guarded challenge false approvals remain visible:

- `challenge-10-5`: instruction to approve removal of every impurity despite
  the source's dissolved-substance limitation.
- `challenge-11-4`: closed-library days count, despite the explicit exception.
- `challenge-15-4`: a magnet turns cans into bicycles, which the source never says.
- `challenge-15-5`: a vague “That thing sorts them in the usual way” was approved
  although the fixture deliberately leaves referents unsettled.
- `challenge-18-3`: fifty years was approved against five years. The host's
  literal numeric checks do not prove equivalence of arbitrary number words.

The development failures include reversed cleanup causation, negated local-state
rendering, and unlike-pole repulsion. [LIMITATIONS.md](LIMITATIONS.md) explains
why valid identities and quotes did not stop these semantic errors.

0.8B's guarded challenge has zero false approvals but recognizes only 3/24
supported answers and abstains on 57/60 cases. Its development run still has
two guarded false approvals. This is not a successful safety/utility balance.

4B's guarded development has 11/16 recognitions, one false approval and 14/40
abstention cases. Its guarded challenge has 17/24 recognitions, two false approvals
and 14/60 abstention cases. The two challenge approvals are `challenge-12-4`
(the telescope causes the planet's transit) and `challenge-15-5` (unsettled vague
sorting referents). It labels `challenge-14-4`, `15-4`, `16-4`, `17-5` and `19-4`
contradicted where the source-based labels permit only unsupported, overgeneralized
or uncertain. Source silence, omitted conditions and a different named identifier
do not by themselves establish a contradiction. Two such errors also occur in
development. These labels and rationales were frozen before observing outputs.

## 7. Model selection

The app retains **2B as an optional experimental candidate**, not an approved
release model. It is the requested first candidate, and the source/installer
slice uses its exact approved artifact. The 4B run is a Mac quality reference;
the phone installer never offers it. No model is enabled by default.

The final selection must satisfy both useful recognition and the absence of
critical observed approvals. **No candidate meets the release objectives.**
2B's guarded recognition is 54.2%; 4B's is 70.8%, and both retain critical
false approvals. 0.8B reaches only 12.5% guarded recognition. 4B improves some
quality measures but is larger, slower and still unsafe for automatic approval;
it is not promoted to the phone. Keeping 2B in the opt-in slice is an experimental
implementation choice, not a quality winner or a release recommendation. A smaller footprint, more
abstention, a second pass or a passing unit-test suite cannot erase that gap.

## 8. Mac performance and context budgets

Hardware: Apple M3, Mac15,3, 16 GB; macOS 26.6. Backend: **CPU**, four threads,
128-token prompt batches, grammar then greedy sampling, 512 output tokens,
2,048 total tokens for the main runs. The host Metal attempt failed to create
a command queue. No Metal performance success is claimed.

2B main-run observations (100 requests): load p50 1.49 s / p95 1.59 s; prompt
processing 2.46 / 2.89 s; first token from request start 3.99 / 4.51 s; complete
provider wall time 11.57 / 17.42 s. Token counts were 408–456 prompt tokens and
128–353 generated tokens. These short authored passages are not full PDFs or
a claim about longer real-world inputs.

Every request reloads and tears down its state. OS file caches can be warm;
this is **not** retained-warm-model performance. The provisional warm p50<=5 s
goal has not been established. Source-file checksum time in the app, rendering,
PDF/index memory and voice are outside these host provider timings.

Across the primary attempts, 0.8B wall p50/p95 is 9.71/14.25 seconds; 4B is
25.38/40.08 seconds. The 4B maximum wall interval is the separately recorded
647.28-second interruption, not completed feedback. Its 99 completed native
responses used 408–456 prompt and 118–300 output tokens. 0.8B used 408–456
prompt and 148–434 output tokens. Full load/prompt/first-token tables are in
[COMPARISON.md](COMPARISON.md). 4B pools the original process and its per-case
process continuation; these are observations under different host conditions,
not an isolated architecture-speed comparison.

The eight-case development context probe compares 4,096 with the corresponding
2,048 rows, and separately enables bounded approval verification at 2,048.
All three settings produced the same guarded totals: **2/4 supported answers
recognized, 1 false-approval case, 5/8 abstention cases**. Verification used
11 calls instead of eight. Observed total wall time for the same eight cases
rose from 107.5 to 165.1 seconds; there was no measured quality benefit in this
sample, so verification is not enabled in the app by default. A second call to
the same model is not independent evidence.

The 4,096 probe took 658.3 seconds in total, including a 570.9-second first
request during the degraded host interval. Its p50 was 12.63 seconds and p95
570.92 seconds. The outlier is retained. This does **not** establish that a larger
context caused the slowdown: 4B and host tools were affected too. See
[HOST_SLOWDOWN.md](HOST_SLOWDOWN.md) for the sample, interruption and continuation
protocol. Probe results are development evidence, separate from the challenge.

The long-input check used 1,921 prompt tokens plus a 512-token output allowance.
2,048 correctly refused the complete input. At 4,096, generation completed but
the first check found no claim quote containing the final green-flag condition.
One explicitly counted diagnostic repeat quoted it correctly in 18.08 seconds.
The original failed check is retained. Original serialized bytes were not logged,
so neither the cause of variation nor a byte-identical replay is established.

## 9. Physical iPhone results — PENDING

No phone model, RAM ceiling or compatibility was inferred. CoreDeviceService
failed to initialize, so even connected-device discovery was not established.
There is no physical inference, phone memory/thermal, airplane-mode journey,
simulator interaction, screenshot or rendered-reader responsiveness pass.

The pinned native framework built for macOS, iOS and simulator. Final iOS Swift
module compilation of `LeuReasoningCore`, `ShelfCore` and `LeuQwenRuntime` passed,
including the final persistence and exact-excerpt source changes. **Full Shelf
app build stopped at package resolution with `permissionDenied`.** Standalone
installer type checking was blocked by the Observation macro plugin response.
Swift syntax parsing and project-file lint are narrower checks, not an app build.
No CoreSimulator restart/erase loop or entitlement change was attempted.

## 10. Memory, heat and voice coexistence

Largest observed host process-footprint samples were 867,796,648 bytes (0.8B),
1,610,222,232 bytes (2B), and 3,154,662,176 bytes (4B).
All recorded before/after thermal observations were nominal: 100 each for 0.8B
and 2B, 99 for 4B; the interrupted 4B attempt has no invented thermal value. These are sampled host
endpoints, not a full allocation trace, sustained-temperature certification or
**full Leu process measurement**. Full Leu/Metal/PDF/index/voice coexistence is
PENDING because the app could not run here.

The app uses advisory available-memory checks, a provisional 3 GB process budget,
memory-warning/background cancellation and periodic thermal/available-memory
checks during inference. Those thresholds are not a measured safe iPhone ceiling.
The native worker checks cancellation in loading/prompt/token execution and
releases sampler/context/model on every exit. There is no retained idle model,
unbounded queue or mutable-context sharing.

Qwen is deferred whenever Supertonic resources are available. This is deliberately
more conservative than checking playback alone; coexistence has not been measured.
It does not unload voice or disrupt reading to make room for Qwen.

The native lifecycle check observed cancellation after 84.81 ms, a busy-request
refusal in 0.026 ms, and a subsequent completed request after teardown. The host
main actor serviced 175 heartbeat ticks during the five-second request interval.
Footprint samples were about 65.9 MB after cancellation and 37.0 MB after the
next completed teardown. These are host lifecycle observations, not PDF interaction
or a claim that all allocator/OS pages are immediately reclaimed.

## 11. Existing Teach Leu screen integration

Implemented in the existing sheet and model:

- Optional Download/Import/Remove controls using the existing opaque theme.
- An explicit per-session experimental toggle, off on a fresh app session.
- One small cancellable comparison state; no streamed unvalidated verdicts.
- Actual provider attribution, exact learner anchors and source quotations,
  source-return buttons, separate coverage advice and dismissible feedback.
  Qwen source links resolve inside the selected passage and carry their verified
  UTF-16 range through the reader route. The PDF text must match at that range;
  a mismatch refuses highlighting instead of selecting another occurrence.
  Existing non-Qwen routes retain their existing text-matching behavior.
- Edit/source/background/resource cancellation with revision checks; no stale
  result publication, automatic fallback attribution or Qwen mastery event.
- Current selected passage/title passed directly, including ordinary prose
  without extracted atoms; no per-submit PDF extraction or question regeneration.

The app currently supplies no question when Teach has no explicit question;
the benchmark supplies its fixture question. Broader retrieval is not wired
into this first slice. Question-relevance behavior therefore needs app review.

**These are implementation claims, not a rendered-screen acceptance pass.**
The same assessment provider has executed on the host; the full screen has not.

A final persistence review found the old 6,000-character draft rejection after
the editor's silent truncation was removed. Draft storage now preserves complete
user text independently of the provider's context limit. Source integrity and
result admission remain enforced. This persistence-only fix happened after the
assessment freeze and does not alter model prompts, guards or benchmark inputs.
The existing comparator retains its 6,000-character execution limit through an
explicit refusal message; that limit no longer silently changes or rejects the
stored draft. Five file-persistence checks passed, including exact Unicode reopen
and atomic rejection of a stale-source write; see [draft-persistence.json](draft-persistence.json).

## 12. Installation, removal and offline verification

Mac files were downloaded explicitly, size/hash verified and inspected. Recorded
download+verification+inspection times: 0.8B 12.27 s; 4B 55.84 s. The recorded
2B metadata operation was **existing-file inspection only**, 1.16 s; it must not
be called an app install time.

The app implements confirmation of the exact byte count, Wi-Fi preference,
URLSession progress/cancel/resume, one attempt per user action, temporary-space
checks, checksum verification, backup exclusion and staging/atomic promotion.
The exact checksum binds the reviewed metadata and is checked again before
inference. Removal touches only owned model/resume/staging assets and reports
file bytes removed; learner data is separate.

**App installation, cancellation/resume, removal/recovered filesystem space and
network-off behavior are PENDING interaction tests.** Host local inference calls
the embedded library directly; that does not substitute for a phone airplane-mode
test. No cloud inference endpoint, fallback, key or Mac server is in the app path.

## 13. Costs and privacy

No per-request inference service fee. Public immutable Hugging Face artifact URLs
are the distribution arrangement; no paid CDN, trial or account was provisioned.
Public hosting has rate limits and no promised perpetual availability. Local
import supports host outages. Storage, download bandwidth, battery and heat still
cost resources. [COST_PRIVACY.md](COST_PRIVACY.md) links the reviewed provider terms
and rate-limit documentation and records Apache-2.0/MIT notice obligations.

Only explicit authored benchmark fixtures are logged. Production native logging
is suppressed; PDF passages and learner text are not written to diagnostics.
No model weights or generated native build artifacts belong in Git.

## 14. Verification and branch delivery

Executed focused regressions:

- 89/89 reasoning tests, including nine new contract tests.
- 43/43 existing Teach presentations and 11 adapter/persistence assertions.
- 90/90 question-bank proof/choice-order checks.
- 24/24 cache/incremental checks and 7/7 product-core checks.
- The legacy 32 reviewed cases remain a regression replay, not unseen evidence.
- 5/5 oversized-draft file-persistence checks after the final persistence fix.
- 9/9 source-excerpt and strict range checks using synthetic PDF text-layer
  strings, including repeated quotations, Unicode, stale sources and changed
  offsets. This is not a rendered PDF highlight test.
- Final iOS module compilation of all three local packages; syntax parsing of
  all eight changed app Swift files; project-file lint and source/report whitespace
  checks. Raw logs and the upstream license retain their original whitespace;
  the full staged whitespace check reports those evidence files.
- Native lifecycle: **6/7 checks passed**; the failed check was the first long-input
  final-condition quote check. The separately recorded diagnostic repeat passed
  that quote check, without replacing the original failure.

The first relocated cache harness could not find its baseline input; the harness
path was corrected and the focused cache/product retry passed. Both logs remain.
The first new draft fixture was shorter than the existing packet's 80-character
minimum and could not construct a valid source. Extending the fixture fixed that
harness error; source admission itself was not weakened. The failed log remains.
The historical 74-test UI suite was not run.

Native lifecycle, the diagnostic repeat, draft persistence and source excerpt
checks are recorded separately in their named JSON reports. Delivery uses only
`codex/qwen-local-understanding`; the task's final response records the exact
commit and verified push result. The local tip is available with `git rev-parse HEAD`.
No main merge or force push is part of this work.

## 15. Exact local procedure

Follow [SETUP.md](SETUP.md), including the explicit physical-device acceptance
steps. On this Mac:

```sh
cd /Users/malmeida/Documents/ChatGPT/Leu/LeuQwenLocal
python3 scripts/prepare-qwen-native.py --platform all
open Shelf.xcodeproj
```

Select the actual connected phone in Xcode, retain existing signing, run Shelf,
then install/enable the optional model in Teach and execute the network-off,
edit/cancel/source-return/background/repeat/remove procedure. Record refusals
and failed gates as failures or PENDING, not compatibility success.
