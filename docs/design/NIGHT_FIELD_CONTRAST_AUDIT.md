# Night Field contrast audit — native certification OPEN

## Source and protected behavior

Built baseline: /Users/malmeida/Downloads/Leu-NightField-Pass1/LeuNativeLatest. Its night-field-build.log ends in BUILD SUCCEEDED for the earlier, unpatched app. The old LeuNativeV24_5 recovery checkout still uses Gallery Minimalism and is not this design's baseline.

Patched review checkout: /Users/malmeida/Documents/ChatGPT/Leu/LeuNightFieldContrast. The original downloaded checkout has not been changed. Its earlier build does not verify this patch.

206 protected files remain byte-identical: core learning/provenance, model providers/prompts/validation, persistence, PDF extraction, voice engines/Pronunciation/Supertonic, reader model and horizontal page-turn implementation. See evidence/protected-paths.json. AppPreferences changes only reader color returns. Reconstruction's post-check display stays active after rearranging so correct positions update progressively; no answer-generation or scoring rules changed.

## Semantic colors before / after

| Role | Before | After |
|---|---|---|
| App / secondary / raised surface | #0B0B0C / #141416 / #1D1D20 | Preserved, explicit semantic roles |
| Primary text | #F3F2EE | Preserved |
| Secondary | #8B8B86 | #B9B9B2 |
| Tertiary | #5F5F5C | #A2A29C |
| Signal / foreground | #C8F135 / local white overrides | #C8F135 / #0B0B0C |
| Pressed signal | Whole-button opacity | Solid #B4D92F / #0B0B0C |
| Disabled control | Ad hoc dimming | #1D1D20 / #B9B9B2 |
| Accent text on light | Bright lime | signalText #365500 |
| Fields | Inherited light mode/default placeholder | #1D1D20 / #F3F2EE / #B9B9B2 placeholder |
| Menu/dialog | Background-dependent native presentation | #1D1D20 / #F3F2EE / #B9B9B2 secondary |
| Meaningful boundary | Faint hairline or faded tint | separator #81817C |
| Success / warning / danger | Unpaired roles | #58D69B / #E8B54A / #F18B79, each paired with #0B0B0C |
| Reader paper | Warm background inherited near-white shell text | #FBF8F2 / #1F1E1B |
| Reader secondary | #6F6A61 | #56534B |
| Reader night | Separate muted raw colors | Semantic dark surface and primary/secondary text |
| Cover text | Six failing pairs across five palettes | Neutral foreground corrections and darker forest/slate ground; all 12 cover pairs pass |

Search and spoken highlights use solid signal with ink. The source text itself is unchanged.

## Actual contrast calculations

scripts/test-night-field-contrast.py reads actual Swift literals and aliases. It calculates sRGB relative luminance and (Llighter + 0.05)/(Ldarker + 0.05). Tests cover black/white 21:1, identical colors 1:1, known #777 contrast/symmetry, 30 canonical pairings, and 12 cover pairings: **45 / 45 PASS**.

Normal text requires 4.5:1; primary and secondary reading/UI roles target 7:1. Meaningful graphics and boundaries require 3:1. Assertions use unrounded ratios.

| Pair | Ratio | Minimum | Result |
|---|---:|---:|---|
| textPrimary / surfacePrimary | 17.56:1 | 7.0:1 | PASS |
| textPrimary / surfaceSecondary | 16.42:1 | 7.0:1 | PASS |
| textPrimary / surfaceRaised | 15.01:1 | 7.0:1 | PASS |
| textSecondary / surfacePrimary | 9.97:1 | 7.0:1 | PASS |
| textSecondary / surfaceSecondary | 9.33:1 | 7.0:1 | PASS |
| textSecondary / surfaceRaised | 8.52:1 | 7.0:1 | PASS |
| textTertiary / surfacePrimary | 7.67:1 | 4.5:1 | PASS |
| textTertiary / surfaceSecondary | 7.17:1 | 4.5:1 | PASS |
| textTertiary / surfaceRaised | 6.55:1 | 4.5:1 | PASS |
| onSignal / signal | 15.07:1 | 7:1 | PASS |
| onSignal / signalPressed | 12.09:1 | 7:1 | PASS |
| menuForeground / menuSurface | 15.01:1 | 7:1 | PASS |
| menuSecondary / menuSurface | 8.52:1 | 7:1 | PASS |
| fieldForeground / fieldSurface | 15.01:1 | 7:1 | PASS |
| fieldPlaceholder / fieldSurface | 8.52:1 | 7:1 | PASS |
| disabledForeground / disabledSurface | 8.52:1 | 4.5:1 | PASS |
| successForeground / success | 10.78:1 | 7:1 | PASS |
| warningForeground / warning | 10.44:1 | 7:1 | PASS |
| dangerForeground / danger | 8.16:1 | 7:1 | PASS |
| readingForeground / readingSurface | 15.73:1 | 7:1 | PASS |
| readingSecondary / readingSurface | 7.24:1 | 7:1 | PASS |
| signalText / readingSurface | 8.07:1 | 7:1 | PASS |
| signal / fieldSurface | 12.88:1 | 3:1 | PASS |
| success / surfaceRaised | 9.21:1 | 3:1 | PASS |
| separator / fieldSurface | 4.30:1 | 3:1 | PASS |
| separator / surfacePrimary | 5.03:1 | 3:1 | PASS |
| separator / surfaceSecondary | 4.70:1 | 3:1 | PASS |
| separator / menuSurface | 4.30:1 | 3:1 | PASS |
| danger / menuSurface | 6.97:1 | 4.5:1 | PASS |
| untested / surfaceRaised | 5.43:1 | 3:1 | PASS |

