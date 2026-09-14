# LeuReasoningCore

A source-grounded reasoning engine for Leu. It is **not** V28 and it is not a UI
package: it has no SwiftUI, no UIKit, no ShelfCore dependency and no app target.
It can be built and tested entirely on its own.

The thesis: Leu gets more intelligent by having a **better internal
representation**, **better provenance** and **harder reasoning constraints** —
not by putting a bigger model in more places.

## The pipeline

```
SourceBlock ──► SourceRoleClassifier ──► SourceRoleAssignment
                                              │
                              ReasoningProposalProvider (proposes)
                                              │
                              ProposalAdmissionGate (admits)      ← the boundary
                                              │
                                        KnowledgeAtom
                                              │
                              KnowledgeGraphBuilder + GraphValidator
                                              │
                                       KnowledgeGraph
             ┌────────────┬───────────────┬────────────┬────────────────┐
        Mechanism     CausalChain    Counterfactual  Concept        Synthesis
         Engine         Engine          Engine      Compressor    (multi-source)
             └────────────┴───────────────┴────────────┴────────────────┘
                                              │
                 ExplanationAligner ─► MisconceptionFinding ─► QuestionPlan
                                              │                ExplanationMove
                                      UnderstandingState ─► SuggestionReason
```

## The rules that make it safe

1. **Two admissibility classes, never flattened.** `sourceSupported` means the
   document says it. `inferredValidated` means Leu composed source facts under a
   named `InferenceRule`. Attribution text differs ("From …" vs "Leu connected …").
2. **`confidenceInParsing` is about the parse, not the truth.** The source stays
   authoritative; a low value means Leu may have misread the sentence.
3. **Learner claims are a different type.** `LearnerProposition` is not a
   `KnowledgeAtom` and cannot enter the graph.
4. **Models may only propose.** `ProposalAdmissionGate` requires a verbatim span
   plus in-span subject and object. A hallucinated claim is counted as a
   rejection, not stored.
5. **Silence is a first-class answer.** Every engine returns an
   `unansweredReason` / `gaps` / `openQuestions` rather than filling the hole.
6. **Deterministic ids.** Every id is an FNV-1a digest of its defining content,
   so re-extraction is idempotent and persisted references stay valid.
7. **Every suggestion carries a `SuggestionReason`.** There is no opaque ranking
   signal and nothing optimises for engagement.

## Running the certification

```sh
scripts/evaluate-super-intelligence.sh              # structural audit + swift test
scripts/evaluate-super-intelligence.sh --structural # no toolchain needed
cd Packages/LeuReasoningCore && swift test
```

The hard gate is zero: no unsupported statement, no unsupported causal bridge,
no invented counterfactual consequence, no manufactured contrast.

To certify against a different corpus:

```sh
LEU_GOLDEN_CORPUS=/path/to/corpus.json swift test
```

The corpus is regenerated from its authoring script:

```sh
python3 Tests/LeuReasoningCoreTests/Fixtures/authoring/build_corpus.py
```

## Integrating it later

`ReasoningCore` is the only entry point an integrator needs. Adapting Leu's
existing extraction output means mapping pages to `SourceBlock` (text plus any
font size, boldness and vertical position the PDF pipeline already has) and
persisting `KnowledgeGraph` and `UnderstandingState`, both of which are `Codable`
and version-stamped with the extraction version that produced them.
