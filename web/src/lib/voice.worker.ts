/// <reference lib="webworker" />
import { KokoroTTS } from 'kokoro-js'

/* Kokoro, in a worker so the page never stutters while it speaks. It is given the passage
   already cut into sentences and renders them one after another, posting each as soon as it is
   ready, so the page can play one while the next is made and light up exactly what is heard.

   Where the browser has WebGPU (Chrome, Edge, Safari 26 on a Mac) the full model runs on the
   graphics chip, many times faster than speech, so there are no gaps. Elsewhere the 8-bit model
   runs on WebAssembly with several threads (the dev server sends the cross-origin isolation
   headers that threads need). Either way it is downloaded once and then works offline. */

type In =
  | { type: 'load' }
  | { type: 'speak'; id: number; pieces: string[]; voice: string; speed: number }
  | { type: 'cancel' }

let tts: Promise<KokoroTTS> | null = null
let current = 0

async function gpu(): Promise<boolean> {
  const nav = navigator as Navigator & { gpu?: { requestAdapter(): Promise<unknown> } }
  if (!nav.gpu) return false
  try { return !!(await nav.gpu.requestAdapter()) } catch { return false }
}

function load() {
  tts ??= (async () => {
    const fast = await gpu()
    postMessage({ type: 'engine', engine: fast ? 'webgpu' : 'wasm' })
    return KokoroTTS.from_pretrained('onnx-community/Kokoro-82M-v1.0-ONNX', {
      dtype: fast ? 'fp32' : 'q8',
      device: fast ? 'webgpu' : 'wasm',
      progress_callback: (p: { status: string; progress?: number; file?: string }) => {
        if (p.status === 'progress' && p.file?.endsWith('.onnx')) postMessage({ type: 'progress', value: (p.progress ?? 0) / 100 })
      },
    })
  })()
  return tts
}

self.onmessage = async (event: MessageEvent<In>) => {
  const message = event.data
  if (message.type === 'cancel') { current = 0; return }
  try {
    const model = await load()
    if (message.type === 'load') { postMessage({ type: 'ready' }); return }
    current = message.id
    for (let index = 0; index < message.pieces.length; index++) {
      if (current !== message.id) return
      const text = message.pieces[index]
      if (!/[A-Za-z0-9]/.test(text)) { postMessage({ type: 'chunk', id: message.id, index, samples: new Float32Array(0), rate: 24000 }); continue }
      const started = performance.now()
      const audio = await model.generate(text, { voice: message.voice as never, speed: message.speed })
      if (current !== message.id) return
      const samples = audio.audio as Float32Array
      postMessage({ type: 'chunk', id: message.id, index, samples, rate: audio.sampling_rate, ms: performance.now() - started }, [samples.buffer])
    }
    if (current === message.id) postMessage({ type: 'done', id: message.id })
  } catch (error) {
    tts = null
    postMessage({ type: 'error', id: 'id' in message ? message.id : 0, message: String(error) })
  }
}
