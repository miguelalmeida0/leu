CLAIM PAGES: 40/40
QUESTIONS: 25
CONNECTIONS: 10
PARAPHRASE FIXTURES: 43/43

Executed `python3 scripts/run-v28-results.py` against ShelfCore and fingerprint-checked production V5 PDFKit analyses of the four actual PDFs. All counts above come from emitted runtime results, not mock generation. No Foundation Models inference is claimed.

## Claim reconstruction

The fixed, preselected 40-page sample is unchanged. Each accepted packet retains its card title span, primary factual block, adjacent sentence ranges and local reference resolution. Mnemonics, interview formulations, advice and examples remain separately labeled; only primary facts produce these questions. Source text is never rewritten in its citation.

The initial contextual attempt yielded 17/40 because repeated titles in interview sections made whole-page title matching ambiguous. Restricting title resolution to the region before the factual block recovered the actual card identity. `claim-yield-initial17.json` and `claim-rejection-diagnosis.json` preserve that diagnosis.

| Page | Card | Claims |
|---|---|---|
| 8 | HTTP | 1 |
| 16 | HTTP methods | 1 |
| 24 | JSON | 1 |
| 32 | Cache hit | 1 |
| 41 | Stateful system | 1 |
| 49 | Refresh token | 1 |
| 58 | Relational database | 1 |
| 65 | Race condition | 1 |
| 74 | Webhook | 1 |
| 83 | try / catch | 1 |
| 91 | Immutability | 1 |
| 99 | Array.reduce | 1 |
| 108 | Props | 1 |
| 116 | Effect cleanup | 1 |
| 124 | React.memo | 1 |
| 133 | Tree shaking | 1 |
| 141 | Client-side routing | 1 |
| 149 | Event bubbling | 1 |
| 158 | Message queue | 1 |
| 166 | Unit test | 1 |
| 173 | Docker | 1 |
| 181 | Latency | 1 |
| 190 | Queue | 1 |
| 198 | KISS | 1 |
| 207 | Type guard | 1 |
| 215 | Utility types | 1 |
| 224 | Lifting state up | 1 |
| 232 | Headless component | 1 |
| 240 | State machine | 1 |
| 249 | Module | 1 |
| 257 | Single Responsibility Principle | 1 |
| 266 | Denormalization | 1 |
| 274 | Deadlock | 1 |
| 282 | Write-through cache | 1 |
| 290 | Distributed cache | 1 |
| 299 | Tokenizer | 1 |
| 307 | Grounding | 1 |
| 315 | Inference | 1 |
| 324 | Contract test | 1 |
| 332 | SLO / error budget | 1 |

## All 25 questions — inspected

Each wrong option is an independently verified factual statement about another mechanism, not an invented technical falsehood. Correctness is relative to the specific named source concept and its stated effect. All emitted stems, choices, correct answers and full factual explanations were read. Review notes explain why each pair of alternatives fails to answer that question.

Some alternatives are easier than others after excluding overlapping implementations. These results establish source-grounded mechanism/tradeoff questions; they do not establish every proposed Question V4 cognitive family.

### p.16 — HTTP methods

According to the source, how do HTTP methods make API contracts predictable and communicate semantics to clients, caches, and infrastructure?

- A. The server message that reports the result of a request. (Response, p.15)
- B. Standard verbs that express what operation a request intends to perform. (HTTP methods, p.16)
- C. The payload sent inside a request, commonly with POST, PUT, or PATCH. (Request body, p.19)

Answer: **B**. HTTP methods: Standard verbs that express what operation a request intends to perform. They make API contracts predictable and communicate semantics to clients, caches, and infrastructure.

Review: Operation verbs explain request intent; neither the response nor request payload supplies that method contract.

### p.49 — Refresh token

According to the source, how does a refresh token balance user convenience with short-lived access credentials?

- A. Cross-Site Scripting: untrusted content causes attacker-controlled script or dangerous markup to execute in a user's browser context. (XSS, p.52)
- B. A longer-lived credential used to obtain new access tokens without asking the user to sign in again. (Refresh token, p.49)
- C. Server-recognized state that ties a sequence of requests to an authenticated user or interaction. (Session, p.44)

Answer: **B**. Refresh token: A longer-lived credential used to obtain new access tokens without asking the user to sign in again. It balances user convenience with short-lived access credentials.

Review: Renewing access credentials explains the stated balance; neither an attack mechanism nor generic session state is refresh-token renewal.

