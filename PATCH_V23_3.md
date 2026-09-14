# Leu Native V23.3 — Progress Progressive-Disclosure Convergence

V23.3 keeps the Gallery Minimalism redesign intact and closes the final Apple XCUITest failure cluster found in V23.2.

## What the Mac run proved in V23.2

- native Xcode build succeeded;
- 182/182 portable core tests passed;
- 20/20 Apple PDF and viewport tests passed;
- Reader interaction repair suite passed 10/10;
- Reader regression suite passed 7/7;
- main native UI suite passed 15/15;
- World Class / Connected Knowledge / Voice suite passed 6/6;
- only 3 of 48 XCUITests remained red, all in the Learning OS Progress path.

## Root cause

The redesigned Study surface exposed `Progress now`, `Progress history`, `Connections`, `Document topics`, and `Search ideas` as children of a SwiftUI `Menu`. On the tested iOS simulator, tapping the `More learning options` control opened the system menu, but those menu children were not exported into the application accessibility hierarchy queried by XCUITest. Their identifiers and visible labels therefore could not be resolved.

This was one accessibility/discoverability defect manifesting as three test failures, not three independent learning-state bugs.

## Production repair

The opaque `Menu` has been removed. `More` is now an inline progressive-disclosure row:

- tapping **More** expands the secondary Study destinations in place;
- **Progress now** and **Progress history** are real semantic buttons;
- **Connections**, **Document topics**, and **Search ideas** use the same contract;
- every row has a stable accessibility identifier, explicit label and useful hint;
- expansion state is exposed as Expanded/Collapsed;
- the transition uses Leu's existing restrained motion vocabulary and selection haptic;
- Gallery Minimalism styling, one-tier IA and the no-tree resume invariant are unchanged.

The native test helper also scrolls expanded rows into a hittable position instead of assuming every progressive-disclosure destination fits in the initial viewport.

## Regression guard

`check-ui-test-contract.py` now fails the release if `LearnSecondaryModes` reintroduces a SwiftUI `Menu` for these high-value destinations or loses the expanded semantic rows.

No failing assertion was deleted, skipped, weakened, or converted into a sleep.
