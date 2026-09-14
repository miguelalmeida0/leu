# Leu V24.1 — Settings Compile Repair

## What the supplied native output establishes

The V24.0 build failed. Xcode listed `SettingsScreen.swift` in the failing arm64
compile command. The supplied 221-line excerpt does **not** include the original
compiler diagnostic. It contains no executed native test results. The three
failed build-command entries are not three failed XCUITests.

The previous chat command appended `tail -n 220 | pbcopy` after a wrapper that
already copied a diagnostic summary. That overwrote the useful summary with the
end of the build log and could omit the earlier error. This was a handoff error,
not evidence of another Progress interaction failure.

## Confirmed source defect and repair

In the actual V24.0 archive, the Voice section used:

```swift
Section("Voice") {
    // Existing settings controls.
} footer: {
    // Existing explanatory copy.
}
```

Apple documents the title/content shorthand only when the footer is EmptyView.
The custom-footer API instead accepts content/header/footer builders. V24.1 uses:

```swift
Section {
    // The same controls and actions, unchanged.
} header: {
    Text("Voice")
} footer: {
    // The same explanatory copy, unchanged.
}
```

This is a concrete constructor mismatch found in the file Xcode identified. It
is consistent with the failing compile command. Without the omitted diagnostic
or a new Apple build, this report does **not** claim it was the only build issue.

Only SettingsScreen.swift changes among application Swift sources, and only for
this constructor and the displayed 24.1 version. Xcode marketing versions and
exact-version source guards are updated to 24.1; dependency pins are unchanged.

## Regression and diagnostic protection

A narrow source rule rejects the invalid title-plus-footer form. Its fixtures
cover the original mutation, the corrected form, nested closures, comments,
strings, sibling sections and valid older labeled initializers. This guard is
not a general Swift parser and is not Apple typechecking.

The summary processor reads the complete log. It retains early errors, nearby
source/caret lines and compiler notes even when over 1,500 ordinary compile
lines follow the error. It preserves failure-only accessibility trees, removes
ANSI styling and explicitly warns when a build failure has no captured error.
The supplied truncated Mac excerpt is also replayed against it; no missing
compiler message is invented.

The QA wrapper still collects diagnostics on failure, preserves the real QA
exit code and copies the summary with pbcopy. The new command deliberately has
no additional tail/copy operation. Native tests, assertions, coverage gates and
performance thresholds are unchanged.

## Executed locally

- 195 portable core tests passed, zero failures; core source and test contents
  are byte-identical to V24.0.
- 27 existing repair-tool regression tests passed.
- 14 new Section/diagnostic-summary regression tests passed.
- 15 existing launcher, simulator-selection and backup-tool checks passed.
- Source, architecture, privacy, design and native-test contracts passed.
- 277 Swift files passed syntax parsing, including the package manifest and
  simulator-selection utility; this does not load Apple's SwiftUI SDK.
- All 20 Apple test methods and all 55 UI test methods remain in the inventory;
  their Swift files are byte-identical to V24.0, but were not executed here.

Actual logs and scope checks are under `evidence/v24-1/`. The current structured
record is `evidence/verification.json`. Older evidence directories are history.

## Native acceptance still required

```bash
SHELF_QA_LOG=qa-v24-1.log ./scripts/qa-and-copy.sh
```

Require build success and all existing stages, with no skips or failure-retry
acceptance, ending in exit code zero. A compiled settings screen does not certify
semantic quality, neural waveform generation, audio quality or physical-device
usability. This repair does not change or newly certify those systems.

## API references

- Apple Section title/content initializer (Footer == EmptyView):
  https://developer.apple.com/documentation/swiftui/section/init(_:content:)
- Apple Section content/header/footer initializer:
  https://developer.apple.com/documentation/swiftui/section/init(content:header:footer:)
