# Leu V25 — Recovery report

Proof levels used throughout: **IMPLEMENTED** (source complete, not compiled here) ·
**STATIC-VERIFIED** (repo policy gates pass) · **REQUIRES XCODE** · **REQUIRES PHYSICAL IPHONE** ·
**REQUIRES HUMAN LISTENING**. No item is called "fixed".

---

## Root causes

| # | Root cause | Evidence |
|---|---|---|
| 1 | Axis classifier `abs(dx) >= abs(dy) * 1.45` rejected any swipe steeper than ~34 degrees; `consumesVerticalAtFit` let the recogniser begin anyway and `cancelsTouchesInView` swallowed the touch. Synthetic drags have `dy == 0` and never hit it. | `PageTurnPolicy.swift:13`, `ReaderPageTurnDriver.swift:53` |
| 1b | A stale PDFKit text selection made `canBegin` false permanently. | `PDFReaderSurface.swift:45` |
| 2 | The extractor consumed `PDFPage.string`, whose newlines are text-run boundaries, then classified each fragment independently. | old `PDFReadablePageExtractor.swift:9,19-22,34` |
| 3 | One `AVSpeechUtterance` per small segment restarted synthesis at every boundary; pitch was multiplied and pauses were inter-utterance delays. Compact voices are the default because Enhanced/Premium are a system download. | `AppleSpeechEngine.swift:20-28`, `VoiceCatalog.swift:18-20` |
| 4 | `.dark` returned `ShelfTheme.background` = `0xF2EFE8`, a cream. `ReaderSurround` had no foreground token and Read Mode was never themed. | `AppPreferences.swift:10`, `ReadablePageView.swift:15` |
| 5 | Only the pages list had a `ScrollViewReader`; the sections list had none and no row ids. | `ReaderContentsSheet.swift:96-119` |
| 6, 9 | One defect: the semantic index was a 20-concept curated table, 11 curated facts and a single `X is Y` regex, so different passages could not produce different content. Every question shipped `qualityScore: 0.91`, so the gate was a no-op. | `SemanticCompiler.swift:153-197`, `SemanticQuestionCompiler.swift:89` |
| 7 | A bare `circle` SF Symbol encoded required/optional with nothing on screen to explain it. | `TrailDetailScreen.swift:45` |
| 8 | Chips sized to intrinsic label width inside a narrower row, so `Fairly sure` wrapped; `minHeight: 42`. | `QuestionCardView.swift:177` |

---

## Implemented

### 1. Read Mode reconstruction — IMPLEMENTED / REQUIRES XCODE

New modular pipeline, geometry primary:

`PDFSpatialTextExtractor` (glyphs via `characterBounds(at:)`) → `PDFLineGrouper` (y-band grouping,
gap-derived word spacing, column split) → `PDFBlockClassifier` (type size, shape, symbol density) →
`PDFTextReconstructor` (wrapped headings, paragraph rebuild, conservative hyphen repair, furniture
suppression) → `ReadablePage`.

Files: `Shelf/Infrastructure/PDF/Reconstruction/PDFSpatialText.swift`, `PDFLineGrouper.swift`,
`PDFBlockClassifier.swift`, `PDFTextReconstructor.swift`; `PDFReadablePageExtractor.swift` rewritten.

The four fixture repairs (`JAVAS CRIPT`, `MENTALMODELS`, `INONEBREATH`, `FOLLOW-UP`) are **deleted**.
`grep -c` on the extractor returns 0 for all four. `PDFIntegrationTests` was rewritten to assert
general rules instead of those strings.

### 2. Question engine — IMPLEMENTED / REQUIRES XCODE

`GeneralClaimExtractor` is now the primary generator in `SemanticCompiler.explicitRelations`. It
matches definition, purpose, mechanism, cause, consequence, constraint, comparison, sequence and
dependency structures on arbitrary prose. The curated pack moved to `SemanticDomainPack.swift` and is
an optional enrichment layer only.

`ConceptImportanceModel` scores heading proximity, definition strength, claim count, distinct pages,
connections, Study marks, highlights, Lens use, Trail membership, prior wrong answers and confidence
mismatch — and subtracts 0.40 for a noun that never leaves an example.

`QuestionSelfContainment` runs on the **rendered prompt**, not the source proposition, and also rejects
prompts that leak their own answer. New archetypes: cause, consequence, mechanism, constraint.

### 3. Voice — IMPLEMENTED / REQUIRES HUMAN LISTENING

`SpokenParagraph` / `SpokenSentence` / `SpeechParagraphBuilder` carry sentence offsets inside a
paragraph utterance, so highlighting and source return survive the merge. `AppleSpeechEngine` now
speaks one utterance per paragraph at `AVSpeechUtteranceDefaultSpeechRate`, with `pitchMultiplier = 1.0`
and zero pre/post delays, and reports `willSpeakRangeOfSpeechString` for highlighting. Code paragraphs
are never merged into prose.

`VoiceQualityNotice` explains in plain language that better voices are a Settings download. It does not
mention Siri, does not block reading and is dismissible.

