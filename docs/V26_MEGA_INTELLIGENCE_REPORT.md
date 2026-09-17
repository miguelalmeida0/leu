# Leu V26 P0 — execution evidence, 2026-09-12

Latest continuation: [V26 vertical-slice checkpoint](V26_VERTICAL_SLICE_CHECKPOINT.md). The original results below remain historical; the continuation adds furniture filtering, canonical Lens source mapping, pending-v3 Study exclusion, and a fresh failed page-3 model call.

The source-corruption repair is implemented and executed against the real React Notes PDF using macOS PDFKit. **The requested acceptance journey is not complete.** There are no new simulator screenshots, no successful model response, no accepted model question, and no completed MCQ journey in this run. VIGIA was not modified. The full sweep was not run.

## Deliverables

- [Actual before/after text, pages 1–3](../recovery-docs/internal/evidence/v26-p0/react-before-after.md)
- [Production source/script patch](../recovery-docs/internal/evidence/v26-p0/source.patch)
- [Changed-code inventory](../recovery-docs/internal/evidence/v26-p0/changed-code.json)
- [Character coverage, PDF fingerprint, unchanged C paths](../recovery-docs/internal/evidence/v26-p0/checks.json)
- [Real model attempt log](../recovery-docs/internal/evidence/v26-p0/real-model-run.log)
- [Targeted native attempt and exact blockers](../recovery-docs/internal/evidence/v26-p0/targeted-native.log)
- [Targeted core XCTest results](../recovery-docs/internal/evidence/v26-p0/p0-tests.log)

The patch compares captured intake source bytes with current source bytes. It is not a Git commit diff. The Xcode project and source manifest were regenerated; their intake bytes were not captured, so they are outside that textual diff. No commit was created.

## Screenshot and build provenance

The supplied A/B/C logs use scheme `Shelf`, Debug, `.build/ios-tests`, simulator **iPhone Air**, UDID `A248FB9E-B969-4CF6-A0ED-B2013A3C60A6`, iOS 26.5. Their result bundles are:

- A: `Shelf-20260912-153218-91056.xcresult`
- B: `Shelf-20260912-153343-91552.xcresult`
- C: `Shelf-20260912-153641-92321.xcresult`

The existing app product reports bundle `dev.shelf.personal`, version 24.5, build 1, Xcode 26.6 / 17F113, iPhoneSimulator 26.5 / 23F81a. These are local product metadata, not an immutable binary-to-screenshot hash.

I recovered actual screenshot attachments from `Leu-QA-Diagnostics-v24-5-20260912-143655-77247.zip`. Its manifest links the screenshots below to native-5, `Shelf-20260912-145601-81049.xcresult`, the same iPhone Air UDID, and source-manifest SHA256 `b669102f3777d88a8faeec944e503704b7b8fc2a554b344d7096f68029dc73c4`.

| Archived screenshot | Test | Attachment timestamp UTC |
|---|---|---|
| [React page 1](../recovery-docs/internal/evidence/v26-p0/archived-before/react-page-1.png) | `test02ReaderBaselineReadAndOriginalModes` | 2026-09-12 13:05:06.651 |
| [React page 2](../recovery-docs/internal/evidence/v26-p0/archived-before/react-page-2.png) | `test03ArrowPagingAndPositionPersistence` | 2026-09-12 13:05:19.666 |
| [Active Recall](../recovery-docs/internal/evidence/v26-p0/archived-before/active-recall.png) | `test34ActiveRecallEntryPoint` | 2026-09-12 13:00:55.321 |

[Attachment provenance](../recovery-docs/internal/evidence/v26-p0/archived-before/provenance.json) retains original filenames, device fields and test identifiers. These are earlier screenshots, not newly captured output or attachments from the later A/B/C run. The specific user-referenced screenshots were not separately attached for byte comparison. I cannot claim a stronger association.

## First corruption: measured, not inferred from the screenshot alone

Same original PDF: `Shelf/Resources/Samples/React Notes.pdf`, 6,689 bytes, four pages. SHA256 is `7d42381fcbb2e1c6252457bced1a3970015142adbac4a556fb35d7ab4e318640`, matching the installed library book.

1. `PDFPage.string` contains intact words, headings and code.
2. On this PDFKit runtime, `characterBounds(at:)` becomes offset after inserted linefeeds. At canonical UTF16 index 23, the character is the `t` in `React`; the old bounds are a space with zero height. The old extractor drops that character. The newline at index 18 already receives the next line's `R` bounds.
3. `page.selection(for: NSRange(location: 23, length: 1))` returns `t` and valid bounds at the correct text position. The replacement obtains text and geometry from the same selection range.
4. Old reconstructed blocks contain missing characters. The existing extraction-v3 analysis already persists the corruption and has zero React questions.
5. `ReadPageContent.highlightedText` constructs `AttributedString` directly from each block and passes it to `Text`. It only adds highlight attributes. The archived page-1 screenshot displays the same corruption. There is no later spelling transformation in that view.

