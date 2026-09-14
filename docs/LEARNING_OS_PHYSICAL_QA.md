# Shelf Learning OS V20 — Physical iPhone Acceptance

Run the automated suite first with `./scripts/qa-and-copy.sh`. Then test the exact signed build on the target iPhone with real imported PDFs, including a 300+ page document.

## Reader regression gate

- Original horizontal mode settles on exactly one PDF page at fit-page scale.
- Horizontal page turn wins over normal vertical thumb jitter; a deliberate vertical gesture never changes page.
- Zoomed Original pans rather than turns pages; arrows still change page.
- Read horizontal paging works after switching Vertical -> Horizontal -> Vertical -> Horizontal.
- Read vertical mode crosses source-page boundaries continuously.
- Focus controls never cover PDF text; zoom recovery remains reachable.
- Text size, brightness, scrubber and Keep Awake respond on the first touch.
- Bottom transport, Play, bookmark, scrubber and tool rail have independent hit areas and no overlap.

## Learning flows

- Import a new selectable-text PDF while staying in Shelf. Confirm reading remains immediate and Learn later gains topics/questions without reopening the app.
- Open Learn, pick topic + 5/10/20/30 min, and complete a mixed session.
- Verify no generated question contains an answer/distractor that cannot be traced to extracted source text.
- Commit a question, View source, confirm correct PDF/page/source emphasis, then Back to question with state preserved.
- Create Remember and Test objects from an Original-mode text selection; force-quit and verify the Timeline/state survives relaunch.
- Create a diagram mask with multiple regions, study it, reveal it, rate it, relaunch and repeat.
- Create a connection across two PDFs, relaunch, open Connections, move between both first-degree concepts and source links.
- Create/reorder/optionalize a Trail containing a document, page range, learning object, question, mask, connection and lab; relaunch and verify order.
- Record an explanation, rate it Shaky/Okay/Clear, relaunch and play the previous recording.
- Trigger Blind Page after meaningful reading progress; Skip repeatedly and verify prompts become less frequent.
- Complete Interview Mode with answers hidden until commitment and confidence sampled.

## Haptic / audio gate

Exercise every row in `docs/HAPTIC_MATRIX.md`. Verify no duplicate haptic on rerender, no vibration during scroll, haptics stop immediately when disabled, and the explanation recording does not contain a haptic injected after AVAudioRecorder begins.

## Accessibility / visual gate

Test small, standard and large iPhone layouts; portrait and landscape where supported; larger Dynamic Type; Reduce Motion; VoiceOver; increased contrast where practical. Specifically look for clipped titles, hidden CTAs, overlap, low contrast, source-highlight occlusion, sheet detent problems and any regression to excessive cards/glass.

## Performance gate

On a 300+ page PDF, open/read immediately while indexing proceeds. Page turning and text interaction must remain responsive. Force-quit during indexing and reopen; the PDF must remain readable and Shelf must safely restart required analysis without corrupting library or learning snapshots.
