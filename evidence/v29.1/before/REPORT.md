BUILD:
PASS

SWIFT TESTS:
77/77

REAL PDF SAMPLE:
40/40 pages with useful atoms

REAL KNOWLEDGE ATOMS:
80

VALIDATED RELATIONS:
327

MULTI-STEP MECHANISM CHAINS:
7

COUNTERFACTUAL SCENARIOS:
15

LEARNER ALIGNMENT:
32/32

CROSS-DOCUMENT RELATIONS:
10

UNSUPPORTED BRIDGES:
0

INVENTED CONSEQUENCES:
0

UNSUPPORTED SYNTHESIS:
0

MANUFACTURED CONTRASTS:
0

## Verification boundaries

Fresh native `swiftc` build and the actual package XCTest bundle passed. SwiftPM itself is blocked in this execution environment: stock invocation reports `permissionDenied`; a repository-local cache reaches `sandbox-exec: sandbox_apply: Operation not permitted`. The host runner does not disable that sandbox or replace XCTest assertions. It compiles the original tests and package plus the V29 tests, supplies the real resource bundle and executes Xcode’s native `xctest`. No simulator, UI, Foundation Models, backend, paid API or network inference was used.

The inherited four source fixes are preserved in `inherited-fixes.patch` and incorporated. One synthetic disagreement fixture was corrected from “at most 5 attempts” to “exactly 5 attempts”: “at most 3” and “at most 5” are compatible. The existing disagreement assertion remains; the new compatible/disjoint interval test prevents manufactured conflicts.

The fixed sample produced 80 atoms. The complete context index has 310 atoms, including definitions from non-sampled cards and prose from the bundled notes. Its 306 stated edges are reported separately from 11 definitional substitutions and 10 cross-document definition-context edges. These categories are not interchangeable.

There are 25 answered why/mechanism queries, including 7 with two edges. The multi-step paths are definition → stated effect, with the second step admitted by definition substitution. They are useful explanatory paths, not evidence of seven independent multi-hop causal discoveries. Definition-only paths do not count as mechanism answers.

The zero unsupported counts are bounded certification results: admitted-edge/provenance checks, source-span rebinds, conservative consequence rules, quote-only synthesis output and adversarial tests. They are not a universal claim of semantic completeness or zero error on arbitrary PDFs.

## Source sampling

Select every page containing the exact normalized heading IN ONE BREATH, then select 40 indices by round(i × (cardCount − 1) / 39). The page set was fixed before tuning extraction. Primary facts end before MAKE IT STICK. Mnemonic, example, interview-advice and WATCH/LEVEL-UP sections cannot create primary facts. Offsets are UTF-16 indices into the unmodified PDFKit page string.

8, 16, 24, 32, 41, 49, 58, 65, 74, 83, 91, 99, 108, 116, 124, 133, 141, 149, 158, 166, 173, 181, 190, 198, 207, 215, 224, 232, 240, 249, 257, 266, 274, 282, 290, 299, 307, 315, 324, 332

| PDF | SHA-256 |
|---|---|
| javascript_midlevel_interview_mobile_mastery | 55fdadd218b92373dbacf9e32651586fcbec57953631603fabf9185511a4a0a6 |
| React Notes | 7d42381fcbb2e1c6252457bced1a3970015142adbac4a556fb35d7ab4e318640 |
| JavaScript Deep Dive | accd8aa0a192f1848ecfec6cd9e6d4221d29eb3cf1aaddd34b344becac720aa8 |
| System Design | 97cd6c776dd1bc33d843de3d25d94045dc056544d27883a24b5a94dd432cbc7b |

## Best 15 real atoms