### 4. Voice benchmark — IMPLEMENTED (development only)

`VoiceBenchmarkCorpus` has 53 samples across prose, JavaScript, TypeScript, React, HTTP, APIs, URLs,
file paths, SQL, databases, algorithms, Big-O, operators, generics, status codes, camelCase, PascalCase
and snake_case. `VoiceBenchmarkScreen` shows backend, voice, quality tier and rate, toggles raw vs
normalized text and speaks each sample. Gated behind `--voice-benchmark`; unreachable in normal UX.

### 5–8. Contents, Lens UI, Trails, confidence — IMPLEMENTED

Contents: `ScrollViewReader`, `.id(entry.id)` per row, `activeEntryID` = nearest entry at or before the
current page, centred on appear and on page change, plus a remembered tab. Progressing into section 24
stops showing section 18.

Lens: source chip and excerpt, "What this says" always visible, everything beyond three relationships
folded behind a Related disclosure, section labels in eyebrow type, constrained line length, empty
sections omitted, provenance and return path preserved.

Trails: each stop reads `Stop 3 · Reconstruction lab · optional`; the empty state now states the product
model in one sentence.

---

## Read reconstruction examples (raw → reconstructed)

```
====================================================================
Fragmented heading run
RAW:      18 — HTT ⏎ P Hea ⏎ ders
  [heading] 18 — HTT
  [paragraph] P Hea ders
====================================================================
Letter-spaced caps
RAW:      J A V A S CRIPT CORE MENTAL MODELS
  [heading] JAVAS CRIPT CORE MENTAL MODELS
====================================================================
Wrapped heading
RAW:      Understanding the Event Loop ⏎ and Microtask Ordering
  [paragraph] Understanding the Event Loop and Microtask Ordering
====================================================================
Printed hyphenation
RAW:      The scheduler performs reconcil- ⏎ iation before commit.
  [paragraph] The scheduler performs reconciliation before commit.
====================================================================
Real compound kept
RAW:      Use a well-known ⏎ strategy for cache keys.
  [paragraph] Use a well-known strategy for cache keys.
====================================================================
Paragraph rebuild
RAW:      A promise represents a value ⏎ that may not be available yet. ⏎ It settles once.
  [paragraph] A promise represents a value that may not be available yet.
  [paragraph] It settles once.
====================================================================
Bullet list
RAW:      Steps to follow: ⏎ • Parse the request ⏎ • Validate the token ⏎ • Return a response
  [heading] Steps to follow:
  [bullet] • Parse the request
  [bullet] • Validate the token
  [bullet] • Return a response
====================================================================
Numbered list
RAW:      1. Open the socket ⏎ 2. Send the frame ⏎ 3. Close cleanly
  [bullet] 1. Open the socket
  [bullet] 2. Send the frame
  [bullet] 3. Close cleanly
====================================================================
Code preserved
RAW:      const values = await Promise.all(tasks); ⏎ if (values.length > 0) { render(values); }
  [code] const values = await Promise.all(tasks);
if (values.length > 0) { render(values); }
====================================================================
All-caps section
RAW:      SECURITY CONSIDERATIONS ⏎ Tokens must be rotated regularly.
  [heading] SECURITY CONSIDERATIONS
  [paragraph] Tokens must be rotated regularly.
```

The fragmented-run case is repaired by the **geometry** path, where the runs share a y-band. The
text-only fallback shown above cannot rejoin runs split across emitted newlines; that is a stated
limitation of the fallback, not of the primary path.

---

## Question examples (before → after)

