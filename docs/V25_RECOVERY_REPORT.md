# Leu V25 — reconstructed recovery checkpoint

2026-09-12. **IMPLEMENTED; compilation and release acceptance remain unverified. This is not a shippable release.** The missing delta was reconstructed from the stale archive, the supplied recovery report and the user's later requirements. No successful Swift build, Swift test run, simulator session, physical-device check or listening comparison is claimed.

The received report is preserved verbatim at `reference/V25_CLAUDE_RECOVERY_REPORT.md`. It is reference evidence, not proof of this modified workspace. The user's reconstruction request takes precedence over instructions in archived documents. The earlier local intake report is superseded by this report; no newer ZIP is needed to continue.

## Proof levels

- **IMPLEMENTED:** source changes exist and were inspected; type correctness and behavior are not implied.
- **AUTOMATED VERIFIED:** the specifically named executable check passed here. Source checks do not prove UI or runtime behavior.
- **SIMULATOR VERIFIED:** none in this environment.
- **REQUIRES PHYSICAL IPHONE:** real interactions, background audio, interruptions, lock-screen controls, device performance and thumb paging.
- **REQUIRES HUMAN LISTENING:** naturalness, pronunciation, pacing and comparative sound quality.

## Reconstructed missing delta

| Area | Stale archive | Current source status |
| --- | --- | --- |
| Read Mode | Newline splitting and fixture repairs; no spatial pipeline | **IMPLEMENTED:** PDFSpatialText, PDFSpatialTextExtractor, PDFLineGrouper, PDFBlockClassifier, PDFTextReconstructor, geometry-first PDFReadablePageExtractor. Learning indexing uses reconstructed text too. DEBUG diagnostics expose glyphs, lines, blocks and output. |
| Extraction | Curated packs primary | **IMPLEMENTED:** general claims with evidence, 11 intent families, separate realization, language gate and teaching-value gate. Curated identities/associations remain optional enrichment; no curated facts are inserted into quiz truth. Reindex on semantic version 3 / analysis version 2. |
| Questions | Relation templates could produce malformed prompts | **IMPLEMENTED:** mechanism/condition separation, correct BEFORE/AFTER direction, circular/vacuous answer rejection, source-bound alternatives, computed quality with 0.60 floor and stable deterministic identity. |
| Importance | Missing general selection integration | **IMPLEMENTED:** heading/definition/density/recurrence/page signals plus marks, confusion, Lens usage, Trails, connections, errors and confidence mismatch. Used by compilation, study planning and app question/activity entry points. |
| Evaluation | No 100+ general quality corpus | **IMPLEMENTED:** 112 explicit fixtures across 16 domains; 20 rejection examples; intent, provenance and ranking assertions. Runtime result unavailable. |
| Apple voice | One segment per utterance, adaptive pitch/delays | **IMPLEMENTED:** SpokenSentence, SpokenParagraph, SpeechParagraphBuilder; bounded same-block/page prose paragraphs; default system rate × speed, pitch 1.0, zero extra delay; UTF-16 callback mapping to original sentence/source. Code remains separate. |
| Voice UX | Missing paragraph benchmark/notice | **IMPLEMENTED:** automatic Premium → Enhanced → Compact selection, explicit-choice persistence, Compact notice, DEBUG-only 56-sample A/B screen. No Siri API claim. |
| Supertonic | Fixed model/runtime | **IMPLEMENTED:** cancellation generations, pause during synthesis, stale callback handling and temporary WAV cleanup. Perceptual parameters unchanged. Neural speech remains sentence-granularity because genuine sentence timing is unavailable. |
| Contents | Only page grid restored | **IMPLEMENTED:** stable section IDs, nearest preceding section, centred ScrollViewReader restoration, remembered tab; natural page progress updates section. |
| Lens | Facts/relationships with limited explanation | **IMPLEMENTED:** document/page context, expandable excerpt, bounded source-backed plain meaning and key idea; How it works/Related/Questions disclosure; empty-section omission; ten projection fixtures. |
| Source return | Prefix matching, truncated passage, temporary highlight | **IMPLEMENTED:** complete normalized passage matching and UTF-16 mapping; ambiguous matches fail closed; opens Original mode and retains highlight until navigation. |
| Trails | Required/Optional toggle, weak continuity | **IMPLEMENTED:** ordered typed stops, source/page, persisted position, Continue/Next, save before navigation, Back to Trail, contextual move/remove, add confirmation. Required/Optional removed from UI; legacy property retained for decoding compatibility. |
| Dark Read Mode | Night tokens present with foreground/background overrides | **IMPLEMENTED:** selected Read palette propagated into text/pager. Original page colors preserved; dark surround independent. Persistence test added. |
| Confidence | Equal/44pt/single-line/accessibility stack existed | Preserved; **IMPLEMENTED:** scaled minimum width, fitting 4-column → 2×2 → vertical layouts and UI geometry assertion. Smallest-phone rendering unverified. |
| Original paging | 1.15 axis ratio, velocity thresholds and selection clearing already present | Preserved; added deterministic paging-policy coverage. **REQUIRES PHYSICAL IPHONE** for actual fit/zoom/edge gestures. |

