# Repository guide

[Project overview](../README.md) · [Contributing](../CONTRIBUTING.md) · [Security and privacy](../SECURITY.md)

## Product surfaces

| Area | Responsibility |
| --- | --- |
| [`Shelf/`](../Shelf/) | Native iOS application: SwiftUI feature screens, PDFKit reader and platform adapters |
| [`Packages/ShelfCore/`](../Packages/ShelfCore/) | Portable domain, learning contracts, repositories and deterministic tests |
| [`web/`](../web/) | Vite / React browser companion, independently buildable and served on Vercel |
| [`ShelfTests/`](../ShelfTests/) | Native test targets |
| [`ShelfUITests/`](../ShelfUITests/) | Simulator interaction and accessibility tests |
| [`validation/`](../validation/) | Separate validation fixtures and harnesses |
| [`scripts/`](../scripts/) | Native QA and verification tooling |

## How to start

- [Build and launch the iOS application](../run.sh) — `./run.sh --help` on a Mac with Xcode
- [Run the browser implementation](../web/README.md) — `cd web && npm ci && npm run dev`
- [Architecture and dependency boundaries](ARCHITECTURE.md)
- [Release and validation checklist](RELEASE_CHECKLIST.md)

## Design decisions and evidence

- [Design records](design/) are historical decisions, reviewed references and simulator captures.
- [Engineering history](history/ROOT_FILES.md) preserves archived handoffs and relocation notes.
- Simulator media are evidence of individual runs, **not** proof that a future commit passed those runs.

Keep the repository root for the app, packages, tests, public entrypoints and build configuration. Do not move native source, fixtures, screenshots or historical evidence merely for cosmetic uniformity.
