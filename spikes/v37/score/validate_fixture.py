"""V37 capability spike (throwaway): structural validator for spike case files.

Blind-safe by construction: it prints ONLY case ids, problem codes, target names and counts. It
never prints learner text, credits, misconception claims, notes or any other author-written string,
so it can be run on the sealed primary gate without anyone reading an answer.

usage:
  validate_fixture.py <fixture.json> <catalog.json> --author J|K|L|M|N|O|X   (one author's file + quotas)
  validate_fixture.py <fixture.json> <catalog.json> --gate                   (the merged 240-case gate)
  validate_fixture.py <fixture.json> <catalog.json> --p2 <p2-input.json>      (annotator Y's labels)
  validate_fixture.py <labels.json> <catalog.json> --labels2 <input.json>     (blind second labels)
  validate_fixture.py <fixture.json> <catalog.json>                           (structure only)
Exit code 1 when any problem is found.
"""
import collections
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from spike_rules import (  # noqa: E402  (the rule tables, split out for the 300-line limit)
    STATES, KINDS, TAGS, THEME_OF, THEME_TAGS, QUOTAS,
    REGULAR, STATE_RANGES, SIZE, GATE_MINIMUMS, GATE_STATE_MINIMUMS, words,
    load, Catalog, tag_counts,
)


def check_labels(cid, case, entry, problems, catalog):
    """State, misconceptions and credits against the target's catalogue sentences."""
    rubric = [r["text"] for r in entry["rubric"]]
    sentences = rubric + entry["supporting"]
    state = case.get("state")
    if state not in STATES:
        problems.append(f"{cid} BAD_STATE")
    misconceptions = case.get("misconceptions")
    if not isinstance(misconceptions, list):
        problems.append(f"{cid} MISCONCEPTIONS_NOT_LIST")
        misconceptions = []
    for m in misconceptions:
        if m.get("kind") not in KINDS:
            problems.append(f"{cid} BAD_KIND")
        claim = m.get("claim")
        if claim:
            hits = sum(1 for s in sentences if claim in s)
            if hits != 1:
                problems.append(f"{cid} CLAIM_MATCHES:{hits}")
            if not 4 <= words(claim) <= 8:
                problems.append(f"{cid} CLAIM_WORDS:{words(claim)}")
        if m.get("kind") == "confusion":
            other = m.get("confusedWith")
            if not other:
                problems.append(f"{cid} CONFUSION_NEEDS_CONFUSEDWITH")
            elif other not in entry.get("neighbours", []) and other not in catalog.names and other != entry.get("contrastPartner"):
                problems.append(f"{cid} CONFUSEDWITH_UNKNOWN")
    if state == "misconception" and not misconceptions:
        problems.append(f"{cid} MISCONCEPTION_STATE_NEEDS_ENTRY")
    if state in {"understood", "mostlyUnderstood", "fragile", "insufficient"} and misconceptions:
        problems.append(f"{cid} STATE_FORBIDS_MISCONCEPTIONS")
    credits = case.get("credits")
    if not isinstance(credits, list):
        problems.append(f"{cid} CREDITS_NOT_LIST")
        credits = []
    for credit in credits:
        hits = sum(1 for s in rubric if credit in s)
        if hits != 1:
            problems.append(f"{cid} CREDIT_MATCHES:{hits}")
        if not 4 <= words(credit) <= 8:
            problems.append(f"{cid} CREDIT_WORDS:{words(credit)}")
    if state == "understood" and not credits:
        problems.append(f"{cid} UNDERSTOOD_NEEDS_CREDITS")


