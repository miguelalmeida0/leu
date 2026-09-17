# Leu V24.4 — Lens Compile Repair

## Status and basis

Scoped **source repair candidate**, not an Apple-certified release. The supplied V24.3 Mac log stopped during native compilation in `Shelf/Learning/UnderstandingLensSheet.swift:48`, at the accessibility page-value expression. No portable core, Apple PDF or UI test stage ran in that Mac attempt.

Baseline: `Leu-Native-V24.3-Root-Compile-Repair.zip`.
SHA-256: `ed69203b52158c50170a5619c1fb7a3a8070f49e6d5faf24f81bb0a03df0b821`.
The original ZIP is unchanged. This candidate retains V24.3's RootView repair and all earlier V24.2 interaction/recovery work.

## What the diagnostic does and does not establish

The compiler reported it could not type-check the Lens expression in reasonable time. The original Lens body nested ShelfSheet, ScrollView, VStack, a conditional, a tuple-key-path ForEach, a native Button and another VStack. Relationship/citation/accessibility text was composed inside that expression.

The actual production types were inspected: the proposition ID and relation wording are Strings; the source page index is Int; the source navigation method returns Bool. The page arithmetic is not an identified data-type mismatch. This report does not assert that the highlighted `accessibilityValue` overload alone caused the failure or that the entire problem can be diagnosed from its highlighted token.

The fix removes the nested inference work rather than increasing compiler limits, erasing types, removing source navigation or dropping accessibility.

## Production changes

### Nominal, typed Lens facts

`UnderstandingLensFact.swift` is a presentation-only, Identifiable value type with explicit String fields. It precomputes the concept title, relationship, visible citation, accessibility label, accessibility value and existing stable identifier outside SwiftUI. It retains the same source projection used by V24.3.

The original eligibility rule (`isQuizTruth`), subject lookup, case-insensitive canonical-name matching, cross-document lookup, document/page/proposition sorting and 24-result cap are preserved. No semantic compiler, ontology, provenance model or question-generation rule changes.

### Small native view expressions

`UnderstandingLensSheet` now delegates to small, separately typed content properties. Its body is four lines. Every new Lens `some View` property is at most 18 lines. `ForEach` consumes `[UnderstandingLensFact]` rather than tuple elements with a nested key path.

`UnderstandingLensFactRow` is a separate native SwiftUI Button. The accessibility label and value use the explicit `Text(verbatim:)` overload, so no semantic-field lookup, arithmetic or string concatenation occurs inside those modifiers. Its full-width label keeps the existing styling and gains a rectangular content shape.

The row preserves `understanding-lens-fact-<proposition ID>`, the `Page N` value, the visible source text, and the original relationship labels. No ignored-child replacement accessibility element is added.

### Source navigation is unchanged

The row forwards its own target to the sheet. The sheet calls `queueLensNavigation(to: target, from: source)` and dismisses only when queuing succeeds. The existing Lens origin, Reader source return and navigation-state ownership remain unchanged. Empty results still explicitly state that no verified relationship exists and nothing is generated to fill the gap.

### Recording-permission deprecation

The single deprecated `AVAudioSession.sharedInstance().requestRecordPermission` call in `ExplanationRecorder` now calls `AVAudioApplication.requestRecordPermission`. The existing continuation, denied-permission behavior and recording flow are unchanged. The deployment minimum remains iOS 17. This is separate from Supertonic and does not change speech synthesis.

## Exact scope

Modified existing app files:

- `Shelf/Learning/UnderstandingLensSheet.swift` — bounded rendering and explicit source action.
- `Shelf/Learning/Services/ExplanationRecorder.swift` — permission API call only.
- `Shelf/Features/Settings/SettingsScreen.swift` — displayed version only.

New app files:

- `Shelf/Learning/UnderstandingLensFact.swift`.
- `Shelf/Learning/Components/UnderstandingLensFactRow.swift`.

The two new app files are registered in the Xcode target and manifest. Project synchronization is idempotent. QA labels, the release-version checks, the Lens source-check file set, documentation and integrity hashes are updated. The new repair checks are additive.

