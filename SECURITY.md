# Security and privacy boundaries

Shelf has no backend, account, telemetry SDK, model, analytics endpoint, or network client in its source. It does not request camera/microphone permissions. Original documents, notes, and derived indexes are local. Native file providers and share destinations are separate system/user choices and may transfer data according to their own settings.

The app uses UUID-owned paths, security-scoped/coordinated import, bounded extraction, validated metadata, streaming digests, explicit backups and non-destructive originals. iOS file protection is applied to the application storage directory. These measures are not a claim of independent security certification or universal end-to-end encryption.

## Threat model

Untrusted PDFs may be malformed, very large, scanned, password-locked or expensive to render. Parsing/rendering is delegated to Apple's PDFKit inside the normal app sandbox. Input size and derived-data limits reduce some resource risk but do not prove every hostile PDF is harmless. Keep iOS updated and retain the source externally during initial testing.

Untrusted backup manifests cannot choose paths. Their schema, IDs, lengths and checksums are validated before native merge. The backup checksum detects corruption; it is not a digital signature and cannot establish who created an archive. Anyone able to rewrite an archive and recompute its hashes can create a structurally valid new archive.

Backups and exported PDFs are **not encrypted by Shelf**. A device backup or file provider's protection depends on account/system settings. Deleting the app removes local app data; deleting a file may not securely erase historical filesystem/device-backup copies. No secure-erasure or redaction guarantee is made.

## Sensitive content

Avoid putting private filenames/text into future logs, crash reports, or analytics. Do not silently index into public system search, upload originals, or add third-party SDKs. This implementation performs in-app search only. The included privacy manifest declares local UserDefaults and file-timestamp APIs; it is not an App Store review approval.

## Release requirements

Native compilation, device file protection behavior, provider imports, recovery, interoperability and accessibility remain explicit release gates. See `docs/RELEASE_CHECKLIST.md`. Security findings should be reproduced against a backup or a disposable test library, never the user's sole original.
