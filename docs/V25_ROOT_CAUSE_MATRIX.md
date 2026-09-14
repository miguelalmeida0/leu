# Leu V25 — Root cause matrix

Traced against the V24.5 source. Every entry below cites the line that causes the defect. Nothing here is inferred from the symptom alone.

**Headline finding:** these are not nine tickets. Issues 6 and 9 are the same defect, and Issue 1's simulator/device divergence has a single mechanical explanation. Two of the nine are one-line value errors.

---

## Issue 1 — Original-mode horizontal paging fails on device

**Root cause: the axis classifier rejects arced thumb swipes, and the gesture is consumed anyway so nothing happens.**

`Packages/ShelfCore/Sources/ShelfCore/Domain/PageTurnPolicy.swift:13`

```swift
axis = abs(dx) >= abs(dy) * 1.45 ? .horizontal : .vertical
```

A real thumb swipe arcs. Anything steeper than ~34° from horizontal classifies as `.vertical`. Then in `ReaderPageTurnDriver.swift:53`:

```swift
return policy.axis == .horizontal || consumesVerticalAtFit
```

`consumesVerticalAtFit` is `true` for Original mode (`PDFReaderSurface.swift:42`), so the recogniser **begins**, and `pan.cancelsTouchesInView = true` (line 30) swallows the touch — but `targetDelta` requires `axis == .horizontal` (`PageTurnPolicy.swift:19`) and returns `nil`. The gesture is eaten and no page turns. XCUITest drags are generated with `dy = 0`, so they classify horizontal 100% of the time. **This is the exact mechanism by which a real finger differs from a synthetic gesture.**

Two contributing factors:

- `PageTurnPolicy.swift:24` — `abs(dx) >= width * 0.32 || abs(velocityX) >= 650`. On a 393pt screen that is a 126pt swipe. `swipeReaderContentLeft` drags 0.82→0.18 of the width = 251pt and always clears it; a real short flick of 70–90pt does not.
- `PDFReaderSurface.swift:45` — `(controller.view.currentSelection?.string ?? "").isEmpty`. A real finger resting on text makes PDFKit set a selection; once set it persists, and `canBegin` returns false until it is cleared. This produces the "works, then stops working" pattern. A 0.05s synthetic drag never creates a selection.

**Fix direction:** loosen the ratio to ~1.15 with a dominant-axis re-evaluation during the pan rather than a single lock at begin; scale the commit threshold by velocity rather than a flat 32% of width; clear stale selections on pan begin instead of refusing to begin.

---

## Issue 2 — Read Mode destroys headings

**Root cause: `PDFPage.string` newlines are treated as visual lines.**

`Shelf/Infrastructure/PDF/PDFReadablePageExtractor.swift:9,19-22`

```swift
guard let page = document.page(at: pageIndex), let source = page.string
...
.components(separatedBy: .newlines).map(clean).filter { !$0.isEmpty }
```

`PDFPage.string` emits newlines at **text-run boundaries**, not visual line boundaries. Kerned or letter-spaced headings — very common in generated PDFs — are emitted as several runs, so `18 — HTTP Headers` arrives as `18 — HTT`, `P Hea`, `ders`. Each fragment is then classified independently at line 34 (`if isHeading(line)`), and because each is short, capitalised and unpunctuated, each becomes its own heading block. The reported corruption is produced exactly.

No amount of repair downstream can recover this, because the fragmentation happens before any grouping exists.

**Fix direction:** stop trusting `page.string` for layout. `PDFPage.numberOfCharacters` + `characterBounds(at:)` give per-glyph rects; group by y-band into true visual lines, infer font size from rect height, then classify. That is the `glyph blocks → spatial grouping → line classification → semantic blocks` pipeline the brief asks for, and it needs no dependency beyond PDFKit.

---

## Issue 3 — Voice sounds robotic

**Root cause: the installed voice inventory, not the synthesis configuration.**

`Shelf/Voice/Voices/VoiceCatalog.swift:18-20` already ranks by quality and picks the best available. `AppleSpeechEngine.swift:23` uses `0.48` against a `0.5` default rate — near-neutral and not the problem.

