# Teach Leu navigation repair

## Root cause

`LearningObjectActionSheet` already presented the real `TeachLeuSheet` for its
`.teach` destination. However, its entry row was outside `Passage tools` and
inside `if let intelligence` / `if intelligence.canTeach` conditions.
`ReaderIntelligenceModel.retrieve()` assigned that capability from
`TeachReasoningAdapter.canTeach`, which is `!sources.isEmpty`. Thus a
deterministic fact-extraction capability controlled access to the whole Teach
screen, including the optional Qwen path designed to accept ordinary prose.
No separate feature flag or duplicate Teach screen was involved.

The user's physical report proves the requested Passage tools row was absent.
No runtime trace of that particular passage's extracted facts was available;
the placement error and restrictive gate are established by source inspection.

## Navigation fix

`Shelf/Learning/LearningObjectActionSheet.swift` now puts **Teach Leu** directly
after **Understand** inside **Passage tools**, with the exact subtitle
**Explain this in your own words.** There is only one Teach entry in this menu.

The row is always visible and uses the existing `.teach` sheet destination.
Opening it checks source currency, not deterministic comparison capability.
If the source model has not been initialized, it constructs the existing
`ReaderIntelligenceModel` from the current verified passage before presenting.
An unavailable/stale source produces a visible message instead of a blank sheet.
Source integrity checks were not weakened.

`TeachLeuSheet`, Qwen controls, comparison logic, model installation and the
separate voice-recording route were not changed. No model was downloaded.

## Verification and physical status

- Changed Swift file: syntax parse PASS; source whitespace check PASS.
- Source inspection confirms `.teach` still presents `TeachLeuSheet(model:)`.
- Fresh iPhoneOS build: BLOCKED at package resolution with `permissionDenied`.
- Device discovery: BLOCKED by CoreDeviceService initialization failure.
- Xcode UI access: `Computer Use was not approved to use Xcode`.
- Physical route, Teach screen and Qwen-control visibility: NOT VERIFIED.

The user confirms the preceding packaging repair now permits physical app
installation and launch. That is user-reported evidence for the preceding build,
not a physical pass for this new navigation edit. Existing packaging changes and
the user's Xcode project edits remain preserved in the working tree.

No navigation commit or push has been made pending the requested physical route
gate. The existing commit is `85da85aeab4893f9e796cb950f74f620e4a5f12a`.

## Remaining acceptance

With Xcode/device access restored, build and install the updated app on the
connected iPhone. Follow Reader → Study → Learn from this → Passage tools →
Teach Leu. Verify the explanation input and offline model controls are visible.
Do not download the model. Model enable/removal controls remain governed by the
existing installed-model state; this change does not manufacture an installed
model or bypass its checks.