## Build and exact test totals

Xcode 26.6 (17F113) is installed. Generic iOS Simulator Debug clean builds with signing disabled fail with exit 74 during Swift package resolution (`permissionDenied`), before source compilation. Swift itself fails with `permissionDenied`; workspace-local scratch/cache/temp attempts also fail reading generated `output-file-map.json`. CoreSimulator cannot connect to its device set. These are externally blocked gates, not passing builds and not evidence that the source has no compiler errors.

Evidence: `recovery-evidence/v25/native-build-final.log`, `native-build.log`, `full-qa.log`, `independent-suites.log`, `static-results.json`, and `suites/suite-results.json`. Earlier experiments are not counted as additional tests.

| Check | Exact result |
| --- | --- |
| Structural/import/offline/architecture/UI/source-contract gates | **AUTOMATED VERIFIED:** 16 / 16 passed |
| Python regression methods | 105 attempted: **102 passed, 3 failed** |
| Study-repair tools | 27 / 27 passed |
| Settings compile-repair tooling | 14 / 14 passed |
| V24.2 interaction tooling | 17 / 17 passed |
| V24.3 root compile harness | 12 passed / 1 failed (`permissionDenied`) |
| V24.4 Lens compile harness | 10 passed / 1 failed (`permissionDenied`) |
| V24.5 release tooling/harness | 22 passed / 1 failed (`permissionDenied`) |
| ShelfCore XCTest inventory | 235 methods: 212 retained + 23 added; **0 executed here** |
| Apple integration XCTest inventory | 26 methods: 20 retained + 6 added; **0 executed here** |
| UI XCTest inventory | 59 methods: 57 retained + 2 added; **0 executed here** |
| Runtime batch attempts | All 6 attempted; all exit 1 before tests: core; PDF 26; Release 1; other V24 6; Study 5; remaining UI 47 |
| Swift syntax parser | 314 Swift files parsed; 14 findings across 9 files. Changed/new files have no new finding locations; all findings also occur in baseline files. This parser does not type-check or replace the compiler. |

The normal QA script stops at the first failed Swift-backed harness. Remaining source gates and all six runtime batches were therefore executed separately. The 320 inventoried Swift tests are not counted as passed or failed assertions: none began execution. Historical release evidence shipped in the archive does not verify this modified source.

Existing test methods/assertions remain. Exact inventory constants were updated to 26 integration / 59 UI / 47 remaining UI / 85 total native. UI test 51 explicitly opens How it works before its existing fact assertions. The immutable baseline inventory checks remain.

**Legacy fixture migration:** `PDFIntegrationTests.testReadableModeRepairsKnownExtractionSeamsWithoutChangingSourcePDF` retains every existing content assertion, including JAVASCRIPT, MENTAL MODELS, IN ONE BREATH, FOLLOW-UP and footer exclusion. Its ambiguous text-only input was replaced with a real PDF containing individual glyph drawing runs, measurable word gaps and an isolated numeric footer. A source-byte integrity assertion was added. This supplies the geometry the replacement architecture needs without restoring fixture-specific repairs or removing assertions. Runtime success remains unverified.

## Read Mode examples

These are expectations encoded in new native tests, not observed PDFKit output here:

