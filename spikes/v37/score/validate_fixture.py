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
import re
import sys

STATES = ["understood", "mostlyUnderstood", "fragile", "misconception", "weakReasoning", "insufficient"]
KINDS = {"contradiction", "reversal", "confusion", "overgeneralization"}
TAGS = {"paraphrase", "novelVocabulary", "terse", "verbose", "partiallyCorrect", "confidentlyWrong",
        "rightConclusionWrongReasoning", "multipleMisconceptions", "irrelevantPlausible", "novelExample", "hedged",
        "nearVerbatim", "oppositeMeaningSameWords", "negation", "absoluteVsQualified", "causeVsCorrelation",
        "subjectObjectReversal", "multipleConcepts", "misconceptionParaphrase", "exampleInsteadOfDefinition",
        "veryShort", "verboseOneWrongClause", "pronounAmbiguity",
        # V37 spike additions
        "wrongConclusionPlausibleReason", "typos", "nonNativeEnglish", "analogy", "fluentButWrong",
        "themeJWT", "themeAuthnAuthz", "themeClosure"}
THEME_OF = {("Mobile Mastery", "JWT"): "themeJWT", ("Mobile Mastery", "Authentication"): "themeAuthnAuthz",
            ("Mobile Mastery", "Authorization"): "themeAuthnAuthz", ("Mobile Mastery", "Closure"): "themeClosure",
            ("JavaScript Deep Dive", "closure"): "themeClosure", ("JavaScript Deep Dive", 2): "themeClosure"}
THEME_TAGS = {"themeJWT", "themeAuthnAuthz", "themeClosure"}

# Per-author minimum tag counts. "terse" counts terse or veryShort answers.
QUOTAS = {
    "J": {"nonNativeEnglish": 40, "paraphrase": 8, "novelVocabulary": 6, "rightConclusionWrongReasoning": 5,
          "wrongConclusionPlausibleReason": 1, "themeJWT": 2, "themeAuthnAuthz": 2, "themeClosure": 2, "subjectObjectReversal": 3,
          "negation": 5, "absoluteVsQualified": 2, "causeVsCorrelation": 1, "verboseOneWrongClause": 2, "terse": 3, "veryShort": 2,
          "typos": 3, "analogy": 1, "misconceptionParaphrase": 4, "fluentButWrong": 1},
    "K": {"typos": 18, "terse": 15, "veryShort": 8, "paraphrase": 6, "novelVocabulary": 8, "rightConclusionWrongReasoning": 4,
          "wrongConclusionPlausibleReason": 1, "themeJWT": 2, "themeAuthnAuthz": 2, "themeClosure": 2, "subjectObjectReversal": 2,
          "negation": 3, "absoluteVsQualified": 2, "causeVsCorrelation": 1, "analogy": 1, "misconceptionParaphrase": 3,
          "fluentButWrong": 1},
    "L": {"fluentButWrong": 14, "verboseOneWrongClause": 10, "misconceptionParaphrase": 10, "absoluteVsQualified": 4,
          "paraphrase": 6, "novelVocabulary": 6, "rightConclusionWrongReasoning": 5, "wrongConclusionPlausibleReason": 2,
          "themeJWT": 2, "themeAuthnAuthz": 2, "themeClosure": 2, "subjectObjectReversal": 3, "negation": 3,
          "causeVsCorrelation": 1, "analogy": 1},
    "M": {"analogy": 12, "paraphrase": 8, "novelVocabulary": 10, "exampleInsteadOfDefinition": 3, "rightConclusionWrongReasoning": 4,
          "wrongConclusionPlausibleReason": 1, "themeJWT": 2, "themeAuthnAuthz": 2, "themeClosure": 2, "subjectObjectReversal": 2,
          "negation": 3, "absoluteVsQualified": 2, "causeVsCorrelation": 1, "verboseOneWrongClause": 2, "terse": 2, "typos": 1,
          "misconceptionParaphrase": 3, "fluentButWrong": 2},
    "N": {"rightConclusionWrongReasoning": 20, "wrongConclusionPlausibleReason": 10, "causeVsCorrelation": 8, "paraphrase": 6,
          "novelVocabulary": 6, "themeJWT": 1, "themeAuthnAuthz": 2, "themeClosure": 2, "subjectObjectReversal": 2, "negation": 3,
          "absoluteVsQualified": 2, "verboseOneWrongClause": 2, "terse": 1, "typos": 1, "analogy": 1, "misconceptionParaphrase": 2,
          "fluentButWrong": 2},
    "O": {"nonNativeEnglish": 40, "subjectObjectReversal": 5, "negation": 5, "absoluteVsQualified": 5, "paraphrase": 8,
          "novelVocabulary": 6, "rightConclusionWrongReasoning": 4, "wrongConclusionPlausibleReason": 1, "themeJWT": 2,
          "themeAuthnAuthz": 3, "themeClosure": 2, "causeVsCorrelation": 1, "verboseOneWrongClause": 1, "terse": 4, "veryShort": 2,
          "typos": 3, "analogy": 1, "misconceptionParaphrase": 3, "fluentButWrong": 1},
    "X": {"typos": 3, "nonNativeEnglish": 3, "absoluteVsQualified": 2, "analogy": 2, "wrongConclusionPlausibleReason": 2,
          "causeVsCorrelation": 2, "themeAuthnAuthz": 1},
}
REGULAR = {"understood": (7, 11), "mostlyUnderstood": (3, 7), "fragile": (3, 7), "misconception": (8, 13),
           "weakReasoning": (5, 8), "insufficient": (3, 8)}
