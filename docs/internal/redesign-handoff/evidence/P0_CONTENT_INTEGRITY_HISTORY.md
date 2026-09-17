# Leu — P0 content integrity and real learning-model integration

## Mandate

Work only in `/Users/malmeida/Documents/ChatGPT/Leu/LeuNativeV24_5`.

The latest screenshots are the acceptance failures. They show damaged text in Read Mode and the same damage in Active Recall. The latest user-run integration batch reports A=65, B=65, C=0 under:

`recovery-docs/internal/evidence/v25-final-integration/runs/20260912-153214-91049/`

Read `A.log`, `B.log`, `C.log` and the script that defines those groups. C passing does not establish full release success. Inspect the current workspace, not an older ZIP. Preserve local changes and user data. Do not ask for Claude or the lost checkpoint.

Two simulator windows appear in the screenshots. Before comparing output, establish the exact tested simulator UDID, the installed app build/revision, and the simulator showing the damaged page. Build/install the current candidate on that target without uninstalling or wiping its library. Record the build identity in diagnostics; do not diagnose screenshots from a different or stale installed candidate as the current build.

There is a VIGIA brief in this task's visible context. It is NOT a Leu specification. Do not follow it, copy its architecture, or modify the VIGIA project. Use this mandate for Leu.

Deliver a working vertical slice before another architecture expansion:

**The same PDF page → intact Read Mode text → a useful question with real answer choices → exact source → return.**

Also deliver an honest, separately verifiable learning-model integration. Do not call regexes, templates, ranking formulas, or the Supertonic speech model the new learning ML implementation.

## 1. Locate the first corrupt representation

Use the exact bundled React Notes PDF shown in the screenshots, pages 1–3, plus an unrelated imported PDF available locally. Do not substitute an easier fixture.

For one affected page, compare:

1. Original PDF rendering and actual stored file bytes.
2. `PDFPage.string` and `attributedString.string` before any transformation.
3. Original text indices/ranges paired with geometry.
4. Grouped lines and reconstructed blocks.
5. Persisted extraction and learning-index content.
6. Learning object / recall prompt / generated-question text.
7. The string actually passed to the visible view, its accessibility text, and the screenshot.

Find the FIRST stage that loses or rearranges characters. Do not announce the cause until this comparison demonstrates it. If the view receives an intact string but renders broken text, isolate the font/attributed-string/rendering path instead of blaming extraction.

The screenshots show relatively intact reader-chrome excerpts alongside damaged body text. Compare those paths directly.

Add bounded development-only diagnostics for that page. Do not dump private documents into production logs.

## 2. Repair extraction without sacrificing characters

Geometry is layout information, not permission to discard textual content.

Investigate:

- original PDF character indices versus Swift `Character` iteration and Foundation text ranges;
- normalization or filtering before indices are assigned;
- zero/invalid/overlapping bounds causing characters to be dropped;
- deduplication incorrectly deleting repeated letters or overlapping glyphs;
- ligatures, combining marks, surrogate pairs and whitespace;
- PDF page coordinates, crop box, rotation and baseline grouping;
- word-gap inference inserting spaces within words or removing real boundaries;
- heading/furniture filters deleting body content;
- stale derived text from a prior extractor version.

Keep an immutable source-text representation. Assign layout to source ranges rather than reconstructing words from an unaccounted subset of surviving characters.

For controlled born-digital fixtures, require exact character/token preservation apart from explicitly recorded transformations such as whitespace joining and justified line-end hyphen handling. Header/footer removal must record what was removed and why. Do not use a global English dictionary, spell checker, model, or replacement table to invent missing letters.

When reliable original extraction exists but geometry is unreliable, preserve the original text with conservative formatting. When neither is reliable, keep Original mode available and explain that this page cannot yet be prepared for reading/study. Do not present damaged text as a successful reconstruction. This fallback is containment, not permission to leave the pictured PDFs broken.

