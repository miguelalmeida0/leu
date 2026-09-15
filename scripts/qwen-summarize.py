#!/usr/bin/env python3
"""Summarize preserved final outputs; no model calls or semantic relabeling."""
import csv
import hashlib
import json
import math
import runpy
from collections import Counter
from pathlib import Path

root = Path(__file__).resolve().parent.parent
folder = root / "docs/qwen-local"

def percentile(values, q):
    values = sorted(values)
    return values[max(0, math.ceil(len(values) * q) - 1)] if values else None

def coverage(rows, annotations, ids):
    reviewed = {r["case"]: r for r in annotations}
    by_id = {r["id"]: r for r in rows}
    result = {}
    for pipeline in ("raw", "guarded"):
        counts = Counter()
        for case in ids:
            row = by_id.get(case)
            if not row:
                counts["not_run"] += 1
            elif pipeline not in row:
                counts["abstention"] += 1
            elif case not in reviewed:
                counts["unreviewed"] += 1
            else:
                counts[reviewed[case]["grade"]] += 1
        result[pipeline] = {"denominator": len(ids), **dict(counts)}
    return result

summary = {"quality": {}, "performance": {}, "coverage": {}, "evidence": {}}
challenge_ids = [c["id"] for c in json.loads((folder / "challenge-cases.json").read_text())]
for size in ("2b", "0.8b", "4b"):
    all_rows = []
    for split in ("dev", "challenge"):
        name = f"final-{split}-{size}-2048"
        output = folder / (name + ".jsonl")
        metrics = folder / (name + ".metrics.json")
        if not output.exists():
            continue
        rows = [json.loads(line) for line in output.read_text().splitlines()]
        all_rows += rows
        summary["evidence"][output.name] = {"rows": len(rows), "sha256": hashlib.sha256(output.read_bytes()).hexdigest()}
        if metrics.exists():
            m = json.loads(metrics.read_text())
            summary["quality"][name] = {k: v["totals"] for k, v in m.items() if "totals" in v}
            summary["quality"][name]["execution"] = m["execution"]
    if all_rows:
        runs = [run for row in all_rows for run in row.get("runs", [])]
        perf = {"cases": len(all_rows), "requests": sum(r["request_count"] for r in all_rows),
                "retries": sum(r["retry_count"] for r in all_rows),
                "thermal_before": dict(Counter(r["thermal_before"] for r in all_rows)),
                "thermal_after": dict(Counter(r["thermal_after"] for r in all_rows)),
                "maximum_observed_process_bytes": max((r["peak_observed_footprint"] for r in runs), default=None)}
        for key in ("load_ms", "prompt_ms", "first_token_ms", "total_ms", "prompt_tokens", "output_tokens"):
            values = [r[key] for r in runs]
            perf[key] = {"min": min(values) if values else None, "p50": percentile(values, .5), "p95": percentile(values, .95), "max": max(values) if values else None}
        perf["wall_ms"] = {"p50": percentile([r["wall_ms"] for r in all_rows], .5), "p95": percentile([r["wall_ms"] for r in all_rows], .95), "max": max(r["wall_ms"] for r in all_rows)}
        summary["performance"][size] = perf
        annotation_file = folder / f"coverage-review-{size}.tsv"
        if annotation_file.exists():
            with annotation_file.open() as stream:
                annotations = list(csv.DictReader(stream, delimiter="\t"))
            summary["coverage"][size + "_shared_20_challenge"] = coverage(all_rows, annotations, challenge_ids[:20])
            if annotations:
                ids = [c["id"] for split in ("dev", "challenge") for c in json.loads((folder / f"{split}-cases.json").read_text())]
                summary["coverage"][size + "_100_case_accounting"] = coverage(all_rows, annotations, ids)

for name in ("final-context-probe-2b-4096", "final-context-probe-2b-2048-verify"):
    metric_file = folder / (name + ".metrics.json")
    if metric_file.exists():
        m = json.loads(metric_file.read_text())
        summary["quality"][name] = {k: v["totals"] for k, v in m.items() if "totals" in v}
        summary["quality"][name]["execution"] = m["execution"]

