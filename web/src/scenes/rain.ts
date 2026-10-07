/* Soft rain against the window, synthesised in the browser (a port of RainSound.swift): three
   slow noise integrators make the body of the rain, and now and then a short bright tick lands
   like a drop on glass. Twenty seconds are rendered once and looped with a crossfaded seam. */

let ctx: AudioContext | null = null
let gain: GainNode | null = null
let source: AudioBufferSourceNode | null = null
export let raining = false

function render(audio: AudioContext): AudioBuffer {
  const rate = audio.sampleRate, seconds = 20, n = rate * seconds, xf = rate
  const buffer = audio.createBuffer(2, n, rate)
  for (let ch = 0; ch < 2; ch++) {
    const out = buffer.getChannelData(ch)
    const raw = new Float32Array(n + xf)
    let b0 = 0, b1 = 0, b2 = 0, tick = 0, decay = 0, last = 0, until = 0
    for (let i = 0; i < raw.length; i++) {
      const white = Math.random() * 2 - 1
      b0 = 0.997 * b0 + white * 0.029; b1 = 0.985 * b1 + white * 0.032; b2 = 0.95 * b2 + white * 0.048
      let s = (b0 + b1 + b2 + white * 0.02) * 0.35
      if (--until <= 0) { until = Math.floor((0.08 + Math.random() * 0.37) * rate); tick = 0.05 + Math.random() * 0.07; decay = Math.exp(-1 / (0.025 * rate)) }
      s += (white - last) * tick; tick *= decay; last = white
      raw[i] = s
    }
    for (let i = 0; i < n; i++) out[i] = raw[i]
    // The tail crossfades into the head, so the loop never clicks.
    for (let i = 0; i < xf; i++) { const t = i / xf; out[i] = raw[i] * t + raw[n + i] * (1 - t) }
  }
  return buffer
}

export function toggleRain(): boolean {
  ctx ??= new AudioContext()
  void ctx.resume()
  if (!gain) { gain = ctx.createGain(); gain.gain.value = 0; gain.connect(ctx.destination) }
  const now = ctx.currentTime
  if (raining) {
    gain.gain.setTargetAtTime(0, now, 0.25)
    const s = source; source = null
    setTimeout(() => s?.stop(), 1200)
  } else {
    source = ctx.createBufferSource()
    source.buffer = render(ctx)
    source.loop = true
    source.connect(gain)
    source.start()
    gain.gain.setTargetAtTime(0.55, now, 0.25)
  }
  raining = !raining
  return raining
}

export function stopRain() { if (raining) toggleRain() }
