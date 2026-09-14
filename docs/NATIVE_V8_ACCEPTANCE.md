# Native V8 acceptance

Release blockers addressed in V8:

- Both the top-right + button and empty-library Import PDFs action call one local import action.
- PDF selection uses `UIDocumentPickerViewController(forOpeningContentTypes: [.pdf], asCopy: true)`.
- Multiple selection is enabled.
- Picker cancellation cleanly dismisses without changing library state.
- Successful selections enter the existing staging/import pipeline and surface import progress/errors.
- Opening experience uses opacity only: no image scale, camera movement, blur, zoom, or synthetic handoff shape.
- Cold launch timing: 250 ms dark hold, ~720 ms fade in, ~2.3 s fully-visible hold, ~850 ms crossfade out.
- Reduced Motion uses a short static hold and opacity crossfade only.
- V6/V7 horizontal PDF paging, study marks, text sizing, and voice behavior remain unchanged.