Measured failures: **0 in the 42 tested color pairs**. Application-wide rendered WCAG failures remain UNKNOWN; this is not screen certification.



### Cover text pairings

| Pair | Before colors | Before ratio | After colors | After ratio |
|---|---|---:|---|---:|
| ocean foreground | #203033 / #B7C2C2 | 7.51:1 | #203033 / #B7C2C2 | 7.51:1 |
| ocean muted | #536568 / #B7C2C2 | 3.36:1 | #334746 / #B7C2C2 | 5.40:1 |
| graphite foreground | #F5F1E8 / #4B4A46 | 7.87:1 | #F5F1E8 / #4B4A46 | 7.87:1 |
| graphite muted | #D3CEC3 / #4B4A46 | 5.66:1 | #D3CEC3 / #4B4A46 | 5.66:1 |
| ivory foreground | #26241F / #E9E4D9 | 12.23:1 | #26241F / #E9E4D9 | 12.23:1 |
| ivory muted | #6C675E / #E9E4D9 | 4.43:1 | #59544C / #E9E4D9 | 5.92:1 |
| forest foreground | #FAF6ED / #69705A | 4.79:1 | #FAF6ED / #4A503D | 7.77:1 |
| forest muted | #DFE2D7 / #69705A | 3.93:1 | #DFE2D7 / #4A503D | 6.38:1 |
| sand foreground | #332A22 / #D8C4A4 | 8.26:1 | #332A22 / #D8C4A4 | 8.26:1 |
| sand muted | #625647 / #D8C4A4 | 4.20:1 | #4D4033 / #D8C4A4 | 5.89:1 |
| slate foreground | #FAF7F0 / #77756E | 4.31:1 | #FAF7F0 / #54534E | 7.20:1 |
| slate muted | #E0DDD4 / #77756E | 3.40:1 | #E0DDD4 / #54534E | 5.68:1 |

## Every changed component / file