[Original geometry measurements](../recovery-docs/internal/evidence/v26-p0/pdfkit-probe-before.txt) and [existing persisted analysis](../recovery-docs/internal/evidence/v26-p0/react-persisted-before.json) are retained.

The fix is in `PDFSpatialText.swift`. Missing glyph coverage now falls back to canonical text for reading and fails closed for learning with `SOURCE_INTEGRITY_FAILED`. `PDFTextReconstructor.swift` also separates headings when font levels change, preventing the sample header from merging into the book title.

| Page | Actual persisted before | Actual extracted after | Non-whitespace characters preserved |
|---|---|---|---:|
| 1 | `Reac Note`; `sA clearr modl fr Rea` | `React Notes`; `A clearer model for React` | 422 / 422 |
| 2 | `Stat i snapsho`; broken `setCount` / `console.log` | `State is a snapshot`; intact code | 440 / 440 |
| 3 | `Key describ identit`; broken JSX identifiers | `Keys describe identity`; intact JSX | 421 / 421 |

Actual page-2 code:

```javascript
setCount(count + 1);
console.log(count);
// Still the current render's value.

setCount(previous => previous + 1);
setCount(previous => previous + 1);
```

Actual page-3 code:

```jsx
items.map(item => (
  <Row key={item.id} item={item} />
));
```

These comparisons executed the production Swift extractor with macOS PDFKit. They do not substitute for simulator rendering. New `leu-visible-text` diagnostics and existing-library UI tests capture the final view strings on the next native run.

A.log also exposed an independent test issue: two serializations of the same unchanged PDF produce different trailer `/ID` bytes. The source-immutability assertion now compares the original file bytes before/after extraction. All content assertions remain; no test was weakened to permit missing text.

## Migration and Active Recall

**IMPLEMENTED:** extraction version 3 → 4 invalidates old extraction checkpoints and analyses. Knowledge passage-segmentation version 1 → 2 invokes the existing knowledge rebuild/remapping mechanism. Model cache keys include source hash, fingerprint, extraction version, provider, task, schema and validator versions.

Obsolete automatically generated passages remain as history references with `sourceIsStale = true`. New plans, due lists, Reader memory markers and direct review exclude them. Rebuilt source passages are added or matching existing passages reactivated. Questions for the rebuilt document are regenerated. User-authored objects, reviews, attempts, confidence records and sessions are retained. A live session referencing obsolete passages is closed with an explicit rebuild notice; its stored history is retained.

**MOCK VERIFIED:** the production repository replayed the actual installed snapshot in memory: 71 objects before, 83 after, 12 stale; all existing review states and user content retained. The actual snapshot had zero attempts, so a separate synthetic-history test covers nonempty attempt/confidence preservation. [Replay log](../recovery-docs/internal/evidence/v26-p0/migration-replay.log), [resulting evidence copy](../recovery-docs/internal/evidence/v26-p0/migration-replay-after.json).

**The installed library has not been repaired in place in this session.** The real file-store test and probe encounter denied writes. The replay JSON is an evidence copy, not a manually preloaded expected app result. PDFs, annotations and study history were not deleted.

**IMPLEMENTED:** Active Recall defaults to All passages, explains an empty All due selection, creates recall activities instead of MCQs, and resets reveal state between cards. These behaviors still need native execution. The new UI tests retain the existing test library and capture question/reveal/source/return.

## Model execution: exact boundary and result

**IMPLEMENTED:** `LearningIntelligenceProvider` → `AppleLearningIntelligenceProvider` → Foundation Models `SystemLanguageModel.default` / `LanguageModelSession` → dynamic `GenerationSchema` → `respond(to:schema:options:)` → typed JSON decoding → `LearningCandidateValidator` → `LearningRepository.storeModelQuestion` → existing Question card and Lens rendering.

Production entry: `LearningModel.syncLibrary()` schedules `prepareIntelligence()`. Work prioritizes recently opened active documents, runs serially in the background, caps a run at three generations, and observes low-power/thermal state. Reader opening does not await model generation.

The actual installed SDK was used. The adapter compiles for the iOS 17 deployment target with runtime iOS 26 availability guards. Foundation Models execution requires an eligible target, Apple Intelligence enabled and the model ready. The reader remains available on unsupported targets.