### p.74 — Webhook

According to the source, how does a webhook replace wasteful polling for external service events?

- A. An HTTP callback one system sends to another when an event occurs. (Webhook, p.74)
- B. A long-lived HTTP connection where the server continuously pushes text events to the browser in one direction. (Server-Sent Events, p.73)
- C. A long-lived full-duplex connection that lets client and server send messages in both directions. (WebSocket, p.71)

Answer: **A**. Webhook: An HTTP callback one system sends to another when an event occurs. It replaces wasteful polling for external service events.

Review: The event-triggered system-to-system callback is the webhook mechanism; persistent browser push and bidirectional sockets are distinct protocols.

### p.83 — try / catch

According to the source, how does try / catch let code recover, translate, log, or surface errors deliberately?

- A. Syntax that extracts properties or elements into variables. (Destructuring, p.93)
- B. Syntax for writing Promise-based asynchronous code in a sequential-looking style. (async / await, p.82)
- C. Language syntax for handling exceptions thrown during execution, including rejected promises when awaited. (try / catch, p.83)

Answer: **C**. try / catch: Language syntax for handling exceptions thrown during execution, including rejected promises when awaited. It lets code recover, translate, log, or surface errors deliberately.

Review: Exception handling, including awaited rejection, explains recovery; destructuring and async syntax alone do not catch exceptions.

### p.91 — Immutability

According to the source, how does immutability make state transitions easier to reason about and support change detection by identity?

- A. JavaScript values that are not objects: string, number, boolean, undefined, null, bigint, and symbol. (Primitive values, p.88)
- B. Changing an existing object, array, or other mutable structure in place. (Mutation, p.90)
- C. Treating existing data as unchanged and creating new values for updates. (Immutability, p.91)

Answer: **C**. Immutability: Treating existing data as unchanged and creating new values for updates. It makes state transitions easier to reason about and supports change detection by identity.

Review: Preserving existing data and producing new values supplies the identity distinction; primitive classification and in-place mutation do not. Removed map/filter/spread/copy alternatives that could implement the correct mechanism.

### p.99 — Array.reduce

According to the source, how can Array.reduce compute totals, groups, maps, and other aggregates?

- A. An array method that returns whether all elements pass a predicate. (Array.every, p.98)
- B. An array method that creates a new array by transforming each element. (Array.map, p.94)
- C. An array method that accumulates many elements into a single result. (Array.reduce, p.99)

Answer: **C**. Array.reduce: An array method that accumulates many elements into a single result. It can compute totals, groups, maps, and other aggregates.

Review: Accumulation explains totals and aggregates; universal predicate testing and per-element mapping perform different operations.

### p.108 — Props

According to the source, how do props create explicit data flow and reusable components?

- A. Inputs passed from a parent component to a child. (Props, p.108)
- B. A subsequent render of a component due to state, parent rendering, or context changes. (Re-render, p.111)
- C. A React hook for synchronizing a component with systems outside React after rendering. (useEffect, p.115)

Answer: **A**. Props: Inputs passed from a parent component to a child. They create explicit data flow and reusable components.

Review: Parent-to-child inputs explain explicit prop flow; effect synchronization and subsequent rendering do not define that flow.

### p.116 — Effect cleanup

According to the source, how does effect cleanup prevent duplicate listeners, stale subscriptions, and leaks?

- A. A function beginning with use that composes React hooks into reusable stateful logic. (Custom hook, p.127)
- B. A React hook that caches a function reference until dependencies change. (useCallback, p.123)
- C. The function returned from an effect to undo the previous subscription/resource before rerun or unmount. (Effect cleanup, p.116)

Answer: **C**. Effect cleanup: The function returned from an effect to undo the previous subscription/resource before rerun or unmount. It prevents duplicate listeners, stale subscriptions, and leaks.

Review: Undoing a previous subscription before rerun/unmount addresses duplication and leaks; composing hooks and caching a function reference do not dispose resources.

### p.124 — React.memo

According to the source, how can React.memo reduce expensive child renders when props are stable?

- A. A reusable unit that describes UI from props, state, and context. (React component, p.107)
- B. A React hook for synchronizing a component with systems outside React after rendering. (useEffect, p.115)
- C. A wrapper that can skip rerendering a component when its props are shallowly equal. (React.memo, p.124)

Answer: **C**. React.memo: A wrapper that can skip rerendering a component when its props are shallowly equal. It can reduce expensive child renders when props are stable.

