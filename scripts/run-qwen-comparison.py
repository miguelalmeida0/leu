#!/usr/bin/env python3
"""Freeze settings, then run candidates serially through the app's provider.

Weights must already have been explicitly installed. No downloads, tuning,
hidden retries, result replacement, or model substitution occur here.
"""
import argparse, hashlib, json, os, pathlib, subprocess
root = pathlib.Path(__file__).resolve().parent.parent
os.chdir(root)
parser = argparse.ArgumentParser()
parser.add_argument("--output-directory", type=pathlib.Path, default=root/"docs/qwen-local")
parser.add_argument("--skip-4b", action="store_true", help="Explicitly skip the Mac reference; preserve any partial evidence")
options = parser.parse_args()
out = options.output_directory.resolve()
out.mkdir(parents=True, exist_ok=True)
fixtures = root / "docs/qwen-local"
binary = root / ".qwen-local/host-final/qwen-benchmark"
files = ["Native/Qwen/LeuQwenNative.cpp", "Native/Qwen/include/LeuQwenNative.h",
    "Packages/LeuReasoningCore/Sources/LeuReasoningCore/LocalExplanationAssessment.swift",
    "Packages/LeuQwenRuntime/Sources/LeuQwenRuntime/EmbeddedQwen.swift",
    "Packages/LeuQwenRuntime/Sources/LeuQwenRuntime/LocalQwenProvider.swift",
    "scripts/qwen-benchmark.swift", "docs/qwen-local/dev-cases.json", "docs/qwen-local/challenge-cases.json"]
hashes = {f:hashlib.sha256((root/f).read_bytes()).hexdigest() for f in files}
freeze = dict(contract="qwen-teach-v3", hashes=hashes,
    binary_sha256=hashlib.sha256(binary.read_bytes()).hexdigest(), context=2048,
    output_tokens=512, sampler="grammar then greedy", seed="not used by greedy sampling",
    thinking=False, backend="Mac CPU, no offload", threads=4, batch=128,
    retains_model_between_requests=False, primary_verification_pass=False,
    independent_human_benchmark=False, challenge_tuned=False)
freeze_file = out / "final-settings.json"
if freeze_file.exists(): assert json.loads(freeze_file.read_text()) == freeze, "Settings changed after freeze"
else: freeze_file.write_text(json.dumps(freeze,indent=2)+"\n")
jobs=[]
for size in ["2B","0.8B","4B"]:
    for split in ["dev","challenge"]:
        jobs.append((size,split,2048,False))
for context,verify in [(4096,False),(2048,True)]:
    jobs.append(("2B","context-probe",context,verify))
for size,split,context,verify in jobs:
    if size == "4B" and options.skip_4b:
        print("SKIP 4B", split, "by explicit --skip-4b; existing evidence preserved", flush=True)
        continue
    for f,checksum in hashes.items(): assert hashlib.sha256((root/f).read_bytes()).hexdigest()==checksum, "Frozen source changed"
    cases=fixtures/f"{split}-cases.json"
    results=out/f"final-{split}-{size.lower()}-{context}{'-verify' if verify else ''}.jsonl"
    expected={c["id"] for c in json.loads(cases.read_text())}
    if results.exists():
        rows=[json.loads(line) for line in results.read_text().splitlines()]
        assert {r["id"] for r in rows}==expected and len(rows)==len(expected), "Partial run: preserve it and investigate before resuming"
        continue
    model=root/f".qwen-local/Qwen3.5-{size}-Q4_K_M.gguf"
    assert model.exists(), "Model not installed; no automatic download"
    artifact = next(x for x in json.loads((fixtures/"MODEL_MANIFEST.json").read_text())["candidates"] if x["upstream"].endswith("-"+size))
    assert model.stat().st_size == artifact["bytes"]
    assert hashlib.file_digest(model.open("rb"), "sha256").hexdigest() == artifact["sha256"], "Model checksum mismatch"
    command=[str(binary),str(cases),str(model),str(context),str(results)]
    if verify: command.append("verify")
    print("START",results.name,flush=True)
    subprocess.run(command,env=dict(os.environ,TMPDIR=str(root/".qwen-local/tmp")),check=True)
    subprocess.run(["python3","scripts/qwen-score.py",str(cases),str(results),str(results.with_suffix(".metrics.json"))],check=True)
    print("DONE",results.name,flush=True)
