# Shelf V21 — Connected Knowledge + Voice Architecture

## Product boundary

V21 adds two independent capabilities beside the existing library, reader and Learning OS. Both are deliberately local and deterministic.

```text
Library / PDF
├─ Learning OS (V20)
├─ Connected Knowledge (V21)
└─ Shelf Voice (V21)
```

No V21 capability depends on a network service, hosted inference, local LLM, embedding model, vector database, paid TTS API or account.

## Connected Knowledge

### Source content

`KnowledgePassage`, `KnowledgeSection` and `KnowledgeChapter` are derived from V20 `DocumentAnalysis`. Passage identity combines the stable document UUID with the passage content fingerprint and neighboring-context fingerprints. This deliberately avoids file URLs as identity.

`PassageReanchorer` attempts recovery after segmentation/index changes using content/context/page-proximity signals. If user-linked content cannot be safely resolved, an unavailable passage tombstone is retained so a confirmed relationship is not silently deleted.

### Derived index

`KnowledgeIndexRecord`, `ImportAnalysisState`, detected concept bindings and BM25 posting data are rebuildable. `TechnicalTokenizer` preserves technical strings such as `useEffect`, `React.memo`, `Promise.all`, `HTTP/2`, `C++`, `C#`, `.NET`, `CSS-in-JS`, `z-index` and Big-O forms.

Candidate retrieval uses an inverted BM25 index instead of all-pairs passage comparison. `ConnectionRanker` then adds Shelf-specific signals:

- shared curated/user concepts;
- shared multi-word phrases;
- rare discriminative terms;
- heading context;
- cross-book relevance;
- generic-term penalties;
- near-duplicate penalties and collapsing;
- a strict minimum quality floor.

A suggested result stores a human-readable reason such as `Same concept · Reconciliation` or `Related through · component identity` rather than exposing meaningless similarity percentages.

### User knowledge

`KnowledgeSnapshot` physically separates rebuildable index state from durable user knowledge:

```text
SOURCE-DERIVED
passages / sections / chapters

DERIVED
index records / detected bindings / import state

USER KNOWLEDGE
user Concepts / aliases / bindings
confirmed Connections
Topic Chains
```

`KnowledgeRepository.clearDerivedIndex()` preserves the user-knowledge layer and protected passage tombstones.

### Connection UX

`ConnectedPassageSheet` is the primary interaction, not a global graph. It supports:

- high-confidence local suggestions;
- passage provenance and relationship reason;
- exact cross-book destination;
- confirmed relationship types;
- connection removal;
- user Concepts;
- adding source/destination passages to existing Topic Chains;
- starting new Topic Chains;
- a bounded contextual constellation as an optional spatial view.

The normal list is retained as the complete accessible equivalent of the spatial view.

Read mode now supports passage-sized long-press capture. Original mode continues to use exact PDFKit selection where available. Saved annotations with quote text can reopen the same Connections flow.

### Navigation

`KnowledgeModel` owns passage-level navigation history, not individual views. Cross-book travel stores a `KnowledgeDestination(documentID, pageIndex, sourceText)` and the composition root opens the destination Reader. The destination passage is temporarily emphasized and can return to the previous passage.

### Topic Chains

A Topic Chain is persisted user knowledge. It is an ordered composition over source passages/concepts rather than a copied document. It can be created, appended to, reordered, removed from and read as a cross-book sequence with provenance and one-tap source navigation.

## Shelf Voice

### Compilation boundary

The key invariant is:

```text
raw/source PDF text != spoken text
```

Only `AppleSpeechEngine` may instantiate `AVSpeechUtterance`. The Reader never passes raw PDF text directly to TTS.

```text
SpeechInputBlock
→ PDFTextCleaner
→ source segmentation
→ TechnicalSpeechNormalizer / CodeSpeechNormalizer
→ PronunciationDictionary
→ SpeechProsodyPlanner
→ SpeechSegment(source mapping + spoken text)
→ AppleSpeechEngine
```

Each `SpeechSegment` retains the original source text, document/page/range and the transformed spoken representation. Visible sentence highlighting therefore follows the original source, not character equality against the speech-safe form.

### Normalization modules

Rules remain small and testable:

- PDF extraction cleanup;
- acronyms;
- operators;
- Big-O/math;
- URLs;
- networking versions/status codes;
- high-confidence TypeScript type shapes;
- natural code reading;
- system + user pronunciation dictionary.

User pronunciation overrides always run before the system pronunciation table.

### Prosody

`SpeechProsodyPlanner` differentiates prose, headings, code, formulas, lists, quotes, tables, captions and metadata. Dense code/formulas use a lower content multiplier and structural pauses are compressed—not removed—at faster user speeds.

### Voice selection

`VoiceCatalog` enumerates installed `AVSpeechSynthesisVoice.speechVoices()` and maps Apple quality to Shelf's Premium / Enhanced / Standard labels. `VoiceQualityRanker` prefers Premium, then Enhanced, then Standard, with `en-US` as a tie-breaker. A persisted explicit installed voice wins; missing/removed voices repair to the best available fallback.

### Playback and system integration

`ReaderSpeechController` owns queue state and interruption continuity. `AudioSessionCoordinator` configures `.playback` + `.spokenAudio`, Bluetooth/AirPods-compatible routing and interruption/route-loss callbacks.

`RemoteCommandCoordinator` maps Shelf's sentence queue onto lock-screen / Control Center:

- play;
- pause;
- previous sentence;
- next sentence;
- 15 seconds back;
- 15 seconds forward;
- Now Playing title/state.

The app already declares `UIBackgroundModes = audio`.

## Dependency direction

```text
Foundation-only ShelfCore domains/services
        ↑
app models / repositories / composition
        ↑
SwiftUI + PDFKit + AVFoundation + MediaPlayer adapters
```

Connected Knowledge does not depend on PDFKit types. PDF is the first source adapter; future EPUB/article sources can produce structured passages without replacing the knowledge domain.

## Persistence and migration

Existing V19/V20 library and Learning OS snapshots are untouched. V21 introduces its own checkpointed Knowledge snapshot under Shelf's private app data. Existing documents are backfilled through the normal Learning analysis/index path without blocking reading.

Index versions cover schema, segmentation, concept dictionary and ranking. A changed document/index version rebuilds derived data through the repository repair boundary.

## Performance strategy

- no O(all-passages²) connection scan;
- inverted BM25 candidate generation;
- document-level reindex only when fingerprint/version changes;
- recently opened documents prioritized during backfill;
- analysis/ranking work off the critical reader path;
- bounded related-result counts;
- bounded speech compilation to the current page/source blocks;
- no whole-book speech preprocessing before first playback.
