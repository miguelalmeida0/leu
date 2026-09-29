"""V37 NH holdout (throwaway): double-label agreement (HOLDOUT_PLAN "Double labelling"). Aggregates only:
raw agreement and Cohen's kappa for the coarse state and for reasoningIssue, and the aggregate confusion
counts. Never prints a case id, text or label of any single case.

usage: python3 nh_agreement.py <nh.json> <labels2.json> <double-label-map.json>
"""
import collections
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from nh_rules import coarse  # noqa: E402


def kappa(pairs):
    n = len(pairs)
    observed = sum(a == b for a, b in pairs) / n
    first, second = collections.Counter(a for a, _ in pairs), collections.Counter(b for _, b in pairs)
    expected = sum(first[k] * second[k] for k in set(first) | set(second)) / (n * n)
    return observed, (observed - expected) / (1 - expected) if expected < 1 else 1.0


def main(nh_path, labels_path, map_path):
    cases = {c["id"]: c for c in json.load(open(nh_path))["cases"]}
    labels = {l["id"]: l for l in json.load(open(labels_path))["labels"]}
    mapping = json.load(open(map_path))
    coarse_pairs = [(coarse(cases[cid]), coarse(labels[dl])) for dl, cid in mapping.items()]
    reason_pairs = [(bool(cases[cid]["reasoningIssue"]), bool(labels[dl]["reasoningIssue"])) for dl, cid in mapping.items()]
    per_author = collections.Counter(cid.split("-")[0] for cid in mapping.values())
    raw_c, k_c = kappa(coarse_pairs)
    raw_r, k_r = kappa(reason_pairs)
    print(f"doubleLabelled={len(mapping)} perAuthor " + " ".join(f"{a}={n}" for a, n in sorted(per_author.items())))
    print(f"coarse raw={100 * raw_c:.1f}% kappa={k_c:.3f}")
    print(f"reasoningIssue raw={100 * raw_r:.1f}% kappa={k_r:.3f}")
    print("coarse confusion (first→second) " + " ".join(f"{a}->{b}={n}" for (a, b), n in sorted(collections.Counter(coarse_pairs).items())))
    print("reasoningIssue confusion " + " ".join(f"{a}->{b}={n}" for (a, b), n in sorted(collections.Counter(reason_pairs).items())))
    return 0 if raw_c >= 0.8 and raw_r >= 0.8 else 1


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:4]))
