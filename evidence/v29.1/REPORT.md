# V29.1 — Correct reasoning in the existing Teach Leu surface

Implemented and verified on the host. Native packaging and the simulator
journey remain unverified because the environment blocked Xcode and its macro
plugin. No screenshot is claimed or substituted with a mock.

## Isolation

Integration branch: `codex/v29.1-teach-integration`, based on exact product
commit `d178a129e3c07fca3e6b00dc0b32cb730e4bf22d`. Imported the reasoning
package and host test tool from `fca850a321b408a84ef105eecdf496a06354b8e9`.
`import-manifest.json` records paths and original hashes.

Both frozen checkouts retain their exact HEAD and original status. The two
dirty/untracked research artifacts were backed up with their bytes under
`../v29.1-preservation/20260914-230353/`. Final hash verification is in
`after/baseline-preservation.json`. ShelfCore, question admission, connections,
Try It, extraction V5, voice, and session/Study presentation are unchanged.

## Semantic corrections

Actual canonical source: `Concurrent requests can both make\ndecisions from stale state.`

- Before: subject `Concurrent`, relation `requests`, object `can both make decisions from stale state`.
- After: subject `Concurrent requests`, relation `makes`, object `decisions from stale state`, modality `can`, scope `both`.
- Same exact document, page, UTF-16 offset 178, original span and source role.
- Certified admission now rejects the old atom and accepts the repaired atom.
- General auxiliary/finite-predicate boundaries distinguish noun and verb
  uses of “requests.” Unknown verbs cannot borrow a later noun as a predicate.

`after/exact-extraction.json` contains the actual before/after objects.

“Effect cleanup prevents duplicate listeners” and “HTTP is a protocol” now
receive support, with omitted detail independently shown. “A webhook prevents
server outages” receives no support. Mixed responses identify the supported
and unestablished clauses separately. Overgeneralizations preserve their scope
and condition findings without pretending source silence proves falsehood.

`EXPECTATION-REVIEW.md` justifies all 11 changed V29 expectations against their
actual sources. The original files under `before/` are preserved.

## Product integration

The new app-local `TeachReasoningAdapter` consumes V28.1's existing validated
fact cache. It checks fingerprint, extraction version, exact canonical range,
and source role through existing current-source validation. No PDF is reparsed
on submission. The immutable selected-passage adapter is prepared on a detached
task and reused for submissions. It explicitly calls the strict source-bound
aligner; it never calls the older prototype's similarity-based aligner.

Existing bounded V28.1 paraphrase contracts are retained for their supported
grammar, with all admission checks intact. Unknown topics do not get support.
No phrase tables were added. There is no model inference or network request
in this adapter; the existing model path is unchanged.

Teach Leu renders YOU CAPTURED, WORTH ADDING, CHECK THIS with the source quote,
and NOT ESTABLISHED HERE. It retains editing, exact source navigation, and
the existing coalesced draft persistence. Unsupported/mixed responses are
stored only as learner drafts, never installed as supported claims or recorded
as taught-concept events. Dismissing does not cancel draft writes.

## Executed verification

| Gate | Result |
| --- | --- |
| Reasoning XCTest | 80/80, zero failures (77 baseline + 3 new regression methods) |
| Frozen challenge claim support | Before 3/12; after 12/12 |
| Frozen challenge coverage | Before 3/12; after 12/12 |
| Frozen challenge false approvals | 0; five cases contain accepted claims |
| Production adapter and persistence checks | 11/11 |
| Existing Teach presentations through adapter | 43/43 |
| V28 questions | 90/90 proofs match baseline, including choices/order |
| Reviewed connections | 10 preserved; existing admission protections 14/14 |
| Existing product integration | 7/7 |
| Cache/incremental checks | 24/24, including reopen with zero generation |
| Static wiring and app syntax | 11/11 |
| Xcode project and verification shell syntax | PASS |

Host production-adapter submission (20 warm runs): median approximately
13.8 ms, maximum 14.6 ms. Learner snapshot reopen: 17.3 ms. Existing-document
cached reader availability after reopening: 6.1 ms. Raw samples are in
`after/app-adapter-journey.json` and `after/v28-incremental-and-cache-tests.json`.
These are host timings, not iPhone timings.

The inherited prototype golden evaluation still contains eight pre-existing
label mismatches, including two false approvals in its legacy mixed-case
aligner. That deeper research path is not exposed through this integration.
Its unchanged metrics remain in `after/legacy-golden-evaluation.json`; the
80/80 XCTest result must not be mistaken for a perfect prototype benchmark.

## Native boundary and remaining acceptance

Full native build attempted once: Xcode exit 74, package resolution
`permissionDenied`, CoreSimulator POSIX 61 `Connection refused`. See
`after/native-build.log`. Supplemental iOS module compilation passed for
LeuReasoningCore, ShelfCore and VoiceBugfix; the app module was blocked by
ObservationMacros' plugin server producing a malformed response. Subsequent
Bindable diagnostics stem from the unavailable macro. This is not an app
compile pass. See `after/v28-ios-module-Shelf.log`.

The focused real-product test is written but not executed here:
`ShelfV27IntelligenceUITests/testV291TeachSupportedSubsetMixedClauseEditAndReopen`.
It visits React Notes p.3, checks supported content and missing detail, adds
one unsupported clause, returns to the exact page, edits, and reopens the draft.

Run locally from the integration worktree:

```sh
bash /Users/malmeida/Documents/ChatGPT/Leu/LeuV29Integration/scripts/verify-v291-teach-native.sh
```

The script builds and runs only that journey on the existing iPhone Air
simulator `A248FB9E-B969-4CF6-A0ED-B2013A3C60A6`, then exports its screenshots
from the xcresult. Remaining acceptance is a successful native build, actual
journey execution, screenshot review, and device latency. No other UI suite
was rerun and no device was erased or recreated.
