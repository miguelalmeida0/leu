**Status: corrected patch applied; native certification OPEN. Nothing committed or pushed.**

Checkout: `/Users/malmeida/Documents/ChatGPT/Leu/LeuNightFieldContrast`.
Input patch/report were extracted from `/Users/malmeida/Downloads/files (3).zip`.
`leu-bugfix-20260914.patch` in this folder is the original Claude patch, not the corrected final diff.
`before-sha256.json` records the pre-application source; `changed-files.json` records the modified/new source and hashes.

| Bug | Root cause / evidence boundary | Claude change retained | Corrections | Native result |
|---|---|---|---|---|
| Original paging | The gesture gate checked fit-page magnification only. A page fitted to width can exceed that scale while having no horizontal area to pan. This is proven in the code; the original screenshot was not supplied here. | Compare scaled page width with viewport; use `atFit || horizontallyContained`; preserve native pan above viewport width. | Added an iOS PDFView regression test for width containment and wider zoom. | NOT RUN. Fit page / Fit width swipe / wider-pan screenshots are missing. |
| Malformed quiz/recall | Explicit PDFKit spaces override geometric gaps in tracked labels. The old heading token limit can also merge spaced labels into paragraphs. Separately, fresh indexing reproduced mnemonic clauses becoming factual answers after losing the paragraph's MEMORY prefix. The reported giant option's provenance remains UNKNOWN. | Geometric tracked-label handling, heading counting, analogy exclusion, length cap, duplicate recall title suppression. | Narrow study instructions; retain paragraph/section role through semantic extraction, packets and objects; add final MCQ admission at compilation, model admission and repository boundaries; invalidate old derived banks. | NOT RUN. No five native question screenshots. Fresh host indexing and deterministic tests are evidence only for the available edition and tested rules. |
| Degraded page | Claude carried degraded page numbers as metadata but still admitted text to analysis; resumed checkpoints also needed the exclusion state. | Continue other pages; use canonical PDFKit text; background failures use a quiet notice/trace. | Persist `spatialIntegrityPassed`; retain canonical text but no segments on degraded pages; reject claims, packets, questions and study objects; guard Lens entry/restoration. Existing Explain readable-page integrity guard remains intact. | Deterministic exclusion PASS; iOS integration test NOT RUN. Background-modal journey missing. |
| Voice | Runtime/session creation was repeated for each utterance, and the transport rendered the Apple voice-quality notice. | Compact transport, notice in settings only, cached Supertonic runtime. | Actor serializes runtime creation/use/eviction; key includes model root and voice style; retain runtime during background playback; evict on memory warning; backend notice follows the active engine. Add reuse/load/utterance trace. | Voice Swift module compiles for iOS with actual ONNX headers. Apple playback, Supertonic inference/reuse and compact-strip screenshots NOT RUN. No complete installed Supertonic assets found in the inspected app locations. |

**A — degraded-page intelligence exclusion: PASS for deterministic checks; native gate OPEN.**

The exclusion flows through `SourcePageInput` (including Codable extraction checkpoints), `AnalyzedPage`, `DocumentAnalyzer`, both semantic-compiler passes, `LearningSourcePacket`, candidate validation, repository question/object admission and `LearningSnapshot.studyObjects`. `PDFLearningIndexer` binds the extractor's degraded page IDs to input eligibility before analysis. A forged segment on a degraded page is also rejected by the semantic compiler.

Reading/search remain separate: original PDFKit text is retained as canonical/normalized text. `PDFPageSearch` and import-time `PDFInspector`/`BookTextIndex` still use original `PDFPage.string`; they were not changed. No PDF is deleted. The new iOS integration test checks that a valid neighboring page still yields claims and learning objects.

**B — instruction filter: PASS, 6 reject / 3 technical second-person examples retained.**

There is no blanket you/your/yours/yourself filter. Matching is based on actual study/UI commands and reader-guide structure. The supplied six study instructions reject, while the setState/browser-cache/object-mutation sentences do not. Existing V2 source/negation/qualifier validation remains enabled.

**C — extraction migration: deterministic PASS; file-store/native execution OPEN.**

`SourceExtractionVersion.current` changes from 4 to 5. Existing version checks queue reindexing and discard incompatible extraction checkpoints. Extraction-version-bound model/explanation cache keys no longer load old-version content.