Byte comparisons with V24.3 confirm the entire ShelfCore package (source and tests), all Apple tests, all 55 UI tests, RootView, Knowledge, Voice, design-system files and bundled resources are unchanged. No test assertion or performance threshold is removed or weakened. The no-tree Resume requirement remains intact.

The complete code delta is `docs/V24_4_CODE_CHANGES.diff`. The protected-scope comparison is `docs/internal/evidence/v24-4/scope-comparison.json`.

## Verification actually executed

| Check | Result |
|---|---|
| Portable core suite | **204 tests, 0 failures** |
| Unchanged 1,000-block / 3,000-segment technical-speech benchmark | **2.423335814 seconds**, below the unchanged 3-second limit |
| New repair regression suite | **11 tests passed**, including the compiled projection/action harness |
| Projection/navigation harness | **26 checks passed**, including equality with the original selector over 61 fixture sizes |
| Existing Study repair-tool suite | **27 passed** |
| Existing Settings/compiler-summary suite | **14 passed** |
| Existing V24.2 interaction/recovery suite | **17 passed** |
| Existing V24.3 RootView repair suite | **13 passed**, including its 30 lifecycle checks |
| Existing delivery-tool suite | **15 checks passed** |
| Structural validation | **454 project objects; 328 source/script files** |
| All architecture/privacy/design/source contracts | **Passed** |
| Swift syntax parsing | **293 files passed**; not Apple SDK typechecking |
| V24.4 Apple SDK compilation, PDF tests and XCUITests | **Not executed here** |

The first aggregate verification command reached the delivery-tool stage but exceeded its enclosing tool time limit. The standalone delivery-tool invocation then completed all 15 checks with exit 0. No failed test assertion was silently retried or reclassified. The main core suite has one completed run in this candidate's log.

### What the new harness proves

It compiles the unchanged production `LearningSource`, `StableIdentity` and semantic model definitions into a small ShelfCore module. It compiles and runs the actual `UnderstandingLensFact` implementation, testing fields, source targets, eligibility, literal/Unicode text, sorting, cross-document references, deterministic insertion order and result limits against the V24.3 reference selector.

It also extracts the actual sheet/row action method bodies and executes them with call-recording navigation/dismiss adapters. These verify target forwarding and queue-before-dismiss behavior. They do **not** exercise SwiftUI rendering, accessibility trees, model observation, native presentation, PDFKit or ONNX. The existing native Lens round-trip test remains mandatory and unchanged.

## Required Mac QA — clipboard at the end

```bash
cd "$HOME/Downloads" &&
unzip -oq "Leu-Native-V24.4-Lens-Compile-Repair.zip" &&
cd "LeuNativeV24_4" &&
SHELF_QA_LOG=qa-v24-4.log ./scripts/qa-and-copy.sh
```

The full sequence remains: source checks → native Apple build → 204 core tests → 20 Apple/PDF tests → five V24 journeys → five sensitive Study journeys → all 55 UI tests → strict result inventory. Focused tests repeat in the full suite and are not extra unique tests.

The wrapper preserves the actual exit code, includes compiler diagnostics, collects available failure artifacts, and automatically copies the summary with `pbcopy`. Do not append a `tail | pbcopy` command. Previous workspaces are not removed.

## Remaining acceptance boundaries

V24.4's Apple build must confirm that the Lens compiler diagnostic is resolved and the deprecated permission warning is gone. Syntax parsing and source-policy tests do not establish either outcome. Native interactions, visual fidelity, physical-device recording permissions, Supertonic synthesis and subjective voice quality remain unverified here.

The model installer and optional speech assets are unchanged; the ZIP does not bundle a speech model or initiate a download.

## Primary references

- Swift compiler guidance on overload resolution and separately checked subexpressions: https://forums.swift.org/t/the-compiler-is-unable-to-type-check-this-expression-in-reasonable-time-try-breaking-up-the-expression-into-distinct-sub-expressions/44051
- Apple, SwiftUI accessibilityValue: https://developer.apple.com/documentation/swiftui/view/accessibilityvalue(_:)
- Apple, AVAudioApplication recording permission: https://developer.apple.com/documentation/avfaudio/avaudioapplication/requestrecordpermission(completionhandler:)