if all((folder / name).exists() for name in ("final-dev-2b-2048.jsonl", "final-context-probe-2b-4096.jsonl", "final-context-probe-2b-2048-verify.jsonl")):
    probe_cases = json.loads((folder / "context-probe-cases.json").read_text())
    ids = {c["id"] for c in probe_cases}
    baseline_rows = [r for r in map(json.loads, (folder / "final-dev-2b-2048.jsonl").read_text().splitlines()) if r["id"] in ids]
    probe_rows = {"2048_primary_subset_not_new_calls": baseline_rows,
        "4096": [json.loads(line) for line in (folder / "final-context-probe-2b-4096.jsonl").read_text().splitlines()],
        "2048_verification": [json.loads(line) for line in (folder / "final-context-probe-2b-2048-verify.jsonl").read_text().splitlines()]}
    scoring = runpy.run_path(str(root / "scripts/qwen-score.py"))["score"]
    probe = {"cases": [c["id"] for c in probe_cases], "settings": {}}
    for setting, rows in probe_rows.items():
        metrics = scoring(probe_cases, rows)
        wall = [r["wall_ms"] for r in rows]
        probe["settings"][setting] = {"quality": {k: metrics[k]["totals"] for k in ("raw", "guarded")},
            "requests": sum(r["request_count"] for r in rows), "wall_ms_total": sum(wall),
            "wall_ms_p50_nearest_rank": percentile(wall, .5), "wall_ms_p95_nearest_rank": percentile(wall, .95),
            "maximum_observed_process_bytes": max((run["peak_observed_footprint"] for r in rows for run in r.get("runs", [])), default=None)}
    probe["limits"] = ["Baseline is a selected subset of existing primary calls, not eight additional requests.",
        "4096 contains the 570923 ms degraded-host outlier; it remains in timings and cannot establish a context-size causal effect.",
        "Verification is the same model and was evaluated only on eight development cases, not the frozen challenge."]
    summary["context_and_verification"] = probe

summary["limits"] = [
    "Metrics remain case-level, assistant-authored labels; see per-category original files.",
    "Coverage is a separate post-run qualitative review; ambiguous and unreviewed remain in denominators.",
    "Mac CPU host process, not full Leu or iPhone. Model/context are recreated each request; no retained-warm measurement.",
    "Footprint is sampled, not a guaranteed transient peak. Thermal state 0 means nominal at the recorded endpoints.",
    "Host compilation and evidence review occurred during the serial model comparison; this is not an isolated performance lab."
]
if (folder / "4b-interruption.json").exists():
    summary["interruption"] = json.loads((folder / "4b-interruption.json").read_text())
    four_rows = [json.loads(line) for split in ("dev", "challenge")
        if (folder / f"final-{split}-4b-2048.jsonl").exists()
        for line in (folder / f"final-{split}-4b-2048.jsonl").read_text().splitlines()]
    summary["limits"].append(f"4B currently records {sum('raw' in r for r in four_rows)} completed native responses, {sum(r['status'] == 'interrupted' for r in four_rows)} interrupted attempts and {100-len(four_rows)} unstarted cases. Its original interrupted wall interval is a gap between case flush and confirmed stop, not a completed native latency.")
(folder / "final-summary.json").write_text(json.dumps(summary, indent=2) + "\n")
lines = ["# Frozen comparison tables", "", "Generated from preserved JSONL and per-run metrics by `scripts/qwen-summarize.py`.",
    "Case denominators include rejected and missing outputs. Request accounting identifies partial and resumed runs.",
    "", "## Claim support", "", "| Model | Set | Pipeline | Supported recognition | False approvals | False accusations | Unjustified contradictions | Abstention cases |",
    "|---|---|---|---:|---:|---:|---:|---:|"]
for size in ("0.8b", "2b", "4b"):
    for split in ("dev", "challenge"):
        name = f"final-{split}-{size}-2048"
        if name not in summary["quality"]:
            continue
        m = summary["quality"][name]
        for pipe in ("baseline", "raw", "guarded"):
            t = m[pipe]
            lines.append(f"| {size} | {split} | {pipe} | {t['correct_supported_recognition']}/{t['supported_cases']} | {t['false_approval_cases']}/{t['negative_or_mixed_cases']} | {t['false_accusation_of_supported_cases']}/{t['supported_cases']} | {t['unjustified_contradiction_cases']}/{t['cases']} | {t['abstention_cases']}/{t['cases']} |")
