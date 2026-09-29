#!/usr/bin/env python3
"""V37 capability spike — statistics and the mechanical hard-gate checklist (THROWAWAY).

Reads the score files written by ShelfCore's `ZZSpikeScoreRun` (one per set and run). Prints
aggregates only: no case id or text is ever printed, so the same commands are safe on blind sets.

  stats.py summary SCORE.json [...]                     metrics with 95% Wilson intervals, per configuration
  stats.py compare SCORE.json --a A --b D                 paired D vs A: exact McNemar and a bootstrap interval
  stats.py authors SCORE.json --config D                 coarse accuracy per author (gate ids are "J-01")
  stats.py gate --primary D --mac PG1 PG2 PG3 --iphone PGI --cold COLD \\
                --canonical CM1 CM2 CM3 CI                PREREGISTRATION §5, G1–G16, applied mechanically
"""
import argparse
import json
import math
import random
import sys

THRESHOLDS = {"G1": 0.70, "G2": 0.65, "G3": 0.65, "G4": 0.45, "G5": 0.60, "G6": 0.85, "G7": 0.60,
              "G11": 0.02, "G12": 0.03, "G13": 0.01, "G14": 0.97, "G15": 0.95}
WARM_P95_MS, WARM_FLAG_MS = 12_000, 6_000
COLD_MAX_MS, COLD_FLAG_MS = 20_000, 12_000


def load(path):
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def ratio(a, b):
    return a / b if b else 0.0


def wilson(k, n, z=1.96):
    """95% Wilson score interval for k successes in n trials."""
    if n == 0:
        return (0.0, 0.0)
    p = k / n
    centre = p + z * z / (2 * n)
    spread = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n))
    return ((centre - spread) / (1 + z * z / n), (centre + spread) / (1 + z * z / n))


def mcnemar_exact(b, c):
    """Two-sided exact McNemar p-value: b and c are the discordant pairs."""
    n = b + c
    if n == 0:
        return 1.0
    tail = sum(math.comb(n, i) for i in range(min(b, c) + 1)) / 2 ** n
    return min(1.0, 2 * tail)


def bootstrap_difference(a, b, reps=10_000, seed=3737):
    """Paired bootstrap 95% interval for mean(b) - mean(a), over cases."""
    rng = random.Random(seed)
    n = len(a)
    if n == 0:
        return (0.0, 0.0)
    draws = []
    for _ in range(reps):
        idx = [rng.randrange(n) for _ in range(n)]
        draws.append(sum(b[i] - a[i] for i in idx) / n)
    draws.sort()
    return (draws[int(0.025 * reps)], draws[int(0.975 * reps) - 1])


def p95(values):
    """Nearest-rank 95th percentile."""
    if not values:
        return None
    ordered = sorted(values)
    return ordered[math.ceil(0.95 * len(ordered)) - 1]


def metrics(report, failures=None):
    """PREREGISTRATION §4, from one configuration's report (and the run's failure counts)."""
    cat = report.get("perCategory", {})
    cases = report["cases"]
    m = {
        "G1": (report["coarseRight"], cases),
        "G2": (cat.get("paraphrase", {}).get("right", 0), cat.get("paraphrase", {}).get("n", 0)),
        "G3": (cat.get("novelVocabulary", {}).get("right", 0), cat.get("novelVocabulary", {}).get("n", 0)),
        "G4": (report["weakReasoningDetected"], report["goldWeakReasoning"]),
        "G5": (report["weakReasoningDetected"], report["predictedWeakReasoning"]),
        "G6": (report["committedRight"], report["committed"]),
        "G7": (report["probes"], cases),
        "G8": (report["falseMastery"], report["goldNotPositive"]),
        "G9": (report["harmfulWrites"], cases),
    }
    if failures:
        m["G11"] = (failures.get("schemaError", 0), failures["cases"])
        m["G12"] = (failures.get("refused", 0), failures["cases"])
        m["G13"] = (failures.get("timeout", 0), failures["cases"])
    return m


def summary(paths):
    names = {"G1": "coarse", "G2": "paraphrase", "G3": "novel vocabulary", "G4": "weak-reasoning recall",
             "G5": "weak-reasoning precision", "G6": "commit accuracy", "G7": "follow-up rate", "G8": "false mastery",
             "G9": "harmful-write rate", "G11": "schema errors", "G12": "refusals", "G13": "timeouts"}
    for path in paths:
        score = load(path)
        print(f"== {score['label']} (set {score['set']}, {score['cases']} cases{', blind' if score.get('blind') else ''})")
        for config, report in sorted(score["reports"].items()):
            failures = score.get("failures") if config in ("B", "C", "D") else None
            parts = []
            for gate, (k, n) in metrics(report, failures).items():
                low, high = wilson(k, n)
                parts.append(f"{names[gate]} {k}/{n} {ratio(k, n):.1%} [{low:.0%}–{high:.0%}]")
            print(f"  {config}: " + "; ".join(parts))


def paired(score, config_a, config_b):
    a, b = score["perCase"][config_a], score["perCase"][config_b]
    ids = sorted(set(a) & set(b))
    return [int(a[i]["coarseRight"]) for i in ids], [int(b[i]["coarseRight"]) for i in ids]


def compare(path, config_a, config_b):
    score = load(path)
    a, b = paired(score, config_a, config_b)
    only_a = sum(1 for x, y in zip(a, b) if x and not y)
    only_b = sum(1 for x, y in zip(a, b) if y and not x)
    low, high = bootstrap_difference(a, b)
    print(f"{score['label']}: {config_b} {sum(b)}/{len(b)} vs {config_a} {sum(a)}/{len(a)}; difference "
          f"{ratio(sum(b) - sum(a), len(a)):+.1%} [{low:+.1%}, {high:+.1%}] (paired bootstrap); "
          f"discordant {config_a}-only {only_a}, {config_b}-only {only_b}; exact McNemar p={mcnemar_exact(only_a, only_b):.4f}")