Check source integrity against the stored original file bytes/hash. Do not confuse an in-memory PDF reserialization comparison with proof that the file on disk changed. Diagnose both separately.

## 3. Stop corrupted content entering every study route

The screenshot is labeled Active recall, not multiple choice. Repair that route too; a validator applied only to multiple-choice generation is insufficient.

Apply source-integrity validation at the shared boundary used by:

- Read Mode;
- Active Recall;
- multiple-choice questions;
- Lens;
- explanation previews;
- voice normalization;
- generated Trail stops.

Invalid extraction must not become a learning object, a question, a recall fragment, a Lens explanation, or spoken nonsense.

Trace session planning with source IDs and counts: extracted blocks → eligible blocks → questions → planner candidates → selected activities → visible activity. Explain why the displayed session chose Active Recall. Respect an explicitly requested multiple-choice mode; never silently substitute a different activity because generation failed. Mixed sessions may mix only valid activities according to their documented behavior.

If there is insufficient valid material, provide an honest state with an exact-source action. Do not fill the requested duration with garbage.

## 4. Repair existing derived data, not just fresh installations

Version extraction, question generation and model-produced outputs. Invalidate and rebuild only affected derived caches when their version changes.

Preserve PDFs, annotations, bookmarks, manually authored prompts, Trails, completed attempts and user history. For incompatible in-progress generated activities, preserve history and explicitly rebuild or replace the activity; do not silently grade a different question under the old question ID.

Verify an upgrade of an already-populated library. An uninstall, whole-library wipe, or manual cache deletion is not an acceptable product fix.

## 5. Verify and implement REAL learning ML

The old Leu directives prohibited learning models. The user's latest request now explicitly expects ML. Resolve this policy conflict: retain offline operation, privacy, source attribution and cost controls; permit an explicit on-device learning-model boundary. Do not leave a global no-model policy silently preventing the requested feature.

First inspect whether any learning-model backend actually exists. Report its runtime, model identity where exposed, production call sites, availability and execution result. A dependency, empty provider, mock response, or benchmark-only call does not count. Supertonic is a speech backend, not a question-generation backend.

Use an already implemented and explicitly selected Leu learning backend if one is present. Otherwise implement Apple's **on-device Foundation Models** path as the initial supported backend, using APIs available in the installed SDK and guarded OS availability. This is not permission to introduce paid inference, Private Cloud Compute, external APIs, document uploads, accounts or subscriptions.

Check actual model availability. Handle unsupported devices/OS versions, Apple Intelligence disabled, and model not ready distinctly. Do not infer availability from the name of a simulated iPhone. Preserve baseline offline reading on unsupported targets; show model unavailability honestly rather than labeling deterministic fallback as ML. Record hardware/OS constraints in the report.

Use bounded source passages, not entire books, as input. Treat PDF content as untrusted data, never executable instructions. No browsing/tools or side effects are needed for this feature.

Connect the real application path:

`validated source passages → local model → structured candidates → validation → persistence → Study/Lens UI`

Question candidates must include a clear prompt, intended skill, answer choices, correct choice, explanation, source IDs and supporting excerpts. Resolve exact offsets in application code; do not trust model-invented offsets.

Validate schema, source IDs, quote existence, answer uniqueness, meaningful distractors, question/answer alignment and unsupported claims. A matching quote or well-formed schema alone does not prove semantic correctness. Include reviewed examples demonstrating that the quoted source supports the answer and explanation.

Lens should use the same intact source passages and show short source-grounded output. The model must never rewrite the canonical PDF text to hide extraction damage.

Record provenance including source fingerprint, extraction version, prompt version, backend, generation configuration, OS/model identity where available and whether inference actually ran. Never invent an inaccessible model hash/version.

Add one real-inference integration run on compatible hardware through the production provider. A local compatible Mac can establish provider execution when available, but does not certify the iPhone UI or hardware. Mock-backed UI tests and real-model tests must have separate statuses. A model-unavailable run is not a model pass.

