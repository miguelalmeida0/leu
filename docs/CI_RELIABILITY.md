# Leu CI reliability and release policy

The production browser app and native iOS app are distinct. A successful Vercel deployment is not proof of functioning reader journeys, motion accessibility, or native verification.

## Non-negotiable release rules

1. Use only `test` for development and `main` for production, as required by AGENTS.md. The branches have diverged: never merge the whole `test` branch just to ship one fix. Promote only a reviewed, isolated change and verify the PR merge result.
2. Preflight every browser change with `cd web && npm ci && npm run build`. Syntax/type/build failures mean **stop**, even when unrelated CI is green.
3. When changing reader, PDF parsing, navigation, voice, or motion, reproduce the affected Playwright journey. Always cover an iPhone/WebKit viewport and a desktop/Chromium viewport; motion work includes reduced motion, default autoplay and explicit Play/Pause.
4. Push to `test` first. Do not promote a failing or unverified commit to `main`. Wait for required checks on the PR merge result, not on an old head SHA.
5. Never bypass CI by removing tests, skipping a viewport, relaxing a valid assertion, ignoring exit codes, adding `continue-on-error`, or claiming a deploy is verification.
6. Treat any red `main` as a release stop. Fix the underlying fault first, retain screenshots/logs, rerun the full affected suite, and only then resume features.

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
4. Keep the existing ruleset restricting new development branches to `main` and `test`. Do not weaken the security or authorship policy to work around a CI failure.
5. Verify enforcement with a test: a direct push to `main` is rejected, and a PR with failing `web-release-gate` cannot merge. If this cannot be achieved with the current two-branch topology, stop and resolve the branch model explicitly rather than silently accepting an unprotected `main`.

**Do not enable required checks before the new jobs have reported their status.** If GitHub refuses settings via the connected app, the repository owner must do this in GitHub's Settings UI.

## Recovery checklist

- Inspect the *first failing step* and its logs; distinguish build syntax errors, dependency/runner installation problems, accessibility regressions, browser flakiness, and real product failures.
- Reproduce the same user-visible behavior. For Home, a reduced-motion environment must start paused and show Play; without reduced motion it should autoplay; after an explicit Play/Pause the choice must persist.
- Fix the cause with the smallest change. Do not rerun a deterministic failed commit repeatedly hoping it changes.
- Confirm the new `web-release-gate` and native core check are green, record the exact run and SHA, and only then declare the release ready.
