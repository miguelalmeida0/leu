# Native V17 acceptance

1. Original mode uses horizontal continuous PDFKit paging, not UIPageViewController.
2. A slow or fast horizontal drag at fit scale moves between pages without vertical drift.
3. Bottom previous/next arrows change pages without a white/patch flash.
4. Pulling down inside document content never closes the reader.
5. Pulling the explicit top grabber down closes the book; double tapping it also closes.
6. Focus mode retains the same close-book grabber at the top.
7. Contents shows embedded PDF outline entries when present.
8. PDFs without embedded outlines receive a local inferred section index from page headings.
9. Contents entries navigate to the correct PDF page.