def check_fixture(data, catalog, problems, require_prefix=None):
    cases = data.get("cases") if isinstance(data, dict) else None
    if not isinstance(cases, list):
        problems.append("FILE NO_CASES_LIST")
        return []
    ids = collections.Counter(c.get("id") for c in cases)
    for cid, n in ids.items():
        if n > 1:
            problems.append(f"{cid} DUP_ID:{n}")
    texts = {}
    groups = collections.defaultdict(list)
    for case in cases:
        cid = case.get("id", "?")
        for field in ("id", "document", "text", "state", "misconceptions", "credits", "categories", "paraphraseGroup", "notes"):
            if field not in case:
                problems.append(f"{cid} MISSING_FIELD:{field}")
        if require_prefix and not re.fullmatch(rf"{require_prefix}-\d{{2}}", str(cid)):
            problems.append(f"{cid} BAD_ID_FORMAT")
        if case.get("concept") is not None and case.get("page") is not None:
            problems.append(f"{cid} BOTH_CONCEPT_AND_PAGE")
        key, entry = catalog.entry(case)
        if entry is None:
            problems.append(f"{cid} TARGET_NOT_IN_CATALOG")
            continue
        text = case.get("text") or ""
        if not text.strip():
            problems.append(f"{cid} TEXT_EMPTY")
        if len(text) > 1200:
            problems.append(f"{cid} TEXT_TOO_LONG:{len(text)}")
        normalized = " ".join(text.lower().split())
        if normalized in texts:
            problems.append(f"{cid} DUP_TEXT_OF:{texts[normalized]}")
        texts[normalized] = cid
        check_labels(cid, case, entry, problems, catalog)
        tags = case.get("categories") or []
        for tag in tags:
            if tag not in TAGS:
                problems.append(f"{cid} BAD_TAG")
        n = words(text)
        if "terse" in tags and not 3 <= n <= 10:
            problems.append(f"{cid} WORDS_TERSE:{n}")
        if "veryShort" in tags and not 1 <= n <= 5:
            problems.append(f"{cid} WORDS_VERYSHORT:{n}")
        if "verbose" in tags and n < 60:
            problems.append(f"{cid} WORDS_VERBOSE:{n}")
        if "verboseOneWrongClause" in tags and (n < 60 or case.get("state") not in {"misconception", "weakReasoning"}):
            problems.append(f"{cid} VERBOSE_ONE_WRONG_CLAUSE_RULE")
        if "wrongConclusionPlausibleReason" in tags and case.get("state") != "misconception":
            problems.append(f"{cid} TAG_STATE:wrongConclusionPlausibleReason")
        if "rightConclusionWrongReasoning" in tags and case.get("state") not in {"weakReasoning", "misconception"}:
            problems.append(f"{cid} TAG_STATE:rightConclusionWrongReasoning")
        if "misconceptionParaphrase" in tags and case.get("state") not in {"misconception", "weakReasoning"}:
            problems.append(f"{cid} TAG_STATE:misconceptionParaphrase")
        theme = THEME_OF.get(key)
        present = THEME_TAGS & set(tags)
        if (theme and present != {theme}) or (not theme and present):
            problems.append(f"{cid} THEME_TAG_MISMATCH")
        for s in [r["text"] for r in entry["rubric"]] + entry["supporting"]:
            if len(s) > 30 and s in text and "nearVerbatim" not in tags:
                problems.append(f"{cid} VERBATIM_SOURCE")
        if case.get("paraphraseGroup"):
            groups[case["paraphraseGroup"]].append(case)
    for gid, members in groups.items():
        if not 3 <= len(members) <= 4:
            problems.append(f"GROUP {gid} SIZE:{len(members)}")
        if len({m.get("state") for m in members}) > 1:
            problems.append(f"GROUP {gid} STATES_DIFFER")
        if len({tuple(sorted(x.get("kind", "") for x in m.get("misconceptions") or [])) for m in members}) > 1:
            problems.append(f"GROUP {gid} KINDS_DIFFER")
        if len({(m.get("document"), m.get("concept"), m.get("page")) for m in members}) > 1:
            problems.append(f"GROUP {gid} TARGETS_DIFFER")
    return cases