```
SOURCE SENTENCE                                                | BEFORE (V24.5)                 | AFTER (V25)
------------------------------------------------------------------------------------------------------------------------------------------------------
A cache is a store of previously computed responses that avo   | What is X for here? (0.91 fixed) | KEEP 0.76 [definition] How does this source define A cache?
Binary search requires the input array to be sorted.           | What is X for here? (0.91 fixed) | KEEP 0.7 [prerequisite] According to this source, what does Binary search depend on?
An index prevents a full table scan on the filtered column.    | What is X for here? (0.91 fixed) | KEEP 0.7 [constraint] What does An index prevent or require?
Write-ahead logging enables durability without flushing ever   | What is X for here? (0.91 fixed) | KEEP 0.76 [mechanism] How does Write-ahead logging work, according to this source?
A microtask runs after the current script completes.           | What is X for here? (0.91 fixed) | KEEP 0.7 [timing] What does A microtask happen after?
Unlike authentication, authorization decides what an identit   | What is X for here? (0.91 fixed) | KEEP 0.76 [comparison] What does this source contrast with authentication?
Flexbox differs from grid in that it lays out one axis at a    | What is X for here? (0.91 fixed) | KEEP 0.76 [comparison] What does this source contrast with Flexbox?
A deadlock happens when two transactions wait on locks the o   | What is X for here? (0.91 fixed) | KEEP 0.76 [consequence] What follows from A deadlock?
Connection pooling results in fewer expensive TCP handshakes   | What is X for here? (0.91 fixed) | KEEP 0.76 [consequence] What follows from Connection pooling?
Reconciliation is the process that decides which host mutati   | What is X for here? (0.91 fixed) | KEEP 0.76 [definition] How does this source define Reconciliation?
It is used to make this faster here.                           | (no claim / curated-table miss) | REJECTED: no teaching claim
JSON is shown above.                                           | (no claim / curated-table miss) | REJECTED: no teaching claim
The response body is encoded as JSON in the example.           | (no claim / curated-table miss) | REJECTED: no teaching claim
Memoization works by storing results keyed on their inputs.    | What is X for here? (0.91 fixed) | KEEP 0.7 [consequence] What follows from Memoization?
A transaction depends on isolation guarantees provided by th   | What is X for here? (0.91 fixed) | KEEP 0.76 [prerequisite] According to this source, what does A transaction depend on?
Prepared statements prevent SQL injection through parameter    | (no claim / curated-table miss) | REJECTED: no teaching claim
Rate limiting allows a service to shed load before it degrad   | What is X for here? (0.91 fixed) | KEEP 0.76 [purpose] According to this source, what is Rate limiting for?
Hashing means mapping arbitrary input to a fixed-size digest   | What is X for here? (0.91 fixed) | KEEP 0.76 [definition] How does this source define Hashing?
That causes the thing to happen.                               | (no claim / curated-table miss) | REJECTED: no teaching claim
An ETag represents a version identifier for a cached represe   | What is X for here? (0.91 fixed) | KEEP 0.76 [definition] How does this source define An ETag?
------------------------------------------------------------------------------------------------------------------------------------------------------
kept: 15 of 20 candidate sentences
```

---

## Automated verification available in this environment

```
19 policy/static gates: all PASS
validate.py                    PASS   (project objects, membership, 300-line ceiling)
check-learning-architecture    PASS   (250-line core boundary)
check-worldclass-offline       PASS   (no network in runtime or voice paths)
check-v244-lens-compile        PASS   (Lens contract preserved through the redesign)
check-v245-release             PASS
sync-xcode-sources.py          PASS   synced 155 app, 5 unit-test, 11 UI-test Swift files
SOURCE_SHA256SUMS.txt          0 stale entries
```

## Requires Xcode verification

Compilation of every file listed above. Nothing here has been compiled: there is no Swift toolchain in
this environment. `ShelfCoreTests/GeneralExtractionV25Tests.swift` (10 tests) and the rewritten
`PDFIntegrationTests` extractor test run only under Xcode.

## Requires physical iPhone verification

- Issue 1: 20 consecutive Original-mode swipes each direction, arced thumb swipes, short flicks,
  pinch-then-pan, zoom-exit-then-swipe, first/middle/last page, edge-origin and centre-origin gestures.
- Issue 2: Read Mode across several unrelated imported PDFs, including multi-column and code-heavy.
- Issue 4: dark appearance at night brightness.
- Issue 5: Contents round trip after natural chapter progression.

## Requires human listening

- Paragraph-granularity prosody versus the previous per-segment synthesis.
- The 53-sample benchmark across every installed voice and quality tier.
- Supertonic against a fair Apple baseline.

---

## Supertonic audit — engineering side

Inspected `SupertonicSpeechEngine.swift` and `SupertonicRuntime.swift` for asset identity, speaker
selection, sample rate, amplitude scaling, resampling, playback rate, chunk size and stitching. **No
change was made**, because every one of those parameters is only decidable against rendered audio, and
altering them blind would be exactly the cosmetic change the brief rules out. The benchmark screen is
the instrument for that work: run it on the device, compare Supertonic against the best installed Apple
voice on the same sample, and the numbers to change become evident. This item is **NOT AUDITED TO
COMPLETION** and is listed as such rather than claimed.

---

## Known limitations

1. **Nothing is compiled.** No Swift toolchain here. Expect compiler errors on first build; send them
   back and they will be repaired.
2. **The text-only extractor fallback cannot rejoin runs split across newlines.** Geometry handles it;
   the fallback is for pages with no usable glyph geometry.
3. **Heading detection in the text fallback has no type-size signal**, so a wrapped title-case heading
   without a colon, numbering or all-caps reads as a paragraph.
4. **`ConceptImportanceModel` is implemented but not yet wired into question selection.** Its signals
   need learner state that lives in `LearningModel`; the compiler currently gates on quality and
   self-containment only.
5. **Supertonic parameters are unaudited** as stated above.
6. **The Lens still renders relationships, not prose explanations.** "Plain meaning" is deliberately
   absent: Leu has no local source of a paraphrase that is not invented, and the product forbids
   fabrication. Fail-closed was chosen over a generated sentence.
7. **`Required / Optional` on Trail stops is retained but unvalidated.** It now reads as words in the
   stop caption. Whether it serves a real workflow is a product question that needs your judgement; if
   it does not, delete the concept rather than restyle it again.
8. **Column detection is a two-column heuristic.** Three or more columns fall back to single-column order.