Review: Skipping on shallowly equal props explains the conditional reduction; component description and effect synchronization do not establish memoization.

### p.133 — Tree shaking

According to the source, how does tree shaking reduce shipped JavaScript without manual deletion?

- A. Client-Side Rendering: the browser executes JavaScript to build most of the UI after loading the app shell/data. (CSR, p.137)
- B. Changing views and history in JavaScript without requesting a full new HTML document each time. (Client-side routing, p.141)
- C. Build-time elimination of unused module exports when static analysis allows it. (Tree shaking, p.133)

Answer: **C**. Tree shaking: Build-time elimination of unused module exports when static analysis allows it. It reduces shipped JavaScript without manual deletion.

Review: Static elimination of unused exports reduces shipped code; rendering location and view/history changes do not remove exports.

### p.141 — Client-side routing

According to the source, how does client-side routing make SPA navigation fast while preserving URLs?

- A. Changing views and history in JavaScript without requesting a full new HTML document each time. (Client-side routing, p.141)
- B. The browser's tree of objects representing the current document and its elements. (DOM, p.148)
- C. Dividing application JavaScript into multiple chunks that can be loaded independently. (Code splitting, p.132)

Answer: **A**. Client-side routing: Changing views and history in JavaScript without requesting a full new HTML document each time. It makes SPA navigation fast while preserving URLs.

Review: Updating views and history without another full HTML request explains the stated navigation behavior; DOM structure and chunking do not supply that routing mechanism.

### p.149 — Event bubbling

According to the source, how does event bubbling enable parent handlers and event delegation?

- A. Single Page Application: a web app where client-side navigation updates views without full document reloads for most routes. (SPA, p.139)
- B. Deferring loading or initialization until a resource is actually needed. (Lazy loading, p.131)
- C. The phase where an event triggered on a descendant propagates upward through its ancestors. (Event bubbling, p.149)

Answer: **C**. Event bubbling: The phase where an event triggered on a descendant propagates upward through its ancestors. It enables parent handlers and event delegation.

Review: Upward propagation connects descendants to parent handlers; app routing and deferred resource loading do not propagate events.

### p.158 — Message queue

According to the source, how does a message queue decouple request latency from background work and smooth bursts?

- A. A durable or buffered channel where producers enqueue messages/jobs and consumers process them later. (Message queue, p.158)
- B. A key-value configuration value provided by the process environment. (Environment variable, p.176)
- C. An architecture where business capabilities are split into independently deployable networked services. (Microservices, p.161)

Answer: **A**. Message queue: A durable or buffered channel where producers enqueue messages/jobs and consumers process them later. It decouples request latency from background work and smooths bursts.

Review: Enqueue-now/process-later separates request work from consumption; environment configuration and service decomposition do not establish that buffering.

### p.166 — Unit test

According to the source, how does a unit test give fast feedback on logic and edge cases?

- A. The ability to understand internal system behavior from outputs such as logs, metrics, traces, and profiles. (Observability, p.180)
- B. A focused test of a small behavior, usually with controlled dependencies. (Unit test, p.166)
- C. Recording structured events about application behavior for debugging, audit, and operations. (Logging, p.178)

Answer: **B**. Unit test: A focused test of a small behavior, usually with controlled dependencies. It gives fast feedback on logic and edge cases.

Review: Focused behavior with controlled dependencies explains unit-test feedback; observing and logging application outputs are different activities. Excluded neighboring testing techniques that could also supply fast feedback.

### p.173 — Docker

According to the source, how does Docker make dependencies and runtime environment reproducible across machines?

- A. Attempting a failed operation again when the failure may be temporary. (Retry, p.155)
- B. A platform for packaging and running applications in isolated containers based on images. (Docker, p.173)
- C. A retry strategy where delays grow after consecutive failures, often with random jitter. (Exponential backoff, p.156)

Answer: **B**. Docker: A platform for packaging and running applications in isolated containers based on images. It makes dependencies and runtime environment reproducible across machines.

Review: Container images explain reproducible packaging; repeated attempts and delay strategies address transient failures instead.

### p.207 — Type guard

According to the source, how does a type guard centralize validation and improve downstream ergonomics?

- A. A file containing TypeScript type declarations without runtime implementation. (Declaration file (.d.ts), p.220)
- B. A runtime check that also teaches TypeScript a more specific type. (Type guard, p.207)
- C. A type that effectively disables TypeScript checking for that value. (any, p.203)