- Shelf/App/RootView.swift
- Shelf/App/ShelfApp.swift
- Shelf/DesignSystem/LeuAccessibleSurfaces.swift
- Shelf/DesignSystem/LeuComponents.swift
- Shelf/DesignSystem/LeuDesign.swift
- Shelf/DesignSystem/LeuPrimaryButtonStyle.swift
- Shelf/DesignSystem/ReaderTrackingSlider.swift
- Shelf/DesignSystem/ShelfControls.swift
- Shelf/DesignSystem/ShelfTheme.swift
- Shelf/Features/Collections/CollectionsSheet.swift
- Shelf/Features/Collections/TagsScreen.swift
- Shelf/Features/ExplainLikeTen/ExplainLikeTenSheet.swift
- Shelf/Features/Library/BookDetailsSheet.swift
- Shelf/Features/Library/Components/BookActionsMenu.swift
- Shelf/Features/Library/Components/BookTile.swift
- Shelf/Features/Library/Components/CollectionFilterBar.swift
- Shelf/Features/Library/Components/LibraryHeader.swift
- Shelf/Features/Reader/Components/ReadContinuousDocumentView.swift
- Shelf/Features/Reader/Components/ReadPageContent.swift
- Shelf/Features/Reader/Components/ReaderBottomBar.swift
- Shelf/Features/Reader/Components/ReaderStateSheet.swift
- Shelf/Features/Reader/Components/ReaderStudyDrawer.swift
- Shelf/Features/Reader/Components/ReaderTextSizeMenu.swift
- Shelf/Features/Reader/Components/ReaderTopBar.swift
- Shelf/Features/Reader/Components/SemanticZoomSurface.swift
- Shelf/Features/Reader/Components/TimedReadingSheet.swift
- Shelf/Features/Reader/NoteEditorSheet.swift
- Shelf/Features/Reader/ReaderNotesSheet.swift
- Shelf/Features/Reader/ReaderScreen.swift
- Shelf/Features/Reader/ReaderSearchSheet.swift
- Shelf/Features/Settings/SettingsScreen.swift
- Shelf/Features/Settings/TrashSheet.swift
- Shelf/Knowledge/Components/ConceptDetailSheet.swift
- Shelf/Knowledge/Components/ConnectedPassageSheet.swift
- Shelf/Knowledge/Components/ConnectionConstellationSheet.swift
- Shelf/Knowledge/Components/KnowledgeSearchSheet.swift
- Shelf/Knowledge/Components/TopicChainScreens.swift
- Shelf/Learning/Components/PrimaryTabBar.swift
- Shelf/Learning/Components/ReleaseSurface.swift
- Shelf/Learning/ConnectionsSheet.swift
- Shelf/Learning/DiagramMaskEditor.swift
- Shelf/Learning/DiagramRecallStudyView.swift
- Shelf/Learning/DocumentTopicsSheet.swift
- Shelf/Learning/ExplanationRecorderSheet.swift
- Shelf/Learning/InterviewSetupSheet.swift
- Shelf/Learning/LabRunPreview.swift
- Shelf/Learning/LabScreen.swift
- Shelf/Learning/LearnTodayScreen.swift
- Shelf/Learning/LearningStateSheet.swift
- Shelf/Learning/LearningTimelineSheet.swift
- Shelf/Learning/MemoryMarginMarkers.swift
- Shelf/Learning/QuestionCardView.swift
- Shelf/Learning/SessionCompleteView.swift
- Shelf/Learning/TrailDetailScreen.swift
- Shelf/Learning/TrailsScreen.swift
- Shelf/Learning/UnderstandingLensSheet.swift
- Shelf/Support/AppPreferences.swift
- Shelf/Voice/UI/VoicePlayerStrip.swift
- Shelf/Voice/UI/VoiceSettingsSheet.swift
- Shelf.xcodeproj/project.pbxproj
- evidence/project-manifest.json
- scripts/check-night-field.py
- scripts/sync-xcode-sources.py
- scripts/test-night-field-contrast.py
- scripts/verify-night-field-contrast.sh

- ShelfButtonStyle and LeuSignalButton share LeuPrimaryButtonStyle's normal, pressed and disabled pairings.
- LeuMenu provides an opaque scrollable popover with explicit close/escape, inline selection, original callbacks, destructive role color and readable disabled actions.
- LeuDialog replaces native alert/confirmation presentation with opaque scrollable sheets, preserving original bindings, callbacks and messages.
- LeuTextField renders explicit input/placeholder/focus colors. The shell and sheets use dark mode; light reading surfaces explicitly use ink.
- LeuStepIndicator puts confirmed green checks inside the item's own circle. Unresolved/wrong positions remain neutral; it does not reveal other positions.
- Core headings, reading text and metadata scale with Dynamic Type. Navigation/confidence labels grow; reconstruction previews use a vertical layout at accessibility sizes. Default/AX1 certification remains pending.

Source occurrences removed: **8 white-on-lime**, **0 explicit Material** (none existed in source). **13 native menu/context-menu** and **16 native alert/confirmation** presentations now have owned opaque surfaces. These are source counts, not runtime instance counts.

Former white-on-lime source locations:
- Shelf/DesignSystem/ShelfControls.swift:10
- Shelf/Learning/LearningStateSheet.swift:64
- Shelf/Learning/QuestionCardView.swift:222
- Shelf/Learning/LearnTodayScreen.swift:123
- Shelf/Learning/LearnTodayScreen.swift:155
- Shelf/Features/Library/Components/CollectionFilterBar.swift:51
- Shelf/Features/Library/Components/LibraryHeader.swift:165
- Shelf/Features/Reader/Components/ReaderBottomBar.swift:96

## Every remaining intentional opacity / blur

No explicit Material surfaces remain. Readability-critical surfaces and text use explicit solid colors.

