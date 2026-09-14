# Explain like I'm 10 — provider, cost and privacy

The reader uses the existing `AppleLearningIntelligenceProvider`, now with an additive
`LearningExplanationCapable` method. It creates Apple's default `LanguageModelSession`
with an empty tool list. There is no hosted provider, paid API, document upload, API key,
or cloud fallback. Supertonic speech is unrelated to this explanation path.

Generation begins on the reader's explicit Explain action. A fresh session receives only
the canonical selected span and, where needed, a same-page heading or adjacent context.
The total span limit is 2,400 UTF-16 units. Source text is JSON encoded and treated as
untrusted data. The versioned bundled prompt is mandatory; a missing or mismatched prompt
fails before inference. Refinements regenerate against the original packet.

The provider checks actual runtime availability. iOS 17 remains the deployment target;
Foundation Models calls require iOS 26/macOS 26 and are guarded by SDK and OS availability.
Unsupported device/OS, disabled Apple Intelligence, or model-not-ready states produce
explicit UI notices. An available model that throws produces a failed state; availability
is not proof of execution. No model revision is invented when Apple exposes none.

The runtime feature contains no network client or telemetry. The source audit now covers
`Shelf/Learning`, `Shelf/Features/ExplainLikeTen`, and core Learning as well as Knowledge
and Voice. This static check passed. **Physical-device network traffic has not been
measured**, so it is not a recorded zero-request performance result.

Runtime diagnostics contain counters, availability, validation codes and error domain/code;
they do not print the selected text, generated text, document name or model transcript.
An explicit developer probe separately records the supplied React sample and source
packets into local `recovery-evidence/explain-like-ten` artifacts for review. That probe
is excluded from all shipping targets.

Explanations and their source packets are intended to persist locally beneath
`Learning/Intelligence/Explanations`, using the existing intelligence-store actor. The
cache is bounded to 24 entries and keyed by document fingerprint, exact canonical range,
all context spans, extraction version, language, mode, schema/validator version, backend
and an actual provider revision if exposed. Disk loads revalidate candidates. Removing
a document prunes only that document's derived explanations; it does not touch originals,
annotations or study history. In-flight results cannot recreate a deleted document's cache.

The real file-store tests could not complete atomic writes in this managed environment
(`NSCocoaErrorDomain 513`). Local persistence and offline reopening are therefore
implemented but **not runtime verified**. No storage workaround or cloud service was added.

The debug-only `--explain-like-ten-harness` argument auto-opens the explanation when a real
reader is opened. It uses the production provider, not synthetic answers. Its use is an
explicit developer test action, not background generation in the shipping reader.