lines += ["", "False approvals use negative/mixed-case denominators. A mixed case can count as both false approval and abstention.",
    "False accusations are unsupported, contradicted or overgeneralized labels on clearly supported fixtures; prose mistakes are separate from this structured-label metric.",
    "Unjustified contradictions count a contradicted label where the source-based expected verdict does not permit contradiction, including source-silent assertions; the denominator is all cases.",
    "Full per-category denominators and failure IDs remain in each `final-*.metrics.json`.",
    "", "## Frozen challenge: wording categories", "", "| Model | Pipeline | Informal paraphrases | Concise supported subsets |", "|---|---|---:|---:|"]
for size in ("0.8b", "2b", "4b"):
    path = folder / f"final-challenge-{size}-2048.metrics.json"
    if path.exists():
        m = json.loads(path.read_text())
        for pipe in ("baseline", "raw", "guarded"):
            cols = [m[pipe]["categories"][c] for c in ("informal_paraphrase", "concise_partial")]
            lines.append(f"| {size} | {pipe} | " + " | ".join(f"{c['correct_supported_recognition']}/{c['supported_cases']}" for c in cols) + " |")
lines += ["", "## Coverage review", "", "| Review | Pipeline | Correct/useful | Incorrect | Ambiguous | Abstention | Unreviewed | Not run | Denominator |",
    "|---|---|---:|---:|---:|---:|---:|---:|---:|"]
for name, pipelines in summary["coverage"].items():
    for pipe, c in pipelines.items():
        lines.append(f"| {name} | {pipe} | " + " | ".join(str(c.get(k, 0)) for k in ("useful", "incorrect", "ambiguous", "abstention", "unreviewed", "not_run", "denominator")) + " |")
lines += ["", "Post-run assistant review, not independent human validation. See `COVERAGE_REVIEW.md` and individual TSV rationales.",
    "", "## Mac CPU performance", "", "Times are seconds, p50 / p95, across primary dev+challenge requests. Counts disclose partial runs.",
    "Models reload each request; OS file caches may be warm. No retained-warm-model, full Leu, Metal or iPhone performance is established.",
    "", "| Model | Recorded attempts | Load | Prompt | First token from start | Wall interval | Maximum observed process GiB |", "|---|---:|---:|---:|---:|---:|---:|"]
for size, p in summary["performance"].items():
    durations = [f"{p[k]['p50']/1000:.2f} / {p[k]['p95']/1000:.2f}" for k in ("load_ms", "prompt_ms", "first_token_ms", "wall_ms")]
    lines.append(f"| {size} | {p['cases']} | " + " | ".join(durations) + f" | {p['maximum_observed_process_bytes']/2**30:.3f} |")
lines += ["", "Footprint is sampled at native boundaries; it is not a guaranteed transient peak. Token ranges, endpoint thermal counts and timings are in `final-summary.json`.",
    "The interrupted 4B attempt includes a roughly 10.8-minute gap without a completed result. Its wall interval is operator-recorded, not a completed provider latency; see `4b-interruption.json`. p95 does not summarize away that failure.",
    "4B pools its original process with a continuation that starts one process per previously unstarted case and uses a 120-second watchdog. Model, prompt and decoding remained frozen; the timing protocol changed. The interrupted case was not retried.",
    "", "## Request accounting", "", "| Run | Requests | Retries | Completed | Guard rejected | Verification rejected | Interrupted | Failed | Not run | Native output limit |", "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|"]
for name, m in summary["quality"].items():
    e = m["execution"]; s = e["statuses"]
    lines.append(f"| {name} | {e['requests']} | {e['retries']} | " + " | ".join(str(s.get(k, 0)) for k in ("completed", "guard_rejected", "verification_rejected", "interrupted", "failed", "not_run")) + f" | {e['output_limit']} |")
lines += ["", "Native output-limit count measures failure to finish a structured response, not completeness of every prose sentence. The known 0.8B instruction echo/mid-word detail is separately documented.", ""]
(folder / "COMPARISON.md").write_text("\n".join(lines))
print(json.dumps({"runs": list(summary["quality"]), "coverage": summary["coverage"]}, indent=2))
