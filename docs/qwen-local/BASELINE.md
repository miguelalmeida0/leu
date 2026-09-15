# Qwen local baseline — 2026-09-15

Workspace: `/Users/malmeida/Documents/ChatGPT/Leu/LeuQwenLocal`
Branch: `codex/qwen-local-understanding`
Exact base: `cf62f231e233ee777da318c5c87d17ab3d1d96fa`.

The committed V29.1 integration was clean and had an identical origin tracking
ref when inspected. Its host certification is complete; its report explicitly
leaves native packaging and simulator acceptance unverified. This is the latest
completed implementation checkpoint, not a device-certified product release.

Frozen V28.1 remains at `d178a129e3c07fca3e6b00dc0b32cb730e4bf22d`, clean.
Research remains at `fca850a321b408a84ef105eecdf496a06354b8e9`, with a modified
`evidence/super-intelligence/structural-audit.json` and untracked
`evidence/super-intelligence/evaluation-report.json`. Neither was touched or
copied. A new git worktree was created from the immutable product commit.

## Observed environment

- macOS 26.6 (25G72), arm64; MacBook Pro Mac15,3, Apple M3, 16 GB RAM.
- Approximately 115 GiB filesystem space available before the experiment.
- Xcode 26.6 (17F113); Apple clang 21.0.0.
- Swift 6.3.3 (`swiftlang-6.3.3.1.3`), driver 1.148.6. Initial version query
  failed with `permissionDenied`; the explicit Xcode toolchain query succeeded
  with a workspace-owned temporary directory.
- iOS target 17.0, automatic signing, team `2R4N5A4Q68`, app `dev.shelf.v27`.
- CoreDeviceService failed to initialize; connected iPhone status UNKNOWN.
- No simulator restarts, device erasures, or entitlement changes.

The existing adapter consumes current, extraction-bound `RelationalSourceFact`
values. The atom-proposal provider is not a suitable feedback contract: its
admission gate requires lexical subject/object coverage and generates graph
atoms. Learner semantic assessments must stay separate from knowledge admission.

## Evidence boundaries

Mac inference, iOS compilation, simulator interaction, and physical iPhone
inference are separate gates. Model metadata and successful builds do not prove
semantic correctness or compatibility on the phone. See execution artifacts
and the final status report for which gates actually ran.
