"""Repeated-run summary for one configuration on the open sets (P and C).

Usage: python3 spikes/v37/score/repeat.py LABEL [LABEL ...]   e.g. P-mac-dev11-r1 P-mac-dev11-r2 P-mac-dev11-r3
For each run: D's gate metrics. Then the worst run, the mean, and run-to-run consistency as PREREGISTRATION
§4 defines it (share of cases whose signature is identical across all the runs given)."""
import json, math, os, sys

ROOT = os.path.join(os.path.dirname(__file__), "..")
labels = sys.argv[1:]
config = os.environ.get("CONFIG", "D")


def load(label):
    with open(os.path.join(ROOT, "scores", f"{label}.score.json")) as f:
        return json.load(f)


def quantile(values, q):
    v = sorted(values)
    return v[math.ceil(q * len(v)) - 1] if v else None


rows, runs = [], [load(l) for l in labels]
names = ["coarse", "paraphrase", "novelVocab", "wrRecall", "wrPrecision", "masteryRecall", "misconceptionRecorded",
         "commitAccuracy", "followUp", "falseMastery", "harmful", "schemaErrors", "refusals", "timeouts"]
table = {n: [] for n in names}
for label, s in zip(labels, runs):
    r = s["reports"][config]; cat = r.get("perCategory", {}); rs = s["reasoning"][config]; f = s["failures"]
    vals = {
        "coarse": (r["coarseRight"], r["cases"]), "paraphrase": (cat["paraphrase"]["right"], cat["paraphrase"]["n"]),
        "novelVocab": (cat["novelVocabulary"]["right"], cat["novelVocabulary"]["n"]),
        "wrRecall": (rs["detected"], rs["gold"]), "wrPrecision": (rs["detected"], rs["predicted"]),
        "masteryRecall": (r["masteryCredited"], r["goldPositive"]), "misconceptionRecorded": (r["misconceptionRecorded"], r["goldMisconception"]),
        "commitAccuracy": (r["committedRight"], r["committed"]), "followUp": (r["probes"], r["cases"]),
        "falseMastery": (r["falseMastery"], r["goldNotPositive"]), "harmful": (r["harmfulWrites"], r["cases"]),
        "schemaErrors": (f.get("schemaError", 0), f["cases"]), "refusals": (f.get("refused", 0), f["cases"]),
        "timeouts": (f.get("timeout", 0), f["cases"]),
    }
    for n in names:
        table[n].append(vals[n])
print(f"| {config} | " + " | ".join(labels) + " | mean |")
print("|---|" + "---|" * (len(labels) + 1))
for n in names:
    cells = [f"{a}/{b} ({100 * a / b:.1f}%)" if b else f"{a}/0" for a, b in table[n]]
    mean = sum(100 * a / b for a, b in table[n] if b) / max(1, sum(1 for _, b in table[n] if b))
    print(f"| {n} | " + " | ".join(cells) + f" | {mean:.1f}% |")

sigs = {}
for s in runs:
    for case, entry in s["perCase"][config].items():
        sigs.setdefault(case, []).append(entry["signature"])
same = sum(1 for v in sigs.values() if len(v) == len(runs) and len(set(v)) == 1)
coarse_same = 0
for case in sigs:
    rights = [s["perCase"][config][case]["coarseRight"] for s in runs]
    states = [s["perCase"][config][case]["signature"].split("|")[0] for s in runs]
    coarse_same += len({("misconception" if x == "misconception" else "positive" if x in ("understood", "mostlyUnderstood") else "weak") for x in states}) == 1
print(f"\nrun-to-run consistency (identical signature across {len(runs)} runs): {same}/{len(sigs)} ({100 * same / len(sigs):.1f}%)")
print(f"coarse-class consistency across runs: {coarse_same}/{len(sigs)} ({100 * coarse_same / len(sigs):.1f}%)")

warm, cold = [], []
for label in labels:
    with open(os.path.join(ROOT, "readings", f"{label}.jsonl")) as f:
        for line in f:
            rec = json.loads(line)
            if rec["reading"]["status"] == "empty":
                continue
            (cold if rec["cold"] else warm).append(rec["totalLatencyMs"])
print(f"latency (ms): warm p50 {quantile(warm, .5)} p95 {quantile(warm, .95)} max {max(warm)} (n={len(warm)}); cold {sorted(cold)}")
