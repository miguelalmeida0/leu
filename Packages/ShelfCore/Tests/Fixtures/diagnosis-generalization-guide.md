<!-- The guide given verbatim to both annotators of diagnosis-generalization-dev.json (author A) and
     diagnosis-generalization-sealed.json (author B). Each also received a catalog of their split's concepts
     with the source's rubric and supporting sentences; neither saw Leu's code, lexicon, tests or the other split. -->

# Leu V35 generalization fixture — authoring and labeling guide

You are writing learner explanations and labeling what each one shows, as an experienced
teacher would. The explanations will be used to measure how well an automatic system
judges understanding. You never see the system, and you must not try to guess how it
works. Write the kind of answers real learners write.

## What a case is

A learner has just studied one concept card (or one page) from a source document and is
asked to explain it in their own words. You write what the learner typed and label it.

The catalog you are given lists, per concept: the source sentences that define and explain
it (`rubric`), extra summary sentences (`supporting`), neighbouring concepts from the same
document (`neighbours`) and, sometimes, a concept the source contrasts it with.
Only the catalog's sentences count as "what the source says". Do not label anything as
understood because it is true in general; label against what this source teaches.

## Case fields

```json
{
  "id": "gd-001",
  "document": "Mobile Mastery",
  "concept": "Idempotency",          // exactly the catalog "concept" name; null for a page case
  "page": null,                      // page index for a page case (concept must then be null)
  "text": "what the learner wrote",
  "state": "understood",             // see below — the one label that matters most
  "misconceptions": [                // empty unless state is misconception (or weakReasoning with a wrong reason)
    {"kind": "contradiction", "claim": "short exact substring of the rubric/supporting sentence contradicted",
     "confusedWith": null}
  ],
  "credits": ["short exact substring of each rubric sentence the learner fully expresses"],
  "categories": ["paraphrase", "novelVocabulary"],
  "paraphraseGroup": "pg-07",        // or null
  "notes": "one sentence: why this label"
}
```

`claim` and `credits` entries must be exact, case-sensitive substrings (4–8 words) of exactly
one catalog sentence of that concept, so a program can find the sentence.

## The state label (choose exactly one)

* `understood` — the central idea(s) of the concept are expressed correctly, in any words,
  and nothing stated is wrong. A teacher would say "yes, they get it".
* `mostlyUnderstood` — the central idea is right, but an important secondary element
  (a limiting condition, the purpose, the "why") is missing or vague. Nothing is wrong.
* `fragile` — some correct pieces, but the central idea itself is incomplete, vague or only
  gestured at (the right words without the relationship between them). Nothing is clearly
  wrong, yet a teacher would not trust it.
* `misconception` — the explanation asserts something the source contradicts: the opposite
  of a source statement, a reversed cause/effect or direction, another concept's
  definition (confusion), or "always/never/every" where the source is qualified
  (overgeneralization). Label this even when other parts are right. List each distinct
  wrong idea in `misconceptions` (kind: contradiction | reversal | confusion |
  overgeneralization; `confusedWith` = the other concept's catalog name for a confusion).
* `weakReasoning` — the conclusion, term or definition is right, but the reason or mechanism
  given for it is wrong, circular, or a buzzword non-sequitur that the source does not
  support — the right answer is there without the understanding behind it. If the wrong
  reason directly contradicts a source sentence, record that in `misconceptions` too (the
  state stays `weakReasoning` only when the conclusion itself is right).
* `insufficient` — too short, too vague, off-topic, or plausible-sounding but not about what
  this source teaches; a teacher cannot tell what the learner understands.

## Categories (tag every case with all that apply)

* `paraphrase` — correct content in wording clearly different from the source.
* `novelVocabulary` — uses everyday words, synonyms or jargon the source does not use.
* `terse` — 3–10 words.
* `verbose` — 60+ words, with filler, asides or repetition.
* `partiallyCorrect` — some right, some missing.
* `confidentlyWrong` — a wrong idea stated assertively ("Obviously…", "always").
* `rightConclusionWrongReasoning` — right conclusion, wrong/absent reason.
* `multipleMisconceptions` — two or more distinct wrong ideas in one answer.
* `irrelevantPlausible` — true-sounding statements that are not what the source teaches here.
* `novelExample` — explains through an example or analogy that is not in the source.
* `hedged` — heavy hedging ("I think maybe…", "kind of").
* `nearVerbatim` — mostly copies the source sentence.

## Paraphrase groups (metamorphic tests)

Create groups of 3 or 4 cases that express the *same* understanding (same state, same
misconceptions, same credits) in different words: vary vocabulary, sentence structure,
length, order of ideas, voice, and hedging. Give them the same `paraphraseGroup` id. Make
at least one group per state, including groups for misconceptions and for insufficient.
A group's members must truly mean the same thing — if one adds or drops an idea, it does
not belong in the group.

## Distribution (approximate)

understood 20% · mostlyUnderstood 15% · fragile 15% · misconception 25% (at least a third of
them confusions or overgeneralizations, and at least 5 cases with two misconceptions) ·
weakReasoning 10% · insufficient 15%. At least 35% of cases in paraphrase groups.
At least half of all cases should use few of the source's own key words.

## Rules

* Write like learners: contractions, imprecise words, run-on sentences, the occasional typo
  is fine (not in every case). Never paste a source sentence unless tagging `nearVerbatim`.
* Each case is about one concept (or one page). Do not mention the labels in the text.
* Label honestly and consistently; when torn between two states, prefer the less generous
  one and say why in `notes`.
* Do not read any code, tests or other fixture files in the repository. Use only the catalog
  you are given and this guide.
