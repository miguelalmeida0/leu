"""The metrics block of one development iteration (open sets P and C only), as Markdown.

Usage: python3 spikes/v37/score/devlog.py NN [SCHEMA_SHA]
Reads scores/P-mac-devNN.score.json, readings/P-mac-devNN.jsonl and the three canonical runs
C-mac-devNN-r{1,2,3}. Prints aggregates only (the sets are open, but the habit is kept)."""
import hashlib, json, math, os, sys

ROOT = os.path.join(os.path.dirname(__file__), "..")
NN = sys.argv[1]


def load(path):
    with open(os.path.join(ROOT, path)) as f:
        return json.load(f)


def lines(path):
    with open(os.path.join(ROOT, path)) as f:
        return [json.loads(l) for l in f if l.strip()]


def pct(a, b):
    return f"{a}/{b} ({100 * a / b:.1f}%)" if b else f"{a}/0"


def quantile(values, q):
    if not values:
        return None
    v = sorted(values)
    return v[math.ceil(q * len(v)) - 1]


def schema_sha():
    if len(sys.argv) > 2:
        return sys.argv[2]
    h = hashlib.sha256()
    for name in ("Schema.swift", "Selection.swift"):
        with open(os.path.join(ROOT, "runner/Sources/SpikeKit", name), "rb") as f:
            h.update(f.read()); h.update(b"\0")
    return h.hexdigest()


p = load(f"scores/P-mac-dev{NN}.score.json")
records = lines(f"readings/P-mac-dev{NN}.jsonl")
runs = [f"C-mac-dev{NN}-r{k}" for k in (1, 2, 3)]
out = [f"## Metrics (dev{NN})", "",
       f"* Prompt-set SHA-256: `{records[0]['promptSHA']}`",
       f"* Schema SHA-256 (Schema.swift + Selection.swift at logging time): `{schema_sha()}`", "",
       "| P (80 open cases) | B | C | D |", "|---|---|---|---|"]
rows = {}
for config in ("B", "C", "D"):
    r = p["reports"][config]; cat = r.get("perCategory", {}); rs = p["reasoning"][config]
    rows.setdefault("Coarse", []).append(pct(r["coarseRight"], r["cases"]))
    rows.setdefault("Exact state", []).append(pct(r["exact"], r["cases"]))
    rows.setdefault("Paraphrase", []).append(pct(cat.get("paraphrase", {}).get("right", 0), cat.get("paraphrase", {}).get("n", 0)))
    rows.setdefault("Novel vocabulary", []).append(pct(cat.get("novelVocabulary", {}).get("right", 0), cat.get("novelVocabulary", {}).get("n", 0)))
    rows.setdefault("Weak-reasoning recall", []).append(pct(rs["detected"], rs["gold"]))
    rows.setdefault("Weak-reasoning precision", []).append(pct(rs["detected"], rs["predicted"]))
    rows.setdefault("Mastery recall", []).append(pct(r["masteryCredited"], r["goldPositive"]))
    rows.setdefault("Misconception detection (recorded)", []).append(pct(r["misconceptionRecorded"], r["goldMisconception"]))
    rows.setdefault("Misconception detection (recorded or probed)", []).append(
        pct(r["misconceptionRecorded"] + r["misconceptionProbed"], r["goldMisconception"]))
    rows.setdefault("False mastery", []).append(pct(r["falseMastery"], r["goldNotPositive"]))
    rows.setdefault("Harmful writes", []).append(pct(r["harmfulWrites"], r["cases"]))
    rows.setdefault("Commit accuracy", []).append(pct(r["committedRight"], r["committed"]))
    rows.setdefault("Follow-up rate", []).append(pct(r["probes"], r["cases"]))
for name, values in rows.items():
    out.append(f"| {name} | " + " | ".join(values) + " |")
f = p["failures"]
out += ["", f"* Failures on P: schema errors {f.get('schemaError', 0)}, refusals {f.get('refused', 0)}, "
        f"timeouts {f.get('timeout', 0)}, other {f.get('other', 0)} (of {f['cases']})"]

# Latency: the P run and the three canonical runs, each a fresh process (its first call is cold).
warm, cold, parts = [], [], {"reading": [], "check": []}
for label in [f"P-mac-dev{NN}"] + runs:
    try:
        recs = lines(f"readings/{label}.jsonl")
    except FileNotFoundError:
        continue
    for rec in recs:
        if rec["reading"]["status"] == "empty":
            continue
        (cold if rec["cold"] else warm).append(rec["totalLatencyMs"])
        if not rec["cold"]:
            parts["reading"].append(rec["reading"]["latencyMs"])
            if rec.get("secondOpinion"):
                parts["check"].append(rec["secondOpinion"]["latencyMs"])
out += [f"* Latency, submit → all results (ms): warm p50 {quantile(warm, .5)}, warm p95 {quantile(warm, .95)}, "
        f"warm max {max(warm) if warm else None} (n={len(warm)}); cold {sorted(cold)} (one per process)",
        f"* Warm parts (ms): reading p50 {quantile(parts['reading'], .5)} p95 {quantile(parts['reading'], .95)}; "
        f"check+locator p50 {quantile(parts['check'], .5)} p95 {quantile(parts['check'], .95)} (in parallel with the reading)"]

# Canonical: every configuration per run, and run-to-run consistency of D's decisions.
out += ["", "| Canonical | run 1 | run 2 | run 3 |", "|---|---|---|---|"]
signatures = {}
for config in ("B", "C", "D"):
    cells = []
    for label in runs:
        try:
            s = load(f"scores/{label}.score.json")
        except FileNotFoundError:
            cells.append("—"); continue
        c = s["canonical"][config]
        failed = {k: v for k, v in c["failures"].items() if v}
        cells.append(f"{c['passed']}/{c['cases']}" + (" (" + "; ".join(f"{k}: {','.join(v)}" for k, v in sorted(failed.items())) + ")" if failed else ""))
        if config == "D":
            for case, entry in s["perCase"]["D"].items():
                signatures.setdefault(case, []).append(entry["signature"])
    out.append(f"| {config} | " + " | ".join(cells) + " |")
stable = sum(1 for v in signatures.values() if len(set(v)) == 1)
out += ["", f"* Run-to-run consistency (D, canonical, 3 runs): {stable}/{len(signatures)} cases with identical decisions"]
fired = p.get("checksFired", {}).get("D", {})
out += [f"* Checks fired on P (D): " + ", ".join(f"{k} {v}" for k, v in sorted(fired.items()))]
print("\n".join(out))