def summarize(cases, catalog):
    states = collections.Counter(c.get("state") for c in cases)
    tags = tag_counts(cases)
    grouped = sum(1 for c in cases if c.get("paraphraseGroup"))
    documents = collections.Counter(c.get("document") for c in cases)
    targets = collections.Counter(catalog.entry(c)[0] for c in cases)
    multi = sum(1 for c in cases if len(c.get("misconceptions") or []) >= 2)
    confusion_or_over = sum(1 for c in cases if any(m.get("kind") in {"confusion", "overgeneralization"} for m in c.get("misconceptions") or []))
    lengths = sorted(words(c.get("text") or "") for c in cases)
    print(f"cases={len(cases)} inGroups={grouped} twoPlusMisconceptions={multi} confusionOrOvergeneralization={confusion_or_over}")
    print("states " + " ".join(f"{s}={states.get(s, 0)}" for s in STATES))
    print("tags " + " ".join(f"{t}={tags[t]}" for t in sorted(tags)))
    print("documents " + " ".join(f"{d}={n}" for d, n in sorted(documents.items())))
    print(f"targets={len(targets)} wordCounts min={lengths[0] if lengths else 0} median={lengths[len(lengths) // 2] if lengths else 0} "
          f"max={lengths[-1] if lengths else 0} over80={sum(1 for n in lengths if n > 80)}")
    return states, tags, grouped, documents, targets, multi, confusion_or_over


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    problems = []
    data, catalog_data = load(argv[0], problems), load(argv[1], problems)
    if data is None or catalog_data is None:
        for p in problems:
            print("PROBLEM", p)
        return 1
    catalog = Catalog(catalog_data)
    mode = argv[2] if len(argv) > 2 else None

    if mode == "--labels2":
        source = load(argv[3], problems)
        inputs = {c["id"]: c for c in source["cases"]}
        labels = data.get("labels") if isinstance(data, dict) else None
        if not isinstance(labels, list):
            print("PROBLEM FILE NO_LABELS_LIST")
            return 1
        seen = collections.Counter(l.get("id") for l in labels)
        for cid in inputs:
            if seen.get(cid, 0) != 1:
                problems.append(f"{cid} LABEL_COUNT:{seen.get(cid, 0)}")
        for label in labels:
            cid = label.get("id", "?")
            if cid not in inputs:
                problems.append(f"{cid} UNKNOWN_ID")
                continue
            for field in ("id", "state", "misconceptions", "credits", "notes"):
                if field not in label:
                    problems.append(f"{cid} MISSING_FIELD:{field}")
            _, entry = catalog.entry(inputs[cid])
            if entry is None:
                problems.append(f"{cid} TARGET_NOT_IN_CATALOG")
                continue
            check_labels(cid, label, entry, problems, catalog)
        for p in problems:
            print("PROBLEM", p)
        print(f"labels={len(labels)} states " + " ".join(f"{s}={sum(1 for l in labels if l.get('state') == s)}" for s in STATES))
        print(f"problems {len(problems)}")
        return 1 if problems else 0

    author = argv[3] if mode == "--author" else None
    cases = check_fixture(data, catalog, problems, require_prefix=author)

    if mode == "--p2":
        source = load(argv[3], problems)
        expected = {c["id"]: c for c in source["cases"]}
        got = {c.get("id"): c for c in cases}
        if set(got) != set(expected):
            problems.append(f"FILE P2_IDS_DIFFER:{len(set(got) ^ set(expected))}")
        for cid, want in expected.items():
            case = got.get(cid)
            if case and (case.get("text") != want["text"] or case.get("concept") != want["concept"] or case.get("document") != want["document"]):
                problems.append(f"{cid} P2_INPUT_CHANGED")

    states, tags, grouped, documents, targets, multi, confusion_or_over = summarize(cases, catalog)

    if author:
        if len(cases) != SIZE[author]:
            problems.append(f"QUOTA size {len(cases)}/{SIZE[author]}")
        for tag, need in QUOTAS[author].items():
            if tags[tag] < need:
                problems.append(f"QUOTA {tag} {tags[tag]}/{need}")
        for state, (low, high) in STATE_RANGES[author].items():
            if not low <= states.get(state, 0) <= high:
                problems.append(f"STATE {state} {states.get(state, 0)} not in [{low},{high}]")
        if author != "X":
            theme_cases = sum(1 for c in cases if THEME_TAGS & set(c.get("categories") or []))
            if theme_cases < 5:
                problems.append(f"QUOTA themeCases {theme_cases}/5")
            non_theme = [k for k in list(catalog.concepts) + list(catalog.pages) if k not in THEME_OF]
            for k in non_theme:
                if targets.get(k, 0) < 3:
                    problems.append(f"TARGET_USE {k[0]}|{k[1]} {targets.get(k, 0)}/3")
            if documents.get("Mobile Mastery", 0) > 20:
                problems.append(f"MOBILE_MASTERY {documents.get('Mobile Mastery', 0)}/20 max")
            if grouped < 12:
                problems.append(f"QUOTA inParaphraseGroups {grouped}/12")
            if multi < 2:
                problems.append(f"QUOTA twoPlusMisconceptions {multi}/2")
            if confusion_or_over < 4:
                problems.append(f"QUOTA confusionOrOvergeneralization {confusion_or_over}/4")
        elif len(targets) < 5:
            problems.append(f"QUOTA distinctTargets {len(targets)}/5")

    if mode == "--gate":
        authors = collections.Counter(str(c.get("id", "?")).split("-")[0] for c in cases)
        print("authors " + " ".join(f"{a}={n}" for a, n in sorted(authors.items())))
        if len(cases) != 240 or sorted(authors.values()) != [40] * 6:
            problems.append("GATE size/authors")
        for tag, need in GATE_MINIMUMS.items():
            if tags[tag] < need:
                problems.append(f"GATE_QUOTA {tag} {tags[tag]}/{need}")
        for state, need in GATE_STATE_MINIMUMS.items():
            if states.get(state, 0) < need:
                problems.append(f"GATE_STATE {state} {states.get(state, 0)}/{need}")
        if len(targets) < 30:
            problems.append(f"GATE targets {len(targets)}/30")
        if len(documents) < 5:
            problems.append(f"GATE documents {len(documents)}/5")
        if documents.get("Mobile Mastery", 0) > 120:
            problems.append(f"GATE mobileMastery {documents.get('Mobile Mastery', 0)}/120 max")
        if grouped < 72:
            problems.append(f"GATE inParaphraseGroups {grouped}/72")
        wrong = states.get("misconception", 0)
        if confusion_or_over * 3 < wrong:
            problems.append(f"GATE confusionOrOvergeneralization {confusion_or_over} < a third of {wrong}")

    for p in problems:
        print("PROBLEM", p)
    print(f"problems {len(problems)}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