Answer: **B**. Type guard: A runtime check that also teaches TypeScript a more specific type. It centralizes validation and improves downstream ergonomics.

Review: A runtime check with type refinement supplies the guard mechanism; declarations alone have no runtime validation, and any disables checking.

### p.224 — Lifting state up

According to the source, how does lifting state up create one source of truth for coordinated UI?

- A. A pure function that computes next state from current state and an action. (Reducer, p.227)
- B. Move shared state to the nearest common owner of components that need it. (Lifting state up, p.224)
- C. Interactive components must expose their current state to assistive technologies, not only visually. (Accessibility state, p.247)

Answer: **B**. Lifting state up: Move shared state to the nearest common owner of components that need it. It creates one source of truth for coordinated UI.

Review: A common owner explains one source of shared state; next-state calculation and exposing accessibility state do not choose ownership.

### p.232 — Headless component

According to the source, how does a headless component separate interaction logic from product-specific appearance?

- A. Move shared state to the nearest common owner of components that need it. (Lifting state up, p.224)
- B. Reusable behavior and accessibility without prescribing final visual styling. (Headless component, p.232)
- C. Keep state as close as possible to the components that actually need it. (State colocation, p.223)

Answer: **B**. Headless component: Reusable behavior and accessibility without prescribing final visual styling. It separates interaction logic from product-specific appearance.

Review: Reusable behavior without prescribed styling explains the separation; moving or colocating state addresses ownership rather than appearance.

### p.240 — State machine

According to the source, how does a state machine prevent impossible UI combinations in complex flows?

- A. Keep state as close as possible to the components that actually need it. (State colocation, p.223)
- B. An explicit model of allowed states and transitions. (State machine, p.240)
- C. Move shared state to the nearest common owner of components that need it. (Lifting state up, p.224)

Answer: **B**. State machine: An explicit model of allowed states and transitions. It prevents impossible UI combinations in complex flows.

Review: Explicit allowed states and transitions constrain combinations; state location alone does not specify allowed transitions.

### p.257 — Single Responsibility Principle

According to the source, how does the Single Responsibility Principle prevent unrelated concerns from becoming entangled?

- A. Change internal structure while preserving externally observable behavior. (Refactoring, p.262)
- B. Hide internal state/implementation and expose only the operations consumers need. (Encapsulation, p.250)
- C. A module should have one coherent reason to change. (Single Responsibility Principle, p.257)

Answer: **C**. Single Responsibility Principle: A module should have one coherent reason to change. It prevents unrelated concerns from becoming entangled.

Review: One coherent reason to change supplies the named principle; generic refactoring and hiding implementation do not impose that responsibility boundary.

### p.266 — Denormalization

According to the source, how does denormalization trade write complexity/ storage for read performance?

- A. Intentionally duplicate or precompute data to make reads simpler or faster. (Denormalization, p.266)
- B. A controlled change to database structure or data as the application evolves. (Schema migration, p.271)
- C. Lock data before modifying it so competitors must wait. (Pessimistic locking, p.275)

Answer: **A**. Denormalization: Intentionally duplicate or precompute data to make reads simpler or faster. It trades write complexity/ storage for read performance.

Review: Duplication/precomputation supplies the stated storage/write versus read tradeoff; migrations and locks do not establish that read optimization. Removed indexing/materialized-view alternatives.

### p.282 — Write-through cache

According to the source, how does a write-through cache keep cached values fresh for subsequent reads?

- A. A cache strategy that evicts the least recently used entry when space is needed. (LRU cache, p.285)
- B. Writes update the cache and backing store as part of the write path. (Write-through cache, p.282)
- C. A cache shared across application instances, commonly over the network. (Distributed cache, p.290)

Answer: **B**. Write-through cache: Writes update the cache and backing store as part of the write path. It keeps cached values fresh for subsequent reads.

Review: Updating both stores on the write path establishes write-through freshness; eviction policy and shared placement do not synchronize writes.

### p.290 — Distributed cache

According to the source, how does a distributed cache give multiple servers a common cache instead of isolated in-process copies?

- A. The application checks cache first, loads from source on miss, then populates the cache. (Cache-aside, p.281)
- B. Writes update the cache and backing store as part of the write path. (Write-through cache, p.282)
- C. A cache shared across application instances, commonly over the network. (Distributed cache, p.290)

