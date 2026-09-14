# LEU — Current Product / Screen Flow Handoff

**Purpose:** Give Claude an accurate mental model of the current Leu product before brainstorming the *next* generation of features.

**Current build:** Native iOS / SwiftUI, Leu V24.5.

---

## 0. PRODUCT IN ONE SENTENCE

Leu is a local-first iPhone PDF reading + learning system that turns a personal PDF library into source-linked reading, memory, study, voice, and connected-knowledge experiences without requiring an account, backend, subscription, or generative-AI study dependency.

The important idea is that Leu is **not just a PDF viewer** and **not just a flashcard app**. Its current primitives already include:

- native PDF reading
- local library organization
- exact-source-linked study material
- deterministic questions
- recall scheduling / memory state
- Active Recall and Interview modes
- connected concepts/passages across books
- Trails (ordered paths through ideas)
- Understanding Lens with return-to-source behavior
- reconstruction labs
- explain-it-yourself audio
- voice reading with technical-text normalization
- optional on-device neural voice
- emotional study completion / Release interaction
- interruption recovery and study persistence
- haptics and native iPhone interactions

Any next-feature ideation should start **above this baseline**.

---

# 1. TOP-LEVEL INFORMATION ARCHITECTURE

Leu deliberately has **one persistent primary navigation level**:

```text
┌──────────────────────────────────────┐
│                LEU                   │
│                                      │
│        Current primary screen        │
│                                      │
├──────────────────────────────────────┤
│   Library        Study       Trails  │
└──────────────────────────────────────┘
```

Persistent bottom navigation:

1. **Library** — own/read/find/manage PDFs.
2. **Study** — retrieve, practice, understand, review.
3. **Trails** — connect ideas across documents into ordered paths.

Settings, Favorites, Recents and Tags are intentionally **inside Library**, not a second competing global tab bar.

---

# 2. APP LAUNCH / RECOVERY

```text
Launch
  ↓
Bootstrap local Library
  ↓
Bootstrap Learning state
  ↓
Was there an unfinished study session?
  ├─ YES → restore directly into Study
  └─ NO  → remain in Library
  ↓
Bootstrap Connected Knowledge index
```

Important behavior:

- unfinished Study can restore after relaunch
- completed sessions must NOT reopen as unfinished
- manual navigation after launch must not be stolen by delayed recovery
- app checkpoints study state when moving inactive/background
- source jumps preserve document + page + excerpt + Lens origin

---

# 3. LIBRARY FLOW

## 3.1 Library landing

```text
Library
  ├─ Continue Reading hero (when relevant)
  ├─ Scope filters
  │    ├─ All
  │    ├─ Favorites
  │    ├─ Recents
  │    └─ Tags
  ├─ Collections filter
  ├─ Search books/passages
  ├─ Cross-library concept/passage search
  ├─ PDF grid / optional compact list
  ├─ Import PDF (+)
  └─ Library options (...)
       ├─ Sort
       ├─ Manage collections
       ├─ Tags & marks
       └─ Settings
```

### Core library principles

- PDFs remain the canonical documents.
- Collections are filters, not duplicate folders/filesystems.
- A document can belong to multiple collections without copying the PDF.
- Search can surface both documents and indexed passages.
- Imported documents stay local.

## 3.2 Open a book

```text
Library book
  ↓
Full-screen Reader
```

Book-level actions also expose editing/organization and connected-knowledge entry points.

---

# 4. READER FLOW

Reader is one of Leu's most important hubs.

```text
Reader
  ├─ Original PDF mode
  │    └─ native PDFKit page behavior / fixed-layout fidelity
  │
  ├─ Read mode
  │    ├─ vertical continuous reading
  │    ├─ horizontal page reading
  │    └─ semantic zoom / alternate semantic level
  │
  ├─ Top chrome
  ├─ Bottom reader controls
  ├─ Focus mode
  ├─ Contents
  ├─ Search
  ├─ Notes
  ├─ Reader settings
  ├─ Reading state
  ├─ Timed reading
  ├─ Bookmark / study marks
  ├─ Study drawer / inspector
  ├─ Learning Object actions
  ├─ Understanding Lens
  ├─ Knowledge search
  ├─ Voice settings
  └─ optional Blind Page prompt
```

