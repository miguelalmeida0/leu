# V37 spike addendum to the authoring and labelling guide

Everything in `guide.md` and `guide-v36-addendum.md` still applies, **except where this
addendum replaces it**:

* the case fields;
* the six states and their meaning;
* the misconception kinds;
* credits and claims as exact substrings;
* paraphrase groups;
* the rule to prefer the less generous label when torn;
* your writing voice.

## 1. What this addendum replaces

* **Size.** Write exactly the number of cases your brief gives (40 for a gate author).
* **Documents.** Your catalogue has shared *theme* targets, two Mobile Mastery concepts and
  three pages from three short documents.
  * At most **20** of your cases may be about Mobile Mastery.
  * Use **each non-theme target at least 3 times.**
  * Write at least 5 theme cases, per the theme minimums in your brief.
* **State distribution.** Use the state ranges in your brief, not the V35 percentages.
* **Categories.** Your brief gives a minimum count per tag; it replaces "at least two of
  each". Tag every case with every tag that applies.
* **Paraphrase groups.** At least **12** of your cases must be in groups of 3–4 members. A
  group's members share one target, one state and the same misconception kinds.
* **Validator.** Run `python3 validate_fixture.py <your file> <your catalogue> --author
  <your letter>` until it prints `problems 0`.

## 2. New tags

| Tag | Meaning | State rule |
|---|---|---|
| `wrongConclusionPlausibleReason` | The reason given is true or plausible, but the conclusion drawn from it is wrong ("JWTs are signed, so nobody can read them") | misconception |
| `typos` | Natural misspellings, keyboard slips or phonetic spellings, 1–4 per answer; the meaning is still readable | any |
| `nonNativeEnglish` | Realistic first-language transfer: articles, prepositions, word order, false friends, tense. Never caricature; always understandable | any |
| `analogy` | Explains by comparison with something from everyday life | any |
| `fluentButWrong` | Polished, confident, well structured, and wrong somewhere important | misconception or weakReasoning |
| `themeJWT` | A case about the JWT concept | — |
| `themeAuthnAuthz` | A case about Authentication or Authorization | — |
| `themeClosure` | A case about Closure (Mobile Mastery), closure (JavaScript Deep Dive), or JavaScript Deep Dive page 2 | — |

**Theme tags.** Every case on a theme target carries its theme tag, and no other case does.

## 3. What theme cases should probe

* **JWT:** signing vs encryption.
  * Is the payload readable?
  * What does the signature guarantee?
  * Why is no database lookup needed?
* **Authentication vs authorization:**
  * identity vs permission;
  * which comes first;
  * confusing one for the other in either direction;
  * "identity alone is not permission".
* **Closures:**
  * keeping access to the enclosing scope's variables after the outer function returns;
  * access vs copying values;
  * separate calls creating separate environments.

## 4. Reasoning labels

* **Right conclusion, wrong reason** (`rightConclusionWrongReasoning`): state `weakReasoning`.
  List a misconception only when the reason directly contradicts a source sentence; the state
  then stays `weakReasoning` as long as the conclusion is right.
* **Wrong conclusion, plausible reason** (`wrongConclusionPlausibleReason`): state
  `misconception`, with its kind and the contradicted claim.
* **Causal vs correlational** (`causeVsCorrelation`): "A happens with B, so A causes B" where
  the source says otherwise (or nothing) is a misconception when it contradicts the source, and
  weak reasoning when it only props up a right conclusion.

## 5. Length

* `terse`: 3–10 words. `veryShort`: 1–5 words. `verbose` and `verboseOneWrongClause`: 60 or
  more words.
* Keep most answers at **80 words or fewer**. Long answers are allowed up to 1,200 characters.

## 6. Confidentiality

Your cases are a sealed test set.

* Do not show them, quote them or summarize their wording to anyone, including in your final
  message.
* Read only the files your instructions name.