The problem is that **Premium and Enhanced voices are not installed by default on iOS**. The user must download them in Settings → Accessibility → Spoken Content → Voices. With none installed, `ranked.first` is a *compact* voice, which is the 2010-era synthesiser the user is hearing. `VoiceSettingsSheet.swift:54` already detects this case but the app does not treat it as a first-run blocker.

Also worth stating plainly, because the brief asks not to pretend: **Siri voices are not available to third-party apps** through `AVSpeechSynthesisVoice`. No code change can access them.

Secondary, real: `AppleSpeechEngine.speak` creates **one `AVSpeechUtterance` per segment** with `preUtteranceDelay`/`postUtteranceDelay`. If segmentation is fine-grained, every boundary is a synthesiser restart, which destroys cross-sentence prosody and is a large part of the "chopped" quality.

**Fix direction:** detect quality tier at launch and surface a one-time, dismissible route to install an Enhanced/Premium voice; merge segments into utterances at paragraph granularity and express pauses as SSML-style punctuation inside one utterance rather than as delays between utterances; then re-evaluate Supertonic against a fair baseline.

---

## Issue 4 — Dark appearance is not dark

**Root cause: the dark token returns a light colour, and Read Mode has no theme at all.**

`Shelf/Support/AppPreferences.swift:10`

```swift
case .dark: return ShelfTheme.background
```

`ShelfTheme.swift:12` — `background = Color(hex: 0xF2EFE8)`. That is **cream**. Selecting "Dark surround" paints a light cream surround.

Second, independent cause: `ReaderSurround` exposes only `color` — a background. It has **no foreground token**, and every consumer is a UIKit background assignment around the PDF (`PDFReaderSurface.swift:66,91,99`, `PDFSessionController.swift:102`). Read Mode text is never themed, so even with a correct dark background the type would stay `ShelfTheme.text` charcoal.

**Fix direction:** add `background`/`foreground` pairs per surround (dark ≈ `0x14161A` on `0xD8D4CC`, not pure white on pure black), and apply them in `ReadablePageView`. Leave Original mode painting the surround only, as the brief requires.

---

## Issue 5 — Contents loses the user's location

**Root cause: the sections list has no scroll restoration; only the pages list does.**

`Shelf/Features/Reader/ReaderContentsSheet.swift:96,117-119` wraps the **pages** list in `ScrollViewReader` and calls `proxy.scrollTo(model.pageIndex, anchor: .center)` on appear. The **sections** list has no `ScrollViewReader` and no `.id` on its rows. It only *marks* the current entry with a "Current location" caption (line 56-59). So reopening Contents renders from item 1 with the active section marked somewhere far below the fold — precisely as reported.

`@State private var selected = 0` (line 8) also resets the Sections/Pages tab on every presentation.

**Fix direction:** mirror the pages implementation — `ScrollViewReader`, `.id(entry.id)` per row, and on appear scroll to the nearest TOC entry at or before `model.pageIndex` with `anchor: .center`. Track last-explicitly-selected separately from derived-current so section 18 does not persist once reading reaches 24.

---

## Issue 6 — Lens repeats the same generic prompts

## Issue 9 — Question engine produces low-value questions

**These are one defect. The semantic index is a hardcoded 20-concept table.**

`Packages/ShelfCore/Sources/ShelfCore/Learning/Semantic/SemanticCompiler.swift:153-197`

- `domainPack` — **20 concepts**, all React / JS / browser / HTTP / CSS.
- `curatedFacts` — **11 facts**, all React / browser / HTTP, matched by `requiredPhrases.allSatisfy { lower.contains($0) }`.
- `CodeSemanticParser` — **5 hardcoded substring checks**.
- The only general-purpose extractor is one regex at line 89: `^(term) (is|means|refers to) (value)$`.

