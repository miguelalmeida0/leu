"""V37 capability spike (throwaway): builds the development set's P1 sample, the P2 labelling input
and every author's catalogue from the exported knowledge-base catalogue. Deterministic (seed 3737).

Reads only source catalogues, the V35 dev fixture (development data) and the concept lists of earlier
authoring catalogues. Never reads any sealed fixture or any gate case.

usage: python3 build_catalogs.py <spike-dir> <v35-authoring-dir> <v36-authoring-dir>
"""
import collections
import json
import os
import random
import re
import sys

SEED = 3737
THEME_CONCEPTS = [("Mobile Mastery", "JWT"), ("Mobile Mastery", "Authentication"), ("Mobile Mastery", "Authorization"),
                  ("Mobile Mastery", "Closure"), ("JavaScript Deep Dive", "closure")]
THEME_PAGES = [("JavaScript Deep Dive", 2)]
# The V36 adversarial suite minus the three sentences that duplicate canonical cases (C2, C3, C5).
P2 = [
    ("A closure remembers its surrounding bindings.", "Closure", ["paraphrase", "novelVocabulary"]),
    ("A refresh token is a longer-lasting credential that gets you new access tokens without logging in again.", "Refresh token", ["paraphrase", "novelVocabulary"]),
    ("Idempotency makes retries dangerous.", "Idempotency", ["oppositeMeaningSameWords"]),
    ("Nobody holding a JWT can read the claims in its payload.", "JWT", ["oppositeMeaningSameWords"]),
    ("Throttling waits until the events stop coming and only then runs the handler once.", "Throttling", ["oppositeMeaningSameWords"]),
    ("Repeating an idempotent operation does not have the same effect as doing it once.", "Idempotency", ["negation"]),
    ("Retrying a failed call always makes it succeed eventually, whatever the error.", "Retry", ["absoluteVsQualified"]),
    ("You try a failed call again when the failure might only be temporary.", "Retry", ["absoluteVsQualified", "paraphrase"]),
    ("Big tables are usually the slow ones, so a table's size is what an index shrinks to make lookups fast.", "Database index", ["causeVsCorrelation"]),
    ("Calls that fail at night tend to succeed in the morning, so the time of day is what makes a retry work.", "Retry", ["causeVsCorrelation"]),
    ("An access token is a longer-lived credential used to obtain new refresh tokens.", "Refresh token", ["subjectObjectReversal"]),
    ("Authorization is what an allowed identity uses to decide who it is.", "Authorization", ["subjectObjectReversal"]),
    ("An index speeds up lookups on a column, because the database keeps the results of earlier queries and hands them back.", "Database index", ["rightConclusionWrongReasoning"]),
    ("A refresh token gets you a new access token without logging in again, because your password is stored inside it.", "Refresh token", ["rightConclusionWrongReasoning"]),
    ("Authentication checks who you are; authorization then decides what you may do.", "Authentication", ["multipleConcepts"]),
    ("Debouncing waits for a pause in the events, while throttling runs at most once per window.", "Debouncing", ["multipleConcepts"]),
    ("Idempotency is about retries.", "Idempotency", ["partiallyCorrect", "terse"]),
    ("JWTs are really popular and lots of web frameworks support them.", "JWT", ["irrelevantPlausible"]),
    ("Marking a cookie HttpOnly makes XSS attacks harmless.", "HttpOnly cookie", ["misconceptionParaphrase"]),
    ("Pressing an elevator call button five times still brings just one elevator.", "Idempotency", ["exampleInsteadOfDefinition"]),
    ("It's fast.", "Database index", ["veryShort"]),
    ("A JWT is a compact token with a header, a payload and a signature. The signature lets the API check who issued it without looking anything up in a database. Because it is encrypted, nobody can read the claims inside.", "JWT", ["verboseOneWrongClause", "verbose"]),
    ("A stateless server handles each request without relying on anything kept in its own memory, so any replica can take the next request, which makes horizontal scaling easier; that is also why stateless servers never need a database.", "Stateless server", ["verboseOneWrongClause", "verbose"]),
    ("It keeps it so that it doesn't have to make it again.", "useCallback", ["pronounAmbiguity"]),
    ("It keeps them around after it finishes so that it can use them.", "Closure", ["pronounAmbiguity"]),
]
# A page about the sample notes themselves ("Your highlights belong to you"), not teachable content.
META_PAGES = {("React Notes", 3)}
GATE_AUTHORS = ["J", "K", "L", "M", "N", "O"]


