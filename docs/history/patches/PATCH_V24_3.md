# Leu V24.3 — Root Compile Repair

## Status

A scoped **source repair candidate**, not an Apple-certified release. The latest V24.2 Mac run stopped in `RootView.swift` during compilation; its core, Apple integration and UI test stages did not execute. No V24.3 Apple build or simulator run has been performed here.

Basis: `Leu-Native-V24.2-Interaction-and-Recovery-Repair.zip`, SHA-256 `34b7da5c2bd77c8e31d9ce37b86cb486e449009542027f4c8c6caa6a48f7aa00`. The original archive was verified and extracted separately. This candidate does not overwrite it.

## Observed build blocker and repair

The supplied diagnostic reports the compiler could not typecheck an expression in reasonable time at `RootView.swift:59`, highlighting `await container.knowledge.syncLibrary()`. The call was inside a 101-line `body` expression containing phase rendering, bottom chrome, startup/recovery, six change observers, presentations, backup import/confirmation and error presentation.

That diagnostic alone does **not** establish a defect in `KnowledgeModel.syncLibrary`, and a typechecker timeout can also obscure another type mismatch. The repair makes each responsibility independently typecheckable instead of deleting the awaited operation or changing navigation.

`RootView.body` is now six lines. Its view expression is separated into named `some View` properties for root content, bottom chrome, lifecycle modifiers, Reader/sheet presentations and backup presentation. Each contains 18 lines or fewer. Async bootstrap, sync, recovery, change handlers and import completion live in explicitly typed, MainActor-isolated methods. The book fingerprint collection and Boolean presentation bindings have explicit types.

There is no `AnyView`, new navigation stack, new Progress modal, additional state owner, increased typechecker timeout, disabled concurrency checking or compiler-warning suppression.

### Behavior preserved

- The same root-owned `primaryArea` and `studySurface` own navigation.
- Startup still awaits Library, then Learning, restores an eligible unfinished Study session once, and then bootstraps Knowledge.
- Scene inactivity still requests a checkpoint only when a Study session exists.
- Synchronization still awaits Learning before Knowledge.
- Starting recall from Progress still reveals Study's landing/session surface.
- A pending source destination waits until the existing Reader dismisses; Lens origin, document, page and source text are forwarded unchanged.
- Presentation modifier order, bottom navigation, notices, backup confirmation, merge sequence and error presentation remain in the same order.
- The conditional Progress/Study screen contents and Library subroutes are unchanged.

## Reported attributed-text warnings

The three warning classes refer to SwiftUI attributed-string background color, foreground color and font key paths. The app has five corresponding dynamic attribute writes in two highlighting helpers.

Those writes now use explicit `AttributeScopes.SwiftUIAttributes.*Attribute.self` subscripts. The same string range, colors, opacity and font are retained. This avoids dynamically forming the relevant attribute key paths; it does not declare unsafe values Sendable or relax compiler settings. Apple SDK compilation is still needed to confirm those warnings are absent.

## Exact production scope

Four existing app Swift files differ from V24.2:

1. `Shelf/App/RootView.swift`: expression decomposition and typed lifecycle methods.
2. `Shelf/Features/Reader/Components/ReadPageContent.swift`: two explicit attribute-key assignments.
3. `Shelf/Features/Reader/ReaderSearchSheet.swift`: three explicit attribute-key assignments.
4. `Shelf/Features/Settings/SettingsScreen.swift`: displayed version only, from 24.2 to 24.3.

Xcode marketing version and QA/report labels are updated. There are no new app source files or target-membership changes; 450 project objects still resolve.

**All ShelfCore source and tests, all Apple unit tests, all 55 UI tests, Learning, Knowledge, Voice, design tokens and bundled resources are byte-identical to V24.2.** This includes the no-tree Resume design and V24.2's interaction/persistence repairs.

`docs/V24_3_CODE_CHANGES.diff` contains the complete code delta. `evidence/v24-3/scope-comparison.json` records unchanged directories.

## Verification actually executed

| Check | Result |
|---|---|
| Structural/project validation | Passed: 450 objects; 321 source/script files; largest file remains 298 lines |
| Existing source/architecture/privacy/design contracts | Passed |
| New root compile source contract | Passed; not an Apple typecheck |
| New repair regression suite | 13 tests passed, including execution of extracted production lifecycle handlers |
| Extracted RootView lifecycle harness | 30 checks passed: startup order, one-time restore, checkpoint triggers, tab/session routing, pending source handling, Lens origin and backup behavior |
| Existing repair-tool tests | 27 passed |
| Existing Settings/compiler-summary tests | 14 passed |
| Existing V24.2 interaction/summary tests | 17 passed |
| Existing delivery-tool checks | 15 passed |
| Swift syntax parsing | 288 files passed; not Apple SDK typechecking |
| Full portable ShelfCore run | **203 of 204 passed; one performance failure** |
| Unchanged voice performance gate | Candidate: **4.0409 seconds**, against unchanged `<3.0 seconds` |
| Unmodified V24.2 benchmark control | **3.3839 seconds**, also above the same limit |
| Optional older recovery harness | Annotated model typechecking completed; its following execution phase did not complete within the enclosing command's timeout and is **not counted as passed** |
| V24.3 native Apple build, PDF tests and XCUITests | **Not run here** |

The core performance failure is retained in the logs. The candidate's entire ShelfCore package is byte-identical to the baseline, and the same benchmark also failed in a separate run of the unmodified V24.2 package. This comparison does not establish why runtime varies or certify the performance budget. No threshold, test, optimization mode or assertion was weakened; there was no retry-until-green result.

### Limits of the new harness

The new Python suite extracts the actual RootView lifecycle method bodies without editing those bodies, compiles them with `-strict-concurrency=complete -warnings-as-errors`, and executes them with portable model/scene/state adapters. The production `PrimaryArea` enum is included unchanged. The harness preserves a struct host with nonmutating state setters.

This checks event ordering and routing decisions in those methods. It does **not** instantiate SwiftUI, validate observation/rendering, exercise PDFKit, load ONNX, test an Apple SDK, or replace any native acceptance test. The native tests remain mandatory and unchanged.

## Mac QA — automatic clipboard summary

```bash
cd "$HOME/Downloads" &&
unzip -oq "Leu-Native-V24.3-Root-Compile-Repair.zip" &&
cd "LeuNativeV24_3" &&
SHELF_QA_LOG=qa-v24-3.log ./scripts/qa-and-copy.sh
```

The existing full sequence remains: source checks → Apple build → 204 core tests → 20 Apple/PDF tests → five V24 journeys → five sensitive Study regressions → all 55 UI tests → strict result inventory. The new root source/logic check runs before the Apple build. The focused gate tests also occur in the complete UI suite; they are not additional unique tests.

The wrapper retains actual compiler diagnostics, preserves the real exit code, collects available diagnostics on failure, and automatically copies the summary with `pbcopy`. Do not append a `tail | pbcopy` command. No previous workspace is removed.

Supertonic synthesis and subjective listening quality are still separate acceptance work; this compile repair does not certify them.

## Primary references consulted

- Swift compiler discussion of inference budgets and independent subexpressions: https://forums.swift.org/t/the-compiler-is-unable-to-type-check-this-expression-in-reasonable-time-try-breaking-up-the-expression-into-distinct-sub-expressions/44051
- Apple, AttributedString and typed attribute subscripts: https://developer.apple.com/documentation/foundation/attributedstring
- Apple, AttributedSubstring and in-place range mutation: https://developer.apple.com/documentation/foundation/attributedsubstring
- Apple, fileImporter signatures: https://developer.apple.com/documentation/swiftui/view-presentation
