"""V37 NH holdout (throwaway): the NH validator (HOLDOUT_PLAN "Validation"). Blind-safe: it prints ONLY
case ids, problem codes and counts, never learner text, labels, notes or any other author-written string.

usage:
  validate_nh.py <cases.json> <catalog.json> --author Q|R|S|T|U|V      (one author's file and quotas)
  validate_nh.py <nh.json> <catalog-nh.json> --gate <p-dev.json>       (the merged 240 cases)
  validate_nh.py <labels.json> <catalog-nh.json> --labels2 <input.json> (the blind second labels)
Exit code 1 when any problem is found.
"""
import collections
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from spike_rules import THEME_OF, THEME_TAGS, load, Catalog, tag_counts, words  # noqa: E402
from validate_fixture import check_fixture, check_labels, summarize  # noqa: E402
from nh_rules import (AUTHORS, NH_QUOTAS, NH_STATE_RANGES, NH_MINIMUMS, NH_STATE_MINIMUMS, NH_REASONING_MIN,  # noqa: E402
                      NH_BOTH_MIN, REASONING, REASONING_TAGS, is_misconception)


def reasoning_checks(cases, problems):
    """reasoningIssue on every case, consistent with the reasoning-fault tags; returns (true, both)."""
    true = both = 0
    for case in cases:
        cid = case.get("id", "?")
        value = case.get("reasoningIssue")
        if not isinstance(value, bool):
            problems.append(f"{cid} REASONING_ISSUE_MISSING")
            continue
        tags = set(case.get("categories") or [])
        if tags & REASONING_TAGS and not value:
            problems.append(f"{cid} REASONING_TAG_WITHOUT_ISSUE")
        if "causalReversal" in tags and not (value or any(m.get("kind") == "reversal" for m in case.get("misconceptions") or [])):
            problems.append(f"{cid} CAUSAL_REVERSAL_RULE")
        if value:
            true += 1
            both += is_misconception(case)
    return true, both


def author_checks(author, cases, catalog, problems):
    states = collections.Counter(c.get("state") for c in cases)
    tags = tag_counts(cases)
    targets = collections.Counter(catalog.entry(c)[0] for c in cases)
    documents = collections.Counter(c.get("document") for c in cases)
    if len(cases) != 40:
        problems.append(f"QUOTA size {len(cases)}/40")
    for tag, need in NH_QUOTAS[author].items():
        if tags[tag] < need:
            problems.append(f"QUOTA {tag} {tags[tag]}/{need}")
    for state, (low, high) in NH_STATE_RANGES[author].items():
        if not low <= states.get(state, 0) <= high:
            problems.append(f"STATE {state} {states.get(state, 0)} not in [{low},{high}]")
    if sum(1 for c in cases if THEME_TAGS & set(c.get("categories") or [])) < 5:
        problems.append("QUOTA themeCases <5")
    for k in [k for k in list(catalog.concepts) + list(catalog.pages) if k not in THEME_OF]:
        if targets.get(k, 0) < 3:
            problems.append(f"TARGET_USE {k[0]}|{k[1]} {targets.get(k, 0)}/3")
    if documents.get("Mobile Mastery", 0) > 20:
        problems.append(f"MOBILE_MASTERY {documents.get('Mobile Mastery', 0)}/20 max")
    if sum(1 for c in cases if c.get("paraphraseGroup")) < 12:
        problems.append("QUOTA inParaphraseGroups <12")
    if sum(1 for c in cases if len(c.get("misconceptions") or []) >= 2) < 2:
        problems.append("QUOTA twoPlusMisconceptions <2")
    if sum(1 for c in cases if any(m.get("kind") in {"confusion", "overgeneralization"} for m in c.get("misconceptions") or [])) < 4:
        problems.append("QUOTA confusionOrOvergeneralization <4")
    true, both = reasoning_checks(cases, problems)
    need_true, need_both = REASONING[author]
    if true < need_true:
        problems.append(f"QUOTA reasoningIssue {true}/{need_true}")
    if both < need_both:
        problems.append(f"QUOTA reasoningIssueAndMisconception {both}/{need_both}")
    print(f"reasoningIssue true={true} false={len(cases) - true} withMisconception={both}")


