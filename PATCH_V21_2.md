# Shelf V21.2 compile repair

This patch fixes the four Apple-SDK compile errors reported by the V21.1 native compile gate:

- `StudySessionScreen.activityBody` now uses result-builder-safe `if let`/`else` instead of `guard` plus early `return` inside `@ViewBuilder`.
- `LearningTrail` and `TrailNode` now conform to `Hashable`, allowing `navigationDestination(item:)` to compile.
- `ConnectionConstellationSheet` no longer calls the nonexistent `frame(width:minHeight:)` overload; fixed width and minimum height are expressed as two valid frame modifiers.
- A new `check-swiftui-compile-contract.py` gate catches these exact regression classes before the longer Apple test stages.

No product behavior, ranking logic, knowledge persistence, voice normalization, or reader gesture policy was weakened to make the build pass.
