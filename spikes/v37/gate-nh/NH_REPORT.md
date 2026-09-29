# V37 NH holdout — aggregate report (no case text, no labels)

Created 2026-09-29 for the frozen candidate `28ee88a` (manifest `6ca3364`), following HOLDOUT_PLAN.md.
Orchestrated from the Mac session at the owner's explicit approval (deviation D10 in PREREGISTRATION);
the orchestrator saw only ids, problem codes and counts.

## Authors and targets

* Six new author agents Q–V (personas in `guides/nh-author-briefs.md`), 40 cases each; one new blind second
  labeller. Earlier authors J–O, W, X, Y, Z not reused.
* Targets: seeded partition, seed 3738 (`score/build_nh_catalogs.py`, `catalogs/nh/`): 36 targets (6 theme,
  30 non-theme) across 7 documents; non-theme targets disjoint from P. All 12 Mobile Mastery cards are fresh;
  17 of the 18 small-document pages were also pages of the retired PG (the only eligible pages left).

## Validation (`score/validate_nh.py --gate`, problems 0; each author file `--author`, problems 0)

* cases=240; authors Q=40 R=40 S=40 T=40 U=40 V=40; targets=36; documents=7 (Mobile Mastery 116/240)
* states: understood=54 mostlyUnderstood=21 fragile=18 misconception=78 weakReasoning=50 insufficient=19
* quotas (minimum): paraphrase 74/40, novelVocabulary 86/40, rightConclusionWrongReasoning 50/40,
  wrongConclusionPlausibleReason 39/16, themeJWT 25/10, themeAuthnAuthz 33/12, themeClosure 49/10,
  subjectObjectReversal 19/16, negation 66/20, absoluteVsQualified 23/16, causeVsCorrelation 15/12,
  causalReversal 19/16, verboseOneWrongClause 18/16, terse 31/24, veryShort 15/12, typos 33/24,
  nonNativeEnglish 80/80, analogy 38/16, misconceptionParaphrase 72/24, fluentButWrong 28/20
* reasoningIssue: true=93 (min 60), of which with a misconception 56 (min 16); false=147
* paraphrase groups: 80 cases; two or more misconceptions: 15; confusion or overgeneralization: 25
* no duplicate ids or answer texts; no answer text shared with P; non-theme targets disjoint from P
* word counts: min 3, median 31, max 86; ≤ 80 words: 236 (the iPhone latency sample), over 80: 4

## Double labelling (`score/nh_agreement.py`)

* 60 cases, 10 per author (seed 3738), neutral ids DL-01…DL-60; first round, no guide repair.
* coarse state: raw 95.0%, Cohen's κ 0.925 (confusion: misconception→weak 1, weak→misconception 2)
* reasoningIssue: raw 98.3%, Cohen's κ 0.964 (true→false 1)
* Caveat: authors and second labeller are instances of the same model family; agreement measures
  consistency under the guide, not independence of human judgement.
