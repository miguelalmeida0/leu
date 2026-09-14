# Shelf V21.4 — UI integration and QA repair

V21.4 addresses the eight UI-test failures exposed after the V21.3 Apple compile gate became green.

## Product fixes

- Shelf's five secondary destinations (Library, Favorites, Recents, Tags, Settings) are no longer hidden inside a horizontal scroller. They now remain directly reachable across the iPhone width with an editorial, non-pill selection indicator.
- Learning actions now expose stable semantic identities and concise VoiceOver labels for Remember, Test, Connect, Mask and Explain. Compound descriptive copy is moved into accessibility hints instead of contaminating the control label.
- Question choices now expose explicit answer labels and stable source-independent identifiers.
- Knowledge search refreshes automatically when background local indexing completes while a query is already present.
- Connected Passage updates automatically as passage indexing arrives, and its empty/indexing state keeps the "Related in your library" context visible without inventing weak connections.

## QA corrections

- The UI fixture no longer searches `useEffect` inside the bundled React Notes PDF because that literal token is not present in the sample document. The end-to-end test now uses `setCount`, a real camelCase token in the fixture. Technical-token preservation for `useEffect`, `React.memo`, `Promise.all`, `HTTP/2`, etc. remains covered by deterministic ShelfCore fixtures.
- SwiftUI controls are located through stable semantic identifiers with a generic accessibility fallback when XCUI exports the identifier on a styled semantic element rather than its concrete Button query.

No ranking floor, offline/privacy guarantee, learning persistence, voice normalization, reader gesture behavior, or confirmed-connection semantics were weakened to make the tests pass.
