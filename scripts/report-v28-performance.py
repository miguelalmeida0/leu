#!/usr/bin/env python3
"""Summarize measured runs, retaining the functionally locked V28 evidence."""
from pathlib import Path
import hashlib, json, math, subprocess
root = Path(__file__).resolve().parent.parent
out = root/'docs/v28.1/performance'
baseline = json.loads((out/'baseline.json').read_text())
optimized = json.loads((out/'optimized.json').read_text())
tests = json.loads((out/'incremental-and-cache-tests.json').read_text())
integration = json.loads((out/'integration-results.json').read_text())
wiring = json.loads((out/'production-wiring.json').read_text())
quality = (out/'quality-results.log').read_text()
assert integration['passed'] == integration['total'] == 7
assert len(wiring) == 11 and all(row['passed'] for row in wiring)
assert all(value in quality for value in ['CLAIM PAGES: 40/40', 'QUESTIONS: 25', 'CONNECTIONS: 10', 'PARAPHRASE FIXTURES: 43/43', 'ADMISSION PROTECTIONS: 14/14'])
def percentile(data, stage, fraction=.5):
    values = sorted(m['milliseconds'] for m in data['metrics'] if m['stage'] == stage)
    return values[max(0, math.ceil(len(values)*fraction)-1)]
def ms(data, stage, fraction=.5):
    return f'{percentile(data, stage, fraction):.2f} ms'