STATE_RANGES = {
    "J": REGULAR, "K": REGULAR, "M": REGULAR, "O": REGULAR,
    "L": {"understood": (5, 9), "mostlyUnderstood": (3, 6), "fragile": (2, 5), "misconception": (14, 19),
          "weakReasoning": (5, 8), "insufficient": (2, 5)},
    "N": {"understood": (3, 7), "mostlyUnderstood": (2, 4), "fragile": (1, 4), "misconception": (10, 14),
          "weakReasoning": (19, 24), "insufficient": (0, 3)},
    "X": {"understood": (2, 4), "mostlyUnderstood": (1, 3), "fragile": (1, 3), "misconception": (3, 6),
          "weakReasoning": (2, 4), "insufficient": (0, 2)},
}
SIZE = {"J": 40, "K": 40, "L": 40, "M": 40, "N": 40, "O": 40, "X": 15}
GATE_MINIMUMS = {"paraphrase": 40, "novelVocabulary": 40, "rightConclusionWrongReasoning": 40, "wrongConclusionPlausibleReason": 16,
                 "themeJWT": 10, "themeAuthnAuthz": 12, "themeClosure": 10, "subjectObjectReversal": 16, "negation": 20,
                 "absoluteVsQualified": 16, "causeVsCorrelation": 12, "verboseOneWrongClause": 16, "terse": 24, "veryShort": 12,
                 "typos": 24, "nonNativeEnglish": 80, "analogy": 16, "misconceptionParaphrase": 24, "fluentButWrong": 20}
# The sums of the per-author minimums, so six valid author files always make a valid gate.
GATE_STATE_MINIMUMS = {"understood": 36, "mostlyUnderstood": 17, "fragile": 15, "misconception": 56, "weakReasoning": 44,
                       "insufficient": 14}


def words(text):
    return len(text.split())


def load(path, problems):
    try:
        return json.load(open(path))
    except Exception as error:  # never echo content
        problems.append(f"FILE {path.rsplit('/', 1)[-1]} BAD_JSON:{type(error).__name__}")
        return None


class Catalog:
    def __init__(self, data):
        self.concepts = {(c["document"], c["concept"]): c for c in data["concepts"]}
        self.pages = {(p["document"], p["page"]): p for p in data["passages"]}
        self.names = {c["concept"] for c in data["concepts"]}

    def entry(self, case):
        concept, page = case.get("concept"), case.get("page")
        if concept is not None:
            return (case.get("document"), concept), self.concepts.get((case.get("document"), concept))
        return (case.get("document"), page), self.pages.get((case.get("document"), page))


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


def tag_counts(cases):
    counts = collections.Counter(tag for c in cases for tag in set(c.get("categories") or []))
    counts["terse"] = sum(1 for c in cases if {"terse", "veryShort"} & set(c.get("categories") or []))
    return counts


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
