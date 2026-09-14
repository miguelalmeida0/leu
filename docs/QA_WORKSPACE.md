# Shelf VSCode native QA workspace

Shelf is a native SwiftUI/PDFKit app. Playwright is not the native UI automation layer.
Use XCUITest for the iOS app and reserve Playwright for the legacy PWA/browser build.

## Open in VSCode

```bash
cd "$HOME/Downloads/ShelfNativeV17Audit"
code .
```

If `code` is unavailable, in VSCode run **Shell Command: Install 'code' command in PATH** from the Command Palette.

## One-command audit

```bash
./scripts/qa-native.sh
```

This runs structural validation, portable core tests, Apple PDF integration tests, and the screen-by-screen XCUITest suite.
Results are written under `.build/results/*.xcresult`.

## VSCode tasks

Use **Terminal → Run Task**:

- Shelf: Full native QA
- Shelf: UI audit only
- Shelf: PDF integration only
- Shelf: Structural validation
- Shelf: Open in Xcode

## Deep device checks XCUITest cannot certify alone

Run these manually on the physical iPhone after every reader change:

1. ten slow page drags in each direction;
2. ten rapid flicks;
3. start a drag then reverse before release;
4. zoom PDF, pan horizontally, verify no accidental page turn;
5. scroll vertically while deliberately adding small horizontal drift;
6. switch Read ↔ Original and verify position remains stable;
7. select, mark, close, reopen, and return to the exact mark;
8. start/pause/resume speech and verify highlighted sentence tracks playback;
9. test Dynamic Type and Reduce Motion;
10. airplane mode, force quit, relaunch, and open an imported PDF.

## Optional Playwright — legacy PWA only

If you also want browser regression coverage for `Shelf-PWA`, create a separate web QA folder:

```bash
mkdir -p qa-web && cd qa-web
npm init -y
npm i -D @playwright/test
npx playwright install chromium webkit
```

Do not treat those results as native iPhone certification.

## V4 accessibility lookup policy
Reader automation prefers explicit accessibility identifiers, but falls back to the user-facing accessibility label when SwiftUI/XCUI flattens a custom control and drops its identifier. This avoids modifying production layout solely for test discovery and keeps the audit aligned with the VoiceOver-facing contract. Disabled controls are not mandatory contract probes because some simulator runtimes omit them from the tree.
