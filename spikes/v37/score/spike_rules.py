"""V37 capability spike (throwaway): the case rules the validator enforces, split out of
validate_fixture.py only to respect the repository's 300-line file limit. Behaviour is unchanged."""
import collections
import json

STATES = ["understood", "mostlyUnderstood", "fragile", "misconception", "weakReasoning", "insufficient"]
KINDS = {"contradiction", "reversal", "confusion", "overgeneralization"}
TAGS = {"paraphrase", "novelVocabulary", "terse", "verbose", "partiallyCorrect", "confidentlyWrong",
        "rightConclusionWrongReasoning", "multipleMisconceptions", "irrelevantPlausible", "novelExample", "hedged",
        "nearVerbatim", "oppositeMeaningSameWords", "negation", "absoluteVsQualified", "causeVsCorrelation",
        "subjectObjectReversal", "multipleConcepts", "misconceptionParaphrase", "exampleInsteadOfDefinition",
        "veryShort", "verboseOneWrongClause", "pronounAmbiguity",
        # V37 spike additions
        "wrongConclusionPlausibleReason", "typos", "nonNativeEnglish", "analogy", "fluentButWrong",
        "themeJWT", "themeAuthnAuthz", "themeClosure",
        # NH holdout addition (HOLDOUT_PLAN): cause and effect swapped
        "causalReversal"}
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


def tag_counts(cases):
    counts = collections.Counter(tag for c in cases for tag in set(c.get("categories") or []))
    counts["terse"] = sum(1 for c in cases if {"terse", "veryShort"} & set(c.get("categories") or []))
    return counts
