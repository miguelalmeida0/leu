# Leu V23.7 — Parent-Owned Progress Surface

V23.7 removes the last cross-view/model presentation dependency from Study Progress.

- `LearnTodayScreen` now owns Progress presentation as local SwiftUI state.
- `LearnSecondaryModes` emits a direct `onProgress` callback; it does not mutate a domain-model UI flag.
- Progress replaces the Study root synchronously; it is not a sheet, navigation destination, or menu.
- `LearningStateSheet` is now a flat full-screen surface with direct `Now`, `History`, and `Done` controls.
- The obsolete `LearningModel.learningStatePresented` flag is removed.
- Accessibility wrappers that could collapse the Progress tab controls are removed.
- XCUITest convergence gate 36/39/40 remains first in Mac QA and now asserts the visible Progress surface itself.

No product capability, offline guarantee, Gallery Minimalism rule, or existing test assertion was weakened.
