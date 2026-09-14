# Leu V23.5 — Deterministic Study Presentation Convergence

V23.5 fixes the final Progress presentation cluster found by the V23.4 native XCUITest run.

- Replaced six chained Study `.sheet` modifiers with one typed `Destination` + `.sheet(item:)` presenter.
- Progress, Active Recall, Interview Mode, Connections, Document Topics and Search Ideas now share one deterministic presentation path.
- Moved Progress accessibility identifiers onto concrete sheet content containers.
- Progress XCUITests now assert the real interactive `Now` / `History` controls rather than depending on a wrapper-only identifier.
- Added static regression guards forbidding the old multi-sheet presentation pattern.
- Preserves Gallery Minimalism, one-tier IA, unified Marks/Trails, source-return behavior and the no-tree resume invariant.
- Marketing version: 2.3.5.
