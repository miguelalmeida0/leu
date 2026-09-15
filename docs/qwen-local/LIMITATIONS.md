# Known limitations

## Release status

None of the three candidates met the frozen quality objectives. Guarded challenge
recognition was 3/24 (0.8B), 13/24 (2B), and 17/24 (4B), with zero, five and two
false-approval cases respectively. 4B also made five unjustified contradiction
claims. 0.8B's 57/60 abstention cases prevent calling its zero approvals success.

No hardware is enabled by default. Model assessments are suggestions tied to
quoted sources, not independently verified entailment. The model may be wrong
even when the JSON, exact quote and document identity are all valid. Outputs
never become knowledge-graph facts or taught-concept events.

## Observed development failures

The first development contract generated feedback before the learner quote.
It produced duplicate anchors and unsupported approvals. Reordering the schema
improved binding, but did not solve semantic accuracy. Both development runs are
retained separately from the frozen final comparison.

Examples from the final 2B development run:

- `dev-01-3`: “Duplicate listeners prevent effect cleanup.” received support,
  reversing the source's causal direction.
- `dev-03-4`: “Local state changes cannot cause a memoized component to render.”
  received support despite the source explicitly saying they can.
- `dev-07-3`: “Unlike poles repel in the demonstration.” received support when
  the source says unlike poles attract.

These passed quote/identity validation. They demonstrate why that validation is
not an entailment proof. See raw and guarded results, not just test pass counts.
Coverage suggestions also frequently repeat captured material or attach a true
detail to an excerpt that does not establish it. These require semantic review.

The final 0.8B `challenge-17-5` coverage echoed assessment instructions after
source details and ended mid-word. It passed structural validation. Zero native
output-limit failures therefore does not establish complete or appropriate prose.

## Contract and runtime tradeoffs

- Exact binding rejects duplicate/overlapping anchors and omitted substantive
  submission text. Some correctly assessed paraphrases still fail this contract.
  Rejections are abstentions, not accusations that the learner is wrong.
- Numeric/identifier and simple universal-scope checks are conservative. They
  do not constitute a general proof of negation, causality or entailment.
- A second call to the same checkpoint is correlated evidence. Its benefit and
  overhead are measured separately; it is not an independent verifier.
- Each request loads and unloads its model. There is no retained warm-model fast
  path, and no assessment cache that could accidentally reuse another answer.
- Process footprint is sampled at native boundaries. Samples are not a complete
  allocation trace and cannot certify transient peaks or iPhone jetsam safety.
- A host slowdown interrupted 4B and affected the first 2B context probe too.
  See `HOST_SLOWDOWN.md`; this is not proven to be a model-specific deadlock.
- The first 4,096-token long-context check fit 1,921 prompt tokens but failed
  to quote the final condition in a claim. One explicit diagnostic repeat did
  quote it correctly. The first result remains a failure. Its original serialized
  payload bytes were not recorded, so the cause of variation is unresolved.
- Freezing provider code, instructions and case values does not prove byte-for-byte
  prompt identity across process restarts. Original input serialization bytes
  were not captured in the primary logs; no bit-identical replay claim is made.
- The Mac benchmark process includes the actual Swift provider, guard and
  deterministic adapter, but not the rendered Leu app, PDF renderer or voice.
- Supertonic coexistence is deliberately deferred while its assets are available.
  The current app uses only the selected passage and title, not broad retrieval.
- Import/download/removal and the rendered Teach journey are implemented but not
  certified through the app in this environment. Full app compilation is pending.

## Benchmark interpretation

The 100 added fixtures were authored by the coding assistant, with source-based
rationales. They are not independent human evaluation. Forty development cases
and sixty challenge cases use disjoint concepts/passages. The challenge is held
out from prompt/guard tuning, not proof of unseen real-world reliability.

The deterministic comparison runs ordinary-prose extraction before the existing
Teach adapter. Report the count of admitted source facts: an empty fact set is a
real limitation of that path, not a successful semantic abstention strategy.
The separate 43-case existing-product regression uses the preserved real-document
fixtures and remains a distinct, previously known test set.
