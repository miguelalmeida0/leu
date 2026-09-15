# Frozen comparison tables

Generated from preserved JSONL and per-run metrics by `scripts/qwen-summarize.py`.
Case denominators include rejected and missing outputs. Request accounting identifies partial and resumed runs.

## Claim support

| Model | Set | Pipeline | Supported recognition | False approvals | False accusations | Unjustified contradictions | Abstention cases |
|---|---|---|---:|---:|---:|---:|---:|
| 0.8b | dev | baseline | 0/16 | 0/24 | 0/16 | 0/40 | 40/40 |
| 0.8b | dev | raw | 12/16 | 8/24 | 0/16 | 0/40 | 19/40 |
| 0.8b | dev | guarded | 6/16 | 2/24 | 0/16 | 0/40 | 32/40 |
| 0.8b | challenge | baseline | 0/24 | 0/36 | 0/24 | 0/60 | 60/60 |
| 0.8b | challenge | raw | 11/24 | 4/36 | 0/24 | 0/60 | 41/60 |
| 0.8b | challenge | guarded | 3/24 | 0/36 | 0/24 | 0/60 | 57/60 |
| 2b | dev | baseline | 0/16 | 0/24 | 0/16 | 0/40 | 40/40 |
| 2b | dev | raw | 16/16 | 12/24 | 0/16 | 0/40 | 14/40 |
| 2b | dev | guarded | 10/16 | 3/24 | 0/16 | 0/40 | 27/40 |
| 2b | challenge | baseline | 0/24 | 0/36 | 0/24 | 0/60 | 60/60 |
| 2b | challenge | raw | 24/24 | 11/36 | 0/24 | 0/60 | 28/60 |
| 2b | challenge | guarded | 13/24 | 5/36 | 0/24 | 0/60 | 42/60 |
| 4b | dev | baseline | 0/16 | 0/24 | 0/16 | 0/40 | 40/40 |
| 4b | dev | raw | 16/16 | 3/24 | 0/16 | 2/40 | 6/40 |
| 4b | dev | guarded | 11/16 | 1/24 | 0/16 | 2/40 | 14/40 |
| 4b | challenge | baseline | 0/24 | 0/36 | 0/24 | 0/60 | 60/60 |
| 4b | challenge | raw | 24/24 | 3/36 | 0/24 | 5/60 | 3/60 |
| 4b | challenge | guarded | 17/24 | 2/36 | 0/24 | 5/60 | 14/60 |

False approvals use negative/mixed-case denominators. A mixed case can count as both false approval and abstention.
False accusations are unsupported, contradicted or overgeneralized labels on clearly supported fixtures; prose mistakes are separate from this structured-label metric.
Unjustified contradictions count a contradicted label where the source-based expected verdict does not permit contradiction, including source-silent assertions; the denominator is all cases.
Full per-category denominators and failure IDs remain in each `final-*.metrics.json`.

## Frozen challenge: wording categories

| Model | Pipeline | Informal paraphrases | Concise supported subsets |
|---|---|---:|---:|
| 0.8b | baseline | 0/12 | 0/12 |
| 0.8b | raw | 4/12 | 7/12 |
| 0.8b | guarded | 2/12 | 1/12 |
| 2b | baseline | 0/12 | 0/12 |
| 2b | raw | 12/12 | 12/12 |
| 2b | guarded | 5/12 | 8/12 |
| 4b | baseline | 0/12 | 0/12 |
| 4b | raw | 12/12 | 12/12 |
| 4b | guarded | 6/12 | 11/12 |

## Coverage review

