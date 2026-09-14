# Verification and test commands

## Executed in this delivery environment (V19)

- Swift 6.2.1 on Linux: the portable `ShelfCore` package compiled.
- **120 XCTest tests passed, zero failures.** Nineteen specifically exercise the V19 page-turn policy. See `evidence/v19/core-tests-linux.log`.
- Native source files were parsed with the Swift frontend. Parsing is not Apple-SDK typechecking.
- The `.pbxproj` was parsed using `plutil`; project file references, local package wiring and scheme targets were structurally checked.
- Shell scripts were syntax-checked, the simulator selector was exercised against fixtures, and the optional backup extractor was checked for good/corrupt input.
- All six original sample PDFs (24 pages) were rendered and visually checked. The sample-page contact sheet is not a screenshot of the app.

## Not executed here

The environment has no macOS, Xcode, iOS simulator, Apple SDK, signing identity, or physical phone. Native compilation, PDFKit runtime tests, UI tests, rendering screenshots, device performance, installation, and signing renewal remain **unverified here**. CI configuration is included; no claim is made that a remote CI run occurred.

## Portable tests

```bash
./scripts/test-core.sh
```

Coverage includes hash vectors/chunk boundaries, corrupt/future metadata, checkpoint recovery, failed persistence rollback, repeated/invalid imports, concurrent repository updates, annotation and bookmark rules, filtering and UTF-16 text locations, duplicate-aware restore, malformed/truncated/tampered archives, streaming checksums, and merge idempotency.

No coverage percentage is claimed. The test count is not a substitute for behavioral scope or device tests.

## Apple integration and UI tests

```bash
./scripts/test-ios.sh
```

The script builds for a real available iPhone simulator and writes a dated `.xcresult` under `.build/results/`. Open the result in Xcode to inspect failures and screenshot attachments. One flow can be selected:

```bash
./scripts/test-ios.sh -only-testing:ShelfTests/PDFIntegrationTests
./scripts/test-ios.sh -only-testing:ShelfUITests/ShelfUITests
```

Twelve Apple PDF/PDFKit tests cover readable bundled PDFs, extraction, invalid inputs, source-page search, original-byte preservation, portable notes, idempotent annotation rendering, thumbnail decoding, mixed-size one-page geometry, resize refitting, zoom preservation, and flow-mode page identity. Thirty-two UI/regression journeys cover the library and reader; tests 22–31 specifically exercise the physical-device interaction repairs introduced in V19.

UI tests launch with `--uitesting --reset-library`; test files use a separate test library location. Never reuse those launch flags for your real library. `--no-samples` starts without sample seeding and is useful for empty-state tests.

## Structural validation

Optional developer tool (Python 3 standard library only):

```bash
python3 scripts/validate.py
```

This checks file sizes, manifests, plist/asset/scheme syntax, source target membership, and forbidden remote Swift dependencies. It does not build Apple code. When `plutil` is available, it additionally parses and checks project references.

## Release gate

A release is not qualified until native compilation, integration tests, UI tests, and the device checklist in `RELEASE_CHECKLIST.md` pass. Preserve real results and screenshots under a new evidence run. Do not relabel planned checks as passed.
