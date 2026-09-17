# Repository structure

**Repository role:** Native SwiftUI/PDFKit iPhone application

The public root is product-first: runtime code, framework configuration,
tests, project docs and legal metadata stay visible. Agent runtime material,
historical planning and generated QA output live in explicit internal
namespaces.

## Rules

1. Product/runtime architecture owns the root.
2. Claude/Codex/agent material lives under `docs/internal/automation/` or `tooling/`.
3. Local agent conventions are recreated with `scripts/dev/bootstrap-local-tooling.sh`.
4. Generated output is not a root architectural concept.
5. Historical material lives under `docs/archive/`.
6. Framework-required configuration stays at root.

## Moved

- `.vscode` -> `docs/internal/editor/vscode`
- `SOURCE_SHA256SUMS.txt` -> `docs/integrity/SOURCE_SHA256SUMS.txt`
- `Start Leu.command` -> `scripts/dev/Start Leu.command`

## Notes

- None.

## Root before

```text
.github/
.gitignore
.vscode/
LICENSE
Packages/
README.md
SECURITY.md
SOURCE_SHA256SUMS.txt
Shelf.xcodeproj/
Shelf/
ShelfTests/
ShelfUITests/
Start Leu.command
THIRD_PARTY_NOTICES.md
contracts/
docs/
run.sh
scripts/
validation/
```

## Root after

```text
.github/
.gitignore
LICENSE
Packages/
README.md
SECURITY.md
Shelf.xcodeproj/
Shelf/
ShelfTests/
ShelfUITests/
THIRD_PARTY_NOTICES.md
contracts/
docs/
run.sh
scripts/
validation/
```