| Source page | Structured claim | Exact source text |
|---|---|---|
| javascript_midlevel_interview_mobile_mastery p.16 | HTTP methods → makes → API contracts predictable | They make API contracts predictable and communicate semantics to clients, caches, and infrastructure. |
| javascript_midlevel_interview_mobile_mastery p.16 | HTTP methods → communicates → semantics to clients, caches, and infrastructure | They make API contracts predictable and communicate semantics to clients, caches, and infrastructure. |
| javascript_midlevel_interview_mobile_mastery p.41 | Many real systems → requires → durable or connection-specific state; the challenge is managing it safely | Many real systems need durable or connection-specific state; the challenge is managing it safely. |
| javascript_midlevel_interview_mobile_mastery p.49 | Refresh token → balances → user convenience with short-lived access credentials | It balances user convenience with short-lived access credentials. |
| javascript_midlevel_interview_mobile_mastery p.65 | Concurrent → requests → can both make decisions from stale state [can; ] | Concurrent requests can both make decisions from stale state. |
| javascript_midlevel_interview_mobile_mastery p.74 | Webhook → replaces → wasteful polling for external service events | It replaces wasteful polling for external service events. |
| javascript_midlevel_interview_mobile_mastery p.83 | try / catch → enables → code recover, translate, log, or surface errors deliberately | It lets code recover, translate, log, or surface errors deliberately. |
| javascript_midlevel_interview_mobile_mastery p.91 | Immutability → makes → state transitions easier to reason about | It makes state transitions easier to reason about and supports change detection by identity. |
| javascript_midlevel_interview_mobile_mastery p.91 | Immutability → supports → change detection by identity | It makes state transitions easier to reason about and supports change detection by identity. |
| javascript_midlevel_interview_mobile_mastery p.99 | Array.reduce → computes → totals, groups, maps, and other aggregates [can; ] | It can compute totals, groups, maps, and other aggregates. |
| javascript_midlevel_interview_mobile_mastery p.108 | Props → creates → explicit data flow and reusable components | They create explicit data flow and reusable components. |
| javascript_midlevel_interview_mobile_mastery p.116 | Effect cleanup → prevents → duplicate listeners, stale subscriptions, and leaks | It prevents duplicate listeners, stale subscriptions, and leaks. |
| javascript_midlevel_interview_mobile_mastery p.124 | React.memo → reduces → expensive child renders [can; when props are stable] | It can reduce expensive child renders when props are stable. |
| javascript_midlevel_interview_mobile_mastery p.133 | Tree shaking → reduces → shipped JavaScript without manual deletion | It reduces shipped JavaScript without manual deletion. |
| javascript_midlevel_interview_mobile_mastery p.141 | Client-side routing → makes → SPA navigation fast while preserving URLs | It makes SPA navigation fast while preserving URLs. |

## Best 15 relations

