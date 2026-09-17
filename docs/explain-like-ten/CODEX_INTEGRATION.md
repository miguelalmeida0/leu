# CODEX_INTEGRATION — Explain like I'm 10

> Historical handoff supplied in `explain-like-ten-feature.zip`. Its environment, file
> counts, proposed patches and unexecuted-test statements describe the author's baseline.
> The integration below has now been adapted to the live checkout; do not reapply these
> patches. See [INTEGRATION_RESULT.md](INTEGRATION_RESULT.md) for current code and evidence.

## Baseline identity

There is **no base SHA to report**. `docs/history/manifests/GIT_INFO.txt` states the supplied archive is a source
archive with no repository and no commit, and the extracted tree contains no `.git`. The
closest immutable identifier available is the source manifest:

```
SOURCE_SHA256SUMS.txt  sha256 = b669102f3777d88a8faeec944e503704b7b8fc2a554b344d7096f68029dc73c4
                       entries = 635
```

That hash matches the source-manifest SHA256 already cited in `docs/V26_MEGA_INTELLIGENCE_REPORT.md`,
so the baseline is the same tree Codex's V26 P0 evidence refers to. No branch was created,
no commit was made, nothing was pushed.

## Missing control documents

The prompt refers to files that **do not exist in this archive**. This is a disclosed blocker,
not an assumption:

| Referenced | Present | Action taken |
|---|---|---|
| `CURRENT_STATE_AND_OWNERSHIP.md` | no | Ownership inferred from the prompt only. Collision map below. |
| checkpoint manifest | no | Used `SOURCE_SHA256SUMS.txt` + `docs/internal/evidence/project-manifest.json` instead. |
| `RUNTIME_EXPLANATION_PROMPT.txt` | no | Authored as `Shelf/Features/ExplainLikeTen/RUNTIME_EXPLANATION_PROMPT.txt`, version 1. |
| `contracts/explanation-candidate.schema.json` | no | Authored at `contracts/explanation-candidate.schema.json`. |
| `ACCEPTANCE_TESTS.md` | no | Authored at `docs/explain-like-ten/ACCEPTANCE_TESTS.md`. |
| `PROVIDER_COST_PRIVACY.md` | no | Authored at `docs/explain-like-ten/PROVIDER_COST_PRIVACY.md`. |
| `AGENTS.md` / `CLAUDE.md` | no | None found; no repository instructions were available to follow. |

## The integration dependency that blocks this feature

`LearningIntelligenceProvider` (`Packages/ShelfCore/Sources/ShelfCore/Learning/Intelligence/LearningIntelligence.swift:47`)
exposes exactly:

```swift
var backend: String { get }
func availability() async -> LearningModelState
func generateQuestion(from packet: LearningSourcePacket) async throws -> LearningModelCandidate
```

**There is no explanation entry point.** Per the brief I did not build a second provider, did
not open a `LanguageModelSession`, and did not copy the Apple provider's inference. Instead the
feature defines its own adapter boundary and consumes a capability you supply.

Until that capability is injected, `ExplainLikeTenFeature.live(...)` returns
`.unavailable` and the sheet shows an honest unavailable state. It never falls back to the
test double. `ExplainLikeTenFeatureTests.testLiveCompositionRefusesWithoutSharedCapability`
locks that behaviour in.

## Proposed shared addition — YOURS TO APPLY, NOT APPLIED HERE

`docs/explain-like-ten/integration/shared-addition.patch` contains the minimal additive
proposal. It keeps every feature type out of ShelfCore:

```swift
public struct LearningExplanationRequest: Codable, Sendable {
    public var promptBody: String        // span-labelled source, built by the feature
    public var instructions: String      // RUNTIME_EXPLANATION_PROMPT version 1
    public var allowedSpanIDs: [String]
    public var maximumWords: Int
}

public protocol LearningExplanationCapable: Sendable {
    func generateExplanationJSON(_ request: LearningExplanationRequest) async throws -> String
}
```

`AppleLearningIntelligenceProvider` then conforms using its existing conventions — greedy
sampling, `maximumResponseTokens`, the 30-second `withThrowingTaskGroup` timeout, the
untrusted-data instruction block, and a `DynamicGenerationSchema` mirroring
`contracts/explanation-candidate.schema.json`. The schema shape is in the patch.

## Adapter mapping

| Feature side | Shared side |
|---|---|
| `ExplanationSourcePacket.promptBody` | `LearningExplanationRequest.promptBody` |
| `RUNTIME_EXPLANATION_PROMPT.txt` (v1) | `LearningExplanationRequest.instructions` |
| `ExplanationSourcePacket.allowedSpanIDs` | `LearningExplanationRequest.allowedSpanIDs` |
| `ExplanationSchema.hardMaximumWords` (220) | `LearningExplanationRequest.maximumWords` |
| returned JSON | decoded to `ExplanationCandidate` by `V26ExplanationAdapter` |
| `provider.backend` | `ExplanationRecord.backend` |
| `provider.availability()` | `ExplanationRecord.availability` |

`ExplanationSourcePacket` is deliberately separate from `LearningSourcePacket`:
yours is shaped for question generation and keyed for a question cache. Nothing in this
feature mutates or replaces it.

## Wiring, once the capability exists

In the app target, where the provider is already constructed:

```swift
let provider = AppleLearningIntelligenceProvider()
let explain = ExplainLikeTenFeature.live(
    sharedAvailability: { await provider.availability() },
    sharedExplain: { packet, mode in
        let request = LearningExplanationRequest(
            promptBody: packet.promptBody,
            instructions: ExplanationPrompt.text(mode: mode),
            allowedSpanIDs: Array(packet.allowedSpanIDs),
            maximumWords: ExplanationSchema.hardMaximumWords)
        let json = try await provider.generateExplanationJSON(request)
        return try JSONDecoder().decode(ExplanationCandidate.self, from: Data(json.utf8))
    },
    backend: provider.backend)
```

## Proposed host hooks — YOURS TO APPLY

All three files are reader shell / shared Lens surfaces and are reserved. Exact edits are in
`docs/explain-like-ten/integration/host-hooks.patch`.

1. `Shelf/Learning/LearningObjectActionSheet.swift` — one action row after `Understand`:
   `action("Explain like I'm 10", "text.book.closed", "Rewrite this passage in plain words.", id: "learning-action-explain-like-ten")`
2. `Shelf/Features/Reader/ReaderModel.swift` — `var explainLikeTenSource: LearningSource?`
3. `Shelf/Features/Reader/ReaderScreen.swift` — one `.sheet(...)` alongside the existing Lens sheet,
   presenting `ExplainLikeTenSheet` and calling `controller.reset()` on dismiss.

The current-passage path already exists: `ReaderModel+Learning.swift:20-29` builds a
`LearningSource` from the current page, and `selectReadBlock` (line 32) builds one from a
selected block. Both feed `ExplanationPacketBuilder` unchanged, so no extraction work is needed.

## Ownership conflicts

| Area | Owner | This feature |
|---|---|---|
| `LearningIntelligence.swift`, `AppleLearningIntelligenceProvider.swift` | Codex | read only; addition proposed as a patch |
| Semantic Core, extraction, `LearningRepository`, migrations | Codex | untouched |
| Reader shell, shared Lens / Study / Trails, speech | Codex | untouched; hooks proposed as a patch |
| `Shelf.xcodeproj/project.pbxproj`, `docs/internal/evidence/project-manifest.json` | Codex | **untouched** — see below |
| Design tokens (`ShelfTheme`, `ShelfControls`) | Codex | consumed only, nothing added |
| `Shelf/Features/ExplainLikeTen/**`, `ShelfTests/ExplainLikeTenFeatureTests.swift`, `contracts/`, `docs/explain-like-ten/**` | this feature | additive |

During this session I ran `scripts/sync-xcode-sources.py` against the working tree by mistake.
It modified `docs/internal/evidence/project-manifest.json`. I restored that file byte-for-byte from the
supplied archive and verified with `diff -rq` that the working tree now differs from the
baseline **only by added files**. `project.pbxproj` was confirmed byte-identical throughout.

## Integration order

1. Apply `shared-addition.patch` to ShelfCore and the Apple provider.
2. Copy the feature files (see "Changed files").
3. Apply `host-hooks.patch`.
4. `python3 scripts/sync-xcode-sources.py` — registers the 7 feature sources and 1 test file.
5. `python3 scripts/validate.py` — expect the pre-existing `appSources` failure to clear.
6. Build and run the test commands below.

## Changed files

Added, nothing modified:

```
Shelf/Features/ExplainLikeTen/ExplanationContract.swift
Shelf/Features/ExplainLikeTen/ExplanationSourcePacket.swift
Shelf/Features/ExplainLikeTen/ExplanationProvider.swift
Shelf/Features/ExplainLikeTen/ExplanationValidator.swift
Shelf/Features/ExplainLikeTen/ExplanationController.swift
Shelf/Features/ExplainLikeTen/ExplainLikeTenSheet.swift
Shelf/Features/ExplainLikeTen/ExplainLikeTenHarness.swift
Shelf/Features/ExplainLikeTen/RUNTIME_EXPLANATION_PROMPT.txt
ShelfTests/ExplainLikeTenFeatureTests.swift
contracts/explanation-candidate.schema.json
docs/explain-like-ten/CODEX_INTEGRATION.md
docs/explain-like-ten/ACCEPTANCE_TESTS.md
docs/explain-like-ten/PROVIDER_COST_PRIVACY.md
docs/explain-like-ten/integration/shared-addition.patch
docs/explain-like-ten/integration/host-hooks.patch
```

## Final app test commands

```bash
python3 scripts/sync-xcode-sources.py
python3 scripts/validate.py
xcodebuild -project Shelf.xcodeproj -scheme Shelf -configuration Debug \
  -destination "platform=iOS Simulator,id=A248FB9E-B969-4CF6-A0ED-B2013A3C60A6" \
  -derivedDataPath .build/ios-tests -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO \
  test -only-testing:ShelfTests/ExplainLikeTenFeatureTests
```

Harness run (no host edits required):

```bash
xcodebuild ... test -only-testing:ShelfTests/ExplainLikeTenFeatureTests
# device/simulator harness UI:
#   launch argument --explain-like-ten-harness
```

## Rollback

Delete the 15 added files and revert the two patches. Nothing else changed, so there is no
data migration, no cache format change and no shared behaviour to undo. The feature has no
persisted state outside its in-memory cache.