rows = [
    ('Full 90-question generation', 'question_generation', 'question_generation'),
    ('Admission plus persistence via public question-array API', 'admission_and_persistence', 'admission_and_persistence'),
    ('Raw durable JSON save', 'raw_persistence', 'raw_persistence'),
    ('Question bank / snapshot decode', 'snapshot_decode', 'snapshot_decode'),
    ('Repository reopen p50', 'document_open', 'document_open'),
    ('Connection query p50', 'connection_query', 'cached_connection_query'),
    ('Teach analysis p50', 'teach_analysis', 'teach_analysis'),
]
table = '\n'.join(f'| {name} | {ms(baseline, a)} | {ms(optimized, b)} |' for name,a,b in rows)
first = tests['checkpoints'][0]
text = f'''# Leu V28.1 performance evidence

Baseline: `300d22c4f9c180c5e23627ee4b7809d88fd43e54`. Branch: `codex/v28.1-instant-intelligence`.

## Measured before and after

Same Mac, same four real PDF analyses, same Swift 5 unoptimized host configuration. Reopen uses ten fresh repository/store instances with the filesystem cache left intact; query/Teach samples use twenty runs. These are host measurements, not iPhone frame-time measurements. p95 uses nearest rank. No PDF or learner text is emitted by production metrics.

| Work | Before | After |
|---|---:|---:|
{table}
| Repository reopen p95 | {ms(baseline, 'document_open', .95)} | {ms(optimized, 'document_open', .95)} |

The normal production path now carries an opaque, already-admitted batch from the generation actor to the repository. Its full validated generation takes {ms(optimized, 'production_validated_generation')}; durable installation takes {ms(optimized, 'production_validated_persistence')}. The public array API still performs independent admission and remains available for untrusted candidates. Those two storage paths are measured separately rather than attributing validation time to disk IO.

Fresh-actor current-page capability discovery from a persisted shard: {tests['reopenedReaderAvailabilityMs']:.2f} ms. Warm capability discovery: {ms(optimized, 'cached_reader_availability')}. The warm connection query includes cache identity checking and actor dispatch. First-ever connection indexing remains background work ({ms(optimized, 'reader_cache_miss')}); reopening its persisted results takes {ms(optimized, 'reopened_connection_snapshot')}. Question decoding does not decode connections.

## What the profile proved

The old approximately 11-second save/reopen was dominated by rebuilding claims, repeated tokenization/normalization inside the distractor sort comparator, and recompiling already-admitted questions. The approximately 2 MB learning snapshot decoded in about 21 ms and raw durable storage was about 47 ms. A database or a learner-state format migration was not justified.

Prepared compiler values preserve the exact comparator scores, exclusions, options and tie-breaks. All 90 complete question proofs match the baseline, including option ordering. The only immutable state shared within generation is scoped to one analysis.

## Cache hit and invalidation

Repository admission issues an internal receipt bound to document identity, fingerprint, extraction version, analysis algorithm, every analyzed page, intelligence schema, question contract, and every question payload. SHA-256 detects payload/source changes; completion metadata has its own checksum. The receipt is a local cache-integrity record, not a signature for untrusted external imports.

Reopen decodes the snapshot and verifies receipts. A hit does zero question generation, zero claim composition, zero role-map reconstruction and zero inference. A miss performs unchanged independent admission once, removes invalid derived questions, preserves learner history and saves a new receipt. Legacy snapshots without completion metadata are not assumed to contain a complete bank. They receive one background completion pass.

Connections use version/content-bound per-document fact shards plus lazily persisted admitted queries. An existing document is not reclassified merely because another document is imported. Removing a document removes it from the active index and query identity. Query state is actor-isolated and bounded to 64 selected-passage variants in memory. Derived cache corruption falls back to source validation, never to invented results.

## Incremental work and the reader

Production saves batches of 12 pages. A resumed run skips completed pages, including pages that correctly yielded zero questions. Actual page changes update scheduling priority: current page, two nearby pages each side, current section, remaining pages. A stale in-flight batch cannot install against a changed analysis.

The interruption/resume test installed {first['questions']} useful question(s) after {first['generationToVisibleMs']:.2f} ms, with only {first['pages']} pages completed, then reopened and completed the same 90-question bank. The test uses 24-page continuation batches to exercise variable checkpoint size; production uses 12.

The locked V4 distractor contract needs a full factual candidate inventory, so this small inventory is still composed once before the first question batch. PDFKit extraction already runs in its own actor and keeps its existing recovery checkpoints; this sprint does not stream partial PDF extraction into changing question contracts. New imports first finish canonical extraction, then publish V4 batches. The reader does not await either stage. This is incremental question admission after extraction, not a claim of page-streaming extraction.

Study uses available material immediately; full-bank preparation no longer disables Start. Source-packet construction and legacy representability preflight moved off the main actor without changing the model contract. Reader capability discovery looks only at the current document first; unrelated indexes do not hold up those controls. No full-screen intelligence loading UI was added.

PDF extraction and analysis remain on PDFKitTextExtractor/PDFLearningIndexer actors. New claim generation, question realization and validation use V4GenerationSession; fact/query caching uses LibraryIntelligenceCache; snapshot encoding, writes and migration use LearningRepository. Main-actor work is presentation assignment, lightweight scheduling and existing reader behavior.

## Persistence and durability

Learning JSON remains compatible with old snapshots. Atomic same-volume rename, synchronized file writes, directory fsync, corruption quarantine and the validated previous generation remain intact. Derived fact/query shards use atomic writes and are disposable; they contain no learner-owned history. No PDFs, annotations, history, voice or Claude reasoning code was changed. No database was introduced.

Metrics include monotonic duration, work count, cache status and serialized bytes. Snapshot decode reports bytes read; production persistence metrics count both the current payload and the previous-generation backup written. Profile rows identify the current snapshot size separately. These serialized bytes are not a physical-device IO counter. Peak RSS is unavailable: /usr/bin/time completed the benchmark but its resource query was denied (sysctl kern.clockrate). The final benchmark runs directly; the failed optional wrapper log is retained. Foundation .atomic derived-cache writes also returned Cocoa 513/POSIX 1 on this host; using synchronized same-volume staging and rename, as the existing snapshot store does, resolved the actual write failure. Tests require real disk cache hits, not just equivalent recomputed results.

## Verification

- Claims: 40/40.
- Fixed sample: 25 reviewed questions; full bank: 90 with all baseline proofs identical.
- Connections: 10 admitted; forward/reverse exact source routes retained.
- Teach: 43/43.
- Admission protections: 14/14.
- Production-core integration: 7/7.
- Wiring and full app syntax: 11/11.
- Cache/incremental/invalidation tests: {tests['passed']}/{tests['total']}.
- iOS ShelfCore module: PASS. Full app module: BLOCKED by Observation macro sandbox (`sandbox_apply: Operation not permitted`), with cascading Observable-conformance errors. No native UI pass is claimed. CoreSimulator was not retried or repaired.

Reproduction: `python3 scripts/run-v28-results.py`, `python3 scripts/test-v28-instant.py`, `python3 scripts/test-v28-product.py`, `python3 scripts/profile-v28.py optimized`, `python3 scripts/check-v28-product-wiring.py`, `python3 scripts/typecheck-v28-product-ios.py --core-only`.

## Physical iPhone acceptance remaining

Open an existing library and measure reader first frame; scroll while a newly extracted document generates batches; switch to a distant page and confirm priority; start Study before all batches finish; background/terminate/reopen and confirm no duplicate or lost questions/history; use Teach, Connections, Collision, library explanations and the key experiment with exact source return. Confirm latency, thermal behavior and memory on device. The existing V28 productization journey remains applicable.
'''
(out/'comparison.md').write_text(text)
paths = subprocess.check_output(['git','diff','--name-only','300d22c4f9c180c5e23627ee4b7809d88fd43e54'],cwd=root,text=True).splitlines()
paths += subprocess.check_output(['git','ls-files','--others','--exclude-standard'],cwd=root,text=True).splitlines()
code = sorted(set(p for p in paths if p.endswith(('.swift','.py')) and not p.startswith('docs/')))
assert not any(p.startswith('Packages/LeuReasoningCore/') for p in code)
(out/'change-manifest.json').write_text(json.dumps({'baseline':'300d22c4f9c180c5e23627ee4b7809d88fd43e54','files':[{'path':p,'sha256':hashlib.sha256((root/p).read_bytes()).hexdigest()} for p in code]},indent=2)+'\n')
assert tests['passed'] == tests['total']
assert percentile(optimized,'document_open') < 250 and percentile(optimized,'document_open',.95) < 500
assert percentile(optimized,'snapshot_decode') < 200 and percentile(optimized,'cached_connection_query') < 150
assert percentile(optimized,'teach_analysis') < 100 and tests['reopenedReaderAvailabilityMs'] < 100
print('Measured performance targets PASS; report and manifest written')