## 4.1 Reading fidelity

Original PDFs preserve:

- original typography
- colors
- code
- diagrams
- layout
- selectable text

Warm/dark reader options change surrounding space rather than pretending a fixed-layout PDF is an EPUB.

## 4.2 Reading → learning

A source passage/page can become a **Learning Object** and stay linked back to its exact source.

```text
PDF source
  ↓
Learning Object action
  ↓
Study / recall / relationships / trails
  ↓
"View source"
  ↓
Return to the exact PDF context
```

## 4.3 Understanding Lens

```text
Reader source
  ↓
Understanding Lens
  ↓
Verified/source-bound facts
  ↓
Select source action
  ↓
Reader opens exact originating location
  ↓
Return can restore Lens context
```

The round trip matters. Leu should not turn reading into detached cards with no path back to the book.

## 4.4 Voice reading

Current voice system includes:

- technical text normalization before speech
- source mapping/highlighting
- Apple voice fallback
- optional on-device neural voice (Supertonic/ONNX)
- background / remote playback infrastructure
- configurable voice/speed/technical reading behavior

Examples of normalization philosophy:

- technical operators should be spoken meaningfully
- acronyms should not be butchered
- code and prose should be treated differently
- spoken output should remain traceable to the source

---

# 5. STUDY LANDING FLOW

```text
Study
  ↓
"What should come back next?"
  ↓
Choose SUBJECT
  ├─ detected topics
  └─ Other
  ↓
Choose TIME
  ├─ 5 min
  ├─ 10 min
  ├─ 20 min
  └─ 30 min
  ↓
Start study session
```

Study material is generated locally from reliable source material. Weak candidates are skipped instead of fabricated.

Topic state can communicate states such as:

- New
- Learning
- Strengthening
- Durable
- Due
- Fading

These are study-state abstractions, not fake neurological precision.

---

# 6. STUDY — SECONDARY MODES

Directly from the Study landing:

```text
More Ways to Study
  ├─ Active Recall
  ├─ Interview Mode
  ├─ Progress
  └─ More
       ├─ Connections
       ├─ Document Topics
       └─ Search Ideas
```

## 6.1 Active Recall

Purpose: retrieve without answer choices.

User configures scope, then starts a recall-focused session.

## 6.2 Interview Mode

Purpose: deliberate-pressure practice.

Current setup supports choices around question volume / due material, then enters the same study-session engine with interview semantics.

## 6.3 Progress

Progress is deliberately **not a generic analytics dashboard**.

It is meant to answer:

- what is alive now?
- what is fading?
- what has happened to my understanding over time?
- what should return next?

Recall can be launched from Progress and must reveal the Study session rather than remain hidden behind Progress.

## 6.4 Connections

Surfaces related ideas/passages across the local library.

Avoid turning this into a generic node graph just because relationships exist underneath.

## 6.5 Document Topics

Surfaces locally identified document topics and lets users work with that structure.

## 6.6 Search Ideas

Searches passages/concepts across the library rather than only filenames.

---

# 7. STUDY SESSION FLOW

A session is a sequence of source-linked activities.

Current activity kinds include:

```text
Question
Recall
Mask / Diagram Recall
Reconstruction
Explain
Continue Reading
```

Generic flow:

```text
Study Session
  ↓
Activity 1 of N
  ↓
Respond / retrieve / reconstruct / explain
  ↓
Confidence + result where applicable
  ↓
Progress to next activity
  ↓
...
  ↓
Session Complete
```

The header includes:

- End session
- current position (X of N)
- save state (Saved / Saving / Not saved)
- approximate requested duration

The system persists enough state to survive interruption and return to the same active context.

---

# 8. QUESTION / MEMORY MODEL

Current question system is deterministic and source-bound.

Supported patterns include examples such as:

- definitions
- cloze / key concept
- list membership
- term ↔ description matching
- source-statement identification

Confidence is tracked separately from correctness so Leu can detect cases like **confident misses** rather than reducing everything to right/wrong.

Memory behavior includes:

- scheduled recall
- fading / due states
- difficult-item review
- blind spots
- reader memory markers
- source return

---