| Relation | Class | Admission rule | Full atom bridge | Sources |
|---|---|---|---|---|
| improves | sourceSupported | none | Type guard → improves → downstream ergonomics | javascript_midlevel_interview_mobile_mastery p.207 |
| smooths | sourceSupported | none | Message queue → smooths → bursts | javascript_midlevel_interview_mobile_mastery p.158 |
| makes | sourceSupported | none | Grounding → makes → outputs verifiable | javascript_midlevel_interview_mobile_mastery p.307 |
| creates | sourceSupported | none | SLO / error budget → creates → a quantitative trade-off between shipping speed and reliability work | javascript_midlevel_interview_mobile_mastery p.332 |
| requests | sourceSupported | none | Concurrent → requests → can both make decisions from stale state [can; ] | javascript_midlevel_interview_mobile_mastery p.65 |
| centralizes | inferredValidated | definitionSubstitution | Type guard → explains → A runtime check that also teaches TypeScript a more specific type; Type guard → centralizes → validation | javascript_midlevel_interview_mobile_mastery p.207; javascript_midlevel_interview_mobile_mastery p.207 |
| smooths | inferredValidated | definitionSubstitution | Message queue → explains → A durable or buffered channel where producers enqueue messages/jobs and consumers process them later; Message queue → smooths → bursts | javascript_midlevel_interview_mobile_mastery p.158; javascript_midlevel_interview_mobile_mastery p.158 |
| prevents | inferredValidated | definitionSubstitution | State machine → explains → An explicit model of allowed states and transitions; State machine → prevents → impossible UI combinations in complex flows | javascript_midlevel_interview_mobile_mastery p.240; javascript_midlevel_interview_mobile_mastery p.240 |
| gives | inferredValidated | definitionSubstitution | Distributed cache → explains → A cache shared across application instances, commonly over the network; Distributed cache → gives → multiple servers a common cache instead of isolated in-process copies | javascript_midlevel_interview_mobile_mastery p.290; javascript_midlevel_interview_mobile_mastery p.290 |
| enables | inferredValidated | definitionSubstitution | Event bubbling → explains → The phase where an event triggered on a descendant propagates upward through its ancestors; Event bubbling → enables → parent handlers and event delegation | javascript_midlevel_interview_mobile_mastery p.149; javascript_midlevel_interview_mobile_mastery p.149 |
| decouples | inferredValidated | definitionSubstitution | Message queue → explains → A durable or buffered channel where producers enqueue messages/jobs and consumers process them later; Message queue → decouples → request latency from background work | javascript_midlevel_interview_mobile_mastery p.158; javascript_midlevel_interview_mobile_mastery p.158 |
| prevents | inferredValidated | definitionSubstitution | Effect cleanup → explains → The function returned from an effect to undo the previous subscription/resource before rerun or unmount; Effect cleanup → prevents → duplicate listeners, stale subscriptions, and leaks | javascript_midlevel_interview_mobile_mastery p.116; javascript_midlevel_interview_mobile_mastery p.116 |
| balances | inferredValidated | definitionSubstitution | Refresh token → explains → A longer-lived credential used to obtain new access tokens without asking the user to sign in again; Refresh token → balances → user convenience with short-lived access credentials | javascript_midlevel_interview_mobile_mastery p.49; javascript_midlevel_interview_mobile_mastery p.49 |
| computes | inferredValidated | definitionSubstitution | Array.reduce → explains → An array method that accumulates many elements into a single result; Array.reduce → computes → totals, groups, maps, and other aggregates [can; ] | javascript_midlevel_interview_mobile_mastery p.99; javascript_midlevel_interview_mobile_mastery p.99 |
| makes | inferredValidated | definitionSubstitution | Docker → explains → A platform for packaging and running applications in isolated containers based on images; Docker → makes → dependencies and runtime environment reproducible across machines | javascript_midlevel_interview_mobile_mastery p.173; javascript_midlevel_interview_mobile_mastery p.173 |

## Best 8 mechanism paths

1. Refresh token —explains→ A longer-lived credential used to obtain new access tokens without asking the user to sign in again; A longer-lived credential used to obtain new access tokens without asking the user to sign in again —balances→ user convenience with short-lived access credentials.
   Sources: javascript_midlevel_interview_mobile_mastery p.49, javascript_midlevel_interview_mobile_mastery p.49, javascript_midlevel_interview_mobile_mastery p.49.
2. Effect cleanup —explains→ The function returned from an effect to undo the previous subscription/resource before rerun or unmount; The function returned from an effect to undo the previous subscription/resource before rerun or unmount —prevents→ duplicate listeners, stale subscriptions, and leaks.
   Sources: javascript_midlevel_interview_mobile_mastery p.116, javascript_midlevel_interview_mobile_mastery p.116, javascript_midlevel_interview_mobile_mastery p.116.
3. Event bubbling —explains→ The phase where an event triggered on a descendant propagates upward through its ancestors; The phase where an event triggered on a descendant propagates upward through its ancestors —enables→ parent handlers and event delegation.
   Sources: javascript_midlevel_interview_mobile_mastery p.149, javascript_midlevel_interview_mobile_mastery p.149, javascript_midlevel_interview_mobile_mastery p.149.
4. Message queue —explains→ A durable or buffered channel where producers enqueue messages/jobs and consumers process them later; A durable or buffered channel where producers enqueue messages/jobs and consumers process them later —decouples→ request latency from background work.
   Sources: javascript_midlevel_interview_mobile_mastery p.158, javascript_midlevel_interview_mobile_mastery p.158, javascript_midlevel_interview_mobile_mastery p.158.
5. Docker —explains→ A platform for packaging and running applications in isolated containers based on images; A platform for packaging and running applications in isolated containers based on images —makes→ dependencies and runtime environment reproducible across machines.
   Sources: javascript_midlevel_interview_mobile_mastery p.173, javascript_midlevel_interview_mobile_mastery p.173, javascript_midlevel_interview_mobile_mastery p.173.