On repository open, outdated derived questions and semantic indexes are removed. Automatic objects are retained by ID but marked stale until eligible current extraction can bind them again. Old analyses and canonical/search text remain while reindexing is pending. User-authored objects, attempts, confidence records, review states, sessions, relationships and trails remain. PDF storage, annotations and notes are not modified.

`migration-memory-probe.log` exercises a populated bank: **212 questions → 0; 1 semantic index → 0**, with nonempty learner records preserved and a second migration producing no changes. This is a deterministic in-memory result. `migration-probe.log` records the separate real-file-store attempt failing with sandbox error 513/EPERM while writing `learning.next.json`; it is not a persistence pass.

**D — option quality path: reported giant-option root cause UNRESOLVED.**

The current production fresh path is `PDFLearningIndexer → SemanticCompiler → SemanticQuestionCompiler.make → QuestionOptionQuality → FinalMCQAdmission → LearningRepository.upsertAnalysis`. `DeterministicQuestionEngine.generate` delegates to this compiler; its older private option builders are not reached by that entry point. The real-model V2 path also retains deterministic realization/validation and now passes the final surface gate before storage.

Before this correction, repository load accepted already-persisted question banks without rerunning option checks. That is a demonstrated admission gap, but is **not proof that the reported screenshot came from that gap**. Neither inspected simulator bank contained the reported question. The report's quoted prompt also does not exactly match the current or supplied snapshot realizer. The original screenshot and affected persisted record are still required to identify the exact producer.

The shared final gate checks option count/uniqueness, known section labels, study instructions/mnemonic markers, option-length ratio/lexical answer cues, and source quote containment within an eligible page. Semantic/V2 claim entailment remains a separate required upstream responsibility; the surface gate alone cannot prove distractor plausibility. Diagnostics include `path=semantic`, question ID, page, option word counts and rejection reason. No quality floor was lowered.

Fresh PDF indexing found and corrected a concrete additional mnemonic leak in the available 64-page manual:

| Before paragraph-role correction | After |
|---|---|
| `What is meant by DOM?` → `the live cake sitting on the table that you can cut and decorate` (p.45) | This mnemonic-derived question is absent. |
| `What is meant by HTTPS?` → `whispering through a locked tube` (p.5) | This mnemonic-derived question is absent. |
| 212 compiled questions | 181 compiled questions; every surviving question passes the final surface gate. |

Evidence: `available-manual-before-memory-correction-analysis.json`, `available-manual-before-memory-correction-questions.json`, `available-manual-analysis.json`, `available-manual-questions.json`, `index-probe.log`.

This is **not a full question-quality certification**: the available edition still exposes generic subjects such as `What does an array method that create?` and distractor plausibility needs review. Those are recorded as unresolved, not presented as good example questions. React Notes p.3 retains **two selectable V2 questions accepted by the unchanged source validator** after actual host PDF indexing; this replay is not model inference.

The local `javascript_midlevel_interview_field_manual.pdf` has **64 pages**. It lacks the specified IN ONE BREATH / MAKE IT STICK / REAL EXAMPLE labels and cannot contain the reported p.194. `geometry-before-after.json` has no tracked-label matches in this edition. No tracked-label screenshot certification is claimed from synthetic geometry tests.

**E — voice lifecycle.**

Existing playback uses AVAudioSession playback and the app declares background audio. Therefore no scene-inactive/background eviction was added. Memory pressure queues eviction on the same actor as synthesis; AVAudioPlayer owns its generated PCM independently. Runtime identity includes voice style as well as model location. `ios-module-VoiceBugfix.log` is a compile result only; load latency, reuse frequency and audible behavior remain unmeasured.

**Verification counts and evidence.**

