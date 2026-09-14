# Native V13 Acceptance

Release blockers for this patch:

- Study marker filters remain in one fixed row and do not shift when selection/content changes.
- Original PDF horizontal paging is owned by PDFKit/UIPageViewController; Shelf no longer adds a competing horizontal recognizer.
- PDF paging scroll views use directional lock and fast native deceleration to suppress diagonal drift.
- Read mode horizontal paging requires clear horizontal intent and uses a spring-backed interactive offset.
- A deliberate downward swipe dismisses both Read mode and Original mode back to the library.
- Selecting a collection chip automatically scrolls it fully into view with native snappy animation.
- Vertical scrolling does not trigger a horizontal page turn unless horizontal intent wins decisively.