def gate_checks(cases, catalog, p_path, problems):
    states = collections.Counter(c.get("state") for c in cases)
    tags = tag_counts(cases)
    documents = collections.Counter(c.get("document") for c in cases)
    targets = collections.Counter(catalog.entry(c)[0] for c in cases)
    authors = collections.Counter(str(c.get("id", "?")).split("-")[0] for c in cases)
    print("authors " + " ".join(f"{a}={authors.get(a, 0)}" for a in AUTHORS))
    if len(cases) != 240 or any(authors.get(a, 0) != 40 for a in AUTHORS) or set(authors) != set(AUTHORS):
        problems.append("NH size/authors")
    for tag, need in NH_MINIMUMS.items():
        if tags[tag] < need:
            problems.append(f"NH_QUOTA {tag} {tags[tag]}/{need}")
    for state, need in NH_STATE_MINIMUMS.items():
        if states.get(state, 0) < need:
            problems.append(f"NH_STATE {state} {states.get(state, 0)}/{need}")
    if len(targets) < 30:
        problems.append(f"NH targets {len(targets)}/30")
    if len(documents) < 5:
        problems.append(f"NH documents {len(documents)}/5")
    if documents.get("Mobile Mastery", 0) > 120:
        problems.append(f"NH mobileMastery {documents.get('Mobile Mastery', 0)}/120 max")
    true, both = reasoning_checks(cases, problems)
    if true < NH_REASONING_MIN:
        problems.append(f"NH reasoningIssue {true}/{NH_REASONING_MIN}")
    if both < NH_BOTH_MIN:
        problems.append(f"NH reasoningIssueAndMisconception {both}/{NH_BOTH_MIN}")
    # Development set P: no shared answer text; non-theme targets disjoint.
    p_cases = load(p_path, problems)["cases"]
    p_texts = {" ".join(c["text"].lower().split()) for c in p_cases}
    p_targets = {(c["document"], c["concept"] if c.get("concept") else c["page"]) for c in p_cases}
    for c in cases:
        if " ".join((c.get("text") or "").lower().split()) in p_texts:
            problems.append(f"{c.get('id')} DUP_OF_P_TEXT")
    shared = [k for k in targets if k not in THEME_OF and k in p_targets]
    if shared:
        problems.append(f"NH nonThemeTargetsInP {len(shared)}")
    short = sum(1 for c in cases if words(c.get("text") or "") <= 80)
    print(f"reasoningIssue true={true} false={len(cases) - true} withMisconception={both} weakReasoning={states.get('weakReasoning', 0)}")
    print(f"le80words={short} over80={len(cases) - short} mobileMasteryShare={documents.get('Mobile Mastery', 0)}/{len(cases)}")


def main(argv):
    if len(argv) < 3:
        print(__doc__)
        return 2
    problems = []
    data, catalog_data = load(argv[0], problems), load(argv[1], problems)
    if data is None or catalog_data is None:
        for p in problems:
            print("PROBLEM", p)
        return 1
    catalog, mode = Catalog(catalog_data), argv[2]
    if mode == "--labels2":
        inputs = {c["id"]: c for c in load(argv[3], problems)["cases"]}
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
            for field in ("id", "state", "misconceptions", "credits", "notes", "reasoningIssue"):
                if field not in label:
                    problems.append(f"{cid} MISSING_FIELD:{field}")
            _, entry = catalog.entry(inputs[cid])
            if entry is None:
                problems.append(f"{cid} TARGET_NOT_IN_CATALOG")
                continue
            check_labels(cid, label, entry, problems, catalog)
            if not isinstance(label.get("reasoningIssue"), bool):
                problems.append(f"{cid} REASONING_ISSUE_MISSING")
        print(f"labels={len(labels)}")
    else:
        author = argv[3] if mode == "--author" else None
        cases = check_fixture(data, catalog, problems, require_prefix=author)
        summarize(cases, catalog)
        if author:
            author_checks(author, cases, catalog, problems)
        elif mode == "--gate":
            gate_checks(cases, catalog, argv[3], problems)
    for p in problems:
        print("PROBLEM", p)
    print(f"problems {len(problems)}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
