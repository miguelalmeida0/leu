# Shelf visual system

## Approved direction

`approved-visual-reference.png` is the user's chosen **Shelf** concept. It is a design reference, not a screenshot of the running app. The implementation translates its dark editorial bookshelf into native controls and real PDF behavior. No Apple-platform screenshot is represented as verified in this handoff.

The library uses six deterministic Canvas cover illustrations instead of remote images or generated assets. The document title, real page count, and real reading position remain the focus. Every cover opens its PDF; the corner menu provides editing actions without making the entire card ambiguous.

## Tokens

| Token | Value | Use |
|---|---|---|
| Background | `#0C1310` | Near-black forest canvas |
| Surface | `#17201B` | Search and secondary surfaces |
| Raised | `#222D26` | Elevated controls |
| Primary text | `#F1EEE5` | Main headings and controls |
| Secondary text | `#ADBAAE` | Metadata and guidance |
| Accent | `#EBCB76` | Selected tab and intentional actions |
| Destructive | `#EDA79A` | Destructive warnings, not general decoration |
| Paper | `#F6F2E9` | Optional reader surround |
| Horizontal gutter | 22 pt | Shared library alignment |
| Control radius | 14 pt | Consistent utility surfaces |

Typography uses system serif for editorial/book titles and system sans-serif for controls and metadata. Fonts come from iOS; there are no font downloads or bundled font files.

## Interaction rules

A cover is the primary affordance. Import is one explicit plus action. The tabs follow the approved design: Library, Favorites, Recents, Tags, Settings. Collections are filters, not a second filesystem. A book can belong to multiple collections without multiplying its original PDF.

Do not introduce a hero banner, metrics dashboard, chat box, paywall, motivational feed, or artificial readiness score. Empty states explain one useful action. Actual operational failures remain visible; transient success notices dismiss without interrupting reading.

The reader keeps controls near the bottom: page navigation, contents, search, bookmark, markup, notes. Focus mode removes the regular chrome but retains an accessible way to restore it. Important / Review / Confusing are manual study annotations, not AI assessments.

## Adaptation and accessibility

The grid uses two columns on iPhone, three in a regular size class, and one with accessibility text sizes; a compact list is optional. Type and cover height scale with Dynamic Type. Controls have accessible labels and practical touch targets. Reduced-motion preference controls the explicit focus transition.

Device verification must cover the smallest supported display, landscape, iPad, VoiceOver reading order, largest Dynamic Type sizes, long document names, long translations, and contrast over every cover palette. These are implemented intentions plus a required test checklist, not a claim of certification.

## PDF fidelity

PDF pages keep their original fonts, colors, diagrams, layout, and selectable text. The app's reading settings do not pretend a fixed-layout PDF is an EPUB. “Warm” and “Dark” alter the surround only. Reflow and recoloring need a separate design/engineering effort and are intentionally absent.