6. State machine —explains→ An explicit model of allowed states and transitions; An explicit model of allowed states and transitions —prevents→ impossible UI combinations in complex flows.
   Sources: javascript_midlevel_interview_mobile_mastery p.240, javascript_midlevel_interview_mobile_mastery p.240, javascript_midlevel_interview_mobile_mastery p.240.
7. Distributed cache —explains→ A cache shared across application instances, commonly over the network; A cache shared across application instances, commonly over the network —gives→ multiple servers a common cache instead of isolated in-process copies.
   Sources: javascript_midlevel_interview_mobile_mastery p.290, javascript_midlevel_interview_mobile_mastery p.290, javascript_midlevel_interview_mobile_mastery p.290.
8. HTTP methods —makes→ API contracts predictable.
   Sources: javascript_midlevel_interview_mobile_mastery p.16, javascript_midlevel_interview_mobile_mastery p.16.

Every displayed edge is present in the admitted graph. A missing continuation is left open; a configured traversal limit is explicitly distinguished from absent source evidence.

## Best 10 counterfactuals

1. {'removed': {'_0': 'Effect cleanup'}}: ruleNoLongerApplies: duplicate listeners, stale subscriptions, and leaks. The source does not establish what happens instead when this support is removed.
2. {'removed': {'_0': 'State machine'}}: ruleNoLongerApplies: impossible UI combinations in complex flows. The source does not establish what happens instead when this support is removed.
3. {'removed': {'_0': 'Event bubbling'}}: ruleNoLongerApplies: parent handlers and event delegation. The source does not establish what happens instead when this support is removed.
4. {'removed': {'_0': 'Message queue'}}: ruleNoLongerApplies: bursts; ruleNoLongerApplies: request latency from background work. The source does not establish what happens instead when this support is removed.
5. {'removed': {'_0': 'Docker'}}: ruleNoLongerApplies: dependencies and runtime environment reproducible across machines. The source does not establish what happens instead when this support is removed.
6. {'removed': {'_0': 'Webhook'}}: ruleNoLongerApplies: wasteful polling for external service events. The source does not establish what happens instead when this support is removed.
7. {'removed': {'_0': 'Tree shaking'}}: ruleNoLongerApplies: shipped JavaScript without manual deletion. The source does not establish what happens instead when this support is removed.
8. {'removed': {'_0': 'Refresh token'}}: ruleNoLongerApplies: user convenience with short-lived access credentials. The source does not establish what happens instead when this support is removed.
9. {'removed': {'_0': 'Distributed cache'}}: ruleNoLongerApplies: multiple servers a common cache instead of isolated in-process copies. The source does not establish what happens instead when this support is removed.
10. {'conditionFalse': {'_0': 'props are stable'}}: ruleNoLongerApplies: React.memo reduces expensive child renders. Your sources say what stops applying, not what happens instead.

Removing prevention never proves failure. Removing sufficient support never proves its outcome false. Only an unconditional necessary prerequisite licenses definite dependency failure and further propagation. An unbound property is unresolved.

## Learner understanding

| Category | Passed/total |
|---|---|
| paraphrase | 10/10 |
| missingCondition | 2/2 |
| partial | 2/2 |
| overgeneralisation | 3/3 |
| contradiction | 4/4 |
| reversal | 2/2 |
| unsupportedAddition | 2/2 |
| unrelated | 4/4 |
| mixed | 3/3 |

