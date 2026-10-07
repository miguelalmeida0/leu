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

## Slices 2–7: every screen in the overview

| Screen | Where | Notes |
|---|---|---|
| 01 Welcome | `Features/Home/WelcomeScreen.swift` | Empty library. Knitting basket render + live yarn (still under Reduce Motion). Optional intention kept on device, shown on Home until dismissed. Sample book via the normal import path. |
| 02b Bring a PDF | `Features/Library/SewnScreen.swift` | After one new PDF. Red running stitch while indexing; neighbours from `documentRelationshipStrengths`, joins named by a shared concept. Not shown under `--uitesting`. |
| 03 Home | slice 1 | |
| 04 Library | `Features/Library` | Felt quilt (`QuiltLayout`), shelf index on iPad, "On the needle". |
| 05 A book | `Features/BookOverview` | From a book's actions ("The whole book"). Chapter strip from the PDF outline (even parts without one), filled by understanding or reading, always said in words. |
| 06 Reading | `Reader/Components/ReaderChapterRail`, `ReaderMarginPanel` | Wide iPad (≥ 1100 pt): rail, page as paper, margin. Narrower widths unchanged. |
| 07 Explain | `ExplainLikeTen/ExplainLikeTenSheet.swift` | Butter felt card; provenance copy unchanged. |
| 08 / 10b Teach, In your own words | `Learning/Intelligence/TeachLeuSheet.swift`, `Globe/` | Snow globe: each idea got across lights a window; only every idea lights the third. Verified comparison unchanged. |
| 09b Study | `Learning/Study` | The session as one sentence of felt patches (`SentenceFlow`, `LeuMenu`); every way maps to an existing session. |
| 11b Notes | `Features/Notes` | Notebook spread from annotations; each note opens its page. |
| 12 Explore | `Knowledge/Explore` | Concepts and their bound passages only; "Make it a trail" writes page-range stops. |
| 13 Trails | `Learning/Trails/TrailWalkMap.swift` | Walk of felt patches joined by thread; wide iPad shows list + walk. |
| 14 Search | `Knowledge/Components/KnowledgeSearchSheet.swift` | Best answer first, searched words marked, Return opens it. |

09a, 10a and 11a were alternatives to 09b, 10b and 11b in the reference and are not built. The
bookshelf animation from the exploration is intentionally excluded.

Navigation is now Home, Library, Reading (opens the last book), Study, Notes, Explore, Trails.
iPhone keeps one floating pill with five places (Home, Library, Study, Notes, Explore); Trails sit inside Explore behind an Ideas | Trails switch. The current place is ink with a red running stitch.
