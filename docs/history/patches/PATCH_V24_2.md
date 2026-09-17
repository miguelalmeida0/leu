# Leu V24.2 — Native Interaction and Study Recovery Repair

## Status

Source repair candidate based on the supplied V24.1 archive. **V24.2 has not been built or run with Xcode/iOS Simulator here.** The local verification below is not Apple certification. Older patch notes and evidence folders describe their own versions, not this candidate.

## What the supplied V24.1 Mac run established

The supplied `Pasted text(20260911-194742).txt` records BUILD SUCCEEDED, 195 core tests passed, and 20 Apple PDF/integration tests passed. V24 feature test 50 passed. Tests 51, 52, 53 and 54 failed; QA stopped before the Study regression gate and complete 55-test suite. Exit code was 65.

The failures are not four proven missing features:

- **51, Lens/source:** the captured reader actually has a return button, but its identifier is absent/replaced by the parent `reader-screen` identifier. The label incorrectly says “Back to question.” The source confirms Lens called `LearningModel.openSource`, without saving its originating Lens passage.
- **52, Settings:** the captured Form remains at the top and only instantiates its upper sections. The test asserted Emotional check-ins and Voice without scrolling to their later rows. It had not reached the neural-voice controls.
- **53, interruption:** the captured app opens Library. `LearningModel.bootstrap` can restore a session, but `RootView` initializes to Library and only handles new session IDs when already in Study. The previous checkpoint also omitted selected answer, confidence, commit state and hints.
- **54, irritated flow:** the captured app is still on question one, with “Commit answer” disabled. Option buttons exist, but all are identified as `question-card`, so the test's `question-option-*` query never selects an answer. This run did not test the emotional response itself.

## Production repair

### Native controls and source return

Container identifiers on Reader, Study session, question, recall, session completion, emotional check-in and release surfaces are replaced by isolated, non-interactive geometry probes. The existing probe is accessibility-visible only under `--uitesting`; it is not a production VoiceOver element. Real controls retain their own native identifiers and labels. No generic `Other` element is accepted as an action target in the new journeys.

The Reader return action no longer replaces its Button with an ignored-child accessibility grouping. It has a full-row hit shape and a 44-point minimum height.

Understanding Lens is presented by the stable Reader after the action sheet dismisses. Following a fact uses the existing knowledge-navigation mechanism with an explicit origin. The inspected source offers **Back to Understanding Lens**, then returns to the original source page and reopens the same Lens passage. It no longer impersonates the question/source route. Facts have deterministic presentation ordering.

### Study restoration and durable writes

On initial bootstrap, the app root selects Study when an unfinished session was actually recovered. This happens once per root lifetime, not on every tab change. Progress keeps its established root-owned routing; there is no Progress navigation rewrite.

`ResumeStudyContext` adds question identity, selected answer, explicit confidence, commitment and hint count, with decoder defaults for V24.0/V24.1 records. A stale question identity cannot inject an answer into a different question.

The repository commits session and resume context in one snapshot transaction. The app captures immutable checkpoint values before suspension and serializes writes in user-event order. A later completion/exit cannot be overwritten by an older queued answer save. Write failures surface a notice/error; the UI displays **Saved** only after persistence returns successfully. Completion updates the observable history as well as disk; repeated saves do not duplicate completion events.

This guarantees preservation of acknowledged checkpoints. It does not claim an operating system force-kill can preserve an uncommitted write that never finished.

### Settings and emotional interaction

Settings now exposes stable identifiers on its existing picker, voice status, install control and delete-history action. The test scrolls the actual Form from a known position before asserting later rows; the product's section order is unchanged.

Question options and confidence expose selected state. The emotional journey uses measured scrolling, a real option tap, a real enabled Commit tap, and real recall ratings. It waits for each activity transition instead of a fixed delay. Existing Release/Continue/I'm done assertions remain, and the accessible non-gesture Release action is now actually tapped.

### Audio warning and tooling

The reported AVAudioPlayerDelegate isolation warning is addressed with a nonisolated callback that transfers only the player's identity and the success flag to MainActor. A stale callback cannot finish a replacement player. Other reported AttributedString/KeyPath concurrency warnings are not presented as fixed.

The Xcode source synchronizer reuses the pre-existing ONNX source IDs rather than adding duplicate build inputs. Structural validation now rejects duplicate source paths within one target. Synchronization was checked for idempotence.

The clipboard summary retains actual compiler errors, source excerpts, failure trees and exit status. Ordinary dependency/build notes no longer flood the clipboard; distinct warnings are grouped with occurrence counts. Full original output remains in the log/diagnostics. An existing failure cannot become success because diagnostics export or clipboard copying worked.

## Native acceptance changes

The total remains **55 UI tests**. The new tests are not skipped or replaced by source-policy checks:

- 51 follows an actual fact, checks the source page and a unique native return button, activates it, verifies the original Lens text, dismisses Lens and verifies the original page.
- 52 reaches the real Settings rows, changes check-ins to Off, verifies that selection after reopening Settings, checks delete-history's empty-state behavior and verifies voice controls. It does not download a model.
- 53 persists an explicit answer and confidence, relaunches without resetting data, verifies those same values and question, then commits and relaunches again to verify the revealed state.
- 54 completes a real short session, selects Irritated, preserves the optional alternatives and invokes accessible Release.

The existing V23 test methods are unchanged. The existing core tests remain; nine checkpoint tests were added.

## Verification executed here

