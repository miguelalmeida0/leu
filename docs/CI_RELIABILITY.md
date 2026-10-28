# Leu CI reliability and release policy

The production browser app and native iOS app are distinct. A successful Vercel deployment is not proof of functioning reader journeys, motion accessibility, or native verification.

## Non-negotiable release rules

1. Use only `test` for development and `main` for production, as required by AGENTS.md. Keep one releasable unit on `test` at a time. Promote only a reviewed, isolated change and verify the current PR merge result. If unrelated work has accumulated, stop and account for it before promotion; never reset or overwrite either shared branch.
2. Preflight every browser change with `cd web && npm ci && npm run build`. Syntax/type/build failures mean **stop**, even when unrelated CI is green.
3. When changing reader, PDF parsing, navigation, voice, or motion, reproduce the affected Playwright journey. Always cover an iPhone/WebKit viewport and a desktop/Chromium viewport; motion work includes reduced motion, default autoplay and explicit Play/Pause.
4. Push to `test` first. Do not promote a failing or unverified commit to `main`. Wait for required checks on the PR merge result, not on an old head SHA.
5. Never bypass CI by removing tests, skipping a viewport, relaxing a valid assertion, ignoring exit codes, adding `continue-on-error`, or claiming a deploy is verification.
6. Treat any red `main` as a release stop. Fix the underlying fault first, retain screenshots/logs, rerun the full affected suite, and only then resume features.

## Lossless two-branch promotion

1. Fetch both branch tips and inspect both the commit graph and the complete tree diff. Commit counts alone do not identify unshipped changes after a squash.
2. If `main` contains changes absent from `test`, merge `main` into `test` through a verified synchronization PR. Preserve both parents and check the resulting tree; never use a reset or an unconditional replacement of the tree.
3. Develop one focused release on `test`. Both workflows run on pushes to `main` and `test`, and on PRs targeting either branch, without path filters.
4. Open `test` -> `main`. Wait for `web-release-gate` and `portable-core` on the current PR merge result, resolve conversations, and inspect the final file diff.
5. Use a merge commit, not squash or rebase, so both persistent branches retain shared ancestry. After merging, fast-forward `test` to the resulting `main` tip if no new work has arrived. If it has, merge production back without overwriting it and verify again.
6. Re-read both tips before each mutation. Use an expected head SHA for PR merges and an expected old SHA with `force: false` for ref updates. A moved ref requires fresh analysis, not an automatic retry.

The October 28, 2026 reconciliation starts from `main` at `b60c653d6137602f7d73c28549c628a3482cace0` and `test` at `2a648e41500c8fee2d6565c1bd4a4c4241347e9f`. Although Git reports 66 test-only commits and two main-only commits, the test tree equals production voice release `7811cb793cd78d8023228d7486fff8eb9ee2f1e6` exactly. Only `tokens/leu.tokens.json` is missing from test. A conflict-free three-way merge produces the existing production tree `48d058af42c6288973c5aeecdba92ac41bca1e32`. Preserve the historical commits; do not replay them as new features.

## Automated checks

- `Shelf verification / portable-core`: native core tests and structural validation.
- `Leu browser journeys / chromium-and-webkit`: build, reader, iPhone/Android/desktop journeys, static animation previews.
- `Leu browser journeys / home-motion-accessibility`: build, real Home rain/steam movement, reduced-motion compliance, Pause/Play, reload and navigation.
- **`Leu browser journeys / web-release-gate`**: stable, fail-closed required check. It succeeds only if both browser jobs succeed. This job always evaluates dependencies, including failures or skipped browser jobs.

Browser jobs use a version-matched Playwright container (v1.56.1), with browsers and system libraries preinstalled, instead of running an expensive apt install each time. This improves feedback speed without compromising the existing assertions. The browser workflow runs for every PR to `main` or `test`, including documentation changes, so a required check is never indefinitely pending due to path filters.

## GitHub repository-owner action (one time)

**GitHub Actions cannot protect `main` by itself.** Repository Settings must enforce a branch protection rule/ruleset for `main`:

1. Go to **Settings > Rules > Rulesets** (or **Branches > Add branch protection rule**) and target `main`.
2. Require a pull request before merging and require successful status checks. Mark **`web-release-gate`** and **`portable-core`** as required (select the GitHub Actions check source). Checks may need one successful run before they appear in the selector.
3. Require the branch to be up to date before merging so the **tested merge result** is current; disable bypasses for normal users and admins, disallow force pushes/deletions, and enforce rules for direct GitHub API pushes too.
4. Keep the existing ruleset restricting new development branches to `main` and `test`. Permit only merge commits for production PRs; keep linear-history enforcement and automatic branch deletion off. Protect `test` against force pushes and deletion without blocking ordinary development pushes. Do not weaken the security or authorship policy to work around a CI failure.
5. Verify enforcement with a test: a direct push to `main` is rejected, and a PR with failing `web-release-gate` cannot merge. If this cannot be achieved with the current two-branch topology, stop and resolve the branch model explicitly rather than silently accepting an unprotected `main`.

For the single-owner workflow, required PRs with zero required approvals enforce CI and conversation resolution, but do not enforce independent human review. Requiring one approval or approval of the latest push needs another eligible reviewer; do not add an administrator bypass to work around that constraint. Bind both required checks to the GitHub Actions app (integration ID `15368`) and leave the bypass list empty.

**Do not enable required checks before the new jobs have reported their status.** If GitHub refuses settings via the connected app, the repository owner must do this in GitHub's Settings UI.

## Recovery checklist

- Inspect the *first failing step* and its logs; distinguish build syntax errors, dependency/runner installation problems, accessibility regressions, browser flakiness, and real product failures.
- Reproduce the same user-visible behavior. For Home, a reduced-motion environment must start paused and show Play; without reduced motion it should autoplay; after an explicit Play/Pause the choice must persist.
- Fix the cause with the smallest change. Do not rerun a deterministic failed commit repeatedly hoping it changes.
- Confirm the new `web-release-gate` and native core check are green, record the exact run and SHA, and only then declare the release ready.
