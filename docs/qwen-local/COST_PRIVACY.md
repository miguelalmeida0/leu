# Cost, distribution and privacy

## Inference

Local inference has no per-request service charge. The native wrapper receives
only a verified model path, bounded source/learner input, schema, and resource
limits. It exposes no HTTP, tool, shell, account or key interface. There is no
cloud fallback. Python is a Mac development/build helper, never an iOS dependency.

The first upstream development `llama-cli` attempt used that tool's internal
server architecture and failed before generation. The successful initial smoke
used `llama-completion`; the app provider uses `leu_qwen_run` directly. No private
PDF or learner data was used in development diagnostics. Benchmark inputs are
explicitly authored local fixtures. Production code suppresses native logging
and does not persist raw model output or prompts in diagnostics.

## Distribution

Selected host: the public Unsloth Qwen3.5 GGUF repository on Hugging Face, using
an immutable revision URL. The 2B artifact was downloaded without an account or
token on 2026-09-15. No paid host, CDN, account, or subscription was provisioned.
The host sees ordinary download metadata such as IP address; it receives no
source passages or learner explanations through the inference path.

[Hugging Face rate-limit documentation](https://huggingface.co/docs/hub/rate-limits)
defines separate API, resolver and page buckets over five-minute windows and
429 responses when exhausted. Anonymous/free quotas can change with platform
health. This is an existing public distribution arrangement, not a promise of
unlimited availability or a service-level agreement. The app makes one attempt
per explicit Download action and supports resumption when URLSession provides
resume data. On failure, existing Teach remains available and local import is
offered. There is no automatic upgrade or alternative multi-gigabyte download.
Use is also subject to [the host's terms](https://huggingface.co/terms-of-service).

The quantizer card names official post-trained Qwen weights and Apache-2.0.
It does not identify its exact conversion commit. The manifest records observed
upstream and exact quantization revisions separately; they are not represented
as a cryptographically proven conversion chain. No local conversion is claimed.

## Device resources and storage

2B weights occupy exactly 1,280,835,840 bytes. Install checks require twice that
plus a 128 MiB margin for staging and final storage. Actual writes may still
fail safely if free space changes. Full process memory also includes context,
Metal/runtime buffers, rendering, indexes and voice resources. GGUF size is not
a memory ceiling. Battery, heat, storage and network data remain real costs.

Weights are optional Application Support assets excluded from backup. Checksum
verification happens before atomic promotion and again before inference. Removal
touches only the model and its resume file, never learner or document data.
The model is disabled on every new app session. App-wide memory warnings,
backgrounding, thermal pressure, edits and cancellation stop the request; native
state is released when its generation loop exits. Physical measurements are
still required before interpreting the provisional memory guards as safe.

Neural voice coexistence is unmeasured. Qwen is deferred whenever Supertonic
resources are available; voice is neither unloaded nor interrupted to make room.
This conservative restriction is a known product limitation.

## Licensing and signing

Model: Apache-2.0. llama.cpp: MIT. Copies are in `licenses/`; retain these and
native third-party notices when distributing builds. Runtime preparation builds
against the pinned source archive, without redistributing weights in Git.
Existing Apple app signing remains unchanged; no new entitlement or Apple
distribution subscription was acquired.
