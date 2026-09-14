#!/bin/bash
# Targeted source checkpoint first. Stops at a failure; never launches full QA.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export LEU_UI_DIAGNOSTICS=1 LEU_PDF_DIAGNOSTICS=1
export SHELF_SIMULATOR_UDID="${SHELF_SIMULATOR_UDID:-A248FB9E-B969-4CF6-A0ED-B2013A3C60A6}"
python3 "$ROOT/scripts/sync-xcode-sources.py"
python3 "$ROOT/scripts/validate.py"
"$ROOT/scripts/test-ios.sh" \
  -only-testing:ShelfTests/PDFIntegrationTests/testReadableModeRepairsKnownExtractionSeamsWithoutChangingSourcePDF \
  -only-testing:ShelfTests/PDFReconstructionV25Tests/testReactCanonicalGeometryAndBlocksPreserveEveryCharacter \
  -only-testing:ShelfTests/PDFReconstructionV25Tests/testFragmentedRunsBecomeOneHeadingFromRealPDFGeometry \
  -only-testing:ShelfTests/PDFReconstructionV25Tests/testNumberedListsCodeAndRealHyphensSurvive \
  -only-testing:ShelfTests/PDFReadFurnitureTests
# First UI launch performs the uninterrupted upgrade/reader/Lens/Study journey.
"$ROOT/scripts/test-ios.sh" \
  -only-testing:ShelfUITests/ShelfSourceRecoveryP0UITests/test62UninterruptedExistingLibraryReadLensStudySourceReturn
# Only after the visible slice passes, run the recall and isolated inference checks.
"$ROOT/scripts/test-ios.sh" \
  -only-testing:ShelfTests/LearningRealModelP0Tests \
  -only-testing:ShelfUITests/ShelfSourceRecoveryP0UITests/test60ExistingLibraryActiveRecallRevealsAndReturns
# The existing C suite resets its test library. It is deliberately not run here.
# Run full QA only after reviewing this checkpoint and its xcresult screenshots.
