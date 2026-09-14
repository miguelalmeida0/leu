# V26 vertical slice — blocked, not release accepted

This checkpoint adds source-path repairs. It does **not** establish a working native vertical slice. New app screenshots: **0**. Successful model responses: **0**. The installed simulator library remains extraction-v3. No library reset or reimport was performed. VIGIA was not modified.

## Changed code

- `PDFDocumentFurniture` recognizes repeated text at consistent page-edge geometry across at least three pages. Read Mode alone filters these lines. Canonical extraction, source provenance and PDF bytes retain them. There is no `SHELF` special case. Two-page documents and inconsistent placements retain their text.
- Reader selections resolve reflowed text back to the canonical PDF range with the existing `SourcePassageMatcher`. Lens receives the exact source substring, including original line breaks. A selection on a different Read page is assigned after navigation, so navigation cannot immediately clear it.
- `SourceExtractionVersion.current` is 4. The existing launch/index check rebuilds older extraction and semantic material. Old-v3 objects are excluded from Study while migration is pending. Objects whose quotes no longer occur on their current source page are also excluded; their stored records remain intact.
- Migration diagnostics record versions and preservation of attempts/confidence records after the repository transaction. Recall and question rendering record source identity.
- Lens requests generation for its selected document/page. An already-running generation can finish before this one bounded pending request. No imported content is sent to a cloud provider.
- Developer diagnostics distinguish attempted calls, responses, acceptance and persistence, and retain the attempted source packet, raw structured candidate, validated question and actual persisted question separately. A failed call stays failed even if availability is `available`.
- The native gate pins the original iPhone Air by default. Its first UI launch runs pages 1–3, page-3 Lens, Study and source return without resetting the library. The visible question must itself carry page-3 model provenance.

[Changed-code patch](../recovery-evidence/v26-vertical-slice/changed-code.patch) contains 25 changed/added paths against this turn's captured `before-source.zip`, including Xcode membership. It is not a Git-base diff and excludes the preceding P0 repair already accepted by the user.

## Actual text and source mapping

The source remains `Shelf/Resources/Samples/React Notes.pdf`, SHA256 `7d42381fcbb2e1c6252457bced1a3970015142adbac4a556fb35d7ab4e318640`.

| Page | Installed v3 | Current production Read Mode extraction |
|---|---|---|
| 1 | `Reac Note`; `sA clearr modl fr Rea` | `React Notes`; `A clearer model for React` |
| 2 | `Stat i snapsho`; `t Setti g stae reques s anothr rende` | `State is a snapshot`; `Setting state requests another render.` |
| 3 | `Key describ identit`; `yA stabe ky hels Reat math n itm` | `Keys describe identity`; `A stable key helps React match an item to its previous instance within a list of siblings.` |

[Full actual before/after text](../recovery-evidence/v26-vertical-slice/actual-before-after.md) includes all three pages and intact code. [Structured output](../recovery-evidence/v26-vertical-slice/read-mode-blocks.json) includes canonical text, Read Mode blocks and canonical Lens source text/ranges. The page ranges are UTF16 `(19,447)`, `(19,469)` and `(19,456)`. PDFKit selection strings equal these canonical substrings exactly.

These checks executed production extraction on **macOS PDFKit**. They are not installed-app screenshots. Three separate generated PDF fixtures passed conservative filtering checks: repeated margins, insufficient pages and inconsistent geometry. Repeated body sentences and unique headings survived.

## Migration and Study trace

The populated library belongs to simulator `A248FB9E-B969-4CF6-A0ED-B2013A3C60A6`, React Notes book `EAD554A9-4A04-4D20-860B-4918CBF2FFD0`.

Its on-disk extraction version is still **3**. Replaying that snapshot through production `LearningRepository` with **mock in-memory persistence**, then indexing the real PDF, produced version **4**. Objects changed from 71 to 83: 12 old derived objects were retained as stale, with 12 repaired objects added. Attempts, confidence records, sessions, Trails, recordings, relationships, masks, timeline and emotional check-ins compared equal. Existing review states were preserved.

The real snapshot contains zero attempts. A separate in-memory regression uses nonempty attempts/confidence data and verifies preservation. Neither proves an installed-library upgrade. The real file-store test failed on a denied write.

