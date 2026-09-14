# Supertonic source audit and listening matrix

Status: **IMPLEMENTED** for lifecycle changes; **REQUIRES HUMAN LISTENING** for sound quality. Values below were inspected in local source. No model was downloaded, no waveform was auditioned, and no measured comparison is claimed.

| Parameter | Current value | Expected effect | Safe range / constraint | A/B procedure |
| --- | --- | --- | --- | --- |
| Model identity | `supertone-oss-archive/supertonic-3`, pinned revision `aafc6e32416a594460b32413efc49d7fe4ce6d46` | Fixes the implementation/assets being compared | Retain pin until a separately validated model change | Record revision with every result |
| Speaker | F1 style | Voice identity and prosody | F1 only in this implementation; other styles unvalidated | Same sample, Apple voice versus F1 |
| Sample rate | Read from `tts.json` → `ae.sample_rate` | Correct duration and playback pitch | Use model rate verbatim; numeric installed value not observed | Inspect installed config and WAV header, record both |
| Amplitude | Gain 1; clamp samples to −1…1; PCM16 ×32767 | Clips outliers; no loudness normalization | Keep unchanged; no empirically validated alternate gain | Compare clipping count, peak/RMS and perceived loudness at fixed volume |
| Speed | Caller clamps requested multiplier to 0.82…1.4; normal request is 1.0. Runtime default 1.03 is overridden by caller | Changes predicted duration | Existing implementation bounds, not a validated quality range | Replay 0.85 / 1.0 / 1.15 with same text; benchmark displays actual clamp |
| Duration | `max(0.15, predictedDuration / max(0.72, speed))` | Minimum duration and speed scaling | Leave unchanged pending listening | Compare short and long corpus items, inspect truncated endings |
| Synthesis steps | 8 | Compute/quality tradeoff | Retain 8; alternate step counts unvalidated | After baseline listening, compare one step count at a time and record latency |
| Resampling | None | Preserves model waveform timing | No rate relabeling | Verify WAV rate equals model rate |
| Chunk size | `base_chunk_size × chunk_compress_factor`, from model config | Latent length quantization | Model-defined; do not tune independently | Record loaded config and output duration |
| Silence | No extra app-inserted pre/post delay | Model determines internal pauses | Do not trim blindly | Listen to clause boundaries and measure first/last non-silent sample |
| Stitching / crossfade | No waveform stitching or crossfade | Sentence requests remain discrete | No guessed timing/crossfade | Compare multi-sentence Apple paragraph with sequential neural sentences |
| Playback / buffering | Entire waveform synthesized before `AVAudioPlayer`; no `AVAudioEngine` scheduling | Startup/inter-sentence gap includes synthesis | Preserve until latency measured | Record request, waveform-ready, playback-start/end times on phone |
| Runtime initialization | Four ONNX sessions created per request; 2 intra-op threads | Potential startup cost | Optimization requires memory/latency evidence | Cold and warm repetitions on same device |
| Randomness | Gaussian latent initialization is nondeterministic | Replays may vary even at identical settings | Do not call repeats sample-identical audio | Repeat each condition several times; log distributions |

This recovery changes cancellation generations, pause-during-synthesis behavior, stale completion handling and temporary WAV cleanup. It does not tune model weights, speaker, steps, gain, sample rate or perceptual parameters.

The debug-only `--voice-benchmark` screen contains 56 text samples. It shows raw and normalized text, the actual selected Apple voice/tier or Supertonic F1, speed, replay and sample switching. Apple Enhanced/Premium choices appear only when installed. Unavailable Supertonic assets are reported without substituting Apple audio. Apple paragraph range callbacks drive sentence highlighting; Supertonic remains sentence-granularity because this runtime supplies no sentence timestamps.

**REQUIRES PHYSICAL IPHONE:** real background playback, interruption, lock-screen commands, memory pressure and latency. **REQUIRES HUMAN LISTENING:** all claims about naturalness, intelligibility, pronunciation, fatigue, pauses and relative Apple/Supertonic quality. No Siri voice access is claimed.