- Adjacent real PDF drawing runs `18 — HTT` + `P Hea` + `ders` should form heading `18 — HTTP Headers` through glyph positioning.
- Two columns on shared Y coordinates should read the complete left column before the right column.
- `1. Open the socket` and `2. Send the frame` retain numbering and separate list entries.
- Monospaced `const values = await Promise.all(tasks);` remains code; measured indentation is retained within code blocks.
- `well-known` stays hyphenated. Soft hyphens join; printed line-end hyphens are removed only if the complete word is independently attested on that page.
- All 24 bundled PDF pages are included in reconstruction coverage; it has not executed here.
- Exact source routing uses a generated PDF and asserts unchanged original bytes and unique whitespace-normalized matching.

There is no global spellchecker or technology-word repair map. Text-only fallback conservatively preserves lines. Missing text layers, incorrect glyph bounds, three-plus-column layouts, tables, rotated text, mathematics and ambiguous reading order remain limitations. No OCR was added.

## Trail walkthrough

Expected flow: create “Networking foundations” → add a source-backed HTTP caching stop → receive title/document/page confirmation → add another stop → Continue → save selected stop ID → open source → Back to Trail → retain current stop/list → Next → save/open next available stop. Moving preserves identity; removing adjusts position; missing references are skipped during resume. Empty Trails explain an ordered path and offer Add. Required/Optional no longer asks for an unsupported decision.

The new UI test covers creation/addition/Continue/Back; core tests cover persisted position and routing. They remain unexecuted. Page-range stops provide page context rather than invented text. An ambiguous text match displays a location failure instead of highlighting another passage.

## Voice benchmark status

Launch Debug with `--voice-benchmark`. The 56 samples cover prose, punctuation, abbreviations, identifiers, code, URLs, lists and multi-sentence material. Switching voice/sample replays the selected text. Apple voices show actual installed tiers. F1 shows model-defined sample rate and actual clamped speed; missing assets show unavailable state. The screen is DEBUG-only with no normal production entry point.

Apple paragraph callbacks supply real sentence positions. Supertonic does not, so no guessed timing was introduced. Pause/resume, sentence navigation, background/interruption behavior, remote controls, resource use and installed voice tiers require runtime checks. Old stored identifiers cannot establish whether selection was implicit or manual; without the new explicit-choice flag, migration uses automatic selection.

## Remaining release work

1. Compile with functioning SwiftPM/CoreSimulator, repair compiler errors and run the complete inventory. No compiler failure can be ruled out by static checks.
2. Execute the 112-fixture corpus and inspect actual questions/options. Same-family source-backed distractors may still be true in another context; arbitrary-prose unique correctness is not proven. Application/debugging extraction is bounded, not a general reasoning engine.
3. Execute the migrated legacy geometry fixture and new PDF tests against bundled and arbitrary imported files.
4. **REQUIRES PHYSICAL IPHONE:** smallest screen and Dynamic Type; Contents 18 → reopen → progress to 24; Trail return; dark persistence; Original swipes left/right, short/long, slow/fast, zoomed/fit, edge/centre, first/last; background/interruption/remote audio and latency.
5. **REQUIRES HUMAN LISTENING:** same-sample Apple Compact/Enhanced/Premium-if-installed versus F1, including code, clause boundaries and long passages. Record device, OS, actual voice, rate, model revision and repeated trials.

Local verification:

```sh
cd /Users/malmeida/Documents/ChatGPT/Leu/LeuNativeV24_5
SHELF_QA_LOG=qa-v25-recovery.log ./scripts/qa-and-copy.sh
```

If the front gate fails, collect independent results with `SHELF_QA_RUN_DIR=recovery-evidence/local-suites python3 scripts/run-qa-suites.py`. An incomplete log is not green.

## Archive comparison and package

Input SHA-256: `22056b577cae129ea244655a265994e9b4203c4ede22a16990c4eb2e3afa6b6b`. `V25_CHANGED_FILES.md` lists exact added/changed/deleted paths; `V25_ARCHIVE_COMPARISON.json` supplies hashes against archive bytes. This is an archive comparison, not a Git diff. The folder is untracked in the parent workspace; no commit was made.