# 9. SESSION COMPLETE / EMOTIONAL FLOW

After a study round:

```text
Session Complete
  ├─ what changed
  ├─ concrete session record
  ├─ Continue reading
  ├─ Review difficult items
  ├─ Done
  └─ optional emotional check-in
```

Emotional choices can lead to different completion behavior.

Current important states include:

### Accomplished

```text
Accomplished
  ↓
Concrete acknowledgement of what was completed
  ↓
Done
```

### Irritated

```text
Irritated
  ↓
"Get it out?"
  ├─ Release
  ├─ Continue
  └─ I'm done
```

### Drained

```text
Drained
  ↓
"You can stop here. Your place is saved."
  ├─ Save my place
  └─ Finish here
```

## 9.1 Release surface

Release is a focused, temporary in-place surface:

```text
Irritated → Release
  ↓
Ephemeral drawing / physical release gesture
  ↓
Release action
  ↓
Drawing is erased
  ↓
"Better?"
  ├─ Continue
  └─ I'm done
```

Principles:

- drawing is ephemeral
- it is not interpreted as psychology
- it is not persisted as an emotion score
- controls must remain outside the gesture area
- exit must remain possible without drawing

---

# 10. RECONSTRUCTION LABS

Study landing includes **Reconstruction Labs**.

Current labs include concepts such as:

- Event Loop
- React Identity
- HTTP Cache
- TypeScript structural typing
- Database transaction

Concept:

```text
Study
  ↓
Reconstruction Lab
  ↓
Rebuild a known system/concept from memory
  ↓
Compare/run through deterministic authored structure
```

These are not generic quizzes and are a strong primitive for future interactive learning features.

---

# 11. TRAILS FLOW

Trails are ordered paths through related material.

```text
Trails
  ├─ Your Trails
  ├─ Topic Chains
  └─ New Trail
```

Create flow:

```text
New Trail
  ↓
Give it a title
  ↓
Trail Detail
  ↓
Add ordered stops
```

Possible Trail stops already include:

- Document
- Page range
- Learning Object
- Question
- Reconstruction Lab
- Mask
- Connection

Trail detail can therefore mix reading, source passages, recall and interactive practice in one ordered conceptual path.

This is one of Leu's most expandable primitives.

---

# 12. SETTINGS FLOW

Settings currently contains:

```text
Settings
  ├─ Your Library
  │    ├─ list vs bookshelf
  │    ├─ PDF first-page covers
  │    ├─ collections
  │    └─ storage
  │
  ├─ Reading
  │    ├─ vertical vs horizontal page movement
  │    ├─ page surround
  │    ├─ keep screen awake
  │    ├─ active-recall pause
  │    ├─ haptics
  │    └─ haptic intensity
  │
  ├─ Connected Library
  │    └─ rebuild derived connection index
  │
  ├─ Backup & Ownership
  │    ├─ export
  │    └─ restore
  │
  ├─ Housekeeping
  │    ├─ Trash
  │    └─ remove bundled samples
  │
  ├─ Voice
  │    ├─ current voice backend
  │    └─ install on-device neural voice
  │
  ├─ Emotional Check-ins
  │    ├─ On / Reduced / Off
  │    └─ delete emotional history
  │
  └─ Privacy & Data Ownership
```

Core privacy posture:

- no account
- no ads
- no subscription
- no generative-AI dependency for learning
- core learning and reading data are local
- explicit exports are user-controlled

---

# 13. CONNECTED KNOWLEDGE FLOW

Connected Knowledge is woven through Library, Reader, Study and Trails rather than being a standalone dashboard.

```text
PDFs
  ↓
Local passage/concept indexing
  ↓
Connections / Topic Chains / Search
  ↓
Open a connected passage
  ↓
Reader jumps to source
  ↓
Navigate back through knowledge travel
```

Current system intentionally prefers readable, source-grounded relationships over a flashy generic knowledge graph.

---

# 14. PRODUCT PRINCIPLES CLAUDE MUST PRESERVE

## A. Source sovereignty

If Leu teaches, recalls, connects or explains something, the user should be able to understand **where it came from** and return to the source.

## B. Reading remains central

Do not accidentally turn Leu into a test-prep dashboard that treats the books as raw input to be discarded.