| Gate | Current result | Evidence |
|---|---|---|
| Targeted actual ShelfCore host XCTest | **58 executed, 0 failures** | `deterministic-tests.log`, `host-targeted-verification.log` |
| Full current ShelfCore | **OPEN; 286 tests expected** | Earlier intermediate full attempt executed 285 with 63 assertion failures, including filesystem denials and a seed-persistence regression subsequently corrected. `host-verification.log`; later checkpoint subset's 7 assertions are environment failures in `host-checkpoint-environment-failures.log`. Neither is a current full-suite pass. |
| iOS ShelfCore module | PASS | `ios-module-ShelfCore.log`, `ios-module-build.log` |
| iOS voice module including ONNX branch | PASS | `ios-module-VoiceBugfix.log` |
| Full iOS app module / Xcode build | BLOCKED | `ios-module-Shelf.log`: sandbox-exec prevents Apple macro process. `native-build-attempt.log`: CoreSimulator POSIX 61 and temporary package-lock denial. No Package.resolved deletion attempted. |
| New native integration tests | NOT RUN; 3 expected | `ShelfTests/BugfixIntegrationTests.swift` |
| Full ShelfTests | NOT RUN; 92 expected | Prior unmodified baseline 89/89 is in `docs/design/question-contract-v2/native-20260913-132621/full-shelf-report.json`. |
| Full UI | NOT RUN; 74 expected | Native runner selects the entire ShelfUITests target. |
| Study DEFAULT / AX1 | NOT RERUN; existing **7/7 and 4/4** preserved | `docs/design/study-home-evidence/native-20260913-121420/` summaries/attachments. Study Home and Night Field production sources unchanged. |
| Session convergence | NOT RERUN; existing **13/13** preserved | `docs/design/session-convergence/native-20260913-121148/session-unit-summary.json`. Only requested duplicate recall title suppression changed in recall presentation. |
| Contrast | **55/55 PASS** | `contrast.log` |
| Structural/native membership | PASS; 565 project objects / 462 source-script files | `validate.log` |

The three new native tests were added to the existing Xcode project and `evidence/project-manifest.json`. Existing valid-source test fixtures now use the current extraction version; their assertions were retained. The old source-sync script does not parse Xcode's reformatted project text, so project membership was applied surgically and validated; the native runner does not invoke that script.

**Native handoff and remaining work.**

From this checkout, run `bash scripts/verify-bugfix-integration.sh`. It compiles once, then runs full core tests, targeted native tests, ShelfTests, session regressions, Study DEFAULT/AX1 and full UI. It exports summaries/attachments, rejects skipped tests and checks exact counts. `--resume <evidence-directory>` reuses completed build/results only when source hashes match. Regression passes alone do not certify the affected-PDF journeys.

Unresolved: native build/execution; actual affected PDF and original screenshots/persisted giant-option record; all requested gesture/background/voice journeys; five generated-question simulator screenshots; tracked-label measurements on the correct edition; actual file-store migration; Supertonic assets/inference/reuse timing; remaining generic-question/distractor quality in the available edition. No affected library has been cleared and no user PDF/history has been deleted.

**Changed files.**

