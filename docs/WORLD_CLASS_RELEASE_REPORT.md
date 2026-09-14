# Shelf V21 — Connected Knowledge + Human Technical Voice Release Report

## A. Visible product changes

V21 keeps Shelf's quiet bookshelf and reader, but adds two deliberate doors into deeper behavior. **Connections** lets a passage lead into related ideas across local books and become a permanent personal relationship or Topic Chain. **Voice & listening** makes technical read-aloud compile a hidden speech-safe representation instead of blindly reading PDF characters.

The V20 Learning OS remains part of the same build.

## B. Architecture introduced

Connected Knowledge adds a Foundation-only domain for passages, sections, chapters, Concepts/Aliases, confirmed Connections, Topic Chains, index records and import state. Retrieval uses a technical tokenizer, inverted BM25 index, deterministic concept catalog, explainable connection ranker and passage reanchorer. `KnowledgeRepository` is the persistence/transaction boundary; `KnowledgeModel` is the app projection/navigation coordinator.

Shelf Voice adds source/spoken speech models, cleanup/normalization modules, pronunciation dictionary, prosody planner, compiler, Apple voice catalog/ranker, AVSpeech engine, audio-session coordinator, lock-screen/Control Center coordinator and compact reader UI.

## C. Connected Knowledge feature matrix

| Capability | Implemented | Current verification | Notes |
|---|---|---|---|
| Stable passage model | Yes | core/static | document + content/context anchoring |
| Local import/backfill indexing | Yes | core/static | reuses V20 document analysis; prioritized by recent open |
| Technical-aware lexical index | Yes | core tests | preserves programming tokens |
| BM25 candidate retrieval | Yes | core benchmark | avoids all-pairs comparison |
| Explainable connection ranker | Yes | core tests | concepts/phrases/rare terms/headings/quality floor |
| Duplicate suppression | Yes | core | near-duplicate Jaccard collapse |
| Suggested vs confirmed links | Yes | core/app | confirmed links only enter durable user store |
| Connected Highlight / passage | Yes | app/UI tests authored | Original exact selection; Read supports paragraph long press |
| Passage teleport + return | Yes | app/UI tests authored | exact PDF/page + temporary source emphasis |
| Backlinks | Yes | core tests | connection lookup is bidirectional |
| Remove link | Yes | app/core | subdued semantic haptic |
| Concepts + aliases | Yes | core/app | curated plus user-created |
| Topic Chains create/append/reorder/remove/read | Yes | core/app/UI tests authored | provenance retained |
| Contextual constellation | Yes | app | max ~6 destination nodes; accessible list remains primary |
| Book relationship interaction | Yes | app | long-press related-book lift, accidental-open suppression |
| Cross-library knowledge search | Yes | core/app | Concepts / highlights / chains / passages / books |
| Reindex safety | Yes | core tests | user data preserved, reanchor or tombstone |
| Offline/privacy boundary | Yes | static audit | no network/model dependencies |

## D. Shelf Voice matrix

| Capability | Implemented | Current verification | Notes |
|---|---|---|---|
| Premium > Enhanced > Standard discovery | Yes | native unit test authored/static | actual installed voice inventory is device-specific |
| Persist/fallback voice choice | Yes | static/native test authored | removed voice repairs to best available |
| Source/spoken separation | Yes | core tests | source mapping remains canonical |
| PDF cleanup | Yes | core tests | pagination wrap/hyphen/header/footer-capable pipeline |
| JS/TS/React/web pronunciations | Yes | core tests | dictionary + specialized deterministic rules |
| Operators/math | Yes | core tests | equality/comparison/boolean/Big-O |
| HTTP versions/status codes | Yes | core tests | includes HTTP/2, 401/403/404/500/502/503 |
| TypeScript generic speech | Yes | core tests | high-confidence Promise/Array forms |
| Natural code mode | Yes | core tests | literal mode remains an architectural option |
| Prosody by content kind | Yes | core tests | code/formula slower, structural pauses retained |
| 0.8×–2.0× speed | Yes | app | device intelligibility must be heard |
| User pronunciation overrides | Yes | app/core | local UserDefaults, user precedence |
| Sentence/source highlighting | Yes | app/core | visible source text, not spoken representation |
| ±15s + sentence transport | Yes | app | bounded speech queue |
| Interruption/route handling | Yes | app | device verification required |
| Background audio | Yes | Info.plist/audio session | physical lock-screen verification required |
| Control Center / lock-screen commands | Yes | MediaPlayer integration | physical verification required |
| Runtime start-latency instrumentation | Yes | app | records request → synth didStart on device |
| Paid/cloud TTS dependency | No | static audit | Apple on-device/system speech only |

