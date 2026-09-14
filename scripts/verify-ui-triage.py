#!/usr/bin/env python3
"""Compile UI tests, run six cause representatives, then only the failed twelve.

Keeps the original 74-test evidence and every completed certification gate intact.
Never resets/reimports the existing simulator library. No automatic test retries.
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
os.chdir(ROOT)
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("evidence", type=Path)
parser.add_argument("--repair-reader-return", type=Path,
                    help="Reuse a 4/6 representative result; run only its two shared-helper failures before the twelve.")
args = parser.parse_args()
baseline = args.evidence.resolve()
summary = json.loads((baseline / "ui-full-summary.json").read_text())
assert (summary["passedTests"], summary["failedTests"], summary["skippedTests"]) == (62, 12, 0)
failed = sorted({"ShelfUITests/" + row["testIdentifierString"].removesuffix("()")
                 for row in summary["testFailures"]})
assert len(failed) == 12
representative_methods = {
    "test57ConfidenceControlsHaveEqualGeometryAndCompleteLabels",
    "test58TrailContinueReturnsToTheRetainedTrail",
    "testMCQPredictionCommitFeedbackAndSourceRoundTrip",
    "test59ExistingReactPagesOneToThreeRetainTextAndCode",
    "test51UnderstandingLensUsesVerifiedSourceFacts",
    "test52V24PrivacyAndNeuralVoiceControlsAreExposed",
}
representatives = [test for test in failed if test.split("/")[-1] in representative_methods]
assert len(representatives) == 6
representative_phase = "representatives"
if args.repair_reader_return:
    previous = args.repair_reader_return.resolve()
    result = json.loads((previous / "representatives-summary.json").read_text())
    assert (result["totalTestCount"], result["passedTests"], result["failedTests"], result["skippedTests"]) == (6, 4, 2, 0)
    representatives = sorted({"ShelfUITests/" + row["testIdentifierString"].removesuffix("()")
                              for row in result["testFailures"]})
    assert set(representatives) == {
        "ShelfUITests/ShelfRecoveryV25UITests/test57ConfidenceControlsHaveEqualGeometryAndCompleteLabels",
        "ShelfUITests/ShelfSessionExperienceUITests/testMCQPredictionCommitFeedbackAndSourceRoundTrip",
    }
    previous_ui = json.loads((previous / "ui-source-sha256.json").read_text())
    current_ui = {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in Path("ShelfUITests").rglob("*.swift")}
    changed = {p for p in set(previous_ui) | set(current_ui) if previous_ui.get(p) != current_ui.get(p)}
    assert changed <= {"ShelfUITests/V24InteractionSupport.swift"}, "Unexpected UI changes since 4/6 result: " + str(changed)
    representative_phase = "reader-return-two"
protected = {p: h for p, h in json.loads((baseline / "source-sha256.json").read_text()).items()
             if p.startswith(("Shelf/", "ShelfTests/", "Shelf.xcodeproj/", "Packages/ShelfCore/Sources/"))}
assert protected
def verify_protected():
    changed = [p for p, h in protected.items() if not Path(p).exists() or hashlib.sha256(Path(p).read_bytes()).hexdigest() != h]
    assert not changed, "Production/native-unit inputs changed; reassess broader gates: " + str(changed)

verify_protected()
run = baseline / ("ui-triage-" + datetime.datetime.now().strftime("%Y%m%d-%H%M%S-%f"))
run.mkdir()
print("UI triage evidence:", run, flush=True)
ui_hashes = {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in Path("ShelfUITests").rglob("*.swift")}
(run / "ui-source-sha256.json").write_text(json.dumps(ui_hashes, indent=2, sort_keys=True))
(run / "selection.json").write_text(json.dumps({"representatives": representatives, "failed12": failed,
    "protectedInputsUnchanged": len(protected)}, indent=2))
device = summary["devicesAndConfigurations"][0]["device"]["deviceId"]
common = ["xcodebuild", "-project", "Shelf.xcodeproj", "-scheme", "Shelf", "-configuration", "Debug",
          "-destination", "platform=iOS Simulator,id=" + device, "-derivedDataPath", ".build/study-home",
          "-parallel-testing-enabled", "NO", "CODE_SIGNING_ALLOWED=NO"]

def invoke(command, name):
    with (run / (name + ".log")).open("w") as log:
        result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT)
    (run / (name + "-exit.txt")).write_text(str(result.returncode) + "\n")
    return result.returncode

def phase(name, tests):
    bundle = run / (name + ".xcresult")
    status = invoke(common + ["-resultBundlePath", str(bundle), "test-without-building"] +
                    ["-only-testing:" + test for test in tests], name)
    if not bundle.exists():
        raise RuntimeError(f"{name}: no xcresult, execution blocked/failed; see {run / (name + '.log')}")
    data = subprocess.check_output(["xcrun", "xcresulttool", "get", "test-results", "summary", "--path", str(bundle)])
    (run / (name + "-summary.json")).write_bytes(data)
    exported = invoke(["xcrun", "xcresulttool", "export", "attachments", "--path", str(bundle),
                       "--output-path", str(run / (name + "-attachments"))], name + "-export")
    result = json.loads(data)
    passed = status == 0 and result.get("result") == "Passed" and result.get("passedTests") == len(tests) and \
        result.get("totalTestCount") == len(tests) and result.get("failedTests") == result.get("skippedTests") == 0
    print(name, {k: result.get(k) for k in ["result", "passedTests", "failedTests", "skippedTests"]}, flush=True)
    assert passed and exported == 0, f"STOP: {name} must pass with complete attachments before continuing."
    verify_protected()
    assert all(hashlib.sha256(Path(p).read_bytes()).hexdigest() == h for p, h in ui_hashes.items()), "UI sources changed during certification"

# Incremental UI-runner build only; never rerun the already-green unit gates.
status = invoke(common + ["build-for-testing", "-only-testing:ShelfUITests"], "build-ui")
if status:
    sys.exit("UI build blocked/failed; see " + str(run / "build-ui.log"))
original_size = subprocess.check_output(["xcrun", "simctl", "ui", device, "content_size"], text=True).strip()
try:
    subprocess.run(["xcrun", "simctl", "ui", device, "content_size", "large"], check=True)
    phase(representative_phase, representatives)
    phase("failed12", failed)
    (run / "passed").touch()
finally:
    subprocess.run(["xcrun", "simctl", "ui", device, "content_size", original_size], check=False)