| Category | Learner explanation | Actual verdict | Findings |
|---|---|---|---|
| paraphrase | Wasteful polling for external service events is replaced by a webhook. | supported |  |
| paraphrase | Event bubbling allows parent handlers and event delegation. | supported |  |
| paraphrase | Effect cleanup avoids duplicate listeners, stale subscriptions, and leaks. | supported |  |
| paraphrase | Explicit data flow and reusable components are created by props. | supported |  |
| paraphrase | Shipped JavaScript without manual deletion is reduced by tree shaking. | supported |  |
| paraphrase | Impossible UI combinations in complex flows are prevented by a state machine. | supported |  |
| paraphrase | One source of truth for coordinated UI is created by lifting state up. | supported |  |
| paraphrase | React.memo can reduce expensive child renders when props are stable. | supported |  |
| paraphrase | HTTP is the request-response protocol used by browsers, apps, and servers to exchange web data. | supported |  |
| paraphrase | JSON is a lightweight text format for structured data using objects, arrays, strings, numbers, booleans, and null. | supported |  |
| missingCondition | React.memo can reduce expensive child renders. | partiallySupported | missingCondition |
| missingCondition | A relational database is excellent. | partiallySupported | missingCondition |
| partial | Effect cleanup prevents duplicate listeners. | partiallySupported | unsupportedAddition |
| partial | HTTP is a protocol. | partiallySupported | unsupportedAddition |
| overgeneralisation | React.memo always reduces expensive child renders. | contradicted | missingCondition, scopeTooBroad |
| overgeneralisation | React.memo always prevents every rerender. | contradicted | scopeTooBroad, unsupportedAddition |
| overgeneralisation | A relational database is always excellent. | contradicted | scopeTooBroad, unsupportedAddition |
| contradiction | Effect cleanup does not prevent duplicate listeners, stale subscriptions, and leaks. | contradicted | incorrectNegation |
| contradiction | A state machine does not prevent impossible UI combinations in complex flows. | contradicted | incorrectNegation |
| contradiction | Event bubbling does not enable parent handlers and event delegation. | contradicted | incorrectNegation |
| contradiction | A webhook does not replace wasteful polling for external service events. | contradicted | incorrectNegation |
| reversal | Parent handlers and event delegation enable event bubbling. | contradicted | reversedCauseEffect |
| reversal | Impossible UI combinations in complex flows prevent a state machine. | contradicted | reversedCauseEffect |
| unsupportedAddition | A webhook prevents server outages. | partiallySupported | unsupportedAddition |
| unsupportedAddition | A state machine creates encrypted backups. | partiallySupported | unsupportedAddition |
| unrelated | Penguins inhabit the southern hemisphere. | notAddressed |  |
| unrelated | The moon orbits Earth. | notAddressed |  |
| unrelated | My lunch contains tomatoes. | notAddressed |  |
| unrelated | A triangle has three sides. | notAddressed |  |
| mixed | A state machine prevents impossible UI combinations in complex flows. A state machine creates encrypted backups. | component-wise; see JSON | unsupportedAddition |
| mixed | A webhook replaces wasteful polling for external service events. A webhook prevents server outages. | component-wise; see JSON | unsupportedAddition |
| mixed | Event bubbling allows parent handlers and event delegation. Event bubbling creates encrypted backups. | component-wise; see JSON | unsupportedAddition |

Paraphrase admission is deliberately bounded: relation synonyms, active/passive exchange, articles and a participial/time alternation. It does not claim unrestricted natural-language understanding. Similarity ranks candidates only. Predicate, arguments, negation, qualifiers, conditions, numbers and identifiers determine support.

## Cross-document reasoning

14 candidates: 10 admitted; 4 unresolved. Request-as-a-verb and ambiguous Interface/Context senses are not admitted. Qualified name resolution is restricted to an explicitly named document namespace.