The checkpoint excludes caches, DerivedData, installed syntax tooling and executable build products. It includes source, tests, reports and execution logs. `SOURCE_SHA256SUMS.txt` binds packaged files excluding itself. Full question/Lens examples and the tuning matrix follow; their proof boundaries are explicit.


## V25 source-inspected examples

These are expected realizations inspected against the implementation and fixture sources, **not captured Swift execution output**. The Swift test process is blocked by `permissionDenied`. They illustrate the intended quality; runtime emission, bank membership, distractor quality and aggregate fixture success remain unverified. The 112-fixture corpus covers 16 domains and records meaningful concepts, incidental concepts, allowed intents and invalid properties. Multiple-choice generation additionally requires at least two distinct source-backed alternatives in the same relation/intent family; a valid open question can therefore be absent from a small document's bank.

## 30 questions and their source-bound answers

Each row corresponds to an explicit sentence in `QuestionQualityCorpus.swift`. Answers preserve the source claim, including its conditions. No external subject facts are inserted by the realizer.

| # | Expected question | Answer from fixture |
| --- | --- | --- |
| 1 | What must happen before a microtask runs? | the current script completes |
| 2 | What does an index prevent? | a full table scan on the filtered column |
| 3 | How does authorization differ from authentication? | authorization determines what an identity may access |
| 4 | What condition causes a deadlock? | two transactions each wait for a lock held by the other |
| 5 | How does Memoization work? | storing results under their input keys |
| 6 | What does an iterator return? | successive values from a collection |
| 7 | What does Event delegation depend on? | propagation through ancestor elements |
| 8 | What does Strict equality prevent? | implicit type conversion |
| 9 | What is meant by closure? | a function together with its lexical environment |
| 10 | What happens after a preflight request runs? | the cross-origin request is sent |
| 11 | Under what condition does an idempotent method guarantee the same intended effect? | the request is repeated |
| 12 | What does a redirect result in? | a request to a different location |
| 13 | What condition causes a repaint? | visible pixels need updating |
| 14 | How does Compositing work? | combining already painted layers |
| 15 | How does Backpressure prevent an unbounded buffer? | slowing the producer |
| 16 | How does a stream pipeline work? | connecting producers to consumers |
| 17 | If a request times out, what behavior should you expect from a retry loop? | A retry loop retries |
| 18 | How does DNS work? | resolving host names through a hierarchy of servers |
| 19 | Why does Congestion control reduce traffic? | overloaded paths drop packets |
| 20 | How do Prepared statements prevent SQL injection? | parameterization |
| 21 | How does a covering index avoid a table lookup? | containing every required column |
| 22 | What trade-off should you consider when using Indexes? | Indexes accelerate reads but add maintenance work during writes |
| 23 | How does a password hash protect against password disclosure? | storing a one-way digest |
| 24 | Under what condition does Encryption guarantee confidentiality? | the key remains secret |
| 25 | What does Binary search require? | the input array to be sorted |
| 26 | How would you reconstruct the steps for Binary search? | First inspect the midpoint, then retain the half containing the target |
| 27 | How does a load balancer work? | distributing requests among healthy servers |
| 28 | What condition causes a cache stampede? | many clients regenerate the same expired value |
| 29 | How does Request coalescing reduce duplicate work? | sharing an in-flight computation |
| 30 | How does an idempotency key prevent duplicate effects? | identifying repeated operations |

Canonical concept names have no initial article; source spelling/capitalization is otherwise retained to avoid lowercasing identifiers. Capitalization in mid-sentence common nouns remains an editorial limitation. These examples are appropriate for introductory recall; they do not establish senior-level discrimination or reliable application reasoning. DEBUGGING currently asks for the observed behavior under an explicit condition, rather than inventing a troubleshooting procedure.

## 20 rejected candidates

The test supplies answer “stored data” and concept “cache” for language-gate isolation. Reasons below describe the violated property; the gate returns its first matching reason.