Answer: **C**. Distributed cache: A cache shared across application instances, commonly over the network. It gives multiple servers a common cache instead of isolated in-process copies.

Review: Shared networked storage supplies a common cache; miss-population and write synchronization policies do not by themselves share storage across servers.

### p.307 — Grounding

According to the source, how does grounding reduce unsupported invention and make outputs verifiable?

- A. A model produces plausible-looking output that is unsupported or incorrect. (Hallucination, p.308)
- B. Constrain model responses to a machine-readable schema such as JSON fields/enums. (Structured output, p.311)
- C. Constrain or support model output with authoritative evidence, tools, or state. (Grounding, p.307)

Answer: **C**. Grounding: Constrain or support model output with authoritative evidence, tools, or state. It reduces unsupported invention and makes outputs verifiable.

Review: Authoritative evidence/tools/state supplies grounding; plausible unsupported output and machine-readable formatting do not supply factual evidence.

### p.324 — Contract test

According to the source, how does a contract test catch breaking API changes without requiring a full end-to-end environment?

- A. Give users/services only the permissions needed for their current job. (Principle of least privilege, p.329)
- B. Verifies that two services/components agree on their integration contract. (Contract test, p.324)
- C. A test that passes or fails nondeterministically without relevant code changes. (Flaky test, p.325)

Answer: **B**. Contract test: Verifies that two services/components agree on their integration contract. It catches breaking API changes without requiring a full end-to-end environment.

Review: Agreement between integrating components establishes a contract test; privilege restriction and test nondeterminism are unrelated mechanisms.

## All 10 cross-PDF connections — inspected

Every cross-document relationship is `INFERRED_VALIDATED`. The underlying assertions are explicit, but their comparison/bridge is an inference. No relationship is presented as an explicitly stated cross-PDF claim. Original scope is retained; the key bridge does not claim keys alone guarantee state preservation.

### 1. js.array.every — sameMechanism

Source A: **JavaScript Deep Dive p.1**, JavaScript Deep Dive; role `ordinary_factual_prose`.

> Find selects the first matching value. Filter creates an
> array containing matching values. Some asks whether
> a match exists; every asks whether all visited items
> pass.

Source B: **javascript_midlevel_interview_mobile_mastery p.98**, Array.every; role `primary_factual`.

> An array method that returns whether all elements
> pass a predicate. It expresses validation across a
> collection and stops at the first failure.

Normalized A: `js.array.every → tests → js.universal-predicate`.
Normalized B: `js.array.every → tests → js.universal-predicate`.

**INFERRED_VALIDATED**. Both factual passages independently describe checking the predicate across all elements in the stated scope. The comparison is inferred from those two explicit assertions; their original conditions remain in the quotations.

Review: ACCEPT for the shared relation above; other facts in either quote are not transferred to the other source.

### 2. js.array.filter — sameMechanism

Source A: **JavaScript Deep Dive p.1**, JavaScript Deep Dive; role `ordinary_factual_prose`.

> Find selects the first matching value. Filter creates an
> array containing matching values. Some asks whether
> a match exists; every asks whether all visited items
> pass.

Source B: **javascript_midlevel_interview_mobile_mastery p.95**, Array.filter; role `primary_factual`.

> An array method that creates a new array containing
> only elements that pass a predicate. It expresses
> selection without manual loops and mutation.

Normalized A: `js.array.filter → selects → js.collection-of-matches`.
Normalized B: `js.array.filter → selects → js.collection-of-matches`.

**INFERRED_VALIDATED**. Both factual passages independently describe forming an array of matching elements. The comparison is inferred from those two explicit assertions; their original conditions remain in the quotations.

Review: ACCEPT for the shared relation above; other facts in either quote are not transferred to the other source.

### 3. js.array.find — sameMechanism

Source A: **JavaScript Deep Dive p.1**, JavaScript Deep Dive; role `ordinary_factual_prose`.

> Find selects the first matching value. Filter creates an
> array containing matching values. Some asks whether
> a match exists; every asks whether all visited items
> pass.

Source B: **javascript_midlevel_interview_mobile_mastery p.96**, Array.find; role `primary_factual`.

> An array method that returns the first element
> matching a predicate, or undefined. It avoids scanning
> manually when only one match is needed.

Normalized A: `js.array.find → selects → js.first-matching-value`.
Normalized B: `js.array.find → selects → js.first-matching-value`.

