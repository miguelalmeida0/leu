# CLAUDE — FULL LEU REDESIGN MANDATE

You are taking over **presentation, interaction design and SwiftUI product UX**, not the learning engine.

The current Leu implementation already contains months of product and technical work. Your job is to make it feel like an extraordinary consumer product without deleting, simplifying away, or re-implementing its intelligence.

## Objective

Create a complete, coherent, visually exceptional Leu redesign that can become the new product shell for the current app and the approved next intelligence surfaces.

The redesign should feel:

- unmistakably Leu;
- premium enough for an Awwwards-level case study while remaining a real usable native iPhone app;
- youthful without becoming childish;
- dynamic without becoming noisy;
- editorial and tactile rather than dashboard-like;
- alive and interactive without generic "AI product" tropes.

## Approved quality reference

The `references/night-field-*.png` images are the strongest approved visual direction so far.

Use their strengths:

- confident typography;
- severe hierarchy;
- minimal persistent navigation;
- strong use of black/graphite plus a high-energy accent;
- source/learning data made visually expressive rather than wrapped in generic cards;
- information density that still feels deliberate;
- a sense that the product has its own visual language.

Do **not** copy them pixel-for-pixel. The redesign may be light, dark, or adaptive. Palette is open. The reference is about product taste and visual confidence, not a mandatory dark theme.

## Do not create a concept-only prototype

Implement against the **actual latest source snapshot** produced by `PACK_CURRENT_SOURCE_FOR_CLAUDE.sh`.

Do not replace real data with fake JSON in production.
Do not create a parallel toy app.
Do not recreate the intelligence engine.
Do not downgrade features because they are hard to redesign.

## Working branch / isolation

Create a new isolated branch/worktree such as:

`claude/leu-redesign-system`

Do not rewrite the active Codex/intelligence branch history.
Do not stash/reset/clean away unrelated work.
Do not deploy or push unless explicitly asked.

Prefer one final coherent commit after the redesign passes its verification rather than a pile of noisy partial commits.

## Implementation order

1. Audit existing source, design tokens, navigation ownership and feature presentation.
2. Build a single Leu design-system layer: color, type, spacing, radius, borders, motion, haptics, semantic state colors.
3. Redesign shell/navigation.
4. Redesign Library.
5. Redesign Reader / source interaction.
6. Redesign Explain Like I'm 10 + Lens presentation.
7. Redesign Study landing + active session.
8. Redesign question/reconstruction/feedback states.
9. Redesign Trails / connections.
10. Redesign Settings only enough to make it coherent with the new system.
11. Verify Dynamic Type, VoiceOver order, 44pt targets, smallest supported iPhone, dark/light if both exist.
12. Capture real simulator screenshots of all acceptance screens.

## Product rule

If the redesign forces a choice between spectacle and reading clarity, reading wins.

