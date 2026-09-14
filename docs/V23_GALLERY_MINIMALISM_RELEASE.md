# Leu V23 — Gallery Minimalism release contract

## Center of gravity

Leu is a reading product first. Library, Study, Trails, Connections, Voice and Progress exist to deepen or return to the current source rather than compete as independent dashboards.

## Visual laws

1. Warm paper is the default field; near-black application backgrounds are not part of V23.
2. Serif carries reading, titles and meaningful source content. Sans/monospaced faces are utility only.
3. Ochre = provenance/selection, olive = knowledge/progress, oxblood = decisive action. Accents stay sparse.
4. A rounded container must express state, grouping, or a physical object. Single list rows stay flat.
5. Leu chrome never intentionally obscures source text.
6. Read and Original content must remain inside the actual viewport on every supported device.
7. Return-to-source and return-to-origin controls must be visible whenever Leu has moved the reader away from context.
8. The resume surface uses abstract light/paper only. **No tree, leaf, foliage or tree-shadow visual is permitted.**

## Native route coverage

- Cold open / continue
- Library: All / Favorites / Recents / Tags & Marks / Settings
- Reader: Read / Original / Focus / More / Reading Settings
- Contents: Sections / Pages / Bookmarks
- In-book search + return breadcrumb
- Your Marks + note editing
- Timed Reading
- Voice settings + active playback rail
- Study home
- Question / answer review / inspect source / return to question
- Active Recall / Interview Mode
- Progress Now / Progress History
- Connections / save / refine / cross-library travel
- Trails / trail detail
- Session Complete

## Release gate

`./scripts/qa-and-copy.sh` is the canonical macOS release gate. It preserves the real QA exit status, writes the full log, writes a compact summary, and places the summary on the clipboard with `pbcopy` so it can be pasted back into the Leu engineering conversation immediately.
