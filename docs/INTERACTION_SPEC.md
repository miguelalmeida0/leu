# Shelf interaction specification — V14

This file is the single implementation vocabulary for motion, touch and haptics. Screen code should reference shared constants rather than invent local timing values.

## Motion

- Page settle: interactive spring, response 0.32, damping 0.90.
- Chrome in: 120 ms ease-out.
- Chrome out: 240 ms ease-in.
- Sheet present: interactive spring, response 0.42, damping 0.85.
- Font/reflow changes: immediate; never animate text re-layout.
- Reduce Motion: no spatial page animation owned by Shelf; prefer cut/crossfade behavior.

## Page gesture

Read mode is direct manipulation: horizontal content offset follows the finger 1:1 after axis lock. Commit when either distance exceeds 32% of viewport width or predicted travel velocity exceeds roughly 480 pt/s. At document boundaries, use non-linear rubber-band resistance.

Original mode delegates page interaction to PDFKit's native page-controller surface rather than layering a second competing pager on top.

## Haptics

Custom Core Haptics only. Default intensity is low and user-adjustable/off:

- Page: transient 0.30 / sharpness 0.55.
- Outline detent: 0.50 / 0.70.
- Mark: 0.15 / 0.30.
- Completion: two restrained transients 90 ms apart.

Haptics are optional and must never block reading if Core Haptics is unavailable.

## Speech highlight

Speech is sentence queued. The active sentence is the persistent reading anchor and receives an antique-gold translucent highlight. Read mode highlights the attributed sentence; Original mode uses temporary in-memory PDF annotations that are removed when playback or the reader ends.