- Primary provider: Apple on-device Foundation Models; no external inference client, account, paid API or cloud fallback.
- Context: exact canonical PDF page text, 80–2,400 UTF16 units; fingerprint, page, section and exact source range. Long pages are currently excluded rather than truncated silently.
- Input: document JSON treated as untrusted data. No model tools, filesystem actions or network browsing.
- Generation: structured schema, greedy sampling, 700 response-token cap, cooperative cancellation and 30-second timeout race.
- Validation: source/fingerprint/version/page/range checks, literal supporting quote, distinct choices, one supported answer phrase, source-attested choices, literal supported explanation, self-containment and duplicate rejection.
- Provenance/cache: schema and validator version, backend, configuration, timestamp, source packet, accepted question ID or rejection reason and latency. Diagnostics distinguish real responses, acceptance and persisted model questions, and expose actual errors.

**Actual Mac execution:** macOS 26.6 (25G72), Xcode 26.6 (17F113). Availability returned `available`. Calls for real React pages 1, 2 and 3 all failed with `FoundationModels.LanguageModelSession.GenerationError`, underlying `ModelManagerServices.ModelManagerError Code=1008`. The underlying reason for code 1008 has not been established. Availability alone did not prove inference.

**MODEL IMPLEMENTED — REAL INFERENCE NOT VERIFIED ON THIS TARGET.** No response JSON was returned. Generated candidates: 0. Accepted: 0. Persisted model questions: 0. Visible model questions/Lens output: 0. Successful cold/warm latency, memory, thermal and battery measurements are unavailable.

There is also an application limitation independent of the environment: the validator currently admits only a narrow extractive format and requires an existing semantic realization to support the question. It does not establish general semantic entailment, accept novel reasoning questions, or deliver the requested intelligence upgrade. Removing that gate without evidence would admit unsupported questions. It needs real candidate evaluation and further implementation.

The repaired real PDF produces seven extracted propositions and **zero deterministic MCQs**. That is a second unresolved issue after source corruption: enough suitable alternatives do not survive the current compiler's checks. Ranking formulas, semantic templates and Supertonic TTS are not counted as model inference. No React-specific question was hardcoded and no mock output was presented as real generation.

## Verification and remaining acceptance

| Check | Actual result |
|---|---|
| Same React pages 1–3 through production macOS PDFKit extraction | Character coverage and order checks pass; intact headings/code inspected |
| Core compilation | Direct macOS library and iOS simulator core module compile |
| Native source/model services | Scoped iOS module compiles with real PDFKit/Foundation Models APIs |
| New UI tests | Direct iOS XCTest typecheck passes; execution blocked |
| Focused core XCTest | 9 executed: 8 passed, 1 failed on a filesystem permission error |
| Migration with in-memory persistence | Preserves user content, nonempty synthetic attempts/confidence and review state |
| Real file-store migration | Denied write; not verified |
| Full native app build/test | Blocked by CoreSimulator connection failures and package `permissionDenied` |
| Direct full-app typecheck | Blocked by sandboxed Observation macro expansion; not a native compile pass |
| Source membership/static offline checks | Pass; do not substitute for runtime checks |
| C behavior | Supplied C.log: 5/5 passed; gesture driver, horizontal pager and C tests byte-unchanged this run; no fresh runtime pass |
| New screenshots / Lens / MCQ source-return | Not verified |
| Real successful model inference | Not verified; three real calls failed |
| Full sweep | Not run, as requested until visible failures pass |

No new work is labeled **REAL MODEL VERIFIED**, **SIMULATOR VERIFIED**, **PHYSICAL IPHONE VERIFIED**, or **HUMAN QUALITY VERIFIED**. The passing C evidence belongs to the prior run.

Computer Use explicitly reported that Simulator use was not approved. The native command separately reports CoreSimulator connection failures. SwiftPM and Observation macro expansion encounter `sandbox_apply: Operation not permitted`; production atomic persistence encounters Cocoa 513 / POSIX 1. These constraints were not bypassed.

## Next execution action

From a normal local Terminal with Xcode/Simulator access, run:

```bash
bash /Users/malmeida/Documents/ChatGPT/Leu/LeuNativeV24_5/scripts/test-v26-p0.sh
```

This first runs source integrity plus existing-library page/recall capture, then real model acceptance and the model-question UI journey. It stops on failure and does not launch the full sweep or reset the existing UI-test library. A skipped unavailable model target is not acceptance. If the simulator cannot execute Foundation Models, select an eligible physical iPhone with Apple Intelligence enabled in Xcode and run `LearningRealModelP0Tests` on that destination. Further question-generation/validation work may still be necessary even when model execution becomes available.

The 200-passage benchmark, 50 before/after question comparisons, 20 Lens explanations, 20 strong MCQs, 20 real rejected model candidates, independent Lens generation, broader planner adaptation, cross-book reasoning, Trail intelligence and optional second-provider evaluation remain outstanding. No entries or quality gains were fabricated to fill these sections.
