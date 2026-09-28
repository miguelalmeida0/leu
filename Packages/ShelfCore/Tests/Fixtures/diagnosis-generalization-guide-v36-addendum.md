# V36 addendum to the authoring and labeling guide

Everything in `guide.md` still applies: the case fields, the six states and their meaning, the
misconception kinds, credits as exact 4–8 word substrings, paraphrase groups, and the rule to
prefer the less generous label when torn. This addendum changes four things.

## 1. Your writing voice

You write as **one particular kind of learner**, described in your brief. Stay in that voice
for most cases, but vary sentence length, structure and register inside it. Real learners
are inconsistent: some answers careful, some rushed.

## 2. Documents

Your catalog mixes the long "Mobile Mastery" manual with six short documents (System Design,
Design Patterns, Coding Interviews, Computer Science Essentials, JavaScript Deep Dive, React
Notes). **At most 40% of your cases may be about Mobile Mastery.** Use every passage and every
concept in your catalog at least once.

A **page case** has `"concept": null` and `"page": <index>`: the learner explains that page as
a whole. Only the page's `rubric` and `supporting` sentences count as what the source says.

## 3. Language that defeats word matching

Write explanations whose correctness cannot be judged by counting shared words. Across your
cases include, and tag, at least two of each:

| category tag | what it means |
|---|---|
| `paraphrase` | right, in wording clearly different from the source |
| `oppositeMeaningSameWords` | reuses the source's words but says the opposite or something else |
| `negation` | a negation decides the meaning (right or wrong) |
| `absoluteVsQualified` | "always / never / every / only" where the source is qualified (or correctly qualified) |
| `causeVsCorrelation` | turns "A causes B" into "A and B go together" or the reverse |
| `subjectObjectReversal` | swaps who acts on whom, or which way a relationship goes |
| `rightConclusionWrongReasoning` | right answer, wrong or missing reason |
| `multipleConcepts` | talks about two or more concepts in one answer |
| `partiallyCorrect` | some right, some missing |
| `irrelevantPlausible` | on topic and true-sounding, but not what this source teaches here |
| `misconceptionParaphrase` | a wrong idea stated in the learner's own words, not the source's |
| `exampleInsteadOfDefinition` | explains only through an example or scenario |
| `veryShort` | 1–5 words |
| `verboseOneWrongClause` | 60+ words, all right except one wrong clause |
| `pronounAmbiguity` | "it" / "this" / "they" makes the referent unclear |

Existing tags (`novelVocabulary`, `terse`, `verbose`, `confidentlyWrong`, `hedged`,
`multipleMisconceptions`, `novelExample`, `nearVerbatim`) still apply. Tag every case with
all that apply.

A wrong clause inside a long, otherwise right answer still makes the state `misconception` (or
`weakReasoning` if it is the reason that is wrong). A reversal, a cause turned into a
correlation, or an absolute where the source is qualified is a misconception (kinds:
`reversal`, `contradiction`, `overgeneralization`).

## 4. Size and distribution

Write **40 cases**. The distribution targets of `guide.md` apply. At least 30% of cases must
be in paraphrase groups of 3–4 members, and at least 4 cases must carry two misconceptions.

Before you finish, run the validator and fix every problem it reports:

```
python3 validate_fixture.py <your fixture.json> <your catalog.json>
```
