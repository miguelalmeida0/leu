#!/usr/bin/env python3
"""Summarize executed evidence without promoting static checks to native proof."""
from pathlib import Path
import hashlib, json, subprocess

root = Path(__file__).resolve().parent.parent
out = root / 'docs/v28/productization'
results = root / 'docs/v28/results-sprint'
load = lambda p: json.loads(p.read_text())
integration = load(out / 'integration-results.json')
assert integration['passed'] == integration['total'] == 7
wiring = load(out / 'production-wiring.json')
assert all(x['passed'] for x in wiring)
claims = load(results / 'claim-yield.json')['claimPages']
questions = len(load(results / 'questions.json'))
connections = len(load(results / 'connections.json'))
teach = load(results / 'teach-paraphrase.json')
baseline = subprocess.check_output(['git', 'rev-parse', '850886a'], cwd=root, text=True).strip()
report = f'''# Leu V28 productization

RESULTS PRESERVED: {claims}/40 claim pages; {questions} reviewed questions; {connections} reviewed cross-PDF connections; {teach['passed']}/{teach['total']} Teach cases.

The preservation commit is `{baseline}` on `codex/v28-living-knowledge`, pushed before product integration. The manifest-listed code and required replay inputs were ported into this worktree. No unrelated checkout was overwritten; main was not merged.

## Executed verification

- Results replay: 40/40, 25, 10, 43/43; 14/14 admission protections.
- Production-core integration: **7/7**. These are real Swift calls through the production adapters, file repository, migration/reopen, planner and deterministic activity. They are not simulator tests.
- Static production wiring and actual Swift syntax: **11/11**. These are not UI execution.
- Current ShelfCore compilation against the iOS SDK: **PASS**.
- Complete Shelf app module: **BLOCKED**, Observation macro process reports `sandbox-exec: sandbox_apply: Operation not permitted`; ensuing Observable/Bindable errors are cascading failures. Do not treat syntax parsing as a successful app build.
- Packaged Xcode build: **BLOCKED**, temporary SwiftPM package-lock permission failure. The error does not establish a malformed Package.resolved file; it was not deleted.
- Simulator/native UI/physical iPhone journey: **NOT EXECUTED**. CoreSimulator returned connection refused. No simulator repair, resets or old 74-test UI sweep were attempted.

See [integration-results.json](integration-results.json), [production-wiring.json](production-wiring.json), [native-build-blocked.log](native-build-blocked.log), and [ios-module-Shelf.log](ios-module-Shelf.log).

## Production paths

| Capability | Production behavior |
|---|---|
| Question V4 | Background preparation builds the real bank and stores complete V4 proofs through LearningRepository. Study waits for preparation and ranks admitted V4 questions first. Visible prompts omit the repeated source prefix; feedback retains the exact passage and explanation. Missing proofs and changed prompts cannot downgrade into legacy admission. |
| Teach Leu V2 | ReaderIntelligenceModel calls V28TeachPresentation and verified V2 semantics locally. Captured ideas, missing conditions, contradictions and unsettled additions have separate visible sections. Draft text remains in the existing understanding-attempt store; the new presentation result is recomputed rather than adding another persistence format. |
| Connections | Retrieval starts with the selected factual passage, validates both sources, and ranks the mechanism bridge before a same-mechanism restatement. Reading either side can retrieve the original admitted proof. Technical proof-level strings are not displayed. |
| Knowledge Collision | One actual admitted pair, a short grounded explanation, both excerpts, and independent source actions. Stable React keys + Reconciliation is the leading React identity pair. |
| Teach the connection | Natural clauses retain their separate supporting sources. Both sides are required before showing YOU CONNECTED. Unknown effects, numeric additions and missing type conditions cannot establish the bridge. |
| Explain from my library | Shows only available exact-source explanation/example/related sections. Examples retain the primary factual rule from the same card. Source links carry document, page and exact range/text. |
| What changes if | The existing stable-key activity now requires a prediction before reordering. The same typed rows produce state `[0,7,0]` with stable keys and `[7,0,0]` with positional keys after order changes to `[C,A,B]`. A related reconciliation passage can open this activity with its actual React Notes citation. |

## Integration defects repaired

1. Reverse reading context originally returned zero relationships from Reconciliation back to React Notes. The reader adapter now tries both admission directions while retaining the original proof and choosing current/related labels from the active reading context. Admission itself was not loosened.
2. Rebuilding the entire claim set for every stored/reopened question repeated identical work. A transaction-local admission context reconstructs current claims once per document and performs the same question checks. It cannot accept caller-supplied claims.
3. The expanded production bank exposed missing noun articles/API capitalization and malformed coordinated clauses outside the original 25. The small QuestionV4 grammar correction preserves names and articles, conjugates coordinated verbs, and withholds mixed-modal/ambiguous compound forms. Claims and source qualifiers remain intact. The original 25-result JSON remains unchanged; this grammar delta is additional to the preservation manifest.
4. Cold preparation now has an explicit Study button state instead of silently waiting. No Study layout or Night Field token redesign was introduced.

## Measured host preparation

- Bank generation: {integration['bankBuildSeconds']:.2f}s.
- Verified storage: {integration['bankSaveSeconds']:.2f}s.
- Verified reopening: {integration['bankReloadSeconds']:.2f}s.
- Complete seven-journey harness: {integration['totalSeconds']:.2f}s.

These are whole-document host timings, not phone interaction latency. The full bank is prepared in the background and reused; fresh import and reopening performance still need physical-device measurement. The original reviewed sample remains 25 questions; additional production-bank candidates have automated admission, not the same manual-review claim.

## One physical-iPhone acceptance journey remaining

Build and run this branch's `Shelf.xcodeproj` / `Shelf` scheme on the existing iPhone development setup. Keep Foundation Models unavailable if desired; these paths do not require it. Add the mobile-mastery fixture from `docs/v28/fixtures/` to the app library alongside React Notes, JavaScript Deep Dive and System Design. Let source preparation complete.

1. Open React Notes p.3 and select the stable-key paragraph.
2. Open the passage action surface, then Connections.
3. Confirm Reconciliation from mobile-mastery p.113 ranks ahead of the key restatement on p.114.
4. Open Knowledge Collision; confirm the pair title, why they belong together, and both actual excerpts.
5. Choose Teach this connection. Enter: “Stable keys let React recognize the same item after reordering. Reconciliation compares the previous and next trees, using element type and keys to keep or replace component instances.”
6. Confirm YOU CONNECTED, with the two clauses bound to their separate documents; missing sibling scope may still appear under WORTH ADDING.
7. Add an unsupported claim such as “Keys encrypt the database.” Confirm it is unsettled and the complete connection is not approved.
8. View first source; confirm React Notes p.3 and the exact quoted passage. Return to the same collision state.
9. View second source; confirm mobile-mastery p.113. Return. Also check Connections from that page can lead back to React Notes.
10. Open What changes if, choose stable IDs, predict where state goes, then reorder. Confirm the item retains its state.
11. Reset, choose index keys, predict, then reorder. Confirm the position retains state. Verify the displayed citation remains React Notes p.3, including when starting from the related page.
12. From the reader's Explain group, open Explain from my library. Verify every visible section has the correct document/page and View in PDF route.
13. Open Teach Leu on the stable-key passage. Try the natural consistent-ID paraphrase and then “Keys make rendering faster.” Check separate captured/missing/unsupported states without a score.
14. Start a short Study session. Confirm the first question is V4, has clean copy without “According to the source,” and offers its actual choices.
15. Answer; inspect FROM YOUR SOURCE and the explanation, then return to the exact PDF passage. Check normal and accessibility text sizes, keyboard reachability, source return state and Night Field contrast on the device.

## Remaining limitations

The visible journey, complete app build, native layout/accessibility and phone timings remain unverified because of the environment failures above. There is no model execution claim. The inherited question transformations and concept/Teach catalog remain bounded; unrepresented content is withheld. This sprint does not claim general semantic entailment, adaptation or mastery. Voice, PDF extraction and the working Explain Like I'm 10 provider path were not changed.
'''
(out / 'README.md').write_text(report)
changed = subprocess.check_output(['git', 'diff', '--name-only', '850886a'], cwd=root, text=True).splitlines()
untracked = subprocess.check_output(['git', 'ls-files', '--others', '--exclude-standard'], cwd=root, text=True).splitlines()
code = sorted(p for p in set(changed + untracked) if not p.startswith('docs/') and (root / p).is_file())
manifest = {'preservationCommit': baseline, 'branch': 'codex/v28-living-knowledge',
            'files': [{'path': p, 'sha256': hashlib.sha256((root / p).read_bytes()).hexdigest()} for p in code],
            'evidence': sorted(p.name for p in out.iterdir() if p.is_file() and p.name != 'change-manifest.json')}
(out / 'change-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
print('Product report and manifest written')
