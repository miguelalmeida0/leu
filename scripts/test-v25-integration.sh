#!/bin/bash
# Target integration failures before the complete native QA run. No skips/retries.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GROUP="${1:-all}"
OUT="$ROOT/recovery-docs/internal/evidence/v25-final-integration/runs/$(date '+%Y%m%d-%H%M%S')-$$"
mkdir -p "$OUT"
export LEU_UI_DIAGNOSTICS=1 LEU_PDF_DIAGNOSTICS=1
STATUS=0
run_group() {
    local name="$1"; shift
    "$ROOT/scripts/test-ios.sh" "$@" > "$OUT/$name.log" 2>&1
    local result=$?
    printf '%s exit=%s log=%s\n' "$name" "$result" "$OUT/$name.log" | tee -a "$OUT/results.txt"
    if [[ "$result" != 0 ]]; then STATUS=1; fi
}
case "$GROUP" in A|B|C|all) ;; *) printf 'Usage: bash scripts/test-v25-integration.sh [A|B|C|all]\n'; exit 2;; esac
if [[ "$GROUP" == A || "$GROUP" == all ]]; then
    run_group A \
        -only-testing:ShelfTests/PDFIntegrationTests/testReadableModeRepairsKnownExtractionSeamsWithoutChangingSourcePDF \
        -only-testing:ShelfTests/PDFReconstructionV25Tests/testFragmentedRunsBecomeOneHeadingFromRealPDFGeometry \
        -only-testing:ShelfTests/PDFReconstructionV25Tests/testNumberedListsCodeAndRealHyphensSurvive
fi
if [[ "$GROUP" == B || "$GROUP" == all ]]; then
    run_group B \
        -only-testing:ShelfUITests/ShelfWorldClassUITests/test50SemanticQuestionUsesFourLevelCertainty \
        -only-testing:ShelfUITests/ShelfWorldClassUITests/test51UnderstandingLensUsesVerifiedSourceFacts \
        -only-testing:ShelfUITests/ShelfWorldClassUITests/test53ActiveStudyContextSurvivesInterruption \
        -only-testing:ShelfUITests/ShelfLearningOSUITests/test33QuestionCommitAndSourceRoundTrip \
        -only-testing:ShelfUITests/ShelfRecoveryV25UITests/test57ConfidenceControlsHaveEqualGeometryAndCompleteLabels
fi
if [[ "$GROUP" == C || "$GROUP" == all ]]; then
    run_group C \
        -only-testing:ShelfUITests/ShelfInteractionRepairUITests/test24OriginalFitRejectsVerticalDriftButTurnsOnHorizontalDrag \
        -only-testing:ShelfUITests/ShelfInteractionRepairUITests/test25OriginalFocusTurnsAndControlsDoNotCoverTheViewport \
        -only-testing:ShelfUITests/ShelfInteractionRepairUITests/test29FlowRoundTripDoesNotDisableReadPaging \
        -only-testing:ShelfUITests/ShelfUITests/test13HorizontalGestureSmokeTestInReadMode \
        -only-testing:ShelfUITests/ShelfUITests/test14HorizontalGestureSmokeTestInOriginalMode
fi
if [[ "$STATUS" == 0 && "$GROUP" == all ]]; then
    printf 'All targeted groups passed. Next: SHELF_QA_LOG=qa-v25-recovery.log ./scripts/qa-and-copy.sh\n'
fi
exit "$STATUS"
