# Leu — Night Field redesign, pass 1

Implemented against the snapshot in `Leu-LATEST-Claude-Redesign-20260912-232703.zip`
(`REDESIGN_HANDOFF/SOURCE_SNAPSHOT_METADATA.txt`: 373 Swift files, 1089 files total,
packed 2026-09-12T23:27:04+02:00 from `/Users/malmeida/Documents/ChatGPT/Leu/LeuNativeV24_5`).

This is the **design-system and shell layer** — steps 1 to 4 of the mandate's implementation
order. It is not the whole redesign; what remains is listed at the end.

## The direction, named

**Night Field.** Graphite and near-black surfaces, one high-energy signal colour, severe
typographic hierarchy, and learning state expressed as shape and colour on the object
itself rather than as dashboard cards.

Taken from the approved references: confident typography, minimal persistent navigation,
black/graphite plus a high-energy accent, source and learning data made visually expressive,
density that still feels deliberate. Not copied pixel-for-pixel — the palette, type ramp and
components are built for this app.

## What changed

### 1. `Shelf/DesignSystem/LeuDesign.swift` — new single source of truth

Colour, type, spacing, radius, border, motion, semantic state.

| Token | Value | Meaning |
|---|---|---|
| `void` | `0x0B0B0C` | App ground. Not pure black — pure black crushes the covers. |
| `surface` / `raised` | `0x141416` / `0x1D1D20` | Cards, then cards above cards. |
| `line` | `0x2B2B30` | Hairline. Structure comes from spacing and type, not boxes. |
| `signal` | `0xC8F135` | The one accent. Held memory, confirmed steps, primary commit. |
| `fading` | `0xE8734A` | Recall slipping. |
| `held` | `signal` | Recall holding. |
| `untested` | `0x6E6E74` | Never recalled. |
| `bend` | `0xE05C42` | Where the learner's model and the source diverged. |

Semantic colour is the rule that matters: **coral means memory is slipping and nothing
else.** A screen that uses it decoratively is a bug, not a style choice.

Three type voices only — strong sans for display and UI, editorial serif for reading,
monospace for metadata and source coordinates. Monospace is what gives the metadata its
own voice without decoration, and it makes numerals line up so a column of state reads as
data without a table around it.

Concept colours are assigned by stable hash, so a concept keeps its colour across sessions.
That is what makes a field of circles readable at a glance instead of decorative.

### 2. `ShelfTheme` now resolves to `LeuDesign`

Every existing call site inherits the redesign with zero churn. `ShelfTheme` keeps its exact
API and becomes an alias layer; `LeuDesign` owns the values. Nothing downstream was edited to
re-skin the app.

**Reading deliberately did not follow the shell into the dark.** `ReaderSurround` keeps its
paper / warm / dark choice, and the paper tokens stay warm. The shell is Night Field; a book
is still allowed to be paper. Where spectacle and reading clarity conflicted, reading won.

### 3. `Shelf/DesignSystem/LeuComponents.swift` — shared components

- `LeuMemoryRing` — how much of a source is currently held, drawn on the source itself.
- `LeuSourceCover` — a cover generated from the document's own title, with diagonal hatching
  drawn in `Canvas`. No stock art, no unrelated landscape, no image asset. A shelf of PDFs
  reads like a record collection because the type does the work.
- `LeuEyebrow` / `LeuMeta` — the uppercase-mono label and metadata voices.
- `LeuFilterPill`, `LeuSignalButton` — pill controls at 44pt.
- `leuSurface()` / `leuTapTarget()` — the standard container and the guaranteed target,
  including the accessibility content shape so assistive technology measures the same
  control a finger reaches.

### 4. `PrimaryTabBar` — floating pill navigation

Library / Study / Trails as a floating capsule with a `matchedGeometryEffect` indicator,
rather than a bar sealing the bottom with a divider. Keeps the content feeling like a page.
Labels stay at every Dynamic Type size — an icon alone is not a sufficient affordance, so
the row grows instead of dropping text. Reduce Motion collapses the indicator to an instant
change rather than a slower one.

### 5. Library header and scope bar

Eyebrow `ON THIS DEVICE`, display-weight title, signal-lime import button, monospace count
line. The italic serif tagline is gone: the locked rules forbid generic taglines, so the
line now states what is actually on the device (`9 sources · stored locally`).

### 6. `scripts/check-night-field.py` replaces `check-gallery-minimalism.py`

The old gate asserted the warm palette and forbade dark mode — it encoded the design being
replaced. The new gate keeps **every behavioural invariant** the old one protected
(no tree/foliage resume imagery, the cognitive resume headline, `reader-context-return`,
`reader-search-return`, one-action connection save, app display name, no legacy two-tier
nav) and adds the locked rules as enforcement rather than review:

- script/handwritten typefaces locked out, and `.custom(` fonts must go through `LeuDesign`;
- `.rounded` system type locked out;
- glassmorphism materials locked out;
- sparkle-as-intelligence iconography locked out;
- no second global navigation inside Study or Trails;
- 44pt minimum kept in the system and in the tab bar;
- the reader must keep its own appearance tokens.

Two corrections worth noting, because they show the gate was wrong before it was right.
It first flagged its own documentation, so it now strips comments and scans code. It then
flagged the Release drawing canvas for the word "scribble" — that is a real drawing surface,
not script typography, so the rule was narrowed to typefaces actually in use.

`scripts/qa-native.sh` points at the new gate. `ShelfTabBar.swift` was deleted: it was the
legacy two-tier component, referenced by nothing.

## Verification

```
16 policy gates run.
15 PASS, including check-night-field and validate (membership re-synced).
1 FAIL: check-learning-architecture —
  LearningRepository.swift is 280 lines against a 250 boundary.
```

That failure is **pre-existing and reserved**: it reproduces on the untouched baseline zip,
and persistence is Codex-owned. It was not touched.

**Nothing here has been compiled.** There is no Swift toolchain in this environment, so no
build, no simulator, and no screenshots. Every change uses APIs already present in the files
it touches, but expect first-build errors.

## Changed files

```
added     Shelf/DesignSystem/LeuDesign.swift
added     Shelf/DesignSystem/LeuComponents.swift
added     scripts/check-night-field.py
modified  Shelf/DesignSystem/ShelfTheme.swift
modified  Shelf/Learning/Components/PrimaryTabBar.swift
modified  Shelf/Features/Library/Components/LibraryHeader.swift
modified  scripts/qa-native.sh
modified  evidence/project-manifest.json   (sync-xcode-sources.py, membership only)
deleted   Shelf/DesignSystem/ShelfTabBar.swift
deleted   scripts/check-gallery-minimalism.py
```

Reserved and untouched: `Packages/ShelfCore/**`, extraction and reconstruction, provider
semantics, validators, schemas and prompts, persistence, migrations, Supertonic plumbing.

## Not done in this pass

Steps 5 to 12 of the mandate remain: Reader and source interaction, Explain Like I'm 10 and
Lens presentation, Study landing and active session, question/reconstruction/feedback states
(including the locked green-check-inside-the-step-indicator rule), Trails and connections,
Settings coherence, the Dynamic Type / VoiceOver / smallest-iPhone sweep, and real simulator
screenshots.

Those screens currently inherit the new tokens, so they will already read as Night Field
rather than as the old warm system — but they have not been *composed* for it. Grid cards
still need `LeuSourceCover` and `LeuMemoryRing` wired to real held/fading data from the
learning snapshot, which needs a thin presentation adapter rather than business logic in
the view.
