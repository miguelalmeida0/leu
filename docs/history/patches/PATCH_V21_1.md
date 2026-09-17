# V21.1 compile repair

The V21 Mac compile gate exposed a Swift language rule that portable syntax parsing did not catch:

`LearningTokens.Type` is invalid because `Type` conflicts with Swift metatype syntax (`foo.Type`).

V21.1 changes that semantic token namespace to `LearningTokens.Typography` and updates every call site. No product behavior or data model was changed by this repair.

Portable verification after the patch:
- structural validation: PASS
- ShelfCore file-scoped import audit: PASS
- Learning OS offline/architecture audits: PASS
- Connected Knowledge architecture audit: PASS
- Shelf Voice architecture audit: PASS
- Connected Knowledge + Voice privacy audit: PASS
- native UI contract audit: PASS
- ShelfCore: 182 tests, 0 failures
- delivery tooling: 15 checks, 0 failures
- Swift parser: 265 source/test files, 0 failures

Apple SDK compilation and simulator UI tests must be re-run on macOS.