Lens facts are rendered from those same propositions (`UnderstandingLensFact.swift:20`: `"\(proposition.relation.questionVerb) \(proposition.objectText)"`). So for any PDF outside that tiny curated domain, **different passages cannot produce different content** — they fall through to the same handful of curated relations or to the single "X is Y" regex. That is the reported "same prompts on completely different pages", and it is the same reason arbitrary PDFs yield weak questions.

Three compounding defects in the question layer:

1. `SemanticQuestionCompiler.swift:89` — `qualityScore: 0.91` is **hardcoded for every question**. There is no quality gate; the brief's "3 excellent rather than 15 garbage" principle has no implementation to enforce it.
2. Prompt templates embed deictics with no antecedent: `"What is the purpose of \(subject.canonicalName) here?"` (line 64), `"...mean in this source?"` (line 52). That is the `What is JSON for here?` shape.
3. `DeterministicQuestionEngine.swift:31-176` — `definitionPool`, `definitionQuestions`, `termMatchingQuestions`, `clozeQuestions`, `listQuestions`, `sourceStatementQuestions` are all `private` and **never called**. `generate()` (line 6) delegates entirely to the semantic path. ~145 lines of dead archetype code.

**Fix direction:** this is the largest piece of work in the patch and it cannot be done with a bigger curated table — that would violate "must work with arbitrary imported PDFs". It needs a general extractor (definitional/causal/contrastive/sequential sentence patterns over reconstructed blocks from Issue 2), real importance scoring from the signals the brief lists, an antecedent-resolution stage, and a scoring gate that rejects. Issue 2 must land first: block reconstruction is the input to concept extraction.

---

## Issue 7 — Trails is unclear

**Root cause: an unlabelled SF Symbol encodes an invisible concept, and `.onDelete` makes destruction the dominant affordance.**

`Shelf/Learning/TrailDetailScreen.swift:45`

```swift
Image(systemName: node.isOptional ? "circle.dashed.inset.filled" : "circle")
```

The "unexplained empty circle" is a required/optional indicator with **no accessibility label, no adjacent text, no legend, and no tap target**. There is no way for a user to learn what it means.

Line 50: `.onMove(perform: move).onDelete(perform: delete)` — standard `List` deletion, which renders the red destructive affordance the user reported, with no explanation of what a stop *is*.

**Fix direction:** the product model has to be settled before the UI. A stop needs a visible type label, a source line, and a position; the circle either becomes a labelled "Optional" chip or is removed; delete moves behind a swipe.

---

# What I changed in this pass

| File | Change |
|---|---|
| `Shelf/Learning/QuestionCardView.swift` | Issue 8, complete. |
| `Shelf/Learning/Components/ReleaseSurface.swift` | Re-applied the V24.5.2 accessibility-frame fix, absent from this zip. |
| `docs/V25_ROOT_CAUSE_MATRIX.md` | This report. |
| `SOURCE_SHA256SUMS.txt` | Refreshed for the two changed sources. |

## Issue 8 — confidence control (fixed)

Root cause: `ConfidenceChipStyle` (`QuestionCardView.swift:177`) sized chips by intrinsic label width — `.padding(.horizontal, 13)` with no width constraint. Four labels (`Guessing`, `Unsure`, `Fairly sure`, `Certain`) need roughly 353pt plus 24pt of spacing inside a ~340pt row, so SwiftUI compressed them and broke `Fairly sure` across lines. `minHeight: 42` was also below the 44pt minimum.

Now: `.frame(maxWidth: .infinity, minHeight: 44)` gives four exactly equal chips with real touch targets; `.lineLimit(1)` makes word corruption impossible; at accessibility sizes the row becomes full-width stacked chips so long labels get **more room rather than smaller type**; the selected border thickens to 1.4 so selection does not rely on fill alone; `.contentShape([.interaction, .accessibility], Capsule())` makes the reported accessibility frame match the target — the same defect class as the Release controls.

---

# Verified / not verified

**Verified here:** all 16 policy audits and 5 Python suites pass; manifest integrity intact (571 entries, 0 stale).

**Not verified:** there is no Swift toolchain in this environment, so neither change has been compiled. Both use only APIs already present in their files.

