# Leu V23.8 — Root-owned Progress convergence

- Moves Study/Progress routing into `RootView`, the stable application root that already owns the primary IA.
- Removes local Progress presentation state from `LearnTodayScreen`.
- Progress now renders as a deterministic root Study surface with direct `landing <-> progress` state.
- Removes the root accessibility identifier from `LearningStateSheet` to avoid container-level semantic propagation/collapse.
- Adds stable identifiers directly to visible Progress content: `progress-title`, `progress-now-view`, `progress-history-view`.
- Keeps `progress-tab-now`, `progress-tab-history`, and `progress-done` on the real controls.
- Updates tests 36/39/40 to assert the visible Progress title by stable identifier before interacting with tabs.
- No product/test assertions are skipped or weakened.