**INFERRED_VALIDATED**. Both factual passages independently describe selecting the first matching value. The comparison is inferred from those two explicit assertions; their original conditions remain in the quotations.

Review: ACCEPT for the shared relation above; other facts in either quote are not transferred to the other source.

### 4. js.array.some — sameMechanism

Source A: **JavaScript Deep Dive p.1**, JavaScript Deep Dive; role `ordinary_factual_prose`.

> Find selects the first matching value. Filter creates an
> array containing matching values. Some asks whether
> a match exists; every asks whether all visited items
> pass.

Source B: **javascript_midlevel_interview_mobile_mastery p.97**, Array.some; role `primary_factual`.

> An array method that returns whether at least one
> element passes a predicate. It expresses existential
> checks clearly and short-circuits once true.

Normalized A: `js.array.some → tests → js.predicate-existence`.
Normalized B: `js.array.some → tests → js.predicate-existence`.

**INFERRED_VALIDATED**. Both factual passages independently describe checking whether a matching element exists. The comparison is inferred from those two explicit assertions; their original conditions remain in the quotations.

Review: ACCEPT for the shared relation above; other facts in either quote are not transferred to the other source.

### 5. programming.closure — sameMechanism

Source A: **JavaScript Deep Dive p.3**, JavaScript Deep Dive; role `ordinary_factual_prose`.

> A closure is a function together with access to its
> surrounding lexical environment. The function can
> keep accessing that environment after the outer call
> has returned.

Source B: **javascript_midlevel_interview_mobile_mastery p.84**, Closure; role `primary_factual`.

> A function plus access to the lexical variables from
> the scope where it was created. Closures power
> encapsulation, callbacks, hooks, and private state
> patterns.

Normalized A: `programming.closure → retains-access → programming.lexical-environment`.
Normalized B: `programming.closure → retains-access → programming.lexical-environment`.

**INFERRED_VALIDATED**. Both factual passages independently describe a function's access to its lexical environment. The comparison is inferred from those two explicit assertions; their original conditions remain in the quotations.

Review: ACCEPT for the shared relation above; other facts in either quote are not transferred to the other source.

### 6. programming.immutable-update — sameMechanism

Source A: **JavaScript Deep Dive p.4**, JavaScript Deep Dive; role `ordinary_factual_prose`.

> To update an item without mutating the source array,
> create a new array and a new object for the item that
> changes.

Source B: **javascript_midlevel_interview_mobile_mastery p.91**, Immutability; role `primary_factual`.

> Treating existing data as unchanged and creating new
> values for updates. It makes state transitions easier to
> reason about and supports change detection by
> identity.

Normalized A: `programming.immutable-update → creates → programming.new-value-preserving-input`.
Normalized B: `programming.immutable-update → creates → programming.new-value-preserving-input`.

**INFERRED_VALIDATED**. Both factual passages independently describe creating new values while preserving the input. The comparison is inferred from those two explicit assertions; their original conditions remain in the quotations.

Review: ACCEPT for the shared relation above; other facts in either quote are not transferred to the other source.

### 7. programming.shallow-copy — sameMechanism

Source A: **JavaScript Deep Dive p.4**, JavaScript Deep Dive; role `ordinary_factual_prose`.

> Unchanged objects are reused here. This is a shallow
> update, not a deep clone of every nested object.

Source B: **javascript_midlevel_interview_mobile_mastery p.100**, Shallow copy; role `primary_factual`.

> A copy where the top-level container is new but
> nested object references are reused. It is the hidden
> reason spread can still allow nested mutation.

Normalized A: `programming.shallow-copy → reuses → programming.existing-object-references`.
Normalized B: `programming.shallow-copy → reuses → programming.existing-object-references`.

**INFERRED_VALIDATED**. Both factual passages independently describe reusing existing object references in a shallow copy or update. The comparison is inferred from those two explicit assertions; their original conditions remain in the quotations.

Review: ACCEPT for the shared relation above; other facts in either quote are not transferred to the other source.

### 8. react.stable-key — sameMechanism

Source A: **React Notes p.3**, React Notes; role `ordinary_factual_prose`.

> A stable key helps React match an item to its previous
> instance within a list of siblings. Reordering should
> not make one item inherit the local state of another.

Source B: **javascript_midlevel_interview_mobile_mastery p.114**, React key; role `primary_factual`.

> A stable identity hint for items among siblings in a
> rendered list. Correct keys let React match items
> across insertions, deletions, and reordering.

