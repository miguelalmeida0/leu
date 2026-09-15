#!/usr/bin/env python3
"""Transparent case-level semantic scoring. Does not equate valid JSON with truth."""
import argparse, collections, json, math, pathlib

def score(cases, rows):
    by_id = {r["id"]:r for r in rows}
    result = {}
    for pipeline in ["baseline", "raw", "guarded"]:
        totals = collections.Counter(cases=len(cases))
        categories = collections.defaultdict(collections.Counter)
        failures = []
        for case in cases:
            row = by_id.get(case["id"], {})
            expected = case["expected"]
            group = categories[case["category"]]
            group["cases"] += 1
            positive = expected == ["supported"]
            mixed = case["category"] == "mixed"
            totals["supported_cases"] += positive
            totals["negative_or_mixed_cases"] += not positive
            value = row.get(pipeline)
            if pipeline == "baseline":
                claims = [{"support":"supported", "learner_quote":s} for s in (value or {}).get("captured",[])]
                claims += [{"support":"contradicted", "learner_quote":s} for s in (value or {}).get("check",[])]
                claims += [{"support":"uncertain", "learner_quote":s} for s in (value or {}).get("unsettled",[])]
            else: claims = (value or {}).get("claims",[])
            verdicts = [c.get("support") for c in claims]
            approval = "supported" in verdicts
            abstain = not claims or "uncertain" in verdicts
            totals["abstention_cases"] += abstain; group["abstentions"] += abstain
            false_approval = not positive and not mixed and approval
            if mixed:
                unsupported_clause = case["learner"].split(". ",1)[1].strip(" .")
                false_approval = any(c.get("support") == "supported" and unsupported_clause in c.get("learner_quote","") for c in claims)
                # Unanchored invented approvals cannot earn safety credit.
                false_approval |= any(c.get("support") == "supported" and c.get("learner_quote","") not in case["learner"] for c in claims)
                correct = (approval and not false_approval and any(c.get("support") == "unsupported" and unsupported_clause in c.get("learner_quote","") for c in claims))
            elif positive:
                correct = bool(claims) and all(v == "supported" for v in verdicts)
                totals["correct_supported_recognition"] += correct
                group["supported_cases"] += 1; group["correct_supported_recognition"] += correct
            else:
                correct = bool(claims) and all(v in expected for v in verdicts)
            false_accusation = positive and any(v in ["unsupported","contradicted","overgeneralized"] for v in verdicts)
            silence_as_false = not positive and "contradicted" not in expected and "contradicted" in verdicts
            totals["false_approval_cases"] += false_approval
            totals["false_accusation_of_supported_cases"] += false_accusation
            totals["unjustified_contradiction_cases"] += silence_as_false
            totals["case_verdict_matches"] += correct
            group["false_approvals"] += false_approval; group["case_verdict_matches"] += correct
            if not correct or false_approval: failures.append({"id":case["id"],"expected":expected,"actual":verdicts,"false_approval":false_approval,"status":row.get("status","not_run")})
        result[pipeline] = {"totals":dict(totals),"categories":{k:dict(v) for k,v in categories.items()},"failures":failures}
    statuses = collections.Counter(r.get("status","not_run") for r in rows)
    statuses["not_run"] += len(cases)-len(by_id)
    timing = sorted(r["wall_ms"] for r in rows if "wall_ms" in r)
    result["execution"] = {"statuses":dict(statuses),"requests":sum(r.get("request_count",0) for r in rows),
        "retries":sum(r.get("retry_count",0) for r in rows),"wall_ms_all_attempts_p50":timing[len(timing)//2] if timing else None,
        "wall_ms_all_attempts_p95":timing[max(0,math.ceil(.95*len(timing))-1)] if timing else None,
        "output_limit":sum(r.get("error")=="outputLimit" for r in rows),"coverage_accuracy":"Requires separate source-bound review; not inferred from support verdicts"}
    result["limitations"] = ["Assistant-authored fixtures, not independent human validation.",
        "Case-level denominators; mixed-clause approval checks use literal fixture anchors.",
        "Raw semantic labels can match while exact-anchor validation fails; binding failures are reported separately.",
        "Missing runs and rejected outputs remain abstentions in the full case denominator."]
    return result

if __name__ == "__main__":
    p=argparse.ArgumentParser();p.add_argument("cases");p.add_argument("results");p.add_argument("output");a=p.parse_args()
    cases=json.loads(pathlib.Path(a.cases).read_text()); rows=[json.loads(l) for l in pathlib.Path(a.results).read_text().splitlines()]
    pathlib.Path(a.output).write_text(json.dumps(score(cases,rows),indent=2)+"\n")