**Cannot be verified without hardware:** Issues 1 and 3. Gesture arbitration and perceived voice quality are not decidable from source or simulator.

---

# Pass 2 — fixes applied

| Issue | File | Change | Status |
|---|---|---|---|
| 1 | `PageTurnPolicy.swift` | Axis ratio 1.45 → 1.15; commit threshold now velocity-graduated (`>= 320` velocity with `>= 44pt` travel) instead of a flat 32% of width. | Needs device |
| 1 | `PDFReaderSurface.swift` | A stale PDFKit selection now gets cleared by the swipe instead of permanently blocking `canBegin`. | Needs device |
| 4 | `ShelfTheme.swift` | Added `nightSurface 0x17181B`, `nightText 0xD9D5CC`, `nightSecondary 0x9A958B`. | Fixed |
| 4 | `AppPreferences.swift` | `.dark` surround no longer returns cream; added `readingBackground` / `readingText`. | Fixed |
| 4 | `ReadablePageView.swift`, `ReadHorizontalPager.swift` | Read Mode now paints the chosen appearance; all three hosts pass it. | Fixed |
| 6, 9 | `SemanticQuestionCompiler.swift` | Teachable-subject and self-contained-answer gates; deictic prompts rewritten; real computed quality score replacing the hardcoded `0.91`, with a `0.60` rejection floor. | Fixed |
| 7 | `TrailDetailScreen.swift` | The bare circle is now a worded `Required` / `Optional` control with a 44pt target; each stop states its type. | Fixed |
| 8 | `QuestionCardView.swift` | Equal-width 44pt chips, no word breaking, stacked layout at accessibility sizes. | Fixed |

## Question gate, verified by replay

Existing ShelfCore fixtures keep producing questions (5 survive of 8 candidates), and weak candidates are now rejected:

```
A closure     forward=0.76 KEEP   reverse=0.63 KEEP
A promise     forward=0.70 KEEP   reverse=0.57 reject
A microtask   forward=0.70 KEEP   reverse=0.57 reject
A component   forward=0.70 KEEP   reverse=0.57 reject
answer "JSON" (bare incidental token)  = 0.42 reject
```

`testSemanticQuestionsHaveFingerprintsAndNoPagePresenceFamily` still gets a non-empty set; `testAmbiguousOrUnsupportedTextFailsClosed` still fails closed.

## Prompt rewrites

| Before | After |
|---|---|
| `What is the purpose of X here?` | `According to this source, what is X for?` |
| `What does X mean in this source?` | `How does this source define X?` |
| `What does X depend on in this source?` | `According to this source, what does X depend on?` |

## Still open

**Issue 2 (Read Mode reconstruction)** — root cause identified and unchanged: the extractor consumes `PDFPage.string`, whose newlines are text-run boundaries. The fix is a `characterBounds(at:)` spatial-grouping pipeline, which cannot be validated without PDFKit. `PDFReadablePageExtractor.swift:70-79` also still contains four hardcoded fixture repairs (`JAVAS CRIPT`, `MENTALMODELS`, `INONEBREATH`, `FOLLOW-UP`) that the brief forbids; removing them requires a general merger — `UITextChecker` is the offline, deterministic option — and the existing `PDFIntegrationTests` assertions depend on those exact strings.

**Issue 3 (voice)** — the real defect is one `AVSpeechUtterance` per segment with inter-utterance delays, which restarts the synthesiser at every boundary. Merging to paragraph granularity touches the prosody planner and the highlight/source mapping together and should not be done without listening to the result.

**Issue 5 (Contents continuity)** — needs a `ScrollViewReader` around the sections list mirroring the existing pages implementation at `ReaderContentsSheet.swift:96-119`.

**Issue 9, remaining half** — the gate rejects bad questions but does not yet create better ones. The generator is still a 20-concept curated table plus one `X is Y` regex, so arbitrary PDFs remain thin. Fixing that depends on Issue 2 landing first: reconstructed semantic blocks are the input to concept extraction.
