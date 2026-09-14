# Shelf backup v1

`.shelfbackup` is a documented, uncompressed streaming container. It is not a ZIP, not an encrypted vault, and not a dependency on a cloud provider. PDFs remain ordinary PDF bytes.

## Byte layout

```text
15 bytes     UTF-8 magic: SHELF-BACKUP\n1\n
8 bytes      Unsigned 64-bit LITTLE-ENDIAN JSON manifest length
N bytes      UTF-8 JSON manifest
variable     Original PDF bytes, concatenated in manifest.originals order
EOF          No trailing bytes allowed
```

The magic length is exactly the UTF-8 length of `SHELF-BACKUP\n1\n` (15). There is no compression, filename entry, arbitrary path, or per-file header after the manifest.

The manifest contains `version: 1`, `exportedAt`, `library` (a complete version-1 LibrarySnapshot), and `originals`, an ordered array of `{ id, size, fingerprint }`. IDs are UUIDs, sizes are positive Int64 byte counts, and fingerprints are lowercase SHA-256 hexadecimal strings. Swift's default JSON date strategy stores seconds relative to January 1, 2001; readers must not interpret those numbers as Unix timestamps.

The snapshot contains books, collections, annotations, bookmarks, and the sample-seeding flag. Book metadata holds the original filename and display title separately. UI preferences and disposable search indexes are not included. Trashed PDFs remain included until permanently deleted.

## Limits and checks

Manifest length is capped at 32 MiB. Each document is capped at 1 GiB. Restore rejects inconsistent/duplicate identities, invalid metadata, unsupported schema/archive versions, incorrect lengths, failed SHA-256 hashes, truncated data, or trailing data. Archive-provided names never become output paths.

Extraction is staged into a fresh temporary directory. Native restore changes the library only after verification and merge planning. A repeated restore is idempotent for unchanged identities; existing local metadata and edits win rather than being overwritten by older backup content.

## Independent extraction

Python 3 is needed only for this optional recovery utility, not for running the app:

```bash
python3 scripts/unpack-backup.py "/path/to/My Library.shelfbackup" "/path/to/recovered-shelf"
```

The destination must not already exist. The extractor validates hashes and writes `Originals/<UUID>.pdf` plus `manifest.json`. Look up human titles in that JSON. It extracts files; it does not claim to render sidecar annotations into PDFs. Use Shelf's annotated-export feature for an already annotated PDF.

Treat extracted JSON and archives as private documents. Shelf adds no password or encryption layer. Store them appropriately and test recovery before deleting the only installed library.
