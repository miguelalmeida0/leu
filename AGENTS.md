# Repository instructions

<!-- BEGIN: owner-branch-policy -->
## Mandatory repository branch and attribution policy

These instructions apply to coding agents, local automation, and repository maintenance.

- Only `main` and `test` are permitted development branches.
- `test` is the working/integration branch; `main` is for reviewed, verified production changes.
- Do not create or push other branches (including feature, fix, release, PR, bot or deployment branches). Work using the permitted refs. If branch protection makes this impossible, stop and request a compliant plan rather than inventing another branch.
- Do not promote unrelated, unverified work from `test` into `main`. Verify and ship a focused change only.
- Never rewrite shared history, reset, force-push, or delete a ref without explicit owner approval and verified preservation of unique work.
- For locally authored changes, set both Git author and committer to `Miguel Almeida <94702822+miguelalmeida0@users.noreply.github.com>`. Do not add automated-agent co-author trailers.
- Preserve real contributor provenance when it differs from this single-owner assumption; stop for review rather than silently misattributing another human's work.
<!-- END: owner-branch-policy -->

## Mandatory CI and release-reliability policy

- Before publishing browser changes, run `cd web && npm ci && npm run build` locally. Treat TypeScript or build errors as blockers, not warnings. Never commit corrupt/binary TS or TSX, unresolved conflict markers, or incomplete edits.
- Exercise the relevant real-browser journey after changes to reader, Home, interactions or animation. Test iPhone/WebKit and desktop/Chromium, normal and reduced motion. Automatic motion must respect the OS preference; an explicit Play may override it for the scene.
- Push work to `test`; wait for `Leu browser journeys / web-release-gate` and `Shelf verification / portable-core` to pass. Require the same checks on the PR's merge result before promoting a focused, reviewed change to `main`. A green Vercel deployment alone never implies product certification.
- If tests cannot run in the agent's environment, clearly report this and let CI on `test` verify the change. Do not declare success or promote it to `main` without confirmed green checks.
- Never make CI green by deleting tests, skipping a browser/viewport, weakening accessibility assertions, introducing `continue-on-error`, disabling the gate, or suppressing failures. Fix the source cause; update expectations only with evidence of an intentional behavior change.
- When `main` is red, prioritize a minimal corrective patch. Pause unrelated feature releases until verification recovers. Report the failing test, linked run, fix and rerun result; do not retry unchanged deterministic failures indefinitely.
- The repository owner must enforce required PRs and status checks in GitHub branch protection; documentation and workflows alone cannot block direct pushes. See [docs/CI_RELIABILITY.md](docs/CI_RELIABILITY.md).
