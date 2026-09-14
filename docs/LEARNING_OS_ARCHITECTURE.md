# Shelf Learning OS V20 — Architecture

Shelf V20 keeps the reader as a stable content plane and adds an offline learning domain beside it. No learning feature depends on a network service, account, backend, generative model, embedding service, Vision, or Core ML.

## Data flow

```text
PDF in Shelf vault
  -> PDFLearningIndexer (PDFKit, background actor)
  -> DocumentAnalyzer
  -> SourceSegment[]
  -> TopicClassifier
  -> DeterministicQuestionEngine + QuestionQualityEvaluator
  -> LearningRepository
  -> LearningSnapshot
       |- LearningObject
       |- LearningQuestion
       |- ReviewState / LearningAttempt
       |- LearningRelationship
       |- LearningTrail
       |- DiagramMask
       |- ExplanationRecording metadata
       |- StudySession
       `- LearningTimelineEvent
  -> Learn / Reader learning actions / Trails
```

## Boundaries

### ShelfCore / Learning domain

The domain is Foundation-only and contains source identity, document analysis models, topics, learning objects, questions, memory state, attempts, relationships, trails, masks, recordings, sessions, timeline events and reconstruction-lab definitions.

`LearningRepository` is the transaction boundary for learning persistence. `FileLearningSnapshotStore` writes a checkpointed JSON snapshot under Shelf's private app data. Existing PDF/library metadata remains in the pre-existing library repository; V20 does not migrate or destroy it.

### Analysis and question generation

`DocumentAnalyzer` normalizes PDF text, repairs confident line-wrap hyphenation, detects repeated headers/footers, segments paragraphs, headings, lists, definitions and code-like blocks, and scores importance. `TopicClassifier` applies deterministic vocabularies plus title/filename/outline/body-frequency weighting. Manual document topics replace automatic topic membership for session planning and captured objects.

`DeterministicQuestionEngine` supports definition, cloze/fill-key-concept, list membership, term-description matching and source-statement identification. Correct answers and distractors are drawn from extracted source material. `QuestionQualityEvaluator` rejects malformed, duplicate, ambiguous or structurally weak candidates. Stable IDs and deterministic option ordering prevent question churn across launches.

### Memory and sessions

`ShelfReviewScheduler` owns deterministic spaced retrieval. `TopicLearningAggregator` derives calm topic states without claiming neurological probability. `ShelfStudySessionPlanner` combines due urgency, weakness, importance, novelty, topic and estimated duration while avoiding repetitive activity runs.

### Presentation

Primary navigation is `Shelf / Learn / Trails`. The existing library remains the visual hero. Learning UI uses semantic `LearningTokens`, Dynamic-Type text styles, the existing dark forest/ivory/gold identity, and restrained signal colors.

Reader learning actions are contextual: `Remember / Test / Connect / Mask / Explain`. Original PDF mode can capture PDFKit text selection, text range and page bounds. Read mode currently falls back to the reflowed current-page source because its SwiftUI text surface does not yet expose a robust user text-selection range.

### Haptics

`HapticProviding` and `HapticEvent` form one semantic tactile language. Standard UIKit feedback is used for standard semantics; Core Haptics is reserved for the two-part Shelf session-complete signature. Haptics are optional and suppressed while audio recording is active.

### Audio

Self-explanations use AVFoundation only. Audio is recorded to local app storage as `.m4a`; no transcription, upload, speech scoring or model inference occurs.

## Invalidation and persistence

A `DocumentAnalysis` records document fingerprint and parser algorithm version. Shelf reuses unchanged analysis and reindexes when the file fingerprint or algorithm version differs. Imported/changed active books trigger `LearningModel.syncLibrary()` without blocking reading.

The V20 learning snapshot schema is versioned independently from the existing Shelf library snapshot. This keeps V19 reader/library data intact and leaves room for future migrations or future alternate implementations of analysis/question protocols without coupling the UI to any AI provider.
