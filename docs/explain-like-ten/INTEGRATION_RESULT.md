# Explain like I'm 10 — integration result, 12 September 2026

**Code integrated; acceptance NOT MET.** The feature now has a production reader action,
shared Apple provider call, canonical source packet, validated response sheet and local
cache implementation. A real explanation request failed before returning content. No
native screenshots, physical-device performance results or independent human review were
produced. This is not a release approval or completion of the earlier Leu P0 UI gates.

Work is in `/Users/malmeida/Documents/ChatGPT/Leu/LeuNativeV24_5`. VIGIA was not modified.
The attached handoff's statements about missing tooling and unimplemented shared hooks
were treated as historical context. Its proposed patches were adapted to this checkout.

## Concrete changes

The reader's “Learn from this” sheet now offers **Explain like I'm 10**. Its coordinator
captures a canonical passage, dismisses the action sheet, then presents the explanation.
The sheet exposes the exact original passage, Even simpler, Show an example, saved-answer
provenance and explicit unavailable/refusal/failure states. Examples have an **Illustration**
label. Plain text uses `Text(verbatim:)`; URLs are not made into links. Existing recording
“Explain” and Understanding Lens actions retain their behavior.

`LearningExplanationCapable` is additive to the shared provider. Production wiring is:

```
LearningObjectActionSheet → ReaderExplanationCoordinator
→ ExplanationPacketBuilder (canonical range, fingerprint, extraction v4)
→ ExplanationController → V26ExplanationAdapter
→ AppleLearningIntelligenceProvider.generateExplanationJSON
→ LanguageModelSession.respond (structured schema, tools: [])
→ ExplanationValidator → ExplanationRecord
→ LearningIntelligenceCache / ExplainLikeTenSheet
```

The new explanation path does not call `QuestionRealizer`, generate multiple-choice
questions, or relabel regex checks as model inference. Existing question generation,
semantic compilation, extraction and migration implementations were preserved.

Prompt/schema/validator version is 2. A missing or mismatched bundled prompt fails before
inference. The source packet resolves to exact canonical PDF text, requires extraction
v4 or later, rejects damaged/noncanonical input, and binds every context span into the
cache key. The response has at most 220 visible words including the preserved term and
definition; each block cites supplied spans. Deterministic checks cover obvious lost
qualifiers, numbers, protected code literals, instruction-shaped output and malformed
refusals. These checks do **not** establish entailment or semantic correctness.

The incoming controller could retain an in-flight request for passage A when passage B
was selected in the same mode. It now invalidates A before installing B. Tests actually
start both provider calls, complete B, and then deliver A late. Closing also drops a
late response; identical in-flight taps coalesce. There is at most one repair retry.
All test doubles live in the unit-test target, outside production sources.

The bounded local cache revalidates disk loads and separates document/page/range/language/
mode/version/backend. Library deletion prunes only derived explanations. Late results
cannot recreate a deleted document's cache. Failed library bootstrap cannot trigger an
empty-library prune. The PDF files, annotations and study-history stores are not rewritten
by this feature. Offline disk reopening remains unverified because file writes failed.

## Actual source and actual model result

The probe extracted the same bundled **React Notes**, page 3, through the production PDF
geometry/reconstruction code, then built a packet against `PDFPage.string`.

PDF SHA-256: `7d42381fcbb2e1c6252457bced1a3970015142adbac4a556fb35d7ab4e318640`.
The 162-character canonical selection passed to the feature was:

```
A stable key helps React match an item to its previous
instance within a list of siblings. Reordering should
not make one item inherit the local state of another.
```

The heading span was `Keys describe identity`. Reconstructed text contained the same
words with paragraph wrapping normalized. No text-repair change was made in this turn.
The full canonical page, reconstructed selection, range and packet are in the evidence
inventory; the exact runtime request packet is `real-source-packet.json`.

**After generation: no accepted explanation exists.** Two explicit diagnostic runs used
the real shared Apple provider on macOS 26.6. Both reported `apple-on-device / available`,
entered `generateExplanationJSON`, and threw
`FoundationModels.LanguageModelSession.GenerationError -1`. Each recorded one attempt,
zero responses, zero validator rejections and zero accepted results. No model output was
persisted or displayed. The second probe returned exit code 2. These probes did not expose
an underlying cause; earlier question-provider errors are not substituted as this result.

## Verification results