| Candidate | Reason |
| --- | --- |
| What does A microtask happen after? | Capitalized subject article |
| What does An index prevent or require? | Mixed predicate and capitalized article |
| What does this source contrast with authentication? | Unresolved reference / source filler |
| What follows from A deadlock? | Capitalized subject article |
| What does it mean? | Unresolved “it” |
| Why does this work? | Unresolved “this” |
| What happens here? | Unresolved “here” |
| What do they require? | Unresolved “they” |
| What does that cause? | Unresolved “that” |
| What does a cache prevents? | Broken auxiliary/verb agreement |
| According to this source, what is caching? | Source filler |
| How does {subject} work? | Template artifact |
| What completes ___ in a cache? | Template artifact |
| What is <concept> used for? | Template artifact |
| Which definition | Incomplete question |
| Why? | Insufficient standalone context |
| What is stored data? | Leaks the supplied answer |
| What does the above prevent? | Unresolved location reference |
| How do those relate? | Unresolved “those” |
| What do these require? | Unresolved “these” |

A separate teaching-value gate also rejects circular definitions and bare categories such as “Caching is a technique.” Grammar alone is insufficient. Neither gate is a general natural-language grammar checker.

## 10 differentiated Lens projections

These are expected projections from `LensDifferentiationV25Tests`. Each composed sentence retains its proposition ID, original document ID, page and source text. Definition paraphrases change only the copula; other rows retain source wording. Questions appear under progressive disclosure.

| Passage / key idea | What this says | Question |
| --- | --- | --- |
| React effects | React effects rerun when a dependency changes identity. | If a dependency changes identity, what behavior should you expect from React effects? |
| Reconciliation | Reconciliation means the process of comparing interface descriptions to choose updates. | What is meant by Reconciliation? |
| HTTP caching | HTTP caching reduces origin requests by reusing fresh responses. | How does HTTP caching reduce origin requests? |
| authorization | Unlike authentication, authorization determines what an identity may access. | How does authorization differ from authentication? |
| Indexes | Indexes accelerate reads but add maintenance work during writes. | What trade-off should you consider when using Indexes? |
| transaction | A transaction means a unit of work committed atomically. | What is meant by transaction? |
| microtask | A microtask runs after the current script completes. | What must happen before a microtask runs? |
| Binary search | Binary search requires the input array to be sorted. | What does Binary search require? |
| CSS grid | CSS grid works by arranging content in rows and columns. | How does CSS grid work? |
| Distributed caching | Distributed caching reduces origin load by serving shared cached responses. | How does Distributed caching reduce origin load? |

Lens composition is limited to three same-subject claims from the selected passage. Unrelated source/document facts cannot become its plain meaning. Empty meaning/examples are omitted. This is bounded deterministic composition, not a general document summarizer.


## Supertonic source audit and listening matrix

Status: **IMPLEMENTED** for lifecycle changes; **REQUIRES HUMAN LISTENING** for sound quality. Values below were inspected in local source. No model was downloaded, no waveform was auditioned, and no measured comparison is claimed.

| Parameter | Current value | Expected effect | Safe range / constraint | A/B procedure |
| --- | --- | --- | --- | --- |
| Model identity | `supertone-oss-archive/supertonic-3`, pinned revision `aafc6e32416a594460b32413efc49d7fe4ce6d46` | Fixes the implementation/assets being compared | Retain pin until a separately validated model change | Record revision with every result |
| Speaker | F1 style | Voice identity and prosody | F1 only in this implementation; other styles unvalidated | Same sample, Apple voice versus F1 |
| Sample rate | Read from `tts.json` → `ae.sample_rate` | Correct duration and playback pitch | Use model rate verbatim; numeric installed value not observed | Inspect installed config and WAV header, record both |
| Amplitude | Gain 1; clamp samples to −1…1; PCM16 ×32767 | Clips outliers; no loudness normalization | Keep unchanged; no empirically validated alternate gain | Compare clipping count, peak/RMS and perceived loudness at fixed volume |
| Speed | Caller clamps requested multiplier to 0.82…1.4; normal request is 1.0. Runtime default 1.03 is overridden by caller | Changes predicted duration | Existing implementation bounds, not a validated quality range | Replay 0.85 / 1.0 / 1.15 with same text; benchmark displays actual clamp |
| Duration | `max(0.15, predictedDuration / max(0.72, speed))` | Minimum duration and speed scaling | Leave unchanged pending listening | Compare short and long corpus items, inspect truncated endings |
| Synthesis steps | 8 | Compute/quality tradeoff | Retain 8; alternate step counts unvalidated | After baseline listening, compare one step count at a time and record latency |
| Resampling | None | Preserves model waveform timing | No rate relabeling | Verify WAV rate equals model rate |
| Chunk size | `base_chunk_size × chunk_compress_factor`, from model config | Latent length quantization | Model-defined; do not tune independently | Record loaded config and output duration |
| Silence | No extra app-inserted pre/post delay | Model determines internal pauses | Do not trim blindly | Listen to clause boundaries and measure first/last non-silent sample |
| Stitching / crossfade | No waveform stitching or crossfade | Sentence requests remain discrete | No guessed timing/crossfade | Compare multi-sentence Apple paragraph with sequential neural sentences |
| Playback / buffering | Entire waveform synthesized before `AVAudioPlayer`; no `AVAudioEngine` scheduling | Startup/inter-sentence gap includes synthesis | Preserve until latency measured | Record request, waveform-ready, playback-start/end times on phone |
| Runtime initialization | Four ONNX sessions created per request; 2 intra-op threads | Potential startup cost | Optimization requires memory/latency evidence | Cold and warm repetitions on same device |
| Randomness | Gaussian latent initialization is nondeterministic | Replays may vary even at identical settings | Do not call repeats sample-identical audio | Repeat each condition several times; log distributions |

