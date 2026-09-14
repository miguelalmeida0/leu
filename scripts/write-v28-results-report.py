#!/usr/bin/env python3
"""Format the inspected actual-source outputs; never generates accepted content."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parent.parent
out = root / 'docs/v28/results-sprint'
read = lambda name: json.loads((out / name).read_text())
claims = read('claim-yield.json')
questions = read('questions.json')
connections = read('connections.json')
teach = read('teach-paraphrase.json')
protections = read('admission-protections.json')
assert teach['passed'] == teach['total']
assert all(x['passed'] for x in protections)

# Review decisions made after reading every stem, option and cited factual block.
review = {
    16: 'Operation verbs explain request intent; neither the response nor request payload supplies that method contract.',
    49: 'Renewing access credentials explains the stated balance; neither an attack mechanism nor generic session state is refresh-token renewal.',
    74: 'The event-triggered system-to-system callback is the webhook mechanism; persistent browser push and bidirectional sockets are distinct protocols.',
    83: 'Exception handling, including awaited rejection, explains recovery; destructuring and async syntax alone do not catch exceptions.',
    91: 'Preserving existing data and producing new values supplies the identity distinction; primitive classification and in-place mutation do not. Removed map/filter/spread/copy alternatives that could implement the correct mechanism.',
    99: 'Accumulation explains totals and aggregates; universal predicate testing and per-element mapping perform different operations.',
    108: 'Parent-to-child inputs explain explicit prop flow; effect synchronization and subsequent rendering do not define that flow.',
    116: 'Undoing a previous subscription before rerun/unmount addresses duplication and leaks; composing hooks and caching a function reference do not dispose resources.',
    124: 'Skipping on shallowly equal props explains the conditional reduction; component description and effect synchronization do not establish memoization.',
    133: 'Static elimination of unused exports reduces shipped code; rendering location and view/history changes do not remove exports.',
    141: 'Updating views and history without another full HTML request explains the stated navigation behavior; DOM structure and chunking do not supply that routing mechanism.',
    149: 'Upward propagation connects descendants to parent handlers; app routing and deferred resource loading do not propagate events.',
    158: 'Enqueue-now/process-later separates request work from consumption; environment configuration and service decomposition do not establish that buffering.',
    166: 'Focused behavior with controlled dependencies explains unit-test feedback; observing and logging application outputs are different activities. Excluded neighboring testing techniques that could also supply fast feedback.',
    173: 'Container images explain reproducible packaging; repeated attempts and delay strategies address transient failures instead.',
    207: 'A runtime check with type refinement supplies the guard mechanism; declarations alone have no runtime validation, and any disables checking.',
    224: 'A common owner explains one source of shared state; next-state calculation and exposing accessibility state do not choose ownership.',
    232: 'Reusable behavior without prescribed styling explains the separation; moving or colocating state addresses ownership rather than appearance.',
    240: 'Explicit allowed states and transitions constrain combinations; state location alone does not specify allowed transitions.',
    257: 'One coherent reason to change supplies the named principle; generic refactoring and hiding implementation do not impose that responsibility boundary.',
    266: 'Duplication/precomputation supplies the stated storage/write versus read tradeoff; migrations and locks do not establish that read optimization. Removed indexing/materialized-view alternatives.',
    282: 'Updating both stores on the write path establishes write-through freshness; eviction policy and shared placement do not synchronize writes.',
    290: 'Shared networked storage supplies a common cache; miss-population and write synchronization policies do not by themselves share storage across servers.',
    307: 'Authoritative evidence/tools/state supplies grounding; plausible unsupported output and machine-readable formatting do not supply factual evidence.',
    324: 'Agreement between integrating components establishes a contract test; privilege restriction and test nondeterminism are unrelated mechanisms.'
}
assert set(review) == {q['claim']['card']['pageIndex'] + 1 for q in questions}
reviews = [{'questionID': q['id'], 'page': q['claim']['card']['pageIndex'] + 1,
            'decision': 'ACCEPT', 'review': review[q['claim']['card']['pageIndex'] + 1],
            'scope': 'Reviewed this emitted question; does not certify every possible future distractor.'}
           for q in questions]
(out / 'question-review.json').write_text(json.dumps(reviews, indent=2) + '\n')

lines = [f"CLAIM PAGES: {claims['claimPages']}/40", f'QUESTIONS: {len(questions)}',
         f'CONNECTIONS: {len(connections)}', f"PARAPHRASE FIXTURES: {teach['passed']}/{teach['total']}", '',
         'Executed `python3 scripts/run-v28-results.py` against ShelfCore and fingerprint-checked production V5 PDFKit analyses of the four actual PDFs. All counts above come from emitted runtime results, not mock generation. No Foundation Models inference is claimed.', '',
         '## Claim reconstruction', '',
         'The fixed, preselected 40-page sample is unchanged. Each accepted packet retains its card title span, primary factual block, adjacent sentence ranges and local reference resolution. Mnemonics, interview formulations, advice and examples remain separately labeled; only primary facts produce these questions. Source text is never rewritten in its citation.', '',
         'The initial contextual attempt yielded 17/40 because repeated titles in interview sections made whole-page title matching ambiguous. Restricting title resolution to the region before the factual block recovered the actual card identity. `claim-yield-initial17.json` and `claim-rejection-diagnosis.json` preserve that diagnosis.', '',
         '| Page | Card | Claims |', '|---|---|---|']
for r in claims['pages']:
    lines.append(f"| {r['page']} | {r['title']} | {r['claimCount']} |")
lines += ['', '## All 25 questions — inspected', '',
          'Each wrong option is an independently verified factual statement about another mechanism, not an invented technical falsehood. Correctness is relative to the specific named source concept and its stated effect. All emitted stems, choices, correct answers and full factual explanations were read. Review notes explain why each pair of alternatives fails to answer that question.', '',
          'Some alternatives are easier than others after excluding overlapping implementations. These results establish source-grounded mechanism/tradeoff questions; they do not establish every proposed Question V4 cognitive family.', '']
for q in questions:
    page = q['claim']['card']['pageIndex'] + 1
    lines += [f"### p.{page} — {q['claim']['card']['title']}", '', q['prompt'], '']
    for i, c in enumerate(q['choices']):
        lines.append(f"- {'ABC'[i]}. {c['text']} ({c['sourceTitle']}, p.{c['sourcePage']})")
    lines += ['', f"Answer: **{'ABC'[q['correctChoice']]}**. {q['explanation']}", '', 'Review: ' + review[page], '']
lines += ['## All 10 cross-PDF connections — inspected', '',
          'Every cross-document relationship is `INFERRED_VALIDATED`. The underlying assertions are explicit, but their comparison/bridge is an inference. No relationship is presented as an explicitly stated cross-PDF claim. Original scope is retained; the key bridge does not claim keys alone guarantee state preservation.', '']
for i, c in enumerate(connections, 1):
    lines += [f"### {i}. {c['relationA']['subject']} — {c['relationship']}", '']
    for label in ['A', 'B']:
        s = c['source' + label]
        lines += [f"Source {label}: **{s['documentTitle']} p.{s['pageIndex']+1}**, {s['title']}; role `{s['role']}`.", '',
                  '> ' + s['quote']['text'].replace('\n', '\n> '), '']
    for label in ['A', 'B']:
        r = c['relation' + label]
        lines.append(f"Normalized {label}: `{r['subject']} → {r['relation']} → {r['object']}`.")
    lines += ['', f"**{c['proofLevel']}**. {c['whyValid']}", '', 'Review: ACCEPT for the shared relation above; other facts in either quote are not transferred to the other source.', '']
lines += ['## Teach Leu', '',
          '43/43: 20 supported paraphrases, 10 overgeneralizations, 10 contradictions, two incomplete application-check claims, and the unsupported rendering-speed claim. Every case binds to an exact current factual source passage. Fixtures are external test inputs; production code contains no fixture-output lookup.', '',
          'Supported core ideas remain partial captures of a multi-clause source packet in the existing Teach validator. Matching the identity relation does not silently mark sibling scope or every source detail covered.', '',
          'The additional mixed-claim probe initially found two false acceptances: an identity paraphrase plus database downloading, and a closure paraphrase plus file deletion. `admission-protections-before.json` preserves both failures. Admission now refuses unrepresented clause vocabulary and unresolved negative scope even if the core relation matches.', '',
          f"Focused admission protections: {sum(x['passed'] for x in protections)}/{len(protections)}. Forged answers/options, role changes, unsupported bridges, false explicit-proof labels, stale sources, numeric/API additions and unsupported mixed clauses are rejected.", '',
          '## Quality boundaries and unresolved coverage', '',
          '- No unsupported answer statements, malformed stems, excluded-role leakage, duplicate answers or oversized options were found in the 25 reviewed outputs.',
          '- The 15 sampled cards without questions remain explicitly rejected; their claims still survive. The current transform needs a supported adjacent cognitive relation and balanced options.',
          '- Question realization currently delivers mechanism/tradeoff forms. General cause, distinction, sequence, failure-mode and example/application realization remains incomplete.',
          '- Connection normalization is a finite technical catalog with same-mechanism matching and one proved bridge shape. Arbitrary cross-domain relationships are not established.',
          '- Teach alignment covers five technical families with controlled vocabulary and polarity/scope rules. Unknown wording conservatively stays unsettled; this is not general semantic entailment or model inference.',
          '- These are executed core-engine results from real PDF sources. This sprint does not claim native UI integration of Question V4/Connection V2 or a simulator study journey.',
          '- No simulator, Foundation Models debugging, UI change, persistence feature, broad test sweep, commit or push was performed for this emergency sprint.', '',
          '## What became possible', '',
          'The supplied PDF now yields card-scoped factual packets on all 40 sampled pages, usable questions with independent source-bound options, ten inspectable links to three other real PDFs, and local Teach feedback that recognizes different wording while separating missing conditions and contradictions.', '']
(out / 'RESULTS.md').write_text('\n'.join(lines))
paths = [
 'Packages/ShelfCore/Sources/ShelfCore/Learning/Intelligence/ContextualClaimComposer.swift',
 'Packages/ShelfCore/Sources/ShelfCore/Learning/Intelligence/QuestionV4.swift',
 'Packages/ShelfCore/Sources/ShelfCore/Learning/Intelligence/TechnicalConceptCatalog.swift',
 'Packages/ShelfCore/Sources/ShelfCore/Learning/Intelligence/NormalizedConceptRelation.swift',
 'Packages/ShelfCore/Sources/ShelfCore/Learning/Intelligence/TeachLeu/TeachLeuV2.swift',
 'Packages/ShelfCore/Sources/ShelfCore/Learning/Intelligence/TeachLeu/TeachLeu.swift',
 'scripts/run-v28-results.py', 'scripts/v28-results.swift', 'scripts/write-v28-results-report.py']
manifest = {'scope': 'Emergency results sprint only; no claim of a clean Git baseline.',
            'code': [{'path': p, 'sha256': hashlib.sha256((root / p).read_bytes()).hexdigest()} for p in paths],
            'evidenceDirectory': 'docs/v28/results-sprint',
            'evidence': sorted(p.name for p in out.iterdir() if p.is_file() and p.name != 'change-manifest.json')}
(out / 'change-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
print('RESULTS.md and exact change manifest written')