| Location | Reason |
|---|---|
| Shelf/DesignSystem/CoverIllustration.swift:29 | Decorative cover illustration, hatch, or edge; readable cover content uses solid fills. |
| Shelf/DesignSystem/CoverIllustration.swift:40 | Decorative cover illustration, hatch, or edge; readable cover content uses solid fills. |
| Shelf/DesignSystem/CoverIllustration.swift:44 | Decorative cover illustration, hatch, or edge; readable cover content uses solid fills. |
| Shelf/DesignSystem/CoverIllustration.swift:69 | Decorative cover illustration, hatch, or edge; readable cover content uses solid fills. |
| Shelf/DesignSystem/CoverIllustration.swift:76 | Decorative cover illustration, hatch, or edge; readable cover content uses solid fills. |
| Shelf/DesignSystem/LeuComponents.swift:132 | Decorative cover illustration, hatch, or edge; readable cover content uses solid fills. |
| Shelf/DesignSystem/ShelfTheme.swift:55 | Unused compatibility helper for decorative card strokes, not typography. |
| Shelf/Features/Library/Components/LibraryHeader.swift:176 | Decorative cover illustration, hatch, or edge; readable cover content uses solid fills. |
| Shelf/Features/Library/Components/LibraryHeader.swift:178 | Decorative cover illustration, hatch, or edge; readable cover content uses solid fills. |
| Shelf/Features/Opening/OpeningDustView.swift:6 | Decorative entrance image/dust animation, not a readable surface. |
| Shelf/Features/Opening/OpeningExperienceView.swift:26 | Decorative entrance image/dust animation, not a readable surface. |
| Shelf/Features/Reader/ReaderScreen.swift:140 | Dismissal scrim only; panel text has a separate opaque surface. |
| Shelf/Learning/Components/ShelfSectionSwitcher.swift:43 | Decorative hairline in legacy section switcher, not state information. |

Decorative hairlines retain the original low-contrast line token. Meaningful field/control/step boundaries use separator or state tokens.

## Automated verification and build results

| Check | Result |
|---|---|
| python3 scripts/check-night-field.py | PASS; regression alarms, not accessibility proof |
| python3 scripts/test-night-field-contrast.py | 45 / 45 PASS |
| python3 scripts/validate.py | PASS; native membership, 551 project objects, resources and structural checks |
| Shared component iOS SDK typecheck | PASS |
| Changed-view typecheck against real compiled production model module | PASS at recorded checkpoint; inputs/log in evidence |
| Full app source typecheck | BLOCKED: Observation macro plugin sandbox_apply denial |
| Required xcodebuild build | BLOCKED, exit 74 before compilation |
| Relevant native UI tests | BLOCKED, exit 74 before launch |
| Default / AX1 visual certification | 0 / 16 |

CoreSimulator is unavailable to this session and Xcode's temporary package-lock access is denied. The lock error is not proof of malformed Package.resolved contents. No existing tests were modified or weakened. The existing UI tests were requested but never launched; no passing/skip counts are inferred.

The changed-view check uses the existing real compiled model module, not mocks. It is not an app build/link or runtime check. Temporary validation copies import the module. Identical pre-existing View extensions come from that module to avoid duplicate declarations; production files are not altered for this check.

## Screenshot inventory

No synthetic images or old screenshots are presented as results.

| No. | Screen | Default | AX1 | Certification |
|---|---|---|---|---|
| 01 | Library | Not captured | Not captured | NOT CERTIFIED |
| 02 | Library menu open | Not captured | Not captured | NOT CERTIFIED |
| 03 | Study home | Not captured | Not captured | NOT CERTIFIED |
| 04 | Trails | Not captured | Not captured | NOT CERTIFIED |
| 05 | New Trail | Not captured | Not captured | NOT CERTIFIED |
| 06 | Reader | Not captured | Not captured | NOT CERTIFIED |
| 07 | Reader menu / controls | Not captured | Not captured | NOT CERTIFIED |
| 08 | Understanding Lens | Not captured | Not captured | NOT CERTIFIED |
| 09 | Explain Like I'm 10 | Not captured | Not captured | NOT CERTIFIED |
| 10 | Active Recall | Not captured | Not captured | NOT CERTIFIED |
| 11 | Interview Mode | Not captured | Not captured | NOT CERTIFIED |
| 12 | Question screen | Not captured | Not captured | NOT CERTIFIED |
| 13 | Reconstruction exercise | Not captured | Not captured | NOT CERTIFIED |
| 14 | Settings | Not captured | Not captured | NOT CERTIFIED |
| 15 | Voice settings | Not captured | Not captured | NOT CERTIFIED |
| 16 | Error / unavailable state | Not captured | Not captured | NOT CERTIFIED |

## Unresolved

1. Fresh native build and relevant UI tests cannot execute in this session because CoreSimulator and Xcode temporary-lock access are denied.
2. All 16 screens need current default/AX1 visual inspection: menu opacity, text/placeholder readability, selected/disabled/pressed/focus states, clipping and native controls.
3. Custom menu/dialog dismissal, keyboard behavior and accessibility focus restoration require runtime verification. The application-wide WCAG failure count remains UNKNOWN.

Run bash scripts/verify-night-field-contrast.sh locally from the patched review checkout. It runs static checks, native build and relevant UI tests, exporting actual screenshot attachments into timestamped evidence. Existing UI tests use the separate Shelf-UITests store; the normal library is not reset. The script does not automatically certify screenshots.

The pass remains **OPEN** until the real simulator UI has been reviewed. The exact patch is evidence/night-field-contrast.patch.
