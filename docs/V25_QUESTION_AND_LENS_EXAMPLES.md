# V25 source-inspected examples

These are expected realizations inspected against the implementation and fixture sources, **not captured Swift execution output**. The Swift test process is blocked by `permissionDenied`. They illustrate the intended quality; runtime emission, bank membership, distractor quality and aggregate fixture success remain unverified. The 112-fixture corpus covers 16 domains and records meaningful concepts, incidental concepts, allowed intents and invalid properties. Multiple-choice generation additionally requires at least two distinct source-backed alternatives in the same relation/intent family; a valid open question can therefore be absent from a small document's bank.

## 30 questions and their source-bound answers

Each row corresponds to an explicit sentence in `QuestionQualityCorpus.swift`. Answers preserve the source claim, including its conditions. No external subject facts are inserted by the realizer.

| # | Expected question | Answer from fixture |
| --- | --- | --- |
| 1 | What must happen before a microtask runs? | the current script completes |
| 2 | What does an index prevent? | a full table scan on the filtered column |
| 3 | How does authorization differ from authentication? | authorization determines what an identity may access |
| 4 | What condition causes a deadlock? | two transactions each wait for a lock held by the other |
| 5 | How does Memoization work? | storing results under their input keys |
| 6 | What does an iterator return? | successive values from a collection |
| 7 | What does Event delegation depend on? | propagation through ancestor elements |
| 8 | What does Strict equality prevent? | implicit type conversion |
| 9 | What is meant by closure? | a function together with its lexical environment |
| 10 | What happens after a preflight request runs? | the cross-origin request is sent |
| 11 | Under what condition does an idempotent method guarantee the same intended effect? | the request is repeated |
| 12 | What does a redirect result in? | a request to a different location |
| 13 | What condition causes a repaint? | visible pixels need updating |
| 14 | How does Compositing work? | combining already painted layers |
| 15 | How does Backpressure prevent an unbounded buffer? | slowing the producer |
| 16 | How does a stream pipeline work? | connecting producers to consumers |
| 17 | If a request times out, what behavior should you expect from a retry loop? | A retry loop retries |
| 18 | How does DNS work? | resolving host names through a hierarchy of servers |
| 19 | Why does Congestion control reduce traffic? | overloaded paths drop packets |
| 20 | How do Prepared statements prevent SQL injection? | parameterization |
| 21 | How does a covering index avoid a table lookup? | containing every required column |
| 22 | What trade-off should you consider when using Indexes? | Indexes accelerate reads but add maintenance work during writes |
| 23 | How does a password hash protect against password disclosure? | storing a one-way digest |
| 24 | Under what condition does Encryption guarantee confidentiality? | the key remains secret |
| 25 | What does Binary search require? | the input array to be sorted |
| 26 | How would you reconstruct the steps for Binary search? | First inspect the midpoint, then retain the half containing the target |
| 27 | How does a load balancer work? | distributing requests among healthy servers |
| 28 | What condition causes a cache stampede? | many clients regenerate the same expired value |
| 29 | How does Request coalescing reduce duplicate work? | sharing an in-flight computation |
| 30 | How does an idempotency key prevent duplicate effects? | identifying repeated operations |

Canonical concept names have no initial article; source spelling/capitalization is otherwise retained to avoid lowercasing identifiers. Capitalization in mid-sentence common nouns remains an editorial limitation. These examples are appropriate for introductory recall; they do not establish senior-level discrimination or reliable application reasoning. DEBUGGING currently asks for the observed behavior under an explicit condition, rather than inventing a troubleshooting procedure.

## 20 rejected candidates

The test supplies answer “stored data” and concept “cache” for language-gate isolation. Reasons below describe the violated property; the gate returns its first matching reason.

| Candidate | Reason |
| --- | --- |
| What does A microtask happen after? | Capitalized subject article |
| What does An index prevent or require? | Mixed predicate and capitalized article |
| What does this source contrast with authentication? | Unresolved reference / source filler |
| What follows from A deadlock? | Capitalized subject article |
| What does it mean? | Unresolved “it” |
| Why does this work? | Unresolved “this” |
| What happens here? | Unresolved “here” |
| What do they require? | Unresolved “they” |
| What does that cause? | Unresolved “that” |
| What does a cache prevents? | Broken auxiliary/verb agreement |
| According to this source, what is caching? | Source filler |
| How does {subject} work? | Template artifact |
| What completes ___ in a cache? | Template artifact |
| What is <concept> used for? | Template artifact |
| Which definition | Incomplete question |
| Why? | Insufficient standalone context |
| What is stored data? | Leaks the supplied answer |
| What does the above prevent? | Unresolved location reference |
| How do those relate? | Unresolved “those” |
| What do these require? | Unresolved “these” |

A separate teaching-value gate also rejects circular definitions and bare categories such as “Caching is a technique.” Grammar alone is insufficient. Neither gate is a general natural-language grammar checker.

## 10 differentiated Lens projections

These are expected projections from `LensDifferentiationV25Tests`. Each composed sentence retains its proposition ID, original document ID, page and source text. Definition paraphrases change only the copula; other rows retain source wording. Questions appear under progressive disclosure.

| Passage / key idea | What this says | Question |
| --- | --- | --- |
| React effects | React effects rerun when a dependency changes identity. | If a dependency changes identity, what behavior should you expect from React effects? |
| Reconciliation | Reconciliation means the process of comparing interface descriptions to choose updates. | What is meant by Reconciliation? |
| HTTP caching | HTTP caching reduces origin requests by reusing fresh responses. | How does HTTP caching reduce origin requests? |
| authorization | Unlike authentication, authorization determines what an identity may access. | How does authorization differ from authentication? |
| Indexes | Indexes accelerate reads but add maintenance work during writes. | What trade-off should you consider when using Indexes? |
| transaction | A transaction means a unit of work committed atomically. | What is meant by transaction? |
| microtask | A microtask runs after the current script completes. | What must happen before a microtask runs? |
| Binary search | Binary search requires the input array to be sorted. | What does Binary search require? |
| CSS grid | CSS grid works by arranging content in rows and columns. | How does CSS grid work? |
| Distributed caching | Distributed caching reduces origin load by serving shared cached responses. | How does Distributed caching reduce origin load? |

Lens composition is limited to three same-subject claims from the selected passage. Unrelated source/document facts cannot become its plain meaning. Empty meaning/examples are omitted. This is bounded deterministic composition, not a general document summarizer.