| Check | Result |
|---|---|
| Portable ShelfCore suite | **204 tests, zero failures** |
| New checkpoint coverage | **9 tests** within those 204: legacy/new decoding, disk reopen, mismatch/bounds rejection, idempotence, completion, exit and write failure |
| Actual Observation-annotated LearningModel typecheck | Passed with complete concurrency checking and platform dependency stubs |
| Recovery-logic harness | **9 checks passed**, using unchanged production method bodies and real repository/disk store; Observation/PDF/UI adapters excluded |
| Existing repair-tool regression tests | **27 passed** |
| Settings/compiler-summary regression tests | **14 passed** |
| New interaction-policy/summary mutation tests | **17 passed** |
| Existing simulator/launcher/backup-tool checks | **15 passed** |
| Structural and architecture/privacy/design policies | Passed; **450 project objects**, no duplicate target inputs |
| Swift syntax parsing | **286 files passed**; not Apple SDK typechecking |
| Native V24.2 Apple build / PDF tests / UI tests | **Not run here** |

The optional recovery harness first typechecks the actual annotated model. This Linux Swift distribution's Observation runtime has an unresolved linker symbol, so its separate execution phase removes only Observation annotations in generated `.build` copies and substitutes platform adapters. It does not alter production source, relax the 204 core tests or claim to verify SwiftUI observation/rendering. The native interruption test remains mandatory.

Logs are under `docs/internal/evidence/v24-2/`. `docs/V24_2_CODE_CHANGES.diff` contains the code patch. The semantic compiler/rules, design-system files and bundled resources compare byte-for-byte with V24.1.

## What this does not certify

This patch does not establish a complete V24 release pass, visual fidelity, physical touch/haptics, or Supertonic audio quality. The neural model is not bundled or silently downloaded, and the current Settings acceptance test does not synthesize speech. Installing, exercising and listening to Supertonic remains a separate required voice acceptance step.

## Mac QA

```bash
cd "$HOME/Downloads" &&
unzip -oq "Leu-Native-V24.2-Interaction-and-Recovery-Repair.zip" &&
cd "LeuNativeV24_2" &&
SHELF_QA_LOG=qa-v24-2.log ./scripts/qa-and-copy.sh
```

The same fail-fast sequence remains: structural policies → Apple build → core tests → Apple PDF/integration tests → all five V24 journeys → sensitive Study regressions → all 55 UI tests → strict result inventory. No skipped or failed-then-retried test can count as a green run. The final summary is copied with `pbcopy` and reports the diagnostics archive. Do not append a `tail | pbcopy` command.

## Primary implementation references

- Apple, accessibilityIdentifier: https://developer.apple.com/documentation/swiftui/view/accessibilityidentifier(_:)
- Apple, XCUIElement.isHittable: https://developer.apple.com/documentation/xcuiautomation/xcuielement/ishittable
- Swift compiler diagnostics, actor-isolated calls: https://docs.swift.org/compiler/documentation/diagnostics/actor-isolated-call/

## Changed code files

- `Packages/ShelfCore/Sources/ShelfCore/Learning/Domain/EmotionalModels.swift`
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Domain/ResumeStudyContext.swift`
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Persistence/LearningRepository.swift`
- `Packages/ShelfCore/Sources/ShelfCore/Learning/Persistence/StudyCheckpointMutation.swift`
- `Packages/ShelfCore/Tests/ShelfCoreTests/Learning/StudyCheckpointTests.swift`
- `Shelf/App/AppContainer.swift`
- `Shelf/App/RootView.swift`
- `Shelf/Features/Library/LibraryModel.swift`
- `Shelf/Features/Library/LibraryState.swift`
- `Shelf/Features/Reader/Components/ReaderTopBar.swift`
- `Shelf/Features/Reader/ReaderModel+Lens.swift`
- `Shelf/Features/Reader/ReaderModel.swift`
- `Shelf/Features/Reader/ReaderScreen.swift`
- `Shelf/Features/Settings/SettingsScreen.swift`
- `Shelf/Knowledge/KnowledgeModel+Connections.swift`
- `Shelf/Knowledge/KnowledgeModel.swift`
- `Shelf/Learning/LearningModel+Recovery.swift`
- `Shelf/Learning/LearningModel+Sessions.swift`
- `Shelf/Learning/LearningModel.swift`
- `Shelf/Learning/LearningObjectActionSheet.swift`
- `Shelf/Learning/QuestionCardView.swift`
- `Shelf/Learning/RecallCardView.swift`
- `Shelf/Learning/SessionCompleteView.swift`
- `Shelf/Learning/StudySessionScreen.swift`
- `Shelf/Learning/UnderstandingLensSheet.swift`
- `Shelf/Voice/Engine/SupertonicSpeechEngine.swift`
- `Shelf.xcodeproj/project.pbxproj`
- `ShelfUITests/ShelfWorldClassUITests.swift`
- `ShelfUITests/V24InteractionSupport.swift`
- `scripts/check-gallery-minimalism.py`
- `scripts/check-ui-test-contract.py`
- `scripts/check-v24-contract.py`
- `scripts/check-v242-interactions.py`
- `scripts/qa-and-copy.sh`
- `scripts/qa-native.sh`
- `scripts/summarize-qa.py`
- `scripts/sync-xcode-sources.py`
- `scripts/test-v24-recovery-model.sh`
- `scripts/test-v242-interactions.py`
- `scripts/validate.py`
- `validation/v24-2/RecoveryDependencies.swift`
- `validation/v24-2/RecoveryHarness.swift`
