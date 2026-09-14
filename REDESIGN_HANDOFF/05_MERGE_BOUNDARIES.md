# LEU — CLAUDE / CODEX OWNERSHIP & MERGE BOUNDARIES

Claude is redesigning the product shell and interaction system while the intelligence lane may continue evolving.

## Claude may own

- SwiftUI presentation/views;
- shared visual components;
- design tokens;
- typography;
- spacing;
- semantic color states;
- motion/haptics at the UI layer;
- navigation presentation where behavior remains equivalent;
- accessibility layout/labels when meaning is preserved;
- feature presentation for existing and approved upcoming surfaces;
- development preview fixtures isolated from production.

## Do not rewrite without explicit approval

- PDF extraction/reconstruction;
- canonical source identity/ranges;
- `LearningIntelligenceProvider` semantics;
- Apple Foundation Models production calls;
- explanation/question validators;
- generation schemas/prompts;
- persistence/cache/versioning;
- learner-history storage;
- source provenance;
- question-generation intelligence;
- semantic retrieval implementation;
- Supertonic/ONNX model plumbing;
- migration logic;
- privacy/cost boundaries.

## Presentation adapters

If a screen needs data not yet exposed cleanly, add a thin presentation adapter/view model instead of copying business logic into the view.

Never fabricate production results to make a screen look complete. Use explicit preview/demo fixtures only in previews/development harnesses.

## Tests

Preserve existing accessibility identifiers whenever possible.
If a legitimate redesign requires identifier relocation, update tests to the new real UI without weakening the behavior being tested.

Do not delete tests because the redesign made them inconvenient.

## Current open intelligence gate

At the time of this handoff, Explain-like-10 real UI is 2/2 green, but one persistence/resource unit test has two assertions failing after the schema/prompt moved to v3. Claude should not alter intelligence contracts merely to clear that gate.

