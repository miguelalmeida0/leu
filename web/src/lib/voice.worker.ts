/// <reference lib="webworker" />
import { KokoroTTS } from 'kokoro-js'

/* Kokoro, in a worker so the page never stutters while it speaks. The model is
   fetched once from Hugging Face and kept in the browser cache; after that it works offline. */

type In =
  | { type: 'load' }
  | { type: 'speak'; id: number; text: string; voice: string; speed: number }
  | { type: 'cancel' }

let tts: Promise<KokoroTTS> | null = null
let current = 0

function load() {
  // The 8-bit model (~90 MB) on WebAssembly: one modest download, and it runs in every
  // current browser. (WebGPU wants the 330 MB full-precision model, too heavy to ask for.)
  tts ??= (async () => {
    return KokoroTTS.from_pretrained('onnx-community/Kokoro-82M-v1.0-ONNX', {
      dtype: 'q8',
      device: 'wasm',
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
    // Short pieces first, so the first words come quickly.
    for await (const piece of model.stream(message.text, { voice: message.voice as never, speed: message.speed })) {
      if (current !== message.id) return
      const samples = piece.audio.audio as Float32Array
      postMessage({ type: 'chunk', id: message.id, samples, rate: piece.audio.sampling_rate }, [samples.buffer])
    }
    if (current === message.id) postMessage({ type: 'done', id: message.id })
  } catch (error) {
    tts = null
    postMessage({ type: 'error', id: 'id' in message ? message.id : 0, message: String(error) })
  }
}
