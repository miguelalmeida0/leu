# V18.1 native compile fix

The V18 Mac audit reached Apple SDK compilation and failed in `ReaderModel+Search.swift` because Swift imports are file-scoped: the extension referenced `PassageMatch` but that file imported only Foundation.

V18.1:
- imports `ShelfCore` directly in `ReaderModel+Search.swift`;
- adds `scripts/check-shelfcore-imports.py` to detect the same class of regression statically;
- runs a native `xcodebuild` compile gate before longer QA stages;
- keeps `qa-and-copy.sh` as the fast terminal flow that retains the full log and automatically shows + copies the actionable summary;
- excludes generated `.build` state from the release archive.

Container validation: structural checks, ShelfCore tests, Swift syntax parsing, and the new import audit pass. Apple SDK typechecking/runtime must run on macOS/Xcode.