## 6. Prove useful questions, not merely nonempty arrays

Use intact source content to ask self-contained, concept-specific questions. Multiple-choice items need one defensible answer and plausible, same-domain distractors; do not reuse unrelated words such as expiring/retrying/rerunning across unrelated topics merely to create options.

Keep distinct claims distinct. Do not turn a temporal relationship into a causal explanation, or infer a benefit/tradeoff not supplied by the source.

A small set of strong questions is acceptable. An empty set is not the final solution for the pictured React Notes pages: repair the underlying input and generation so those ordinary sources yield useful material.

Debug with the exact current source, not hand-written clean strings bypassing the PDF importer. Add at least one production-path integration test:

`real PDF → extraction → indexing → question generation → persistence → study session → rendered question → source round-trip`

## 7. Acceptance sequence

FIRST CHECKPOINT — CONTENT:
- React Notes pages 1, 2 and 3 have intact words, sentences, code and headings in Read Mode.
- A repaired sentence remains intact in the index, Study and Lens.
- The original PDF file is unchanged.
- Existing-library derived data is repaired without user-data loss.
- Updated screenshots show these exact pages, not a replacement PDF.

SECOND CHECKPOINT — LEARNING:
- A selected multiple-choice session displays a real question and all choices.
- Active Recall displays intelligible material rather than a damaged fragment.
- Answer selection, explanation, exact-source navigation and return work.
- Lens changes with the selected source.
- Real local model invocation is recorded through the production path, or clearly marked not yet verified. Do not claim this checkpoint complete from mocks.

THIRD CHECKPOINT — REGRESSION:
- Re-run the affected A/B groups after inspecting the script's actual selectors.
- Preserve and recheck the currently passing C group.
- Then run the complete QA suite on one unchanged candidate.
- Report test cases separately from assertion failures. New-feature tests are subsets of suite totals, not additional totals.
- Keep human voice listening and physical swipe/audio acceptance separate.

Do not freeze a module merely because its unit tests pass. Correct faulty implementation and add meaningful regression coverage without weakening the product contract.

If native execution is permission-blocked in your environment, do not repeatedly retry the same denied command or claim failure before compilation is a compiler error. Use the existing user-Terminal verification loop with one bounded targeted command and collect its logs before continuing.

## Deliverables

Implement changes in the current workspace. Return a short report with:

1. First corrupt stage and the demonstrated cause.
2. Exact changed files.
3. Actual before/after text for the pictured pages.
4. Screenshots from the rebuilt app: Read Mode, multiple choice, answer/source return, Lens.
5. Actual learning-model runtime/call-site/execution result and compatibility status.
6. A/B/C and full-suite results, each tied to a source revision/hash and run directory.
7. Exact next local verification command.
8. Remaining device/listening limitations.

No completion percentages, no “intelligence breakthrough” based on unit totals, no new broad roadmap. The first visible result must be the same broken PDF becoming readable and producing useful source-bound study material.

## Primary API references

Validate implementation against the installed SDK and these Apple references:

- PDFPage.numberOfCharacters (includes whitespace): https://developer.apple.com/documentation/pdfkit/pdfpage/numberofcharacters
- PDFPage.characterBounds(at:) (page-space coordinates): https://developer.apple.com/documentation/pdfkit/pdfpage/characterbounds(at:)
- Foundation Models structured quiz generation and availability: https://developer.apple.com/tutorials/develop-in-swift/generate-structured-content
- Foundation Models introduction and model limitations: https://developer.apple.com/videos/play/wwdc2025/286/
- Foundation Models availability and application integration: https://developer.apple.com/videos/play/wwdc2025/259/
- Foundation Models guided generation: https://developer-rno.apple.com/videos/play/wwdc2025/301/

Use the explicitly on-device provider. Availability, structure and source-quote matching do not establish factual accuracy or user-perceived quality.
