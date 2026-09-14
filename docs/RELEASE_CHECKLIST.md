# Native release acceptance

Status at delivery: **Apple-platform checks below have not been executed.** Check boxes only after observing the behavior on the named device/build. Keep a backup outside the app throughout qualification.

## Build and install

- [ ] `./run.sh` builds, installs and launches on a clean available simulator.
- [ ] `./scripts/test-core.sh` passes on the development Mac.
- [ ] `./scripts/test-ios.sh` passes; save the `.xcresult`.
- [ ] Install with a Personal Team on the actual iPhone; cold launch after reboot.
- [ ] Repeat installation without uninstalling; verify documents and notes remain.
- [ ] Verify signing renewal at expiry with the same identity and bundle ID.

## Ownership and reliability

- [ ] Import from Files, Safari, Mail and a downloaded ChatGPT attachment using available provider/open-in paths.
- [ ] Test multiple import, exact duplicates, a duplicate previously in Trash, and canceled provider download.
- [ ] Test invalid, empty, password-locked, missing and oversized inputs; every failure is understandable.
- [ ] Background/terminate during import; no false Saved state or missing original.
- [ ] Save a note, terminate immediately after acknowledgment, relaunch, verify it remains.
- [ ] Verify page, zoom, destination, bookmark and recency after close/reopen/rotation.
- [ ] Fill disk or simulate file protection/write failure; no false success or destructive reset.
- [ ] Airplane-mode relaunch opens every document already imported locally.

## Reader and interoperability

- [ ] Select/highlight/underline with a finger; include multiline and cross-page selections.
- [ ] Add page-only notes to scanned pages; exercise Important / Review / Confusing.
- [ ] Undo/redo a multi-page mark; reopen to verify the committed state.
- [ ] Search accented, emoji and non-Latin text; passage links target the correct region.
- [ ] Test both navigation modes and the embedded outline/thumbnail/bookmark panels.
- [ ] Test 1,000+ pages, image-heavy scans, landscape pages, long code and uncommon fonts.
- [ ] Open annotated exports in Apple Preview and another PDF reader; verify note/highlight portability.
- [ ] Compare original-export hash to imported-original hash.

## Backup and recovery

- [ ] Export a `.shelfbackup` outside the app; close/relaunch before restoring.
- [ ] Restore to a fresh separate installation and verify PDF hashes, notes, collections, positions and bookmarks.
- [ ] Restore the same backup twice; no duplicate books or notes.
- [ ] Merge with newer local edits; local edits remain intact.
- [ ] Reject truncated, corrupted or wrong-format backups without modifying the library.
- [ ] Trash/restore; then confirm permanent deletion and checkpoint recovery behavior.
- [ ] Extract with `scripts/unpack-backup.py` and open the ordinary PDFs independently.

## Design, access and performance

- [ ] Inspect actual screenshots against the approved Shelf reference, not generated marketing mockups.
- [ ] Inspect smallest iPhone, largest Dynamic Type, landscape, iPad and VoiceOver.
- [ ] Every icon/button is named and reachable; no trapped focus or hidden primary action.
- [ ] Book titles remain legible across six palettes; long titles do not cover the menu.
- [ ] All sheet errors remain visible within the sheet, including disk/write failures.
- [ ] Measure scrolling/search/thumbnail memory on the slowest supported phone, not just a simulator.
- [ ] Verify no unintended content/filename network logging and no camera/mic permission prompts.

## Sign-off record

Build / commit: ____________________
Xcode + SDK: _______________________
Device + iOS: ______________________
Core / native / UI results: _________
Backup restore evidence: ___________
Known limitations accepted: _________
