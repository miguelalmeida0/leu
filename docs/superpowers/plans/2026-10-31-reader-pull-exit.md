# Reader Pull to Exit Implementation Plan

> For agentic workers: use superpowers:executing-plans inline; obtain a fresh read-only review before promotion.

**Goal:** A deliberate downward pull exits fullscreen with controlled feedback; short pulls cancel without disrupting sideways pagination.

**Architecture:** Extend the existing pointer owner with a locked gesture axis. A separate dismissal hook moves a dedicated page wrapper, shows threshold feedback, and commits through the existing idempotent fullscreen exit. A small feature-detected vibration helper provides brief semantic ticks without affecting navigation on unsupported devices.

**Tech Stack:** Existing React, TypeScript, Pointer Events, WAAPI, Vibration API; no added dependency.

**Spec:** Current explicit user request and IMG_7924.png. The user has directed implementation and release without approval prompts. Native implementation in this session follows the established workflow.

## Global constraints

- Work on test; only main/test refs; preserve owner attribution and release gates.
- Existing sideways pages, PDF pan/zoom, bookmarks, notes and listening remain available.
- Finger-down is pull-to-exit. Positive vertical wheel scrolling also exits after a deliberate accumulated stroke; small scrolls cancel.
- Axis locks after intent is clear. Horizontal diagonals never turn into dismissal; upward drags never dismiss.
- A selected passage, active pinch or enlarged-original pan takes precedence over dismissal.
- Reduced motion uses the threshold hint and immediate completion, without pull/spring animation.
- Browser haptics are best effort: feature detection, short pulses, rate limiting and exception isolation. No hidden switch overlays, audio substitute, or claim of physical iPhone haptics.

## Review focus

- A cancelled pointer or swipe-to-pinch interruption resets the pull completely.
- Reversing a pull below the threshold cancels it; crossing once does not cause repeated ticks.
- No compatibility click may activate the normal UI after dismissal.
- Zoomed PDF pan and text selection must not exit fullscreen.
- Closing, resizing or unmounting during a pull must not retain an animation/listener or fire a delayed exit.

### Task 1: Implement and verify dismissal

Files: new `web/src/components/paged-reader/useReaderDismiss.ts` and `web/src/lib/haptics.ts`; modify `usePageGesture.ts`, `PagedReader.tsx`, `types.ts`, `styles.css`, `Reader.tsx`; add `web/scripts/reader-dismiss-journeys.mjs` and wire it into browser CI.

Interfaces: PagedReader receives `onExit: () => void`. The dismissal hook consumes root/stage/hint refs, reduced-motion preference and onExit; produces `pull(distance)`, `release(commit)`, `cancel()` and `busy()`. Existing gesture owner invokes those callbacks only for a locked vertical pull or vertical wheel stroke.

- [x] Add a failing browser journey proving deliberate downward exit on real touch input and WebKit pointer input. Observe failure before production edits.
- [x] Implement axis intent, distance threshold (96–140 CSS px according to viewport), resistance, release/cancel and wheel accumulation.
- [x] Add a small threshold hint and bounded exit animation; preserve reduced motion and the fixed shell.
- [x] Add short semantic haptic pulses for threshold, page-turn and fullscreen actions. Unsupported/throwing implementations never block the action.
- [x] Verify six viewport/motion configurations, cancellation, retraction, axis lock, selection, zoomed-original pan, interrupted pinch, bookmark/reopen and clean scroll restoration.
- [x] Run clean install/build, all existing contracts and reader journeys. Obtain a fresh whole-change review.
- [ ] Publish to test; require web-release-gate and portable-core on push and PR merge result; promote then verify the live gesture.

## Verification record

The original real-touch test failed because fullscreen remained active after a deliberate pull. The implemented gesture passes six Chromium/WebKit viewport and motion cases, including short/retracted/cancelled pulls, diagonal axis locking, selected text, zoomed PDF pan, pinch and viewport interruptions, wheel-burst containment, bookmark/reopen, and absent/throwing vibration APIs. The existing six dense-pagination cases, two extraction-failure cases, four full reader journeys, and 26 artwork/voice/accessibility contracts also pass. Clean install and build pass using the native inference dependency's documented CUDA-download skip; browser WASM assets are unchanged.

A fresh whole-change review found a retained offset when selection began during a pull and an occluded reduced-motion hint. Both have regression tests observed failing before the fixes. A desktop test exposed default margin text selection and a trackpad burst advancing two pages; pointer-down ownership and continued burst latching resolve those cases. A rapid touch-to-controls regression also verifies that the compatibility-click shield never swallows a new deliberate press. All assertions remain active in CI. Physical device vibration quality and native iPhone Safari behavior have not been certified by emulation.
