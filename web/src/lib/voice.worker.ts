/// <reference lib="webworker" />
import { KokoroTTS } from 'kokoro-js'

/* Kokoro, in a worker so the page never stutters while it speaks.

   Fast to start:
   - The model is fetched once and kept in the browser's cache; the page asks for persistent
     storage so it isn't evicted.
   - `warm` loads it in the background (the page sends this when you open a book, if you have
     listened before) and renders one tiny phrase, so the GPU shaders are compiled before you
     ever press play.
   - `prefetch` renders the first sentences of the page you're on while you read, so pressing
     Read aloud starts at once. Rendered sentences are kept in a small cache.
   - The first sentence is split at its first natural pause, so the first sound arrives after a
     few words have been rendered, not a whole sentence.

   Where the browser has WebGPU the full model runs on the graphics chip, many times faster
   than speech; elsewhere the 8-bit model runs on WebAssembly threads. */

type In =
  | { type: 'warm' }
  | { type: 'prefetch'; pieces: string[]; voice: string; speed: number }
  | { type: 'speak'; id: number; pieces: string[]; voice: string; speed: number }
  | { type: 'cancel' }

let tts: Promise<KokoroTTS> | null = null
let warmed: Promise<void> | null = null
let current = 0
const cache = new Map<string, { samples: Float32Array; rate: number }>()
let queue: Promise<unknown> = Promise.resolve() // one render at a time

async function gpu(): Promise<boolean> {
  const nav = navigator as Navigator & { gpu?: { requestAdapter(): Promise<unknown> } }
  if (!nav.gpu) return false
  try { return !!(await nav.gpu.requestAdapter()) } catch { return false }
}

function load() {
  tts ??= (async () => {
    const fast = await gpu()
    postMessage({ type: 'engine', engine: fast ? 'webgpu' : 'wasm' })
    const files = new Map<string, { loaded: number; total: number }>()
    const model = await KokoroTTS.from_pretrained('onnx-community/Kokoro-82M-v1.0-ONNX', {
      dtype: fast ? 'fp32' : 'q8',
      device: fast ? 'webgpu' : 'wasm',
      progress_callback: (p: { status: string; file?: string; loaded?: number; total?: number }) => {
        if (p.status === 'progress' && p.file && p.total) {
          files.set(p.file, { loaded: p.loaded ?? 0, total: p.total })
          let loaded = 0, total = 0
          for (const f of files.values()) { loaded += f.loaded; total += f.total }
          // Only a real download is worth a number; a read from the cache is near-instant.
          if (total > 5e6) postMessage({ type: 'progress', loaded, total })
        }
      },
    })
    postMessage({ type: 'loaded' })
    return model
  })()
  return tts
}

function warm() {
  warmed ??= (async () => {
    const model = await load()
    await render(model, 'Hello.', 'af_heart', 1) // compiles the shaders once
    postMessage({ type: 'ready' })
  })()
  return warmed
}

const key = (text: string, voice: string, speed: number) => `${voice}|${speed}|${text}`

function render(model: KokoroTTS, text: string, voice: string, speed: number) {
  const job = queue.then(async () => {
    const hit = cache.get(key(text, voice, speed))
    if (hit) return { ...hit, samples: hit.samples.slice(), ms: 0 }
    const started = performance.now()
    const audio = await model.generate(text, { voice: voice as never, speed })
    const out = { samples: audio.audio as Float32Array, rate: audio.sampling_rate as number }
    cache.set(key(text, voice, speed), { samples: out.samples.slice(), rate: out.rate })
    while (cache.size > 40) cache.delete(cache.keys().next().value!)
    return { ...out, ms: performance.now() - started }
  })
  queue = job.catch(() => undefined)
  return job
}

/** The first piece, split at its first comfortable pause (comma, colon, dash) if it's long. */
function parts(text: string, first: boolean): { text: string; from: number; to: number }[] {
  if (!first || text.length < 70) return [{ text, from: 0, to: 1 }]
  const cut = text.slice(25, 90).search(/[,;:—–]\s/)
  if (cut < 0) return [{ text, from: 0, to: 1 }]
  const at = 25 + cut + 1
  const f = at / text.length
  return [{ text: text.slice(0, at).trim(), from: 0, to: f }, { text: text.slice(at).trim(), from: f, to: 1 }]
}

self.onmessage = async (event: MessageEvent<In>) => {
  const m = event.data
  if (m.type === 'cancel') { current = 0; return }
  try {
    if (m.type === 'warm') { await warm(); return }
    if (m.type === 'prefetch') {
      await warm()
      for (const text of m.pieces) if (/[A-Za-z0-9]/.test(text)) for (const p of parts(text, text === m.pieces[0])) await render(await load(), p.text, m.voice, m.speed)
      return
    }
    current = m.id
    const model = await load()
    for (let index = 0; index < m.pieces.length; index++) {
      const text = m.pieces[index]
      const list = /[A-Za-z0-9]/.test(text) ? parts(text, index === 0) : []
      if (!list.length) { postMessage({ type: 'chunk', id: m.id, index, from: 0, to: 1, samples: new Float32Array(0), rate: 24000, ms: 0 }); continue }
      for (const p of list) {
        if (current !== m.id) return
        const out = await render(model, p.text, m.voice, m.speed)
        if (current !== m.id) return
        postMessage({ type: 'chunk', id: m.id, index, from: p.from, to: p.to, samples: out.samples, rate: out.rate, ms: out.ms }, [out.samples.buffer])
      }
    }
    if (current === m.id) postMessage({ type: 'done', id: m.id })
  } catch (error) {
    tts = null; warmed = null
    postMessage({ type: 'error', id: 'id' in m ? m.id : 0, message: String(error) })
  }
}
