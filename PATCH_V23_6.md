# Leu V23.6 — Deterministic Progress Root Convergence

V23.6 removes Progress from SwiftUI presentation semantics entirely.

## Root cause addressed
Repeated simulator runs proved the Progress row itself was reachable, while the Progress sheet failed to become a stable addressable accessibility surface. Treating this as another selector problem caused unnecessary convergence loops.

## Production fix
- `Progress` now sets `LearningModel.learningStatePresented = true`.
- `LearnTodayScreen` renders `LearningStateSheet` directly as the Study root while that state is active.
- `Now` and `History` therefore live in the same app accessibility hierarchy immediately after the Progress tap.
- `Done` returns to Study by setting `learningStatePresented = false`; no environment dismiss or UIKit sheet lifecycle is involved.
- Progress is removed from the typed modal `Destination` enum.
- Other secondary Study tools continue to use one typed sheet presenter.

## Regression contract
Static QA fails if Progress is reintroduced as a modal destination, if the direct Study-root switch disappears, or if Done stops returning via explicit app state.

Marketing version: 2.3.6.
