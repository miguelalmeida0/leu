# Shelf V20 — Learning OS Mega Release Report

## A. What changed

Shelf remains a native PDF library/reader, but `Learn` and `Trails` now turn locally extracted PDF material into source-bound study. The release adds local PDF analysis, deterministic topics/questions, learning objects, recall scheduling, time-boxed sessions, confidence calibration, first-degree connections, trails, masks, self-explanation recordings, reconstruction labs, a learning timeline, reader memory markers, optional Blind Page prompts and centralized haptics. No generative AI, backend, account or network study dependency was added.

The wolf-with-book mascot remains the app icon from V19.3.1.

## B. Architecture

See `docs/LEARNING_OS_ARCHITECTURE.md`. The important boundary is: PDF parsing, deterministic generation, memory scheduling, persistence and UI are separate capabilities. `LearningSnapshot` is the persistent projection; `LearningObject` is the central source-linked unit.

## C. Feature matrix

| Mandate | Implemented | Automated coverage | Environment-verified | Limitation / note |
|---|---:|---:|---:|---|
| Learn Today + topics + 5/10/20/30 | Yes | Core planner + V20 UI journey | Static/core here | Simulator/device run required on Mac |
| Local PDF analysis | Yes | Analysis unit tests | Core | Extraction uses PDFKit selectable text |
| Invalidation by fingerprint/parser version | Yes | Repository/analysis logic | Core | Index persistence commits per document, not per page |
| Deterministic topic classification | Yes | Unit tests | Core | Seed vocabularies are intentionally extensible, not universal ontology |
| Manual topic override | Yes | Repository test | Core | User edits per document |
| Deterministic question engine | Yes | Question tests | Core | Skips weak candidates rather than fabricating |
| Definition questions | Yes | Yes | Core | — |
| Cloze/fill-key-concept | Yes | Yes | Core | Requires unique salient source term |
| List membership | Yes | Yes | Core | Requires parseable list/corpus distractors |
| Term-description matching | Yes | Yes | Core | Source-extracted terms only |
| Source-statement identification | Yes | Yes | Core | Source statements are not paraphrased |
| Question quality pipeline | Yes | Quality evaluator test | Core | Heuristic, deterministic quality—not semantic model judgment |
| Learning Objects | Yes | Repository + UI action contract | Core/static | Original text selection exact; Read mode fallback is current reflowed page |
| Cover -> Predict -> Reveal -> Judge | Yes | Scheduler/question UI flows | Static/core | Device interaction feel pending |
| Memory scheduler | Yes | Dedicated deterministic tests | Core | Product state labels, no neurological probability claim |
| PDF memory markers | Yes | Static integration | Static | Physical visual density pending |
| Fading | Yes | Scheduler + Learn projection | Core/static | — |
| Time-boxed session planner | Yes | Planner tests | Core | Duration is approximate by design |
| Confidence calibration / Blind spots | Yes | Attempt persistence | Core/static | Aggregate shown as calm recall prompt, not a score |
| Connections | Yes | Repository persistence + UI entry | Core/static | First-degree readable view only, intentionally no generic graph |
| Knowledge graph foundation | Yes | Relationship domain/persistence | Core | Manually authored edges in V20 |
| Reconstruction lab framework | Yes | Catalog/order tests | Core/static | V1 ships deterministic reconstruction/run sequences, not full bespoke simulators |
| 5 initial interview labs | Yes | Catalog tests | Core | Event Loop, React Identity, HTTP Cache, TS Structural Typing, DB Transaction |
| Diagram Recall masks | Yes | Repository persistence + UI | Core/static | User defines regions; no image understanding |
| Blind Page | Yes | Policy tests | Core | Optional; deterministic spacing/backoff |
| Progressive hints | Yes | Question/source logic | Core | Source-bound; no generated explanation |
| Explain it Yourself audio | Yes | Persistence architecture | Static | AVFoundation device permission/audio quality pending |
| Active Recall scopes | Yes | V20 UI entry + planner | Static/core | PDF/topic/trail/all due |
| Interview Mode | Yes | Planner + UI entry | Core/static | No countdown by default |
| Learning Trails | Yes | Repository persistence + V20 UI create | Core/static | Supports documents/page ranges/objects/questions/labs/masks/connections |
| Learning Twin V1 | Yes | Aggregator logic | Core | Deterministic study-state aggregate only |
| Learning Timeline | Yes | Persistence + V20 UI entry | Core/static | Calm chronology, not an activity feed |
| Source reveal / return | Yes | V20 UI journey authored | Static | Actual XCUITest run pending on user's Mac |
| Central haptic language | Yes | Static architecture contract | Static | Physical signatures require iPhone QA |
| Dynamic Type / Reduce Motion foundations | Yes | Static design implementation | Static | Full accessibility certification requires device/simulator |
| Existing reader preservation | Yes in source | Existing V19 regression suites retained | Not Apple-runtime verified here | Must pass `qa-and-copy.sh` on Mac before release sign-off |
| Offline/no-model contract | Yes | Dedicated static audit | Verified here | Importing from a cloud Files provider may require iOS/provider download before Shelf receives the file |

