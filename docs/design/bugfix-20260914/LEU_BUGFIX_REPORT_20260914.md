# Leu — bug-fix report, 14 Sep 2026

Applies to the snapshot `Leu-LATEST-Claude-Bugfix-20260914-000350.zip`.
Patch: `leu-bugfix-20260914.patch` — 17 files, +259 / −26.

```
cd /Users/malmeida/Documents/ChatGPT/Leu/LeuNightFieldContrast
git apply --stat  ../leu-bugfix-20260914.patch   # preview
git apply --check ../leu-bugfix-20260914.patch   # dry run
git apply         ../leu-bugfix-20260914.patch
```

Nothing was committed or pushed. No test was weakened. No cloud dependency, no paid
inference, no redesign of Study Home, Library, Trails or Night Field. "Active Recall"
was not renamed.

---

## BUG 1 — Swiping right in Original does not turn the page

**ROOT CAUSE.** `ReaderPageTurnDriver.canBegin` requires `controller.isAtFitScale()`,
defined as `view.scaleFactor <= fitScale * 1.025`. The magnification it is compared
against, `pdfZoomScale`, is a **single global value** persisted in `UserDefaults` under
`reader.pdfZoomScale` (`AppPreferences.swift:50`) — not per document, not per session.

So one pinch, or one tap on **Fit width** (`fitPDFWidth()` sets the scale to the width
multiplier, which is above 1.0 on any page taller than the viewport), disables page
turning for **every document, permanently**, until the reader finds **Fit page** again.
The page still looks correctly fitted, so there is no visible reason for the failure.

Screenshot 6 confirms the state: `ReaderFocusBar` only renders the "Fit page" button
when `pdfZoomScale > 1.025`, and it is visible.

**CHANGE.**
- `PDFZoomState.horizontallyContained` — true when `pageWidth * scaleFactor <= viewportWidth + 1`.
- `PDFSessionController.canPageHorizontally()` — `zoom.atFit || zoom.horizontallyContained`.
- `PDFReaderSurface` uses it in `canBegin`, and reports it in the diagnostic trace.

Fit-width now pages. A genuine zoom wider than the viewport still keeps PDFKit's native
pan, so the existing "a zoomed PDF keeps native pan" contract is intact. No private
PDFKit scroll view is touched.

**VERIFICATION.** Open Original → pinch slightly or tap Fit width → swipe left/right.
Page advances. Then zoom past the viewport width → swipe pans instead of paging.
With `LEU_UI_DIAGNOSTICS=1`, `GESTURE_ARBITRATION` now carries `contained=`.

---

## BUG 2 — Quiz and recall cards are nonsense

Four distinct defects. Screenshot 1 is produced by all four at once.

### 2a. Tracked labels are shredded into single letters

PDFKit puts a space between **every glyph** of a letter-spaced label, and
`PDFSpatialTextExtractor` sources its glyphs from `page.string`. `PDFLineGrouper.makeLine`
already has a correct geometric space test, but it is short-circuited:

```swift
if explicitSpace || gap > max(first.fontSize * 0.20, tracking * 2.6) { text += " " }
```

Because PDFKit supplies an explicit space on every letter, geometry never gets a vote.
This is why the eyebrow reads `I N O N E B R E AT H` — and why `AT` stays joined, since
that kern pair is the one gap PDFKit did not split.

**CHANGE.** Detect a tracked line (≥ 6 glyphs, > 80 % single letters, median gap
> 0.18 em) and on those lines let geometry decide, with a 1.8× multiplier so the wider
word gap still becomes a space while the letter gap does not. One fix repairs the
eyebrow, heading detection, the reader display and the question text together.

### 2b. A ten-word limit silently swallowed the section labels

`DocumentAnalyzer.isHeading` requires `words.count <= 10`.

| label | tracked tokens | heading? |
|---|---|---|
| `I N O N E B R E AT H` | 10 | yes, by one token |
| `M A K E I T S T I C K` | 11 | **no** |
| `R E A L E X A M P L E` | 11 | **no** |

The two that failed were not standalone, so `paragraphBlocks` merged them into the
neighbouring paragraph. That is exactly why option C ends `the same person. R E A L E X A M P L E`.

**CHANGE.** `DocumentAnalyzer.spokenWordCount` counts a consecutive run of one- or
two-letter capitals as one word, and `isHeading` uses it. Defence in depth for the
lossless fallback path, where there is no geometry to appeal to.

### 2c. Bare `is` / `are` turns any sentence into a definition

The last rule in `GeneralClaimExtractor` maps `means|mean|refers to|...|is|are` to
`.define`. Applied to the memory hook *"One person viewed through two windows is still
the same person"*, `QuestionRealizer` produces precisely the prompt in screenshot 1:

> What does one person viewed through two windows mean in this source?

