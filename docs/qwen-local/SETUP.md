# Run the local integration

This is an experimental branch, disabled by default. A successful build is not
device certification. See the final comparison report before choosing a model.

## Exact local build and device procedure

On this Mac, from Terminal:

```sh
cd /Users/malmeida/Documents/ChatGPT/Leu/LeuQwenLocal
python3 scripts/prepare-qwen-native.py --platform all
open Shelf.xcodeproj
```

The preparation script verifies the pinned llama.cpp archive and builds the
macOS, iPhoneOS and simulator frameworks, including headers and license notices.
It downloads no weights. It uses Xcode at `/Applications/Xcode.app` and CMake
4.1.0 already installed under this workspace's `.qwen-local/build-tools`.
For a fresh checkout, install that build dependency first:

```sh
mkdir -p .qwen-local/tmp
TMPDIR="$PWD/.qwen-local/tmp" python3 -m pip install --target .qwen-local/build-tools cmake==4.1.0
```

In Xcode:

1. Select **Shelf**, select the actual connected iPhone, confirm the existing
   development signing team, and Run. Record the phone model, OS and available
   memory; none was inferred from the simulator name or Mac.
2. Open a PDF passage and **Teach Leu**. Select **Download**, review the exact
   1,280,835,840-byte size, and confirm. Alternatively choose **Import model file**
   for the approved `Qwen3.5-2B-Q4_K_M.gguf` from `.qwen-local` on this Mac.
3. Enable **Offline model** for this app session. Disable networking on the
   phone. Submit a natural explanation and inspect the provider label, feedback
   and quoted source links. A refusal or fallback message is not a Qwen pass.
4. Edit during a request, cancel, and submit again. Verify the exact draft
   survives and a cancelled result cannot replace the newer one.
5. Select **Read this passage**, change pages, return to Teach, then background
   and reopen. Repeat while recording Instruments process footprint, thermal
   state, load/prompt/first-token/validated-feedback time, and reader interaction.
6. Remove the download. Verify the model-file bytes reported removed, that
   existing Teach still works, and that reading, annotations and drafts remain.

The current resource policy defers Qwen whenever Supertonic resources are
available. Coexistence is not certified. It also refuses low available memory
and serious/critical thermal state. Do not change entitlements or delete learner
data to get past these guards. A phone that cannot execute under this policy
remains unsupported by this experimental build.

## Mac reproduction

The native provider uses local libraries directly; it does not start an HTTP
server. CPU comparisons are explicitly distinct from the iOS Metal path.

```sh
cd /Users/malmeida/Documents/ChatGPT/Leu/LeuQwenLocal
LEU_QWEN_BUILD_NAME=host-final python3 scripts/qwen-host-build.py
python3 scripts/run-qwen-comparison.py --output-directory docs/qwen-local/local-replay
```

The comparison checks its frozen source/binary identities and never overwrites
existing results. It skips a completed matching run, rejects a partial run, and
never silently retries or downloads another model. Source changes after the
freeze require a new, explicitly named evaluation; do not delete the evidence
to reuse the old “unseen” label.

This run had an explicitly recorded host slowdown. Its interrupted 4B case was
preserved; `run-qwen-comparison.py --skip-4b` completed the remaining 2B probes.
`qwen-resume-4b.py` then attempts only unstarted 4B cases with a per-process
watchdog. That continuation is documented in `HOST_SLOWDOWN.md`; it is not a
silent retry or a strictly identical timing protocol.

Focused host checks, after the comparison and with no other inference running:

```sh
python3 scripts/qwen-runtime-checks.py --output docs/qwen-local/local-replay/lifecycle.json
python3 scripts/qwen-draft-checks.py --output docs/qwen-local/local-replay/drafts.json
python3 scripts/qwen-draft-checks.py --source-excerpts --output docs/qwen-local/local-replay/excerpts.json
```

They refuse to overwrite existing JSON evidence. The lifecycle run has a known
failed long-input semantic check; its one explicit diagnostic repeat is preserved
separately. A clean process exit must not be inferred from the passing cancellation
checks alone. Choose a new explicitly named evidence destination for another
run; do not delete the recorded failure to get a green result.

Models must be installed explicitly. Example for the first candidate only:

```sh
python3 scripts/qwen-artifacts.py 2B --download
```

The same command accepts `0.8B` or `4B`, each with `--download` required if absent.
The manifest contains the exact sizes and checksums. The 4B model is a Mac
reference and is not offered by the phone's model installer.

## Evidence limits

- Native framework builds and iOS Swift module compilation of all three local
  packages executed here, including the final persistence and exact-excerpt changes.
- Full app build stopped at Xcode package resolution (`permissionDenied`).
- Standalone installer type checking encountered the unavailable Observation
  macro plugin. This is not an installer compile or interaction pass.
- CoreDevice discovery failed. Physical iPhone and simulator journeys remain
  pending; no screenshot, phone speed or phone memory result is claimed.
- The existing 74-test historical UI suite was not run.

No API key, Python process, Ollama, Mac server or cloud account is required by
the phone's inference path after installation.