## D. PDF question engine

Extraction is PDFKit text -> normalized pages -> deterministic source segments. Repeated headers/footers and common line-wrap artifacts are removed; likely headings/lists/definitions/code are classified heuristically. Topic scoring combines title, filename, outline and repeated body terms.

Question candidates are source-bound. Correct answers and distractors originate in extracted source. `QuestionQualityEvaluator` scores clarity, answer uniqueness, option uniqueness, distractor comparability, completeness, topic signal and length/ambiguity penalties. Weak candidates are dropped. IDs and option shuffling are deterministic, so unchanged documents/algorithms produce stable study material.

Image-only/scanned PDFs remain readable but do not receive fabricated questions. OCR/model inference is deliberately absent in V20.

## E. Haptics

See `docs/HAPTIC_MATRIX.md`. One `HapticProviding` interface owns semantics. Standard system feedback handles standard meanings; Core Haptics is reserved for the short Shelf completion signature. The user can disable haptics and adjust intensity.

## F. QA

Container verification completed the portable/core and static gates: **155/155 ShelfCore tests pass**, **199 Swift files syntax-parse**, the Xcode project/source manifest resolves, and the ShelfCore-import, offline/no-model, Learning OS architecture and native UI-contract audits pass. Apple SDK compilation, iOS Simulator XCUITest and signed physical-device behavior cannot be executed in this environment, so V20 is not honestly device-certified until the user runs `./scripts/qa-and-copy.sh` on the Mac and the physical checklist.

The V20 QA runner includes: structural project validation, ShelfCore import boundaries, offline/no-model audit, Learning OS architecture audit, native UI test-contract audit, native Xcode build gate, portable core tests, Apple PDF/viewport tests, retained V19 reader XCUITests and new Learning OS XCUITests.

## G. Visual proof

V20 XCUITests attach screenshots for Learn session, source round-trip, Active Recall setup, Interview setup, Connections, Trail creation, Learning Object actions and persistence. They will be available inside `.build/results/*.xcresult` after the Mac test run. This container cannot render a truthful iOS Simulator screenshot.

## H. Remaining limitations

1. Read-mode learning capture is page-bound rather than an exact user-selected SwiftUI text range; Original/PDFKit selection supports exact selected text and approximate bounds.
2. V20's custom `.shelfbackup` export still covers PDFs, collections, reading positions, bookmarks and notes—not Learning OS state or explanation audio. UI copy now states this explicitly. Normal iOS device backup behavior is separate.
3. Large-document indexing yields off the main actor and is cached by fingerprint/version, but persistence is committed at document completion rather than incremental per-page checkpoints.
4. Reconstruction Labs V1 are polished deterministic reconstruction/run sequences. They are not yet five completely bespoke simulation engines.
5. No OCR for scanned/image-only PDFs by design.
6. Physical haptic quality, microphone contamination, 300+ page performance, full VoiceOver/Dynamic Type/Reduce Motion visual QA and the exact V19 reader gesture behavior require the final real-iPhone pass.

## I. Git

Release branch: `feature/shelf-learning-engine-mega-release`.

The final commit hash and clean-status proof are written to `docs/history/manifests/GIT_INFO.txt` in the downloadable package after the one release commit is created. The package itself omits `.git`.
