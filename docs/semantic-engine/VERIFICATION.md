# Semantic-engine audit: verification and unmeasured gates

Date: 2026-09-12. This records fresh checks during the new architecture audit, not historical V25 release claims. No production code or test assertions were changed. No branch was created because repository Git metadata is read-only under the current task policy.

## Executed baseline

| Check | Result |
| --- | --- |
| Xcode identification | 26.6, build 17F113 |
| Swift executable | `error: permissionDenied` |
| Generic iOS Simulator Debug build | Exit 74; package resolution fails with `permissionDenied` before compilation |
| Existing static/source gates | 16 passed / 0 failed |
| Python regression methods | 105 attempted: 102 passed / 3 failed |
| Failed Python methods | Root lifecycle Swift harness; Lens Swift harness; portable release-state Swift harness. Each fails on `permissionDenied`. |
| Core runtime batch | Attempted; exit 1 before tests |
| PDF integration batch | Attempted; exit 1 before tests |
| Four UI batches | Each attempted; each exit 1 before tests |
| Core test inventory | 235 methods; zero executed |
| PDF integration inventory | 26 methods; zero executed |
| UI inventory | 59 methods; zero executed |
| Runtime total | 320 inventoried methods; zero executed, not 320 passed and not 320 assertion failures |

See [results.json](docs/internal/evidence/results.json), [build.log](docs/internal/evidence/build.log), [runtime-suites.log](docs/internal/evidence/runtime-suites.log), and [suite-results.json](docs/internal/evidence/suites/suite-results.json). All independent suites were attempted despite the first failure. A single successful source gate is not evidence of semantic usefulness.

The first audit is a repository-wide file/import/dependency inventory with focused inspection of import, reader, extraction, normalization, persistence, search, concepts, questions, study, Lens, Trails and voice. [SOURCE_AUDIT.json](SOURCE_AUDIT.json) captures per-file hashes and inventory, allowing the documentation-only scope to be checked. It is not a Git diff; this repository has no commits or tracked files.

## Existing corpus inspection

Python pypdf metadata/text inspection found six bundled PDFs, each four pages: Coding Interviews, Computer Science Essentials, Design Patterns, JavaScript Deep Dive, React Notes and System Design. All 24 pages return nonempty text with pypdf. File sizes range from 6,255 to 7,573 bytes. See [bundled-corpus.json](docs/internal/evidence/bundled-corpus.json).

This proves only the existence, size and pypdf-readable text of those files. It does not execute PDFKit/Vision, validate geometry, establish OCR confidence or represent a 200-page real-world book. The requested ten document classes and 20/100/300/800-page benchmarks are not present as a completed semantic-engine evaluation suite.

## Metrics that must remain unclaimed

| Metric | Current result | Required evidence |
| --- | --- | --- |
| Semantic Recall@1/@3/@5, MRR | Not measured; embedding/retrieval pipeline absent | Held-out labeled queries; exact/BM25/hybrid comparisons on the same corpus |
| Extraction/OCR latency | Not measured with Apple providers | Per-page native/OCR timings on named iPhone/device/OS |
| Time-to-readable | Not measured | Import start → reader usable timestamp, separately from full processing |
| 20/100/300/800-page indexing | Not measured | Stage timings, cancellation/resume and cold/warm cache runs |
| 10/100/1,000-document retrieval | Not measured | Defined library composition; query p50/p95, memory and disk |
| Embedding memory/storage | Not measured; vector store absent | Actual dimensions, page/chunk counts, vector bytes and manifest overhead |
| Question acceptance/rejection rate | Not measured in Swift | Emitted candidate ledger with reason/type/source support and human review |
| Grounded source navigation | Existing source implementation only | Native/OCR/multi-source integration and UI assertions |
| Foundation Models quality | Not measured; adapter absent | Supported-device bounded structured generation and independent grounding checks |
| Adaptive study benefit | Not measured; new concept mastery absent | Replayed distinct histories and useful different sessions after the vertical slice passes |

No synthetic timing estimates or Python substitutes for Apple runtime results are presented as benchmarks. The 188-native/12-OCR acceptance distribution is a future controlled fixture, not an observed import result.

## Environment needed to continue

The user's section 42 requires a branch before implementation. The repository is currently unborn `master` with zero tracked files, and `.git` is read-only to this task. Create the authorized branch in a writable local environment:

```sh
cd /Users/malmeida/Documents/ChatGPT/Leu
git switch -c feature/leu-semantic-learning-engine
```

Before baseline committing, explicitly stage the recovered application source and documentation; exclude checkpoint ZIPs, caches, DerivedData and transient logs. Review the staged files. No commit/push is claimed or performed by this audit.

The Swift/Xcode execution restriction is independent of Git permissions. Run verification from an environment where SwiftPM and CoreSimulator can operate:

```sh
cd /Users/malmeida/Documents/ChatGPT/Leu/LeuNativeV24_5
SHELF_QA_LOG=qa-semantic-baseline.log ./scripts/qa-and-copy.sh
```

If the front gate fails, collect every independent runtime suite with:

```sh
SHELF_QA_RUN_DIR=docs/semantic-engine/docs/internal/evidence/local-suites python3 scripts/run-qa-suites.py
```

The source implementation phase, semantic quality gates and device benchmarks remain outstanding. Neither audit completion nor successful compilation alone would satisfy the user's final acceptance scenario.