This recovery changes cancellation generations, pause-during-synthesis behavior, stale completion handling and temporary WAV cleanup. It does not tune model weights, speaker, steps, gain, sample rate or perceptual parameters.

The debug-only `--voice-benchmark` screen contains 56 text samples. It shows raw and normalized text, the actual selected Apple voice/tier or Supertonic F1, speed, replay and sample switching. Apple Enhanced/Premium choices appear only when installed. Unavailable Supertonic assets are reported without substituting Apple audio. Apple paragraph range callbacks drive sentence highlighting; Supertonic remains sentence-granularity because this runtime supplies no sentence timestamps.

**REQUIRES PHYSICAL IPHONE:** real background playback, interruption, lock-screen commands, memory pressure and latency. **REQUIRES HUMAN LISTENING:** all claims about naturalness, intelligibility, pronunciation, fatigue, pauses and relative Apple/Supertonic quality. No Siri voice access is claimed.


<!-- exact-path-inventory -->
## Exact added and changed paths

28 added, 50 changed, 0 deleted compared with the stale archive. Generated checksum/comparison files and execution logs are accounted separately. This is a byte comparison, not a Git diff.

## Added

- `Packages/ShelfCore/Sources/ShelfCore/Domain/ContentsLocation.swift`
- `Packages/ShelfCore/Sources/ShelfCore/Domain/SourcePassageMatcher.swift`
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Semantic/ConceptImportanceModel.swift`
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Semantic/GeneralClaimExtractor.swift`
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Semantic/QuestionRealizer.swift`
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Semantic/SourceMeaningComposer.swift`
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Sessions/TrailNavigation.swift`
- `Packages/ShelfCore/Sources/ShelfCore/Voice/Compilation/SpeechParagraphBuilder.swift`
- `Packages/ShelfCore/Tests/ShelfCoreTests/Learning/GeneralExtractionV25Tests.swift`
- `Packages/ShelfCore/Tests/ShelfCoreTests/Learning/LensDifferentiationV25Tests.swift`
- `Packages/ShelfCore/Tests/ShelfCoreTests/Learning/NavigationV25Tests.swift`
- `Packages/ShelfCore/Tests/ShelfCoreTests/Learning/QuestionQualityCorpus.swift`
- `Packages/ShelfCore/Tests/ShelfCoreTests/Voice/SpeechParagraphV25Tests.swift`
- `Shelf/Development/VoiceBenchmarkCorpus.swift`
- `Shelf/Infrastructure/PDF/PDFBlockClassifier.swift`
- `Shelf/Infrastructure/PDF/PDFLineGrouper.swift`
- `Shelf/Infrastructure/PDF/PDFSpatialText.swift`
- `Shelf/Infrastructure/PDF/PDFTextReconstructor.swift`
- `Shelf/Learning/TrailAddSheet.swift`
- `Shelf/Voice/UI/VoiceBenchmarkScreen.swift`
- `Shelf/Voice/UI/VoiceQualityNotice.swift`
- `ShelfTests/PDFReconstructionV25Tests.swift`
- `ShelfUITests/ShelfRecoveryV25UITests.swift`
- `docs/V25_IMPLEMENTATION_CHECKLIST.md`
- `docs/V25_QUESTION_AND_LENS_EXAMPLES.md`
- `docs/V25_RECOVERY_REPORT.md`
- `docs/V25_SUPERTONIC_TUNING_MATRIX.md`
- `docs/reference/V25_CLAUDE_RECOVERY_REPORT.md`

## Changed

- `Packages/ShelfCore/Sources/ShelfCore/Learning/Analysis/DocumentAnalyzer.swift`
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Domain/LearningSnapshot.swift`
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Domain/Relationships.swift`
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Persistence/LearningRepository.swift`
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Questions/DeterministicQuestionEngine.swift`
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Semantic/SemanticCompiler.swift`
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Semantic/SemanticModels.swift`
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Semantic/SemanticQuestionCompiler.swift`
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Sessions/StudySessionPlanner.swift`
- `Packages/ShelfCore/Sources/ShelfCore/Voice/Compilation/SpeechCompiler.swift`
- `Packages/ShelfCore/Sources/ShelfCore/Voice/Domain/SpeechModels.swift`
- `Shelf.xcodeproj/project.pbxproj`
- `Shelf/App/AppContainer.swift`
- `Shelf/App/ShelfApp.swift`
- `Shelf/Features/Library/LibraryModel.swift`
- `Shelf/Features/Library/LibraryState.swift`
- `Shelf/Features/Reader/Components/ReadHorizontalPager.swift`
- `Shelf/Features/Reader/Components/ReadPageContent.swift`
- `Shelf/Features/Reader/ReadablePage.swift`
- `Shelf/Features/Reader/ReaderContentsSheet.swift`
- `Shelf/Features/Reader/ReaderModel+Lens.swift`
- `Shelf/Features/Reader/ReaderModel+Reading.swift`
- `Shelf/Features/Reader/ReaderModel.swift`
- `Shelf/Infrastructure/PDF/PDFReadablePageExtractor.swift`
- `Shelf/Infrastructure/PDF/PDFSessionController.swift`
- `Shelf/Infrastructure/PDF/ReaderSpeechController.swift`
- `Shelf/Learning/Components/UnderstandingLensFactRow.swift`
- `Shelf/Learning/LearningModel+Objects.swift`
- `Shelf/Learning/LearningModel+Sessions.swift`
- `Shelf/Learning/LearningModel.swift`
- `Shelf/Learning/QuestionCardView.swift`
- `Shelf/Learning/Services/PDFLearningIndexer.swift`
- `Shelf/Learning/Services/PDFTextExtractor.swift`
- `Shelf/Learning/TrailDetailScreen.swift`
- `Shelf/Learning/UnderstandingLensFact.swift`
- `Shelf/Learning/UnderstandingLensSheet.swift`
- `Shelf/Support/AppPreferences.swift`
- `Shelf/Voice/Engine/AppleSpeechEngine.swift`
- `Shelf/Voice/Engine/SupertonicSpeechEngine.swift`
- `Shelf/Voice/UI/VoicePlayerStrip.swift`
- `Shelf/Voice/UI/VoiceSettingsSheet.swift`
- `Shelf/Voice/Voices/VoiceDescriptor.swift`
- `Shelf/Voice/Voices/VoicePreferenceStore.swift`
- `ShelfTests/PDFIntegrationTests.swift`
- `ShelfUITests/ShelfWorldClassUITests.swift`
- `evidence/project-manifest.json`
- `scripts/sync-xcode-sources.py`
- `scripts/test-study-repair-tools.py`
- `scripts/test-v244-lens-compile.py`
- `scripts/test-v245-release.py`

## Deleted

None.

## Generated outputs

- `SOURCE_SHA256SUMS.txt`
- `docs/V25_ARCHIVE_COMPARISON.json`
- `docs/V25_CHANGED_FILES.md`

