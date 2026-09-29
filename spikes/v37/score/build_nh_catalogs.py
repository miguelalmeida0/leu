"""V37 NH holdout (throwaway): the seeded target partition for authors Q–V (HOLDOUT_PLAN, seed 3738).

Reads only the knowledge-base catalogue, the development fixture's targets (P) and the target lists of
earlier spike catalogues. Never reads any sealed fixture or any case text. Prints target counts only.

* Theme concepts (JWT, Authentication, Authorization, Closure; JavaScript Deep Dive's closure and page 2)
  go to every author, as in the primary gate.
* Each author gets two Mobile Mastery cards never used by any earlier spike set (P, PG, X, Y), and three
  small-document pages from three different documents, disjoint from P (the retired gate's pages are
  eligible: only one fresh page is left otherwise).

usage: python3 build_nh_catalogs.py <spike-dir>
"""
import collections
import json
import os
import random
import sys

SEED = 3738
AUTHORS = ["Q", "R", "S", "T", "U", "V"]
THEME = [("Mobile Mastery", "JWT"), ("Mobile Mastery", "Authentication"), ("Mobile Mastery", "Authorization"),
         ("Mobile Mastery", "Closure"), ("JavaScript Deep Dive", "closure"), ("JavaScript Deep Dive", 2)]
META_PAGES = {("React Notes", 3)}


def keys_of(data):
    return {(c["document"], c["concept"]) for c in data["concepts"]} | {(p["document"], p["page"]) for p in data["passages"]}


def main(spike):
    rng = random.Random(SEED)
    cat = json.load(open(os.path.join(spike, "catalogs", "catalog-full.json")))
    concepts = {(c["document"], c["concept"]): c for c in cat["concepts"]}
    passages = {(p["document"], p["page"]): p for p in cat["passages"]}
    dev = json.load(open(os.path.join(spike, "cases", "p-dev.json")))["cases"]
    p_targets = {(c["document"], c["concept"] if c.get("concept") else c["page"]) for c in dev}
    earlier = set()
    for name in [f"catalog-{a}.json" for a in "JKLMNOXY"] + ["catalog-gate.json"]:
        earlier |= keys_of(json.load(open(os.path.join(spike, "catalogs", name))))
    xy = keys_of(json.load(open(os.path.join(spike, "catalogs", "catalog-X.json")))) | \
        keys_of(json.load(open(os.path.join(spike, "catalogs", "catalog-Y.json"))))
    theme = set(THEME)

    mm = sorted(k for k, c in concepts.items() if k[0] == "Mobile Mastery" and c["section"] and len(c["rubric"]) >= 2
                and k not in theme and k not in p_targets and k not in earlier)
    rng.shuffle(mm)
    chosen_mm = mm[:2 * len(AUTHORS)]
    remaining = collections.defaultdict(list)
    for k in sorted(passages):
        if k[0] != "Mobile Mastery" and k not in theme and k not in p_targets and k not in xy and k not in META_PAGES:
            remaining[k[0]].append(k)
    for doc in sorted(remaining):
        rng.shuffle(remaining[doc])
    assignment = {}
    for i, author in enumerate(AUTHORS):
        docs = sorted(remaining, key=lambda d: (-len(remaining[d]), d))[:3]
        assignment[author] = {"theme": sorted(theme, key=str), "mobileMastery": chosen_mm[2 * i:2 * i + 2],
                              "small": [remaining[d].pop() for d in docs]}
    non_theme = {k for a in assignment.values() for k in a["mobileMastery"] + a["small"]}
    assert not non_theme & p_targets and len(non_theme) == 30

    def build(keys):
        cs = [concepts[k] for k in keys if k in concepts]
        ps = [passages[k] for k in keys if k in passages]
        assert len(cs) + len(ps) == len(keys), keys
        return {"concepts": cs, "passages": ps}

    out = os.path.join(spike, "catalogs", "nh")
    os.makedirs(out, exist_ok=True)
    for author, parts in assignment.items():
        keys = list(parts["theme"]) + list(parts["mobileMastery"]) + list(parts["small"])
        json.dump(build(keys), open(os.path.join(out, f"catalog-{author}.json"), "w"), indent=1, sort_keys=True)
    all_keys = sorted(theme | non_theme, key=str)
    json.dump(build(all_keys), open(os.path.join(out, "catalog-nh.json"), "w"), indent=1, sort_keys=True)
    json.dump({a: {k: [list(t) for t in v] for k, v in parts.items()} for a, parts in assignment.items()},
              open(os.path.join(out, "assignment.json"), "w"), indent=1, sort_keys=True)
    docs = collections.Counter(k[0] for k in all_keys)
    previously = sum(1 for k in non_theme if k in earlier)
    print(f"NH targets={len(all_keys)} (theme {len(theme)}, non-theme {len(non_theme)}, disjoint from P) documents={len(docs)} "
          f"{dict(docs)}; fresh MM pool={len(mm)}; non-theme targets used by an earlier spike set={previously}")


if __name__ == "__main__":
    main(sys.argv[1])