Normalized A: `react.stable-key → enables → react.item-correspondence`.
Normalized B: `react.stable-key → enables → react.item-correspondence`.

**INFERRED_VALIDATED**. Both factual passages independently describe matching list items across renders using keys. The comparison is inferred from those two explicit assertions; their original conditions remain in the quotations.

Review: ACCEPT for the shared relation above; other facts in either quote are not transferred to the other source.

### 9. react.stable-key — mechanism

Source A: **React Notes p.3**, React Notes; role `ordinary_factual_prose`.

> A stable key helps React match an item to its previous
> instance within a list of siblings. Reordering should
> not make one item inherit the local state of another.

Source B: **javascript_midlevel_interview_mobile_mastery p.113**, Reconciliation; role `primary_factual`.

> React's process for comparing previous and next
> element trees and deciding how to update mounted UI.
> It preserves or replaces component instances based on
> element type and keys.

Normalized A: `react.stable-key → enables → react.item-correspondence`.
Normalized B: `react.item-correspondence → governs-with-type-and-keys → react.instance-preservation-or-replacement`.

**INFERRED_VALIDATED**. A links stable keys to matching list items with earlier instances. B links render comparison, element type and keys to preserving or replacing component instances. The shared correspondence concept connects the passages; B's type-and-key condition is retained.

Review: ACCEPT for the shared relation above; other facts in either quote are not transferred to the other source.

### 10. cache.reuse — sameMechanism

Source A: **System Design p.3**, System Design; role `ordinary_factual_prose`.

> A cache avoids repeating work, but introduces a
> second representation that can become stale.

Source B: **javascript_midlevel_interview_mobile_mastery p.31**, Cache; role `primary_factual`.

> A faster storage layer that keeps reusable results so
> expensive work can be avoided. It can reduce latency,
> database load, API cost, and computation.

Normalized A: `cache.reuse → avoids → computation.repeated-work`.
Normalized B: `cache.reuse → avoids → computation.repeated-work`.

**INFERRED_VALIDATED**. Both factual passages independently describe avoiding repeated work through cached results. The comparison is inferred from those two explicit assertions; their original conditions remain in the quotations.

Review: ACCEPT for the shared relation above; other facts in either quote are not transferred to the other source.

## Teach Leu

43/43: 20 supported paraphrases, 10 overgeneralizations, 10 contradictions, two incomplete application-check claims, and the unsupported rendering-speed claim. Every case binds to an exact current factual source passage. Fixtures are external test inputs; production code contains no fixture-output lookup.

Supported core ideas remain partial captures of a multi-clause source packet in the existing Teach validator. Matching the identity relation does not silently mark sibling scope or every source detail covered.

The additional mixed-claim probe initially found two false acceptances: an identity paraphrase plus database downloading, and a closure paraphrase plus file deletion. `admission-protections-before.json` preserves both failures. Admission now refuses unrepresented clause vocabulary and unresolved negative scope even if the core relation matches.

Focused admission protections: 14/14. Forged answers/options, role changes, unsupported bridges, false explicit-proof labels, stale sources, numeric/API additions and unsupported mixed clauses are rejected.

## Quality boundaries and unresolved coverage

- No unsupported answer statements, malformed stems, excluded-role leakage, duplicate answers or oversized options were found in the 25 reviewed outputs.
- The 15 sampled cards without questions remain explicitly rejected; their claims still survive. The current transform needs a supported adjacent cognitive relation and balanced options.
- Question realization currently delivers mechanism/tradeoff forms. General cause, distinction, sequence, failure-mode and example/application realization remains incomplete.
- Connection normalization is a finite technical catalog with same-mechanism matching and one proved bridge shape. Arbitrary cross-domain relationships are not established.
- Teach alignment covers five technical families with controlled vocabulary and polarity/scope rules. Unknown wording conservatively stays unsettled; this is not general semantic entailment or model inference.
- These are executed core-engine results from real PDF sources. This sprint does not claim native UI integration of Question V4/Connection V2 or a simulator study journey.
- No simulator, Foundation Models debugging, UI change, persistence feature, broad test sweep, commit or push was performed for this emergency sprint.

## What became possible

The supplied PDF now yields card-scoped factual packets on all 40 sampled pages, usable questions with independent source-bound options, ten inspectable links to three other real PDFs, and local Teach feedback that recognizes different wording while separating missing conditions and contradictions.