| Term | Definition source A | Use source B | Support |
|---|---|---|---|
| Cache | javascript_midlevel_interview_mobile_mastery p.31: A faster storage layer that keeps reusable results so expensive work can be avoided. | System Design p.3 [A cache → prevents → repeating work [can; ]]: A cache avoids repeating work, but introduces a second representation that can become stale. | INFERRED_VALIDATED — definitionContext |
| Cache | javascript_midlevel_interview_mobile_mastery p.31: A faster storage layer that keeps reusable results so expensive work can be avoided. | System Design p.3 [A cache → introduces → a second representation that can become stale [can; ]]: A cache avoids repeating work, but introduces a second representation that can become stale. | INFERRED_VALIDATED — definitionContext |
| Cache | javascript_midlevel_interview_mobile_mastery p.31: A faster storage layer that keeps reusable results so expensive work can be avoided. | System Design p.3 [Original documents and private annotations → explains → not disposable caches]: Original documents and private annotations are not disposable caches. | INFERRED_VALIDATED — definitionContext |
| Database | javascript_midlevel_interview_mobile_mastery p.57: A system for persistently storing, querying, and updating application data. | System Design p.2 [Passing a database object through every screen → makes → boundaries difficult to change]: Passing a database object through every screen makes boundaries difficult to change. | INFERRED_VALIDATED — definitionContext |
| Closure | javascript_midlevel_interview_mobile_mastery p.84: A function plus access to the lexical variables from the scope where it was created. | JavaScript Deep Dive p.3 [A closure → explains → a function together with access to its surrounding lexical environment]: A closure is a function together with access to its surrounding lexical environment. | INFERRED_VALIDATED — definitionContext |
| React component | javascript_midlevel_interview_mobile_mastery p.107: A reusable unit that describes UI from props, state, and context. | React Notes p.1 [A component → explains → the interface for a particular set of props, state and context]: A component describes the interface for a particular set of props, state and context. | INFERRED_VALIDATED — definitionContext |
| Props | javascript_midlevel_interview_mobile_mastery p.108: Inputs passed from a parent component to a child. | React Notes p.1 [A component → explains → the interface for a particular set of props, state and context]: A component describes the interface for a particular set of props, state and context. | INFERRED_VALIDATED — definitionContext |
| React key | javascript_midlevel_interview_mobile_mastery p.114: A stable identity hint for items among siblings in a rendered list. | React Notes p.3 [A stable key → supports → React match an item to its previous instance within a list of siblings]: A stable key helps React match an item to its previous instance within a list of siblings. | INFERRED_VALIDATED — definitionContext |
| React key | javascript_midlevel_interview_mobile_mastery p.114: A stable identity hint for items among siblings in a rendered list. | React Notes p.3 [An array index → explains → a poor key [can; when items move, are inserted or removed]]: An array index can be a poor key when items move, are inserted or removed. | INFERRED_VALIDATED — definitionContext |
| React key | javascript_midlevel_interview_mobile_mastery p.114: A stable identity hint for items among siblings in a rendered list. | React Notes p.3 [A freshly generated random key → destroys → continuity between renders]: A freshly generated random key also destroys continuity between renders. | INFERRED_VALIDATED — definitionContext |

These edges explain a named term in a second source. They do not assert whole-claim equivalence, contradiction, causation or generalization.

## Multi-source synthesis

15 actual two-source comparisons: ten definition-context pairs and five unresolved controls. Statements are the exact source excerpts, with separate open questions. No real conflict was manufactured to fill a category. The implementation separately tests equivalence, restrictions and numeric/negation conflicts with adversarial cases; those synthetic attacks are not counted as real-document synthesis evidence.

## Question planning and understanding state

Question plans select cognitive operations and required grounded material. The React.memo condition omission produces `identifyMissingCondition` for “props are stable”, priority 0.98, with the explicit learner omission as the reason. Plans contain no generated question copy. `question-plans.json` records every evaluated learner case.

The state evidence projects an explicit source revisit, submitted incomplete explanation, correction and resubmission. Attempts retain the full alignment, including supported, missing and contradicted propositions. Source opening alone creates neither a successful attempt nor mastery. Optional alignment preserves decoding compatibility for prior state archives. No emotion, intelligence, motivation or dwell-time signal is used.

Explanation strategies are selected from admitted source material; no analogy is generated. See `explanation-strategies.json`.

## Performance

Fresh PDFKit bridge: 557.24 ms for 357 pages in 4 PDFs. Measurements use the actual native Mac process, without an optimization build flag.

| Operation | Samples | p50 ms | p95 ms |
|---|---|---|---|
| atomExtraction40Pages | 31 | 109.808 | 113.912 |
| counterfactualQuery | 31 | 0.044 | 0.050 |
| graphConstruction | 31 | 40.144 | 40.541 |
| learnerAlignment | 31 | 21.868 | 22.218 |
| mechanismQuery | 31 | 0.044 | 0.050 |
| multiSourceSynthesis | 31 | 0.136 | 0.140 |
| relationAdmission | 7 | 547.134 | 656.897 |

