# Leu — Felt

Felt replaces Night Field as Leu's product shell. It is a light, textile system: a sage felt
ground, cream paper, deep ink type and a small family of dyed felts. The approved reference
is the 14-screen "full flow" overview (welcome → search). This document records slice 1 and
the order of the slices that follow.

## Slice 1 (this change): system, shell, Home

**Tokens** (`Shelf/DesignSystem/LeuDesign.swift`). Every existing semantic name is kept and
re-pointed, so all ~870 call sites move to Felt without churn.

| Role | Value | Contrast |
|---|---|---|
| Ground `void` | felt `#B6C690` | — |
| Cards `surface` | light felt `#C3D19F` | — |
| Paper `raised` | cream `#F8F1DE` | — |
| Text | ink `#24301F` | ≥ 7:1 on every surface |
| Secondary / tertiary | `#3C4A33` / `#44533A` | ≥ 4.5:1 |
| Primary action | ink pill, cream label | 12.3:1 |
| Red thread | `#B3261E` (graphics), `#8E1F17` (small text on felt) | ≥ 4.5:1 |
| Learning state | held moss `#4D6A3C`, fading tomato, untested sage, bend red thread | ≥ 3:1 |
| Concept colours | butter, tomato, denim, moss, blush, oat | — |

`scripts/test-felt-contrast.py` measures every declared pair from the Swift source;
`scripts/check-felt.py` keeps the locked rules (no script type, no glass, no sparkles, 44pt
targets, one navigation level) and now enforces the Felt palette and type system.

**Type** (`Shelf/DesignSystem/LeuType.swift`). Gabarito for display, UI and labels; Literata
for reading. Static instances (Gabarito 400–900, Literata 400/500/600 + italic) ship as data
assets in `Assets.xcassets/Fonts` and are registered at launch, so no Info.plist or project
resource phase is involved. Every face is built with `relativeTo:` and keeps Dynamic Type.
All system text styles in the app were migrated to `Font.leu(_:serif:weight:)`; system mono
remains only for code and coordinates.

**Shell.** iPhone keeps one floating pill (`PrimaryTabBar`): Home, Library, Study, Trails.
iPad uses `PrimaryTopBar`: the `leu` wordmark (Home), centred places with a red running stitch
under the current one, "Reading" (opens the last book where you left it) and search (⌘K).
The two never appear together. The app is light-only.

**Home** (`Shelf/Features/Home`). "We kept your spot warm." with the real last-opened book,
its page and progress, "Keep reading" and "Something else". The evening nook is the original
Blender render plus live layers drawn in SwiftUI `Canvas`:

- `FoggedWindow`: rain on the glass, drops that slip, fog you can wipe with a finger or the
  iPad pointer, which returns about seven seconds after you stop. VoiceOver gets a direct-touch
  surface and a "Wipe the glass" action. Reduce Motion stills the rain.
- `TeaSteam`: wisps from the cup (decorative, hidden from VoiceOver).
- `RainSound`: rain synthesised on device, off until asked, mixes with other audio.

iPad landscape follows the desktop composition (words left, window and daybed right). iPhone,
iPad portrait and accessibility text sizes reflow into one scrolling column.

UI suites launched with `--uitesting` still start in Library; pass `--start-home` to test Home.

## Next slices (in overview order)

2. Library, Bring a PDF, A book. 3. Reading, Explain, Teach. 4. Study and Ask me (snow globe on
09b/10b). 5. Notes, Explore, Trails, Search. 6. Welcome (knitting basket). Notes and Explore join
the top bar when their screens land, so the navigation never points at an empty place.
