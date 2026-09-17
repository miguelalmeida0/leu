# LEU — APPROVED NEXT INTELLIGENCE SURFACES

This document exists so the redesign will not have to be redone when the intelligence sprints land.

## Sprint 1: source-grounded intelligence

The design system must naturally support:

### Smart questions

Question types are not all multiple choice. A session may contain:

- open recall;
- multiple choice when distractors are genuinely strong;
- mechanism;
- cause/consequence;
- tradeoff;
- compare;
- prediction;
- application;
- debugging;
- constraint;
- sequence;
- reconstruction;
- explain why.

The UI must not assume every question has four answer buttons.

### Lens 2.0

Possible sections, rendered only when useful:

- What this says
- Why it matters
- How it works
- The key distinction
- Common confusion
- Concrete example
- What this connects to
- Question worth asking

Do not design eight permanent cards. Lens is passage-specific and source-bound.

### Source provenance

Any generated learning object needs an obvious path to its exact source. Provenance can be quiet, but never absent.

### Model state

Normal users should not see backend/token/model jargon. Developer diagnostics may.
Graceful unavailable states should preserve reading instead of turning the whole app into an error screen.

## Sprint 2: adaptive learning

### Learner concept state

Design for meaningful states derived from observed learning behavior, not fake analytics.

### Misconception feedback

Target pattern:

- **You got**
- **You missed**
- **You mixed up**
- **Source**

Example: `You focused on order. The source is describing identity.`

Avoid generic "Almost!" copy.

### Confidence × correctness

Confidence remains distinct from correctness and can change the next study action.

### Adaptive session flow

A future session may deliberately move through:

`warm-up retrieval → weak mechanism → application → misconception repair → spaced strong concept → reconstruction`

Design a session shell flexible enough for heterogeneous activities.

### Cross-document connection

A future connection can show two exact source anchors and a validated relationship:

- explains
- extends
- contrasts
- prerequisite
- same mechanism
- tradeoff

Do not default to a graph visualization.

### Spoken answer

A question may accept a spoken answer, then compare the transcript with source-grounded expected ideas.
The layout must not assume typing is the only open-response path.

### Session summary

Prefer states like:

- Solid
- Improving
- Still shaky
- One thing to revisit

No XP / leaderboard / meaningless streak pressure.

