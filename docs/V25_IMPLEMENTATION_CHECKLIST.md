# Reconstruction checklist

The external recovery report arrived during reconstruction and is preserved verbatim in `reference/V25_CLAUDE_RECOVERY_REPORT.md`. The prior local recovery report records intake failures, not Claude's implementation. This checklist uses the user's September 12 reconstruction specification, that recovered report, and the supplied root-cause matrix. The user's later quality requirements supersede the recovered report's admitted limitations.

| Area | Before reconstruction | Required delta |
| --- | --- | --- |
| Read Mode | Newline splitting and four fixture repairs | Glyph model/extractor, line grouping, columns, classifier, reconstructor, debug diagnostics |
| Questions | Curated extraction, computed score/floor present | General claims, explicit intents, realization, language/teaching gate, importance used by selection, 100+ fixtures |
| Voice | One segment per utterance, adaptive pitch/delays | Paragraph builder, sentence ranges, range delegate, neutral defaults, quality notice, 53+ debug samples |
| Contents | Only page grid restores | Stable active section and centred restoration, remembered tab |
| Lens | Source passage and source links present | Plain meaning with evidence, key idea, progressive sections, differentiation tests |
| Trails | Type words present, Required/Optional toggle | Remove meaningless toggle, sequence/source labels, Continue and retained position, add confirmation |
| Dark | Night tokens, Read Mode propagation present | Preserve and exercise |
| Confidence | Equal width, 44pt, single line, accessibility stack present | Preserve and exercise smallest layout |
| Original paging | 1.15 axis, velocity thresholds, selection clearing present | Preserve and add policy matrix, retain physical proof boundary |

Existing tests are preserved. Completion and proof are recorded in `V25_RECOVERY_REPORT.md`; a checked implementation is never a claim of physical verification.
