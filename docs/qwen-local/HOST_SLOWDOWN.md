# Host slowdown and explicit continuation

During the final 4B development run, the last completed case was `dev-07-3` at
10:06:48 Europe/Berlin on 2026-09-15. No next result arrived for approximately
10.8 minutes. A two-second sample at 10:14:27 captured PID 25944 inside active
`llama_decode` / CPU graph and matrix computation. This is **not evidence of a
deadlock**, and the cause remains unresolved. The sampled process footprint was
2.8 GiB, with a reported historical peak of 2.9 GiB in the sample.

The process was explicitly terminated, with exit confirmed by 08:17:36 UTC.
`partial-dev-4b-before-interruption.jsonl` preserves its exact original 33 rows.
`4b-interruption.json` records the event. An operator-authored `interrupted` row
for the next attempted case, `dev-07-4`, was appended to the main result file.
It has no invented model output, native timing or thermal value. Its wall interval
is the observed gap since the preceding case flush, not a completed feedback
latency. Its deterministic baseline is explicitly reused from the identical 2B
fixture result. The interrupted case is never silently retried.

After the 4B process stopped, the first 2B 4,096-context probe also took
570,922.99 ms. Subsequent probe requests returned to approximately 9–14 seconds.
This cross-model slowdown prevents attributing the delay specifically to 4B or
to the 4,096-token setting. The slow request remains in all probe timing results.

Broad process inspection and swap-usage querying were restricted. A targeted
sample of the owned benchmark process and `vm_stat` succeeded. The first VM
observation reported 4,537 free 16-KiB pages, 265,879 pages occupied by the
compressor and 961,702 logical pages stored in it. These indicate substantial
compression; free pages are **not** equivalent to memory available to Leu, and
cumulative paging counters do not establish a current paging rate. A later VM
dump at the probe's recovery is preserved in `host-memory-during-slowdown.txt`.
No other application or user's process was stopped to make room.

## Continuation protocol

`scripts/qwen-resume-4b.py` explicitly attempts only the remaining cases after
the 2B probes and lifecycle checks. Each case uses a fresh child process with a
120-second watchdog. The same frozen benchmark binary, model checksum, prompt,
schema, grammar/greedy decoding, context and Swift guard are checked. The process
lifetime changes: backend initialization is repeated, so resumed timing is not
a strictly controlled comparison with the earlier single-process runs.

Events, exit codes, watchdog actions and outer wall times are recorded in
`4b-continuation-events.jsonl` when executed. Missing responses become recorded
failed/interrupted attempts, not dropped denominators. Two consecutive execution
failures stop the continuation. A process watchdog is not proof of the app's
cooperative cancellation; that is assessed separately by the native lifecycle
checks. All continuation outputs remain held out from prompt/guard tuning.

## Final accounting

The continuation completed all 66 previously unstarted cases (six development,
60 challenge), with no watchdog terminations and no retries. Final 4B evidence
therefore contains 99 native responses and one interrupted attempt across the
100 cases. The historical interruption record remains unchanged; it describes
the state at the time of interruption, not the final completion count.
