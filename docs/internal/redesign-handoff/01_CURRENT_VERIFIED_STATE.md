# LEU — CURRENT VERIFIED STATE

## Product

Leu is a native iPhone PDF reading + learning system. The core product thesis is:

> Documents are sources. The actual product is the evolution of what a person is trying to understand.

Leu is not a PDF viewer with a quiz tab and not a chatbot over documents. Reading, learning state, source provenance, recall, voice, relationships and continuity all remain attached to the user's actual books and passages.

## Platform / architecture

- Native iOS / Swift / SwiftUI.
- PDFKit for original-PDF behavior and canonical PDF access.
- Local-first / offline-first.
- No mandatory account, backend or subscription.
- `ShelfCore` local package remains an important domain/service boundary.
- Optional Supertonic/ONNX local voice path; Apple speech remains available.
- Apple on-device Foundation Models is now a real production learning-intelligence backend on supported environments.

## Primary information architecture

Persistent primary navigation remains intentionally small:

- **Library** — PDFs, ownership, find/read/manage.
- **Study** — retrieval, understanding, practice, progress.
- **Trails** — ordered paths through source-linked ideas/material.

Settings / favorites / recents / tags belong under Library rather than a second competing global navigation system.

## Reader

Current Reader capabilities include:

- Original PDF mode.
- Read Mode.
- repaired extraction-v4 path for readable text;
- Contents;
- Search;
- bookmarks / marks / source-linked learning actions;
- voice reading;
- Study entry point;
- Understanding Lens;
- exact source return;
- page preservation across feature sheets;
- local reading-state persistence.

### Important repaired source-integrity state

The earlier extraction-v3 corruption that produced text such as `Reac Note` and `Key describ identit` was traced to the derived extraction representation rather than the PDF itself.

The repaired production reconstruction for React Notes now preserves intact text such as:

- `React Notes`
- `A clearer model for React`
- `State is a snapshot`
- `Keys describe identity`
- `<Row key={item.id} item={item} />`

Any redesign must treat extraction-v4/canonical source text as authoritative. Do not introduce view-level text "repair" or a second parsing path.

## Explain Like I'm 10 — real production intelligence

This is now a real on-device model-backed feature, not a mock and not deterministic templates relabeled as AI.

Production flow:

`Reader / source passage → canonical source packet → shared Apple learning provider → structured response → deterministic validator → cache/persistence → visible sheet → exact source return`

Current user-facing modes:

1. **Standard** explanation.
2. **Even simpler** refinement.
3. **Show an example** refinement.

The refinement remains bound to the original source passage.

### Latest iOS verification

Latest locally-run single real-model journey:

- opened real React Notes page 3;
- selected the exact canonical passage;
- Standard explanation visible;
- Even simpler visible;
- Show an example visible;
- Illustration label verified;
- closed the sheet;
- returned to React Notes page 3;
- UI test passed.

Latest real `withExample` production trace:

- backend: `apple-on-device`
- availability: `available`
- extraction version: `4`
- prompt version: `3`
- validator version: `2`
- block kinds: `plainMeaning`, `example`
- decoded: true
- first-pass accepted: true
- repair attempted: false
- record installed: true
- cache store completed: true
- visible UI observed: true
- total latency: approximately **4.61 s**

The example schema fix therefore works in the iOS simulator with real Apple inference.

### Current open gate — do not hide it

The same later feature suite produced:

- Explain-like-10 UI: **2/2 passed**.
- Unit tests: **43 executed; 2 assertion failures in one persistence/resource test**:
  `ExplanationPersistenceTests.testVersionedPromptResourceIsPresentAndRefinementsStayOnOriginal`

The failing assertions appeared after the prompt/schema version moved to v3. The visual redesign task must **not** weaken this test or change the model contract to make it green. Treat it as a technical gate owned by the intelligence/QA lane unless explicitly asked otherwise.

## Study baseline

Current/established Study primitives include:

- timed session setup;
- Active Recall;
- Interview Mode;
- progress / memory states;
- confidence separate from correctness;
- question activities;
- recall activities;
- masks / diagram recall;
- reconstruction activities;
- Explain activities;
- Continue Reading;
- interruption/session recovery;
- exact source return;
- session-complete flows.

## Reconstruction Labs

Existing/established concepts include:

- Event Loop;
- React Identity;
- HTTP Cache;
- TypeScript structural typing;
- Database transactions.

### New locked interaction rule

For ordering / reconstruction / sequencing tasks:

- when a position is confirmed correct, show a **green check inside its corresponding circle/step indicator**;
- unresolved/incorrect positions stay neutral;
- update progressively;
- do not reveal all remaining answers;
- no punitive red-heavy treatment.

## Connected knowledge / Trails

Leu already has local source-linked relationships, source jumps, topic chains/search ideas, and ordered Trails. Avoid turning these into a generic node graph or algorithmic feed.

## Voice

Current voice architecture includes:

- technical-text normalization;
- paragraph/source mapping;
- Apple voices;
- optional Supertonic local ONNX voice;
- background/remote transport infrastructure;
- technical pronunciation handling.

Voice quality still requires human listening on physical hardware; do not claim visual redesign work validates TTS quality.

## Emotional completion layer

Existing product behavior includes optional session-completion states such as Accomplished / Irritated / Drained and a temporary Release interaction. These are not psychology scores, do not need to dominate the redesign, and must remain easy to exit.

## Privacy / intelligence policy

Current policy supersedes old deterministic-only wording:

- source documents remain local by default;
- primary intelligence path is on-device;
- no paid-per-question cloud dependency;
- model output must preserve source grounding and provenance;
- no fake model labels for deterministic fallback;
- no giant chat surface as the product center.