def norm(text):
    return re.sub(r"\s+", " ", text).strip()


def normalize_catalog(catalog):
    for c in catalog["concepts"]:
        c["concept"] = norm(c["concept"])
        c["examples"] = [norm(x) for x in c["examples"]]
        c["supporting"] = [norm(x) for x in c["supporting"]]
        for r in c["rubric"]:
            r["text"] = norm(r["text"])
    for p in catalog["passages"]:
        p["pageText"] = norm(p["pageText"])
        p["supporting"] = [norm(x) for x in p["supporting"]]
        for r in p["rubric"]:
            r["text"] = norm(r["text"])
    return catalog


def target_of(case):
    return (case["document"], case["concept"]) if case.get("concept") else (case["document"], case["page"])


def main(spike, v35, v36):
    rng = random.Random(SEED)
    path = os.path.join(spike, "catalogs", "catalog-full.json")
    catalog = normalize_catalog(json.load(open(path)))
    json.dump(catalog, open(path, "w"), indent=1, sort_keys=True)
    concepts = {(c["document"], c["concept"]): c for c in catalog["concepts"]}
    passages = {(p["document"], p["page"]): p for p in catalog["passages"]}

    # P1: a stratified sample of the V35 dev split (development data only).
    dev = json.load(open(os.path.join(spike, "..", "..", "Packages", "ShelfCore", "Tests", "Fixtures", "diagnosis-generalization-dev.json")))
    quota = {"understood": 7, "mostlyUnderstood": 5, "fragile": 5, "misconception": 10, "weakReasoning": 8, "insufficient": 5}
    p1 = []
    for state, n in quota.items():
        pool = sorted((c for c in dev["cases"] if c["state"] == state), key=lambda c: c["id"])
        p1 += rng.sample(pool, n)
    p1.sort(key=lambda c: c["id"])
    theme_tag = {("Mobile Mastery", "JWT"): "themeJWT", ("Mobile Mastery", "Authentication"): "themeAuthnAuthz",
                 ("Mobile Mastery", "Authorization"): "themeAuthnAuthz", ("Mobile Mastery", "Closure"): "themeClosure",
                 ("JavaScript Deep Dive", "closure"): "themeClosure", ("JavaScript Deep Dive", 2): "themeClosure"}
    sampled_groups = collections.Counter(c["paraphraseGroup"] for c in p1 if c.get("paraphraseGroup"))
    for c in p1:
        c["origin"] = "v35-dev"
        # Labels are untouched: only the spike's theme tags are added, and paraphrase groups the
        # sample broke apart (fewer than 3 members left) are cleared.
        tag = theme_tag.get(target_of(c))
        if tag and tag not in c["categories"]:
            c["categories"] = c["categories"] + [tag]
        if c.get("paraphraseGroup") and sampled_groups[c["paraphraseGroup"]] < 3:
            c["paraphraseGroup"] = None
    json.dump({"split": "v37-p1", "cases": p1}, open(os.path.join(spike, "cases", "p1-dev.json"), "w"), indent=1)

    # P2: the adversarial sentences, unlabelled, for annotator Y.
    p2 = [{"id": f"P2-{i + 1:02d}", "document": "Mobile Mastery", "concept": concept, "page": None, "text": text,
           "suggestedCategories": cats} for i, (text, concept, cats) in enumerate(P2)]
    json.dump({"split": "v37-p2-input", "cases": p2}, open(os.path.join(spike, "cases", "p2-input.json"), "w"), indent=1)

    # Targets already used: development (P1, P2) and earlier dev/dev2/sealed36 authoring catalogues
    # (concept names only; the V35 sealed catalogue is deliberately not read).
    used_dev = {target_of(c) for c in p1} | {("Mobile Mastery", c) for _, c, _ in P2}
    earlier = set()
    for folder, names in ((v35, ["catalog-dev.json"]),
                          (v36, [f"catalog-dev2-{a}.json" for a in "CDE"] + [f"catalog-sealed36-{a}.json" for a in "FGHI"])):
        for name in names:
            data = json.load(open(os.path.join(folder, name)))
            earlier |= {(c["document"], norm(c["concept"])) for c in data["concepts"]}
            earlier |= {(p["document"], p["page"]) for p in data.get("passages", [])}
    theme = set(THEME_CONCEPTS) | set(THEME_PAGES)

    # Mobile Mastery cards with at least two core claims, never used before.
    mm = sorted(k for k, c in concepts.items() if k[0] == "Mobile Mastery" and c["section"] and len(c["rubric"]) >= 2
                and k not in theme and k not in used_dev and k not in earlier)
    rng.shuffle(mm)
    gate_mm, x_mm = mm[:12], mm[12:18]

    # Small documents: whole pages only (their single-sentence "concepts" repeat page sentences, and
    # several are extraction noise). Each author gets three pages from three different documents.
    remaining = collections.defaultdict(list)
    for k in sorted(passages):
        if k[0] != "Mobile Mastery" and k not in theme and k not in used_dev and k not in META_PAGES:
            remaining[k[0]].append(k)
    for doc in sorted(remaining):
        rng.shuffle(remaining[doc])
    assignment = {}
    for i, author in enumerate(GATE_AUTHORS):
        docs = sorted(remaining, key=lambda d: (-len(remaining[d]), d))[:3]
        chosen = [remaining[d].pop() for d in docs]
        assignment[author] = {"theme": sorted(theme, key=str), "mobileMastery": gate_mm[2 * i:2 * i + 2], "small": chosen}
    gate_non_theme = {k for a in assignment.values() for k in a["mobileMastery"] + a["small"]}
    assert not gate_non_theme & used_dev and len(gate_non_theme) == 30
    assignment["X"] = {"theme": [("Mobile Mastery", "Authentication"), ("Mobile Mastery", "Authorization")], "mobileMastery": x_mm, "small": []}
    assert not set(x_mm) & gate_non_theme

    def build(keys):
        cs = [concepts[k] for k in keys if k in concepts]
        ps = [passages[k] for k in keys if k in passages]
        assert len(cs) + len(ps) == len(keys), keys
        return {"concepts": cs, "passages": ps}

    out = os.path.join(spike, "catalogs")
    for author, parts in assignment.items():
        keys = list(parts["theme"]) + list(parts["mobileMastery"]) + list(parts["small"])
        json.dump(build(keys), open(os.path.join(out, f"catalog-{author}.json"), "w"), indent=1, sort_keys=True)
    json.dump(build(sorted({("Mobile Mastery", c) for _, c, _ in P2})), open(os.path.join(out, "catalog-Y.json"), "w"), indent=1, sort_keys=True)
    gate_keys = sorted(theme | gate_non_theme, key=str)
    json.dump(build(gate_keys), open(os.path.join(out, "catalog-gate.json"), "w"), indent=1, sort_keys=True)
    json.dump({a: {k: [list(t) for t in v] for k, v in parts.items()} for a, parts in assignment.items()},
              open(os.path.join(out, "assignment.json"), "w"), indent=1, sort_keys=True)

    docs_all = collections.Counter(k[0] for k in gate_keys)
    print(f"P1={len(p1)} states={dict(collections.Counter(c['state'] for c in p1))} P2={len(p2)}")
    print(f"gate targets={len(gate_keys)} (theme {len(theme)}, non-theme {len(gate_non_theme)}) documents={len(docs_all)} {dict(docs_all)}")
    print(f"fresh MM pool={len(mm)}; X MM={len(x_mm)}")


if __name__ == "__main__":
    main(*sys.argv[1:4])
