# Leu Native V23.1 — Apple PDF Readable-Text Repair

V23.1 is the Apple-native convergence patch for the Gallery Minimalism redesign.

## Fixed

- Preserves the V23 Gallery Minimalism redesign and one-tier information architecture.
- Fixes the Apple PDF readable-mode seam where `F O L L O W- U P` became `FOLLOW- U P` after letter-spacing repair.
- The production normalizer now deterministically repairs that remaining two-letter spaced tail to `FOLLOW-UP`.
- The Apple integration assertion remains strict; it was not weakened or skipped.
- Marketing version advances to **2.3.1**.

## Release gate

Run `SHELF_QA_LOG=qa-v23-1.log ./scripts/qa-and-copy.sh` on macOS. V23.1 is release-green only when the Apple build, ShelfTests, and the complete ShelfUITests suite all finish with exit code 0.