- modified [Shelf/Learning/LearningModel.swift](/Users/malmeida/Documents/ChatGPT/Leu/LeuNightFieldContrast/Shelf/Learning/LearningModel.swift)
- modified [Shelf/Learning/RecallCardView.swift](/Users/malmeida/Documents/ChatGPT/Leu/LeuNightFieldContrast/Shelf/Learning/RecallCardView.swift)
- modified [Shelf/Infrastructure/PDF/PDFZoomState.swift](/Users/malmeida/Documents/ChatGPT/Leu/LeuNightFieldContrast/Shelf/Infrastructure/PDF/PDFZoomState.swift)
- modified [Shelf/Infrastructure/PDF/PDFReaderSurface.swift](/Users/malmeida/Documents/ChatGPT/Leu/LeuNightFieldContrast/Shelf/Infrastructure/PDF/PDFReaderSurface.swift)
- modified [Shelf/Infrastructure/PDF/PDFSessionController.swift](/Users/malmeida/Documents/ChatGPT/Leu/LeuNightFieldContrast/Shelf/Infrastructure/PDF/PDFSessionController.swift)
- modified [Shelf/Infrastructure/PDF/PDFLineGrouper.swift](/Users/malmeida/Documents/ChatGPT/Leu/LeuNightFieldContrast/Shelf/Infrastructure/PDF/PDFLineGrouper.swift)
- modified [Shelf/Infrastructure/PDF/ReaderSpeechController.swift](/Users/malmeida/Documents/ChatGPT/Leu/LeuNightFieldContrast/Shelf/Infrastructure/PDF/ReaderSpeechController.swift)
- modified [Shelf/Voice/UI/VoicePlayerStrip.swift](/Users/malmeida/Documents/ChatGPT/Leu/LeuNightFieldContrast/Shelf/Voice/UI/VoicePlayerStrip.swift)
- modified [Shelf/Voice/UI/VoiceSettingsSheet.swift](/Users/malmeida/Documents/ChatGPT/Leu/LeuNightFieldContrast/Shelf/Voice/UI/VoiceSettingsSheet.swift)
- modified [Shelf/Voice/Engine/SupertonicSpeechEngine.swift](/Users/malmeida/Documents/ChatGPT/Leu/LeuNightFieldContrast/Shelf/Voice/Engine/SupertonicSpeechEngine.swift)
- modified [Shelf/Features/Reader/ReaderModel+Lens.swift](/Users/malmeida/Documents/ChatGPT/Leu/LeuNightFieldContrast/Shelf/Features/Reader/ReaderModel+Lens.swift)
- modified [Shelf/Learning/Services/PDFLearningIndexer.swift](/Users/malmeida/Documents/ChatGPT/Leu/LeuNightFieldContrast/Shelf/Learning/Services/PDFLearningIndexer.swift)
- modified [Shelf/Learning/Services/PDFTextExtractor.swift](/Users/malmeida/Documents/ChatGPT/Leu/LeuNightFieldContrast/Shelf/Learning/Services/PDFTextExtractor.swift)
- modified [ShelfTests/ExplainLikeTenFeatureTests.swift](/Users/malmeida/Documents/ChatGPT/Leu/LeuNightFieldContrast/ShelfTests/ExplainLikeTenFeatureTests.swift)
- added [ShelfTests/BugfixIntegrationTests.swift](/Users/malmeida/Documents/ChatGPT/Leu/LeuNightFieldContrast/ShelfTests/BugfixIntegrationTests.swift)
- modified [ShelfTests/ExplanationAdversarialTests.swift](/Users/malmeida/Documents/ChatGPT/Leu/LeuNightFieldContrast/ShelfTests/ExplanationAdversarialTests.swift)
- modified [ShelfTests/ExplanationPersistenceTests.swift](/Users/malmeida/Documents/ChatGPT/Leu/LeuNightFieldContrast/ShelfTests/ExplanationPersistenceTests.swift)
- modified [Packages/ShelfCore/Sources/ShelfCore/Learning/Analysis/DocumentAnalyzer.swift](/Users/malmeida/Documents/ChatGPT/Leu/LeuNightFieldContrast/Packages/ShelfCore/Sources/ShelfCore/Learning/Analysis/DocumentAnalyzer.swift)
- modified [Packages/ShelfCore/Sources/ShelfCore/Learning/Intelligence/GroundedQuestionCompiler.swift](/Users/malmeida/Documents/ChatGPT/Leu/LeuNightFieldContrast/Packages/ShelfCore/Sources/ShelfCore/Learning/Intelligence/GroundedQuestionCompiler.swift)
- modified [Packages/ShelfCore/Sources/ShelfCore/Learning/Intelligence/LearningCandidateValidator.swift](/Users/malmeida/Documents/ChatGPT/Leu/LeuNightFieldContrast/Packages/ShelfCore/Sources/ShelfCore/Learning/Intelligence/LearningCandidateValidator.swift)
- modified [Packages/ShelfCore/Sources/ShelfCore/Learning/Intelligence/LearningIntelligence.swift](/Users/malmeida/Documents/ChatGPT/Leu/LeuNightFieldContrast/Packages/ShelfCore/Sources/ShelfCore/Learning/Intelligence/LearningIntelligence.swift)
- modified [Packages/ShelfCore/Sources/ShelfCore/Learning/Persistence/LearningRepository.swift](/Users/malmeida/Documents/ChatGPT/Leu/LeuNightFieldContrast/Packages/ShelfCore/Sources/ShelfCore/Learning/Persistence/LearningRepository.swift)
- added [Packages/ShelfCore/Sources/ShelfCore/Learning/Persistence/DerivedExtractionMigration.swift](/Users/malmeida/Documents/ChatGPT/Leu/LeuNightFieldContrast/Packages/ShelfCore/Sources/ShelfCore/Learning/Persistence/DerivedExtractionMigration.swift)
- added [Packages/ShelfCore/Sources/ShelfCore/Learning/Semantic/FinalMCQAdmission.swift](/Users/malmeida/Documents/ChatGPT/Leu/LeuNightFieldContrast/Packages/ShelfCore/Sources/ShelfCore/Learning/Semantic/FinalMCQAdmission.swift)
- modified [Packages/ShelfCore/Sources/ShelfCore/Learning/Semantic/GeneralClaimExtractor.swift](/Users/malmeida/Documents/ChatGPT/Leu/LeuNightFieldContrast/Packages/ShelfCore/Sources/ShelfCore/Learning/Semantic/GeneralClaimExtractor.swift)
- modified [Packages/ShelfCore/Sources/ShelfCore/Learning/Semantic/SemanticCompiler.swift](/Users/malmeida/Documents/ChatGPT/Leu/LeuNightFieldContrast/Packages/ShelfCore/Sources/ShelfCore/Learning/Semantic/SemanticCompiler.swift)
- modified [Packages/ShelfCore/Sources/ShelfCore/Learning/Semantic/SemanticQuestionCompiler.swift](/Users/malmeida/Documents/ChatGPT/Leu/LeuNightFieldContrast/Packages/ShelfCore/Sources/ShelfCore/Learning/Semantic/SemanticQuestionCompiler.swift)
- added [Packages/ShelfCore/Sources/ShelfCore/Learning/Semantic/InstructionalText.swift](/Users/malmeida/Documents/ChatGPT/Leu/LeuNightFieldContrast/Packages/ShelfCore/Sources/ShelfCore/Learning/Semantic/InstructionalText.swift)
- modified [Packages/ShelfCore/Sources/ShelfCore/Learning/Domain/LearningSnapshot.swift](/Users/malmeida/Documents/ChatGPT/Leu/LeuNightFieldContrast/Packages/ShelfCore/Sources/ShelfCore/Learning/Domain/LearningSnapshot.swift)
- modified [Packages/ShelfCore/Sources/ShelfCore/Learning/Domain/AnalysisModels.swift](/Users/malmeida/Documents/ChatGPT/Leu/LeuNightFieldContrast/Packages/ShelfCore/Sources/ShelfCore/Learning/Domain/AnalysisModels.swift)
- modified [Packages/ShelfCore/Sources/ShelfCore/Learning/Questions/DeterministicQuestionEngine.swift](/Users/malmeida/Documents/ChatGPT/Leu/LeuNightFieldContrast/Packages/ShelfCore/Sources/ShelfCore/Learning/Questions/DeterministicQuestionEngine.swift)
- added [Packages/ShelfCore/Tests/ShelfCoreTests/Learning/BugfixSafetyTests.swift](/Users/malmeida/Documents/ChatGPT/Leu/LeuNightFieldContrast/Packages/ShelfCore/Tests/ShelfCoreTests/Learning/BugfixSafetyTests.swift)
- modified [Packages/ShelfCore/Tests/ShelfCoreTests/Learning/LearningCandidateValidatorTests.swift](/Users/malmeida/Documents/ChatGPT/Leu/LeuNightFieldContrast/Packages/ShelfCore/Tests/ShelfCoreTests/Learning/LearningCandidateValidatorTests.swift)
- modified [Packages/ShelfCore/Tests/ShelfCoreTests/Learning/SourceIntegrityMigrationTests.swift](/Users/malmeida/Documents/ChatGPT/Leu/LeuNightFieldContrast/Packages/ShelfCore/Tests/ShelfCoreTests/Learning/SourceIntegrityMigrationTests.swift)
- added [Packages/ShelfCore/Tests/ShelfCoreTests/Learning/TrackedLabelAndInstructionTests.swift](/Users/malmeida/Documents/ChatGPT/Leu/LeuNightFieldContrast/Packages/ShelfCore/Tests/ShelfCoreTests/Learning/TrackedLabelAndInstructionTests.swift)
- added [scripts/verify-bugfix-integration.sh](/Users/malmeida/Documents/ChatGPT/Leu/LeuNightFieldContrast/scripts/verify-bugfix-integration.sh)
- modified [scripts/sync-xcode-sources.py](/Users/malmeida/Documents/ChatGPT/Leu/LeuNightFieldContrast/scripts/sync-xcode-sources.py)
- added [scripts/test-bugfix-host.py](/Users/malmeida/Documents/ChatGPT/Leu/LeuNightFieldContrast/scripts/test-bugfix-host.py)
- added [scripts/typecheck-bugfix-ios.py](/Users/malmeida/Documents/ChatGPT/Leu/LeuNightFieldContrast/scripts/typecheck-bugfix-ios.py)
- modified [Shelf.xcodeproj/project.pbxproj](/Users/malmeida/Documents/ChatGPT/Leu/LeuNightFieldContrast/Shelf.xcodeproj/project.pbxproj)
- Updated [evidence/project-manifest.json](/Users/malmeida/Documents/ChatGPT/Leu/LeuNightFieldContrast/evidence/project-manifest.json).