## E. Deterministic performance evidence

Portable benchmark results are environment-specific and must not be confused with iPhone timings.

- Knowledge index query fixture: 10,000 synthetic passage records; latest portable run: **0.0715 s** (`KNOWLEDGE_BENCHMARK`).
- Speech compiler fixture: 1,000 technical blocks / 3,000 speech segments; latest portable run: **2.2721 s** (`VOICE_BENCHMARK`).

Physical iPhone speech startup, memory, CPU, battery and thermals remain separate acceptance measurements.

## F. Privacy guarantees

Connected Knowledge and Shelf Voice contain no `URLSession`, Network/WebKit client, OpenAI/Anthropic/Gemini dependency, remote TTS service, embedding API or vector database. Passage text, highlights, Concepts, Topic Chains and speech-normalized content stay local.

## G. QA

The delivery adds/retains:

- portable ShelfCore unit tests for Learning OS + Knowledge + Voice;
- technical token/ranking/search/reindex/persistence tests;
- speech cleanup/operator/code/math/network/generic/prosody/mapping/golden transformation tests;
- native Knowledge integration and Apple voice-catalog tests;
- world-class XCUITest journeys for Connections, knowledge search, Voice settings/player, Topic Chains and book connections;
- static architecture/privacy/import/UI-contract gates;
- existing PDF viewport and reader interaction regressions.

Portable verification in this delivery environment: **182/182 ShelfCore tests passed**, **263 Swift files syntax-parsed**, **427 Xcode project objects validated**, and **15/15 delivery-tool checks passed**. The project contains **19 native unit-test methods** and **48 XCUITest methods** for Apple-platform execution.

The complete Apple compile/simulator suite must run on the user's Mac through `./scripts/qa-and-copy.sh`.

## H. Genuine unresolved limitations

1. **Device certification is pending.** This container cannot truthfully measure Apple Premium voice naturalness, actual AVSpeech start latency, AirPods/Control Center behavior, haptic quality, 10/30-minute memory/thermal behavior or iPhone frame pacing.
2. **Read mode capture is passage-sized.** V21 adds long-press paragraph capture so it no longer silently falls back to the whole page, but arbitrary sub-paragraph selection remains strongest in Original/PDFKit mode.
3. **Cross-book teleport uses Shelf's existing Reader replacement lifecycle.** Destination page/source focus and return history are implemented, but the transition is not yet a bespoke cross-document matched-geometry animation.
4. **Knowledge publication is document-granular after V20 analysis.** V20 text extraction itself is progressive/off-main, but V21 publishes the connected index after a document analysis bundle is available rather than exposing partial cross-book ranking page-by-page.
5. **Custom `.shelfbackup` does not yet contain V20/V21 learning/knowledge/audio/pronunciation state.** Those are durable local app data, but custom export support is still a separate migration task.
6. **Scanned PDFs remain readable but unconnected if reliable text is unavailable.** V21 deliberately does not add OCR/model inference.
7. **No optional neural TTS engine is shipped.** The KittenTTS experiment in the specification was optional and is not included without real target-device benchmarking against the best Apple Premium voice.
8. **Ranking tuning needs a real personal-library corpus.** The architecture and synthetic benchmarks prevent pathological all-pairs behavior, but final relevance thresholds should be tuned against diverse real books without lowering the quality floor.

## I. Git/release

Branch: `feature/shelf-connected-voice-mega-release`

Baseline: `cf8566b` (`Baseline Shelf V20 Learning OS`)

The final release commit hash is reported by the delivery handoff after the one clean release commit is created and the packaged archive is re-verified.
