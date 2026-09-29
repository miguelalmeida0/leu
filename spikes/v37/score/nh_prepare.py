"""V37 NH holdout (throwaway): merges the six author files into the NH fixture and draws the double-label
sample (10 per author, seed 3738). Writes, in the work folder only: nh.json, dl-input.json (neutral ids
DL-01…DL-60, shuffled; text and target only, no label, no author) and double-label-map.json. Prints counts only.

usage: python3 nh_prepare.py <kits-dir> <work-dir>
"""
import json
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from nh_rules import AUTHORS  # noqa: E402

SEED = 3738


def main(kits, work):
    rng = random.Random(SEED)
    cases = []
    for author in AUTHORS:
        cases += json.load(open(os.path.join(kits, author, "out", "cases.json")))["cases"]
    json.dump({"split": "v37-nh", "cases": cases}, open(os.path.join(work, "nh.json"), "w"), indent=1)
    sample = []
    for author in AUTHORS:
        ids = sorted(c["id"] for c in cases if c["id"].startswith(author + "-"))
        sample += rng.sample(ids, 10)
    rng.shuffle(sample)
    by_id = {c["id"]: c for c in cases}
    mapping, inputs = {}, []
    for i, cid in enumerate(sample):
        dl = f"DL-{i + 1:02d}"
        mapping[dl] = cid
        c = by_id[cid]
        inputs.append({"id": dl, "document": c["document"], "concept": c.get("concept"), "page": c.get("page"), "text": c["text"]})
    json.dump({"cases": inputs}, open(os.path.join(work, "dl-input.json"), "w"), indent=1)
    json.dump(mapping, open(os.path.join(work, "double-label-map.json"), "w"), indent=1, sort_keys=True)
    print(f"merged cases={len(cases)} doubleLabel={len(mapping)} perAuthor=10x{len(AUTHORS)}")


if __name__ == "__main__":
    main(*sys.argv[1:3])