| Review | Pipeline | Correct/useful | Incorrect | Ambiguous | Abstention | Unreviewed | Not run | Denominator |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| 2b_shared_20_challenge | raw | 7 | 10 | 3 | 0 | 0 | 0 | 20 |
| 2b_shared_20_challenge | guarded | 5 | 8 | 2 | 5 | 0 | 0 | 20 |
| 2b_100_case_accounting | raw | 36 | 56 | 8 | 0 | 0 | 0 | 100 |
| 2b_100_case_accounting | guarded | 27 | 38 | 6 | 29 | 0 | 0 | 100 |
| 0.8b_shared_20_challenge | raw | 12 | 8 | 0 | 0 | 0 | 0 | 20 |
| 0.8b_shared_20_challenge | guarded | 3 | 3 | 0 | 14 | 0 | 0 | 20 |
| 0.8b_100_case_accounting | raw | 36 | 59 | 5 | 0 | 0 | 0 | 100 |
| 0.8b_100_case_accounting | guarded | 9 | 21 | 1 | 69 | 0 | 0 | 100 |
| 4b_shared_20_challenge | raw | 10 | 10 | 0 | 0 | 0 | 0 | 20 |
| 4b_shared_20_challenge | guarded | 9 | 6 | 0 | 5 | 0 | 0 | 20 |
| 4b_100_case_accounting | raw | 58 | 35 | 6 | 1 | 0 | 0 | 100 |
| 4b_100_case_accounting | guarded | 51 | 24 | 4 | 21 | 0 | 0 | 100 |

Post-run assistant review, not independent human validation. See `COVERAGE_REVIEW.md` and individual TSV rationales.

## Mac CPU performance

Times are seconds, p50 / p95, across primary dev+challenge requests. Counts disclose partial runs.
Models reload each request; OS file caches may be warm. No retained-warm-model, full Leu, Metal or iPhone performance is established.

| Model | Recorded attempts | Load | Prompt | First token from start | Wall interval | Maximum observed process GiB |
|---|---:|---:|---:|---:|---:|---:|
| 2b | 100 | 1.49 / 1.59 | 2.46 / 2.89 | 3.99 / 4.51 | 11.57 / 17.42 | 1.500 |
| 0.8b | 100 | 0.70 / 0.75 | 1.07 / 1.24 | 1.81 / 2.00 | 9.71 / 14.25 | 0.808 |
| 4b | 100 | 4.76 / 8.26 | 6.86 / 9.74 | 11.79 / 17.04 | 25.38 / 40.08 | 2.938 |

Footprint is sampled at native boundaries; it is not a guaranteed transient peak. Token ranges, endpoint thermal counts and timings are in `final-summary.json`.
The interrupted 4B attempt includes a roughly 10.8-minute gap without a completed result. Its wall interval is operator-recorded, not a completed provider latency; see `4b-interruption.json`. p95 does not summarize away that failure.
4B pools its original process with a continuation that starts one process per previously unstarted case and uses a 120-second watchdog. Model, prompt and decoding remained frozen; the timing protocol changed. The interrupted case was not retried.

## Request accounting

| Run | Requests | Retries | Completed | Guard rejected | Verification rejected | Interrupted | Failed | Not run | Native output limit |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| final-dev-2b-2048 | 40 | 0 | 29 | 11 | 0 | 0 | 0 | 0 | 0 |
| final-challenge-2b-2048 | 60 | 0 | 42 | 18 | 0 | 0 | 0 | 0 | 0 |
| final-dev-0.8b-2048 | 40 | 0 | 16 | 24 | 0 | 0 | 0 | 0 | 0 |
| final-challenge-0.8b-2048 | 60 | 0 | 15 | 45 | 0 | 0 | 0 | 0 | 0 |
| final-dev-4b-2048 | 40 | 0 | 31 | 8 | 0 | 1 | 0 | 0 | 0 |
| final-challenge-4b-2048 | 60 | 0 | 48 | 12 | 0 | 0 | 0 | 0 | 0 |
| final-context-probe-2b-4096 | 8 | 0 | 5 | 3 | 0 | 0 | 0 | 0 | 0 |
| final-context-probe-2b-2048-verify | 11 | 0 | 5 | 3 | 0 | 0 | 0 | 0 | 0 |

Native output-limit count measures failure to finish a structured response, not completeness of every prose sentence. The known 0.8B instruction echo/mid-word detail is separately documented.