There is no answer a reader could reason to, because the source sentence asserts a
resemblance rather than a property. `validConcept` let the subject through because it
only caps at 8 words.

The same catch-all is why page 2 of the front matter became a recall card: the book's
own instruction *"Do not memorize it word-for-word. Keep the structure:"* ends in a
colon with 8 words, so `isHeading` classified it as a heading at importance 0.9, and
`ensureObjects` takes headings at ≥ 0.78 with no front-matter filter.

**CHANGE.** New `InstructionalText` (ShelfCore/Learning/Semantic) with two predicates:
`isReaderInstruction` (imperative opener, or any second-person address) and
`isMemoryHook` (analogy subject or resemblance marker). Applied in
`GeneralClaimExtractor.make` and — instruction test only — in
`LearningRepository.ensureObjects`.

The recall filter deliberately uses only the instruction test. Applying the memory-hook
regex to a whole segment would reject legitimate passages containing "used as" or
"shown in"; upstream, the claim's subject is known, so the test can be precise.

### 2d. Option length was unbounded

`make()` guarded `object.count >= 6` with **no maximum**. `QuestionSelfContainment`
allows an answer up to 320 characters. That is how a ~50-word blob became option D
while the correct answer was three words — answerable on length alone, before reading.

**CHANGE.** Objects capped at 180 characters / 28 words at claim construction, so a
runaway span never reaches the option set in the first place.

**VERIFICATION.** Re-index the JavaScript PDF (the extraction version bump purges the
old bank via `LearningRepository:58`) and check that no option contains a section label,
that no prompt is built on a MAKE IT STICK line, and that page 2 produces no cards.
New test file `TrackedLabelAndInstructionTests.swift` covers all four in isolation.

---

## BUG 3 — "Leu needs your attention: SOURCE_INTEGRITY_FAILED on page 21"

**ROOT CAUSE.** Two independent faults.

**It was fatal.** `PDFTextExtractor.swift:47` **threw**, abandoning indexing for the
whole 345-page document because of one page. And the flag it tests is left at its
`false` default by the lossless fallback branch of `PDFReadablePageExtractor`, which
fires whenever glyph reconstruction disagrees with `page.string` — a ligature or a soft
hyphen is enough. That is not a corrupt document; it is a page the spatial reconstructor
could not verify.

**It interrupted the wrong screen.** `LearningModel.swift:198` set `errorMessage` from
inside the background loop over *all* pending documents, and `LearnTodayScreen` presents
that as a blocking modal with a raw enum name. A ligature on page 21 of a LinkedIn PDF
therefore stopped you mid-session on a different book, with two buttons that both did
nothing.

**CHANGE.**
- The page degrades to its lossless canonical text and is recorded in a new
  `degradedPages` array threaded through `PDFTextExtraction` → `LearningIndexBundle`.
  Indexing continues. The page is still excluded from intelligence, so no model ever
  guesses missing source characters — the original invariant holds.
- Background failures now set the existing quiet `notice` instead of `errorMessage`.
  The raw error goes to `StudyInteractionTrace`. `errorMessage` stays for actions the
  reader actually initiated.

**VERIFICATION.** Import a PDF with a ligature-bearing page. Indexing completes, the
remaining pages produce cards, and the Study tab shows a one-line notice rather than a
modal. `StudyInteractionTrace` records `index.degraded ... reason=reconstruction_unverified`.

---

## BUG 4 — Playback shrinks the page, and the voice is a robot

### 4a. The tiny window is one misplaced view

`VoiceQualityNotice` was rendered **inside** `VoicePlayerStrip`, which sits inside
`ReaderBottomBar`, which is a `safeAreaInset(edge: .bottom)`. The notice is a headline
plus six lines of body plus a button — roughly 200 pt. Starting playback grew the bottom
inset by that much, and the PDF, holding its aspect ratio, collapsed into the letterboxed
strip in screenshot 5. The unstyled "Got it" is the same view: a bare `Button` with no
`buttonStyle`.

**CHANGE.** Removed from the transport strip. It already lives in `VoiceSettingsSheet`,
which has room for it and is where the reader goes to act on it.

### 4b. The notice fired even when it did not apply

`compactOnly` tested only for the absence of a good **Apple** voice, regardless of which
backend was reading. It would have nagged you through neural playback too.

**CHANGE.** `ReaderSpeechController.usesAppleVoices` gates it.

### 4c. The neural voice you already built is not switched on

`SupertonicSpeechEngine` + `SupertonicRuntime` are complete, ONNX-based, fully offline,
and already wired into the reader through `LeuSpeechEngine`, which selects neural
automatically when `neural.isAvailable`. It is simply not installed:
**Settings → Install neural voice (~400 MB)**. Supertonic 3 is one of the few open models
that actually targets mobile, so this was a good pick — my earlier Kokoro suggestion is
redundant, and you should finish this engine instead.

