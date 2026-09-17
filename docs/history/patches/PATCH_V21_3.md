# Shelf V21.3 — Apple compile repair

## Fixed

`Shelf/Knowledge/KnowledgeModel.swift` failed Apple compilation because `Task.detached` referenced the instance property `pipeline` without explicit capture semantics.

Rather than capturing the `@MainActor` model itself from a detached task, V21.3 captures the immutable `KnowledgePipeline` value before entering `Task.detached`:

```swift
let pipeline = self.pipeline
let bundle = await Task.detached(priority: .utility) {
    pipeline.index(analysis: analysis, concepts: seed.concepts, aliases: seed.aliases)
}.value
```

`KnowledgePipeline` is `Sendable`, so the detached indexing work remains off the main actor without crossing the actor boundary through `KnowledgeModel`.

## Regression guard

The SwiftUI compile-contract audit now checks that the pipeline is captured locally before the detached task and rejects a future direct `self.pipeline` capture from the detached closure.

No Connected Knowledge, Learning OS, Shelf Voice, reader, persistence, privacy, or UI behavior was intentionally changed.
