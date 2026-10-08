# Contributing

Leu has two distinct deliverables: the native iOS application in `Shelf/` and the browser companion in `web/`. Do not infer release readiness in one from checks in the other.

## Working agreement

- Follow [`AGENTS.md`](AGENTS.md): work on `test`, release on `main`, and create no additional branches.
- Keep domain rules and deterministic learning contracts in `Packages/ShelfCore/`; SwiftUI screens and PDFKit adapters own presentation and platform access.
- Make file imports, backups and annotations non-destructive. Keep original PDFs immutable.
- Do not commit private PDFs, credential files, local inference weights, Xcode derived data, simulator artifacts or personal test libraries.
- Reproduce bugs and add focused regression coverage before refactoring across feature boundaries.

## Validation

```bash
# macOS with full Xcode 16+
./run.sh --build

# Browser companion (Node 20.19+ or 22.12+)
cd web
npm ci
npm run build
```

For native journey verification use [the release checklist](docs/RELEASE_CHECKLIST.md). Check Dynamic Type, VoiceOver, source passage provenance and interrupted file operations when affected by a change. Do not report simulated or archival evidence as a fresh successful run.

See [`docs/START_HERE.md`](docs/START_HERE.md) for ownership and navigation.