The replay verifies that no React objects are eligible before migration, every repaired eligible quote resolves on its canonical page, and none equals an old damaged source. Its actual React-topic Study plan contains repaired text. That plan currently selects the component passage on page 1; this is **not** the requested model question on page 3. See [migration and planner trace](../recovery-evidence/v26-vertical-slice/migration-replay.log) and [serialized replay snapshot](../recovery-evidence/v26-vertical-slice/migration-replay-after.json).

## Real model execution result

| Field | Actual result |
|---|---|
| Backend | Apple Foundation Models, `apple-on-device` |
| Reported availability | `available` |
| Real provider call attempted | YES, once for repaired page 3 in this checkpoint |
| Successful real inference verified | NO |
| Failure | `FoundationModels.LanguageModelSession.GenerationError`, underlying `ModelManagerServices.ModelManagerError 1008` |
| Model-generated candidates | 0 |
| Accepted / rejected candidates | 0 / 0; validator received no candidate |
| Persisted questions / visible model questions | 0 / 0 |
| Raw structured response | None returned |

The production provider received the exact PDF fingerprint, extraction-v4 and the 507-UTF16-unit canonical page-3 packet. The [actual model log](../recovery-evidence/v26-vertical-slice/real-page3-model-run.log) contains the full input and error. Error 1008's cause is not established. No deterministic question, mock or TTS result is counted as inference.

There is an unresolved code limitation beyond the environment: admission still requires a matching deterministic semantic realization and literal extractive choices. It cannot yet admit general novel reasoning questions. The provider schema still requires MCQ choices; the requested model-generated open-recall alternative is not implemented. Lens consumes an accepted same-page question explanation rather than an independently generated Lens result. These remain release blockers even on a target where inference succeeds. No fabricated candidate or weakened semantic assertion was used to fill them.

## Exact verification

| Check | Result |
|---|---|
| Real-PDF Read extraction, pages 1–3 | Passed text/order, furniture, canonical range and unchanged-PDF assertions on macOS |
| Additional furniture fixtures | 3 scenarios passed on macOS |
| Targeted core XCTest | 10 executed: 9 passed, 1 failed on persistence permission denial |
| Existing-library replay | Passed with mock persistence; installed file unchanged |
| iOS core module | Compiled against installed simulator SDK |
| iOS extraction/model services | Scoped production module compiled |
| Targeted native unit tests and UI suite | Typecheck passed; not executed |
| Full app syntax | Parse passed; not a full app typecheck/build |
| Project membership / structural validation / offline check / shell syntax | Passed |
| Native checkpoint execution | Blocked before launch: CoreSimulator connection invalid/refused |
| New Read/Lens/Study screenshots | None |
| Full sweep | Not run |

Original A/B/C provenance remains in [the preceding report](V26_MEGA_INTELLIGENCE_REPORT.md). C's five gesture tests passed in that supplied run. The gesture driver, horizontal pager and both C test files are byte-identical to this checkpoint's baseline; there is no new C runtime result.

[Verification JSON](../recovery-evidence/v26-vertical-slice/verification.json), [core XCTest log](../recovery-evidence/v26-vertical-slice/core-tests.log), [native blocker](../recovery-evidence/v26-vertical-slice/native-checkpoint.log), and [candidate source hashes](../recovery-evidence/v26-vertical-slice/candidate-source-sha256.json) preserve the evidence and its limits.

## Required execution action

Run from a normal local Terminal with Simulator access:

```bash
bash /Users/malmeida/Documents/ChatGPT/Leu/LeuNativeV24_5/scripts/test-v26-p0.sh
```

It retains the existing UI-test library, uses the original iPhone Air unless overridden, stops at the first failed stage, and writes actual `.xcresult` artifacts under `.build/results`. The uninterrupted UI test captures the three reader pages before the Lens/model gate. The returned `.xcresult` is needed for further diagnosis. A skipped unavailable-model test is not acceptance. On an eligible physical iPhone, `LearningRealModelP0Tests` can separately establish whether Foundation Models returns a real candidate.

This task's filesystem policy cannot approve escalation. CoreSimulator access fails here; Computer Use previously denied Simulator access. Those restrictions were not bypassed. The screenshots, automatic in-place migration, successful novel model question/open recall and useful page-3 Lens remain unverified or unfinished.