## Reproduce

```sh
python3 scripts/test-reasoning-host.py
python3 scripts/certify-v29-reasoning.py
python3 scripts/report-v29-reasoning.py
```

## Remaining limits

- This is an isolated reasoning package, not a V28.1 UI integration. Protected production paths remain unchanged.
- Card/title completion and prose parsing are bounded grammars. Ambiguous pronouns and unsupported grammar remain unresolved; the full rejection file exposes them.
- Cross-source reasoning currently certifies definition-context links. It does not certify broad causal discovery across the library.
- The seven two-edge explanations substitute definitions into stated effects; deeper independent causal mechanisms remain to be proven on richer sources.
- The learner set is 32 authored explanations of actual extracted claims, not an independent human benchmark. Broad free-form paraphrases and implicit premises remain limited.
- The real synthesis sample contains no proven genuine disagreement; adversarial tests cover conflicting and compatible constraints separately.
- SwiftPM launch remains an environment limitation even though native compilation and real XCTest execution pass.

## Scope and files

```text
 M Packages/LeuReasoningCore/Sources/LeuReasoningCore/Atoms/KnowledgeAtom.swift
 M Packages/LeuReasoningCore/Sources/LeuReasoningCore/Atoms/RelationLexicon.swift
 M Packages/LeuReasoningCore/Sources/LeuReasoningCore/Atoms/TextScanning.swift
 M Packages/LeuReasoningCore/Sources/LeuReasoningCore/Concept/ConceptModel.swift
 M Packages/LeuReasoningCore/Sources/LeuReasoningCore/Counterfactual/CounterfactualEngine.swift
 M Packages/LeuReasoningCore/Sources/LeuReasoningCore/Graph/GraphValidator.swift
 M Packages/LeuReasoningCore/Sources/LeuReasoningCore/Graph/KnowledgeGraph.swift
 M Packages/LeuReasoningCore/Sources/LeuReasoningCore/Graph/KnowledgeRelation.swift
 M Packages/LeuReasoningCore/Sources/LeuReasoningCore/Learner/ExplanationAligner.swift
 M Packages/LeuReasoningCore/Sources/LeuReasoningCore/Mechanism/MechanismEngine.swift
 M Packages/LeuReasoningCore/Sources/LeuReasoningCore/Provenance/Grounding.swift
 M Packages/LeuReasoningCore/Sources/LeuReasoningCore/Provenance/SourceRole.swift
 M Packages/LeuReasoningCore/Sources/LeuReasoningCore/ReasoningCore.swift
 M Packages/LeuReasoningCore/Sources/LeuReasoningCore/State/UnderstandingState.swift
 M Packages/LeuReasoningCore/Sources/LeuReasoningCore/Synthesis/MultiSourceSynthesis.swift
 M Packages/LeuReasoningCore/Tests/LeuReasoningCoreTests/Fixtures/golden-corpus.json
 M evidence/super-intelligence/structural-audit.json
?? Packages/LeuReasoningCore/Sources/LeuReasoningCore/Atoms/CanonicalSource.swift
?? Packages/LeuReasoningCore/Sources/LeuReasoningCore/Graph/CertifiedReasoningIndex.swift
?? Packages/LeuReasoningCore/Sources/LeuReasoningCore/Learner/SourceBoundExplanationAligner.swift
?? Packages/LeuReasoningCore/Tests/LeuReasoningCoreTests/V29GroundingTests.swift
?? evidence/super-intelligence/evaluation-report.json
?? evidence/v29-real-reasoning/
?? scripts/certify-v29-reasoning.py
?? scripts/report-v29-reasoning.py
?? scripts/test-reasoning-host.py
?? scripts/v29-certify.swift
?? scripts/v29-pdf-bridge.swift
```

The pre-existing `evidence/super-intelligence` files are preserved and are not treated as fresh V29 certification. The legitimate V29 package, tooling and evidence are the commit scope.
