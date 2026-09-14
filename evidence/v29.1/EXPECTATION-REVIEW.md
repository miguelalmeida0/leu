# Source-based review of the original 32 expectations

Original outputs and expectations remain unchanged under `before/`. See
`after/reviewed-32.json` for every learner response, original verdict, new
per-claim support, missing detail count, reason codes and actual source.

Eleven aggregate verdicts change. None of the ten previously accepted
paraphrases loses support. The three mixed responses retain partial aggregate
support, with the supported and unestablished clauses individually identified.

| Responses | Source-based justification |
| --- | --- |
| Effect cleanup prevents duplicate listeners. | The source explicitly lists duplicate listeners among the effects prevented. The omitted subscriptions/leaks are missing coverage, not an invented assertion. Support changes to supported. |
| HTTP is a protocol. | The source defines HTTP as a request-response protocol. The bare head noun is entailed by that explicit subtype. Missing mechanism/purpose belongs to coverage. Support changes to supported. |
| React.memo can reduce expensive child renders. | The source says this holds when props are stable. The unrestricted assertion is not established; missingCondition is retained, with the quoted condition available to add. |
| A relational database is excellent. | The source limits this to when data relationships and transactional consistency matter. An unqualified assessment is not established. |
| React.memo always reduces expensive child renders. | “Can” under stable props does not establish “always.” scopeTooBroad and missingCondition remain; the source does not prove the universal false. |
| React.memo always prevents every rerender. | The source describes potentially skipping rerenders/reducing expensive renders, under conditions. It does not establish universal prevention. Scope excess and unsupported addition remain, not a proven contradiction. |
| A relational database is always excellent. | Conditional excellence does not establish unconditional excellence. Preserve scopeTooBroad without claiming the source disproves every broader statement. |
| Parent handlers and event delegation enable event bubbling. | The source states the opposite direction of enablement. A forward implication alone neither proves nor disproves its converse. Preserve reversedCauseEffect as an unestablished direction. |
| Impossible UI combinations in complex flows prevent a state machine. | The source says a state machine prevents these combinations. It does not establish this reversed relationship. |
| A webhook prevents server outages. | The source states replacement of wasteful polling for service events. Shared topic supplies no evidence for preventing outages. No partial credit. |
| A state machine creates encrypted backups. | The source states prevention of impossible UI combinations. It contains no backup/encryption claim. No partial credit. |

The 43 V28.1 cases retain their intended presentation in the production adapter.
Its existing bounded contracts remain responsible for grammar they already
validate. For an entirely unrepresented source, the existing full contract is
preserved, including its identifier, scope and unsupported-vocabulary checks;
an unknown family still awards nothing. This avoids breaking the unique-
constraint explanation by splitting away its check-then-insert context.

The new fixed challenge set was written before alignment edits. SHA-256:
`0e0b750daefe40c318d52c9b10799f1745674e9d62c6a80d49effc4d2a504be4`.
It is copied verbatim into permanent XCTest fixtures. Before: support 3/12,
coverage 3/12. After: support 12/12, coverage 12/12, zero false approvals.
Five cases contain accepted claims; this is not an all-unresolved result.

The imported prototype golden evaluation still reports eight pre-existing
label mismatches, including two false approvals in its legacy mixed-case
aligner. That aligner is not used by the app adapter, which explicitly calls
SourceBoundExplanationAligner. No prototype mismatch is advertised as repaired;
the unchanged golden results are retained alongside the 80/80 XCTest result.
