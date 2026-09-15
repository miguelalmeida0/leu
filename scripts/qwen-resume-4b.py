#!/usr/bin/env python3
"""Explicit continuation after the recorded host slowdown; never retry a case.

Remaining cases use one process each and a 120-second process watchdog. This
contains another host stall; it is NOT evidence of in-app cooperative cancel.
Model, prompt, decoder, native library and Swift assessment remain frozen.
"""
import datetime
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time

root = Path(__file__).resolve().parent.parent
os.chdir(root)
folder = root / "docs/qwen-local"
assert (folder / "4b-interruption.json").exists(), "Only for the explicitly recorded continuation"
freeze = json.loads((folder / "final-settings.json").read_text())
binary = root / ".qwen-local/host-final/qwen-benchmark"
model = root / ".qwen-local/Qwen3.5-4B-Q4_K_M.gguf"
artifact = next(a for a in json.loads((folder / "MODEL_MANIFEST.json").read_text())["candidates"] if a["upstream"].endswith("-4B"))
assert hashlib.file_digest(model.open("rb"), "sha256").hexdigest() == artifact["sha256"]
scratch = root / ".qwen-local/4b-continuation"
scratch.mkdir(parents=True, exist_ok=True)
event_file = folder / "4b-continuation-events.jsonl"
assert not event_file.exists(), "Preserve prior continuation; investigate before another invocation"
event_file.touch()
failures_in_a_row = 0
for split in ("dev", "challenge"):
    cases_file = folder / f"{split}-cases.json"
    cases = json.loads(cases_file.read_text())
    destination = folder / f"final-{split}-4b-2048.jsonl"
    if not destination.exists():
        destination.touch()
    previous = [json.loads(line) for line in destination.read_text().splitlines()]
    seen = {r["id"] for r in previous}
    assert len(seen) == len(previous)
    baseline = {r["id"]: r["baseline"] for r in map(json.loads, (folder / f"final-{split}-2b-2048.jsonl").read_text().splitlines())}
    for case in cases:
        if case["id"] in seen:
            continue  # Includes the interrupted dev-07-4; no retry hides it.
        assert hashlib.sha256(binary.read_bytes()).hexdigest() == freeze["binary_sha256"]
        for path, checksum in freeze["hashes"].items():
            assert hashlib.sha256((root / path).read_bytes()).hexdigest() == checksum
        fixture = scratch / (case["id"] + ".json")
        output = scratch / (case["id"] + ".jsonl")
        assert not fixture.exists() and not output.exists(), "No silent case replay"
        fixture.write_text(json.dumps([case]) + "\n")
        start = time.monotonic()
        event = dict(id=case["id"], started_at_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
            process_per_case=True, watchdog_seconds=120, retry_count=0)
        try:
            completed = subprocess.run([str(binary), str(fixture), str(model), "2048", str(output)],
                env=dict(os.environ, TMPDIR=str(root / ".qwen-local/tmp")), timeout=120)
            event["exit_code"] = completed.returncode
        except subprocess.TimeoutExpired:
            event["watchdog_killed_child"] = True
        event["outer_wall_ms"] = (time.monotonic() - start) * 1000
        emitted = [json.loads(line) for line in output.read_text().splitlines()] if output.exists() else []
        if emitted:
            assert len(emitted) == 1 and emitted[0]["id"] == case["id"]
            row = emitted[0]
            failures_in_a_row = 0
        else:
            row = dict(id=case["id"], split=split, category=case["category"], context=2048,
                verify=False, contract=freeze["contract"], backend="Mac CPU", runs=[],
                status="interrupted" if event.get("watchdog_killed_child") else "failed",
                request_count=1, retry_count=0, wall_ms=event["outer_wall_ms"],
                thermal_before=None, thermal_after=None, baseline=baseline[case["id"]],
                baseline_provenance="Reused deterministic result from final 2B run; child did not emit a row",
                error="Continuation child produced no result; see watchdog/exit event", operator_recorded=True)
            failures_in_a_row += 1
        event["status"] = row["status"]
        with destination.open("a") as stream:
            stream.write(json.dumps(row, sort_keys=True) + "\n")
        with event_file.open("a") as stream:
            stream.write(json.dumps(event, sort_keys=True) + "\n")
        print("CONTINUATION", case["id"], row["status"], flush=True)
        if failures_in_a_row >= 2:
            raise SystemExit("Two consecutive resource/execution failures; preserved evidence and stopped")
    subprocess.run(["python3", "scripts/qwen-score.py", str(cases_file), str(destination),
        str(destination.with_suffix(".metrics.json"))], check=True)
