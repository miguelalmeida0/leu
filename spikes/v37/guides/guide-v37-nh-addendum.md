# V37 NH addendum to the authoring and labelling guide

This addendum is for the new independent holdout (NH). The V35 guide, the V36 addendum and the V37 spike
addendum apply unchanged. It adds one label and one tag.

## 1. `reasoningIssue` (required on every case)

Add `"reasoningIssue": true` or `"reasoningIssue": false` to every case. It is judged **independently of
the state**.

It is `true` when the answer reaches a conclusion **through a reason**, and the reasoning does not hold:

* a right conclusion from a wrong, circular or unsupported reason;
* a wrong conclusion drawn from a true or plausible reason;
* co-occurrence read as cause ("A happens with B, so A causes B").

It is `false` when:

* the answer gives no reason at all (a plain statement, definition, example or analogy), even if the
  statement is wrong: a wrong answer alone is not a reasoning issue;
* the answer gives a reason and the reasoning holds.

Consequences:

* Every case tagged `rightConclusionWrongReasoning`, `wrongConclusionPlausibleReason` or
  `causeVsCorrelation` has `reasoningIssue: true`.
* A misconception case can have `reasoningIssue: true` (for example, a plausible reason leading to a
  wrong conclusion). The two labels are independent: set both when both hold.
* A `weakReasoning` case normally has `reasoningIssue: true`; `false` only if no reason is given.

## 2. New tag

| Tag | Meaning | Rule |
|---|---|---|
| `causalReversal` | Cause and effect are swapped ("the cache is fast because the data is used often" when the source says data used often is kept in the fast cache; "users get new tokens, which makes the refresh token work") | a misconception entry of kind `reversal`, or `reasoningIssue: true` |

## 3. File format

Each case has the fields of the spike guide plus `reasoningIssue`. Ids are `<letter>-01` … `<letter>-40`.

## 4. Confidentiality

Your cases are a sealed test set.

* Do not show them, quote them or summarize their wording to anyone, including in your final message.
* Read only the files in your kit folder.