## C. Local-first / offline-first

The current product gets much of its character from private, durable, offline behavior.

## D. Native physicality

Use iPhone-native strengths:

- touch
- gestures
- haptics
- motion
- audio
- lock-screen/background behavior
- interruption/resume
- device-local context

## E. Calm, editorial UI

Avoid:

- dashboard sprawl
- card soup
- generic SaaS surfaces
- neon/glass AI aesthetics
- fake scores
- meaningless gamification
- motivational-feed clutter
- chat boxes as the default answer to every problem

## F. Fewer, stronger actions

Features should reduce cognitive overhead rather than add permanent toolbars and modes.

## G. No detached intelligence

A clever feature is much more valuable when it is attached to:

- an exact passage
- a page
- a document
- a Trail
- a learning object
- an audio moment
- a memory state
- a real reading behavior

---

# 15. WHAT IS ALREADY COVERED — DO NOT PITCH THESE AS "NEW"

Do not return basic variants of these as novel ideas:

- PDF import / folders / tags
- normal highlighting
- bookmarks
- notes
- generic text search
- Favorites / Recents
- generic flashcards
- basic spaced repetition
- quizzes
- Active Recall
- Interview Mode
- progress/history
- reading streaks
- generic AI summaries
- chatbot over PDFs
- basic text-to-speech
- voice speed controls
- knowledge graphs
- connected passages
- topic extraction
- study plans based only on a timer
- "ask your PDF"
- simple mind maps
- generic recommendation feed
- generic gamification / XP / badges
- basic focus mode
- generic "daily review"

If an idea touches one of these, it must transform it into a substantially new interaction or capability.

---

# 16. CURRENT RELEASE NOTE FOR BRAINSTORMING

Assume the three remaining V24.5 UI-test issues are ordinary release bugs that will be fixed. Do **not** turn them into feature ideas.

Known current certification blockers:

- Release/Continue effective touch target is below the required 44 pt in two UI tests.
- Emotional-check-in Settings control becomes unreachable in one long viewport journey.

Treat the product architecture and flows above as the baseline for future ideation.

---

# 17. COMPACT FLOW MAP

```text
                            ┌──────────────┐
                            │    LAUNCH    │
                            └──────┬───────┘
                                   │
                     unfinished study session?
                         ┌─────────┴─────────┐
                        YES                 NO
                         │                   │
                         ▼                   ▼
                    ┌─────────┐       ┌──────────┐
                    │  STUDY  │       │ LIBRARY  │
                    └────┬────┘       └────┬─────┘
                         │                  │
       ┌─────────────────┼───────┐          ├─ Search
       │                 │       │          ├─ Import
       ▼                 ▼       ▼          ├─ Collections
 Active Recall       Interview  Progress    ├─ Favorites/Recents/Tags
       │                 │       │          │
       └────────┬────────┴───────┘          ▼
                │                         READER
                ▼                           │
          STUDY SESSION                     ├─ Original PDF
                │                           ├─ Read mode
        Questions / Recall                  ├─ Contents/Search/Notes
        Masks / Reconstruct                 ├─ Voice
        Explain / Continue                  ├─ Learning Object
                │                           ├─ Understanding Lens
                ▼                           ├─ Connected passage
        SESSION COMPLETE                    └─ Blind Page
                │                                  │
     ┌──────────┼────────────┐                     │
     ▼          ▼            ▼                     │
Accomplished Irritated     Drained                  │
                │                                  │
             RELEASE                               │
                │                                  │
          Better? → exit/resume                    │
                                                   │
                            ┌──────────────────────┘
                            ▼
                         TRAILS
                            │
             Documents / page ranges / objects
             questions / labs / masks / connections
                            │
                            ▼
                      exact source return
```

---

# 18. BRAINSTORM TARGET

The next generation should ask:

> **What can a reading system do in 2030 that Kindle, Apple Books, Readwise, Anki, NotebookLM, Goodreads and today's PDF apps fundamentally do not?**

Leu already owns the primitives of **source, memory, voice, connection, emotion, continuity and touch**. The highest-value next features should combine those primitives into experiences that feel *inevitable after you see them*, not like another menu item.