| Check | Actual result |
|---|---|
| Shared core and feature services, macOS | Compiled with the installed Apple SDK |
| Feature services + actual SwiftUI sheet/theme/controls, iOS 17 target | Compiled against iPhoneSimulator 26.5 SDK |
| Feature unit tests and all native UI-test sources | iOS SDK typecheck passed |
| App Swift source syntax parse | Passed; not a full app typecheck |
| Targeted macOS XCTest execution | 43 tests: **38 passed, five failed** (six assertions/errors) |
| Five real disk persistence tests | Failed on atomic writes, `NSCocoaErrorDomain 513`; not skipped or marked passing |
| Project/resource membership and structural checks | Passed; runtime prompt included in app resources |
| Learning/explanation privacy source audit | Passed; no new network client or hosted backend |
| Native targeted Xcode test command | Exit 74 before compilation/launch: package `permissionDenied` and CoreSimulator connection refused |
| Native screenshots and UI journey | Not executed; no fresh screenshots |
| Real model execution | Two attempts, zero responses/accepted outputs |
| Human quality gate | 0 reviewed; 22/24 acceptable and zero reversals not established |
| Full sweep | Not run; visible/native gates remain unresolved |

The passing tests exercise actual feature state machines with explicit test doubles;
they are not model-quality evidence. Disk tests attempt the real store, including reopen
with an unavailable provider, deletion preservation, page isolation, revalidation and
bounded pruning. They fail visibly in this environment even with their fixture root
inside the writable workspace. No change to atomic persistence was made to manufacture a pass.

The native target was the existing iPhone Air simulator
`A248FB9E-B969-4CF6-A0ED-B2013A3C60A6`, iOS 26.5, using Xcode 26.6 (17F113).
The target was requested, but no new app build or test process launched on it.

The source inventory contains **24 intact passages from six real bundled PDFs**. It is
not proof that all 24 rubric categories are represented. Long-limit passages, equations,
URLs, adversarial meaning checks and every other rubric still require deliberate selection
and human scoring. A1/A3/A6/A7/A8 have deterministic mechanics checks; A2/A4/A5 still need
model execution. No p50/p95, cold/warm, memory or physical-device network measurements exist.

## Evidence and reproduction

All paths below are relative to the checkout:

- `recovery-docs/internal/evidence/explain-like-ten/changed-code.patch`: actual diff against the 370-file
  pre-edit snapshot, covering 29 code/project/resource/contract/script files. No Git base
  commit is invented. `changed-code.json` contains before/after hashes.
- `preserved-source.json`: 21 unchanged sources, including the C gesture/pager sources and
  UI tests, PDF infrastructure, ReaderModel and the existing question-provider source.
- `targeted-tests.log`, `native-targeted.log`, `real-model-execution.log`,
  `real-model-diagnosis.log`: actual execution outputs.
- `real-source-packet.json`, `real-pdf-passage-inventory.json`: source evidence; zero generated
  answers or human scores. `verification.json` separates every proof level.

Run the native feature checks where simulator access is available:

```
bash scripts/test-explain-like-ten.sh
```

The native tests preserve the existing library and contain no seeded answer. The real
explanation test fails if a supported passage never produces an answer. Refined output is
checked by its actual mode, so the previous answer cannot satisfy the refinement wait.
They still need execution and screenshot inspection. On a supported physical iPhone,
review the 24 acceptance cases and eight adversarial cases with the separate correctness,
simplification and formatting scores in `ACCEPTANCE_TESTS.md`.

For focused mechanics and a separate real model probe on macOS:

```
python3 recovery-docs/internal/evidence/explain-like-ten/build-targeted.py core
python3 recovery-docs/internal/evidence/explain-like-ten/build-targeted.py feature
python3 recovery-docs/internal/evidence/explain-like-ten/build-targeted.py tests
TMPDIR="$PWD/.build/explain-like-ten-tests" \
LEU_EXPLANATION_TEST_ROOT="$PWD/.build/explain-like-ten-tests" \
  .build/explain-like-ten-tests/feature-tests
python3 recovery-docs/internal/evidence/explain-like-ten/build-targeted.py model
.build/explain-like-ten-tests/real-explanation-probe \
  "Shelf/Resources/Samples/React Notes.pdf" recovery-docs/internal/evidence/explain-like-ten
```

The debug-only `--explain-like-ten-harness` auto-opens this feature **after opening a real
PDF reader** and uses the production provider. It does not create a standalone synthetic
demo. No repeated full sweep is warranted until model execution, persistence and the
native reader journey can be verified.