One defect would have made it feel slow once enabled: `SupertonicRuntime` was constructed
inside `Task.detached` on **every** `speak()` call, reopening four ONNX sessions per
utterance before any audio could start.

**CHANGE.** New `SupertonicRuntimeCache` actor holds one runtime and reuses it across
utterances, with a `discard()` entry point for backgrounding.

### What Apple can and cannot give you

If you would rather stay on the system synthesizer: Enhanced and Premium voices become
available to third-party apps once the user downloads them, and `VoiceCatalog` +
`VoiceQualityRanker` already select the best installed voice correctly — that code is
fine. But **Siri voices are permanently unavailable** to third-party apps; requesting one
silently substitutes an alternative. There is also no API to download voices
programmatically and no reliable deep link into that Settings pane, so the prompt stays
manual. Premium is good; neural is better, and you have already built it.

**VERIFICATION.** Start playback in Original: the page keeps its size and only the
transport strip appears. Install the neural voice, confirm Settings reads
`Leu Neural · Supertonic 3`, and check that the second sentence starts noticeably faster
than the first.

---

## FILES CHANGED

| File | Bug |
|---|---|
| `Shelf/Infrastructure/PDF/PDFZoomState.swift` | 1 |
| `Shelf/Infrastructure/PDF/PDFSessionController.swift` | 1 |
| `Shelf/Infrastructure/PDF/PDFReaderSurface.swift` | 1 |
| `Shelf/Infrastructure/PDF/PDFLineGrouper.swift` | 2a |
| `…/Learning/Analysis/DocumentAnalyzer.swift` | 2b |
| `…/Learning/Semantic/InstructionalText.swift` *(new)* | 2c |
| `…/Learning/Semantic/GeneralClaimExtractor.swift` | 2c, 2d |
| `…/Learning/Persistence/LearningRepository.swift` | 2c |
| `Shelf/Learning/RecallCardView.swift` | 2c |
| `Shelf/Learning/Services/PDFTextExtractor.swift` | 3 |
| `Shelf/Learning/Services/PDFLearningIndexer.swift` | 3 |
| `Shelf/Learning/LearningModel.swift` | 3 |
| `Shelf/Voice/UI/VoicePlayerStrip.swift` | 4a |
| `Shelf/Voice/UI/VoiceSettingsSheet.swift` | 4b |
| `Shelf/Infrastructure/PDF/ReaderSpeechController.swift` | 4b |
| `Shelf/Voice/Engine/SupertonicSpeechEngine.swift` | 4c |
| `…/Tests/…/TrackedLabelAndInstructionTests.swift` *(new)* | 2 |

---

## UNRESOLVED

1. **Nothing was compiled or run.** There is no Swift toolchain in this environment, so
   every change is reviewed but unbuilt. Brace and paren balance was checked against the
   baseline on all 17 files and is unchanged; that is not a substitute for `xcodebuild`.
   Run the full `ShelfTests` suite plus the new file before trusting any of it.

2. **One question in BUG 2 is still open.** `QuestionOptionQuality.comparable` enforces a
   2.5× word-count ratio, so option D in screenshot 1 should have been rejected before it
   ever reached the card — yet it is there. Fix 2d prevents such an object from being
   built at all, so the symptom should disappear either way, but the reason the existing
   guard did not fire is not established. Worth finding, because it may indicate a second
   path into the option set that I did not locate. Reproduce by indexing the real PDF with
   `LEU_UI_DIAGNOSTICS=1` and comparing `questions.compile generated=` against `accepted=`.

3. **Two thresholds in 2a are estimates.** The tracked-line test (0.18 em median gap,
   80 % single letters) and the 1.8× word-gap multiplier are derived from typical 9 pt
   small-caps tracking, not measured against your actual PDF. Run with
   `LEU_PDF_DIAGNOSTICS=1` on page 27 or 194 and check the `[leu-pdf] lines=` output: the
   labels should read `IN ONE BREATH`, not `I N O N E B R E AT H` and not `INONEBREATH`.
   If they come back glued together, lower the 1.8; if still split, raise it.

4. **`pdfZoomScale` is still global.** BUG 1 is fixed at the gesture layer, so paging now
   works regardless. But magnification is still shared across every document, which is
   probably not what a reader expects when moving between a dense PDF and a sparse one.
   Making it per-document is a behaviour change, so it is out of scope for a bug-fix pass —
   flagging it for your decision.

5. **The tracking fix changes extracted text**, so it needs an
   `SourceExtractionVersion.current` bump to force re-extraction. I did not bump it, since
   that decision interacts with your migration diagnostics and study-history retention
   path. Without the bump, existing documents keep their checkpointed text and the bad
   questions persist.
