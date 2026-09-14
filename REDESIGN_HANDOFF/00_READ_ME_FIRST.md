# LEU — CLAUDE REDESIGN HANDOFF (LATEST PRODUCT STATE)

**Date:** 2026-09-12

This bundle is the redesign source of truth for Claude.

## Critical: what this bundle is and is not

- It contains the **latest verified Leu product/technical state, approved redesign direction, feature matrix, UX rules, merge boundaries, current evidence, and the approved next intelligence surfaces**.
- The exact current Swift workspace lives on the user's Mac at:
  `/Users/malmeida/Documents/ChatGPT/Leu/LeuNativeV24_5`
- ChatGPT does **not** have filesystem access to that Mac path, so this handoff bundle does **not pretend** to contain the latest source code.
- Run `./PACK_CURRENT_SOURCE_FOR_CLAUDE.sh` from this extracted bundle to create the **real final source + handoff ZIP** from the live workspace. That is the ZIP Claude should implement against.
- **Do not use any older V24.5/V25 ZIP as the implementation baseline.** They predate the latest extraction-v4, real Apple on-device intelligence, Explain-like-10 production integration, schema-v3 example path, and current UI verification.

## Current truth that supersedes older docs

Older Leu documentation may say **NO AI / NO ML**. That is obsolete for the learning-intelligence layer.

Current locked policy:

- local/on-device model intelligence is allowed and desired when it materially improves learning;
- default recurring model cost target is €0;
- no required cloud/backend/account;
- PDF/source data remains local by default;
- model output is a candidate, never truth;
- deterministic source binding, validation, persistence and rejection remain mandatory;
- reading remains the heart of Leu.

Read in this order:

1. `01_CURRENT_VERIFIED_STATE.md`
2. `02_CLAUDE_REDESIGN_MANDATE.md`
3. `03_FEATURE_MATRIX.md`
4. `04_LOCKED_DESIGN_RULES.md`
5. `05_MERGE_BOUNDARIES.md`
6. `06_APPROVED_INTELLIGENCE_SURFACES.md`
7. `07_SCREEN_INVENTORY_AND_ACCEPTANCE.md`
8. `references/README.md`

