"""Writes spikes/v37/FREEZE.txt: the frozen V37 configuration (PREREGISTRATION §12 and the Mac session's
freeze list). Run from the repository root on the Mac, on a clean tree at the commit being frozen:

    python3 spikes/v37/score/freeze.py

Every component is hashed as file bytes (SHA-256); a group is the SHA-256 of its members' hashes, in order."""
import datetime, hashlib, os, subprocess

ROOT = subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip()
V = "spikes/v37/"
Z = "Packages/ShelfCore/Tests/ShelfCoreTests/ZZSpike/"
J = "Packages/ShelfCore/Sources/ShelfCore/Learning/Intelligence/"
K = V + "runner/Sources/"

COMPONENTS = [
    ("system prompt (reading)", [V + "prompts/reading.txt"]),
    ("model schema (guided generation, wire words, alias mapping, locator merge)", [K + "SpikeKit/Schema.swift", K + "SpikeKit/Selection.swift"]),
    ("claim construction (export: claims, aliases, neighbours, segments, marker links)", [Z + "ZZSpikeContract.swift", Z + "ZZSpikeSegmenter.swift"]),
    ("claim-family logic, composition and D's agreement rule", [Z + "ZZSpikeComposition.swift"]),
    ("deterministic checks (V1–V11)", [Z + "ZZSpikeChecks.swift"]),
    ("second-opinion prompts (whole-answer check, locator)",
     [V + "prompts/answer-check.txt", V + "prompts/locate.txt"]),
    ("answer-key prompts (compile; the pairwise prompt is kept but no longer called)", [V + "prompts/answer-key.txt", V + "prompts/second-opinion.txt"]),
    ("judgement adapter", [Z + "ZZSpikeAdapter.swift"]),
    ("learner-write policy (unchanged judge, reading, planner, evidence mapper)",
     [J + "Judgement/UnderstandingJudge.swift", J + "Judgement/UnderstandingJudgement.swift", J + "Judgement/JudgementReading.swift",
      J + "Judgement/JudgementReading+Semantic.swift"]),
    ("misconception-memory policy", [Z + "ZZSpikeMemory.swift"]),
    ("scorer", [Z + "ZZSpikeScore.swift", Z + "ZZSpikeCanonical.swift", Z + "ZZSpikeReasoning.swift", V + "score/stats.py"]),
    ("thresholds (preregistered gates; canonical criteria)", [V + "PREREGISTRATION.md", V + "cases/canonical.json"]),
    ("runner (engine, pipeline, request layout, generation settings, CLI)",
     [K + "SpikeFoundation/FoundationModelsEngine.swift", K + "SpikeKit/Runner.swift", K + "SpikeKit/Prompts.swift",
      K + "SpikeKit/Contract.swift", K + "SpikeKit/SHA256.swift", K + "SpikeKit/FakeModel.swift", K + "spike-runner/main.swift"]),
    ("development answer keys (P, C)", [V + "answer-keys/P.json", V + "answer-keys/C.json"]),
]


def sha(path):
    with open(os.path.join(ROOT, path), "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def find(needle):
    """The production files the write policy names that live elsewhere (planner, evidence mapper)."""
    out = subprocess.check_output(["git", "ls-files", "Packages/ShelfCore/Sources"], cwd=ROOT, text=True).split()
    return [p for p in out if os.path.basename(p) == needle]


def run(cmd):
    try:
        return subprocess.check_output(cmd, cwd=ROOT, text=True, stderr=subprocess.STDOUT).strip()
    except Exception as e:  # noqa: BLE001 — recorded as it is
        return f"unavailable ({e})"


for name in ("InterventionPlanner.swift", "LearnerEvidenceMapper.swift"):
    COMPONENTS[8][1].extend(find(name))

status = run(["git", "status", "--porcelain"])
lines = ["# V37 FREEZE (PREREGISTRATION §12; written before any gate run)", "",
         f"frozen code commit: {run(['git', 'rev-parse', 'HEAD'])}",
         f"branch: {run(['git', 'branch', '--show-current'])}",
         f"working tree clean: {'yes' if not status else 'NO'}",
         f"written: {datetime.datetime.now(datetime.timezone.utc).isoformat(timespec='seconds')}", "",
         "primary configuration: D (rows, then whole-answer check → locator; checks V1–V11; composition; unchanged judge)",
         "enabled checks: V1 V2 V3 V4 V5 V6 V7 V8(marker links) V9 V10 V11; P1 (premise), F1 (family), D-rules (credit, cap, wrong, reason, unplaced)",
         f"prompt-set SHA-256 (spike-runner hash): {run([V + 'runner/.build/release/spike-runner', 'hash', '--prompts', V + 'prompts'])}", ""]
for name, files in COMPONENTS:
    hashes = [sha(f) for f in files]
    group = hashlib.sha256("".join(hashes).encode()).hexdigest()
    lines.append(f"## {name}")
    lines.append(f"group-sha256: {group}")
    lines += [f"  {h}  {f}" for h, f in zip(hashes, files)]
    lines.append("")
lines += ["## generation settings (runner Settings)",
          "  greedy sampling; fresh session per call; no prewarming, caching or streaming; calls in sequence",
          "  reading: 450 tokens, 30 s; check and locator: 120 tokens each, 15 s; answer key: 700 tokens, 60 s",
          "  rateLimited: at most 2 retries after 2 s", "",
          "## machine",
          f"  {run(['sw_vers']).replace(chr(10), ' | ')}",
          f"  {run(['xcodebuild', '-version']).replace(chr(10), ' | ')}",
          f"  hw.model: {run(['sysctl', '-n', 'hw.model'])}",
          f"  Apple Intelligence: {run([V + 'runner/.build/release/spike-runner', 'availability'])}", "",
          "## gate fingerprints (ciphertexts untouched)"]
lines += ["  " + l for l in run(["shasum", "-a", "256"] + sorted(f"{V}gate/{f}" for f in os.listdir(os.path.join(ROOT, V, "gate")) if f.endswith(".enc"))).splitlines()]
lines += ["", "The replacement holdout (HOLDOUT_PLAN.md) is created only after this freeze, by the cloud session.",
          "Its answer keys are compiled after the freeze and their SHA-256 is appended then."]
with open(os.path.join(ROOT, V, "FREEZE.txt"), "w") as f:
    f.write("\n".join(lines) + "\n")
print("\n".join(lines[:12]))
