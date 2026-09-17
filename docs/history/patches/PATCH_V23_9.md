# Leu V23.9 — Visible Progress Acceptance

- Corrects the final Progress XCUITest diagnostic contract.
- Progress navigation remains root-owned and non-modal.
- Tests 36/39/40 now verify the user-visible `Your understanding` heading, real Now/History controls, and visible Now/Time Machine content instead of the brittle `progress-title` SwiftUI text identifier.
- The heading is explicitly exposed as an accessibility header with its visible label.
- No product assertion is skipped or weakened: the test must still prove Progress opens, tabs are reachable, History content renders, state survives relaunch, and Now is the default.
