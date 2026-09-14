# Shelf V21 — Physical iPhone Acceptance

Run this after the Mac automated suite is green. Use a real large technical PDF and at least two books with overlapping material. The purpose is to certify interaction quality that source/static tests cannot prove.

## Connected Knowledge

- Import/open multiple related PDFs while connection indexing runs. Reading, page turning and zooming must stay responsive.
- Select an exact Original-mode passage and choose **Learn → Connect**. Related results must be genuinely relevant; a weak source is allowed to return **No strong connections yet**.
- Confirm that each result shows book, page, passage context and a human reason—not a similarity percentage.
- Follow Book A passage → Book B passage. The correct PDF/page must open and the actual source phrase must receive temporary focus.
- Use **Back to previous passage** and verify return to the originating source.
- Confirm **Link these passages**, force-quit Shelf, reopen both sides and verify the backlink remains.
- Remove the connection and confirm it disappears from both discovery directions with one subdued haptic.
- Create a user Concept from a passage, add an alias, relaunch and verify both remain.
- Add passages to an existing Topic Chain; adding the same passage again must not duplicate it.
- Reorder and remove Topic Chain items; relaunch; order must survive.
- Use **Read Chain** across at least three PDFs and open each original source.
- In Read mode, long-press a paragraph. **Learn from this** must use that paragraph rather than silently capturing an unrelated whole page.
- From Notes & highlights, open **Connections** on a saved quoted annotation.
- Search `useEffect`, `React.memo`, `Promise.all`, `HTTP/2`, `C++` and `.NET`. Technical strings must remain intact and results may group Concepts, Your highlights, Topic Chains, Passages and Books.
- Long-press a related book on the shelf. Related books should lift subtly, unrelated books should stay still, and the source book must not accidentally open.
- Enable Reduce Motion and repeat a connection jump/constellation. Navigation must remain understandable without scale-heavy motion.
- Turn on VoiceOver and complete the Connections flow through the list representation; the constellation must never be the only route.

## Shelf Voice — audible corpus

Listen rather than reading the screen. Verify these cases sound understandable without looking:

- `useEffect runs after React commits the rendered output to the DOM.`
- `The === operator performs strict equality, while == allows coercion.`
- `Binary search runs in O(log n), while linear search runs in O(n).`
- `HTTPS encrypts HTTP communication using TLS.`
- `Promise.all resolves when every promise resolves.`
- `Promise<User[]> represents a promise containing an array of User objects.`
- `const [count, setCount] = useState(0)`
- `isAuthenticated && user !== null`
- `https://api.example.com/users/:id`
- `PostgreSQL uses MVCC to manage concurrent transactions.`
- `HTML, CSS, HTTP, DOM, API, JSON, SQL, OAuth and JWT.`
- `HTTP/2 can return HTTP 404 or HTTP 503.`

The visible PDF must remain unchanged while spoken wording changes.

## Voice selection / transport

- Open **Voice & listening**. If Premium or Enhanced English Apple voices are installed, Shelf must rank them above Standard.
- Pick another voice, close/reopen the book and verify the choice persists.
- Remove/unavailable a selected voice if practical, then verify Shelf falls back rather than failing playback.
- Test 0.8×, 1.0×, 1.5× and 2.0×. Code/formulas should remain slightly more deliberate than ordinary prose at the same user speed.
- Play, pause, resume, previous sentence, next sentence, 15s back and 15s forward without losing reading location.
- Change speed while speaking. Change voice while speaking. The queue must continue from the current source rather than restart the page.
- Add a pronunciation override for `PostgreSQL`, preview by reading the source, relaunch and verify it persists.
- Verify sentence highlighting follows the original source even when spoken text differs (`useEffect` → `use effect`). Incorrect word-level jumping is a failure.

## Audio lifecycle

- Lock the screen during playback. Speech should continue under the audio background mode.
- Use Control Center/lock-screen Play/Pause, next/previous and ±15-second controls.
- Connect/disconnect AirPods or Bluetooth audio. Loss of the active route must pause safely rather than restart from the page beginning.
- Receive/simulate an interruption, then resume. Current sentence/page location must survive.
- Background Shelf for several minutes, return and verify state.
- Run at least one 10-minute continuous session and one 30-minute session while watching for audio glitches, thermal warnings, battery spikes and escalating memory.

## Measurements to record

In **Voice & listening**, record request → synthesizer-start latency for cold and warm starts using Premium/Enhanced and Standard voices if available. Also record approximate memory before playback, after 10 minutes and after 30 minutes using Xcode's memory gauge/Instruments. Do not call voice performance certified without these device measurements.

## Existing reader regression

Repeat the V19 physical paging checks: Original fit-page horizontal turns, diagonal thumb drift rejection, zoomed pan ownership, arrows while zoomed, Read horizontal paging, Read continuous vertical flow, first-touch text/brightness controls, focus-mode non-overlap and bottom player spacing.