def authors(path, config):
    score = load(path)
    groups = {}
    for case_id, entry in score["perCase"][config].items():
        author = case_id.split("-")[0]
        right, n = groups.get(author, (0, 0))
        groups[author] = (right + int(entry["coarseRight"]), n + 1)
    if score.get("blind") and min(n for _, n in groups.values()) < 5:
        raise SystemExit("refused: on a blind set every author group must hold at least 5 cases (ids look per-case)")
    print(f"{score['label']} {config} coarse by author: " + " ".join(f"{a}={r}/{n}" for a, (r, n) in sorted(groups.items())))


def consistency(scores, config):
    """Share of cases whose signature is identical in every given run."""
    per_run = [s["perCase"][config] for s in scores]
    ids = set(per_run[0])
    for run in per_run[1:]:
        ids &= set(run)
    same = sum(1 for i in ids if len({run[i]["signature"] for run in per_run}) == 1)
    return same, len(ids)


def latency_gates(iphone, cold):
    """G16-warm on the iPhone run (≤ 80 words, after the process's first model call); G16-cold on the cold launches."""
    warm = [row["totalMs"] for row in iphone.get("latency", []) if 0 <= row["words"] <= 80 and row["processCallIndex"] > 0]
    launches = [row["totalMs"] for row in cold.get("latency", []) if row["cold"] and row["processCallIndex"] == 0 and 0 <= row["words"] <= 80]
    warm_p95 = p95(warm)
    cold_max = max(launches) if launches else None
    warm_pass = warm_p95 is not None and warm_p95 <= WARM_P95_MS
    cold_pass = len(launches) == 20 and cold_max <= COLD_MAX_MS
    warm_note = "UX problem (6–12 s)" if warm_pass and warm_p95 > WARM_FLAG_MS else ""
    cold_note = "needs a prewarming strategy (12–20 s)" if cold_pass and cold_max > COLD_FLAG_MS else ""
    if len(launches) != 20:
        cold_note = f"expected 20 cold launches, found {len(launches)}"
    return (("G16-warm", warm_pass, f"p95 {warm_p95} ms over {len(warm)} answers", warm_note),
            ("G16-cold", cold_pass, f"slowest {cold_max} ms over {len(launches)} launches", cold_note))


def gate(args):
    runs = [load(p) for p in args.mac] + [load(args.iphone)]
    primary = args.primary
    baseline = metrics(runs[0]["reports"]["A"])
    rows = []
    for gate_id in ("G1", "G2", "G3", "G4", "G5", "G6", "G7", "G8", "G9", "G11", "G12", "G13"):
        results = []
        for run in runs:
            k, n = metrics(run["reports"][primary], run.get("failures"))[gate_id]
            value = ratio(k, n)
            if gate_id in ("G7", "G11", "G12", "G13"):
                ok = value <= THRESHOLDS[gate_id]
            elif gate_id == "G8":
                ok = value <= ratio(*baseline["G8"])
            elif gate_id == "G9":
                ok = value <= 0.6 * ratio(*baseline["G9"])
            else:
                ok = value >= THRESHOLDS[gate_id]
            results.append((ok, value, run["label"]))
        lower_is_better = gate_id in ("G7", "G8", "G9", "G11", "G12", "G13")
        worst = (max if lower_is_better else min)(results, key=lambda r: r[1])
        rows.append((gate_id, all(r[0] for r in results), f"worst {worst[1]:.1%} ({worst[2]})", ""))
    canonical = [load(p).get("canonical", {}).get(primary, {}) for p in args.canonical]
    rows.append(("G10", len(canonical) == 4 and all(c.get("passed") == 5 for c in canonical),
                 "canonical " + " ".join(f"{c.get('passed', 0)}/5" for c in canonical), ""))
    same, n = consistency(runs[:3], primary)
    rows.append(("G14", ratio(same, n) >= THRESHOLDS["G14"], f"{same}/{n} identical across Mac runs 1–3", ""))
    same, n = consistency([runs[0], runs[3]], primary)
    rows.append(("G15", ratio(same, n) >= THRESHOLDS["G15"], f"{same}/{n} identical, Mac run 1 vs iPhone", ""))
    rows.extend(latency_gates(runs[3], load(args.cold)))
    for gate_id, ok, detail, note in sorted(rows, key=lambda r: (int(r[0][1:].split("-")[0]), r[0])):
        print(f"{gate_id:9} {'PASS' if ok else 'FAIL'}  {detail}{'  — ' + note if note else ''}")
    verdict = all(r[1] for r in rows)
    print(f"GATE {'PASS' if verdict else 'FAIL'} (primary {primary}; any miss fails)")
    return verdict


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("summary").add_argument("scores", nargs="+")
    c = sub.add_parser("compare")
    c.add_argument("score"); c.add_argument("--a", default="A"); c.add_argument("--b", default="D")
    a = sub.add_parser("authors")
    a.add_argument("score"); a.add_argument("--config", default="D")
    g = sub.add_parser("gate")
    g.add_argument("--primary", default="D"); g.add_argument("--mac", nargs=3, required=True)
    g.add_argument("--iphone", required=True); g.add_argument("--cold", required=True)
    g.add_argument("--canonical", nargs=4, required=True)
    args = parser.parse_args(argv)
    if args.command == "summary":
        summary(args.scores)
    elif args.command == "compare":
        compare(args.score, args.a, args.b)
    elif args.command == "authors":
        authors(args.score, args.config)
    else:
        return 0 if gate(args) else 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
