import { useSyncExternalStore } from 'react'
import { getState, update, useStore } from './store'

/* Reading aloud. Kokoro voices run in the browser (downloaded once, then offline). Until the
   voice is ready, or if this browser can't run it, the system voice reads instead. */

export const voices = [
  { id: 'af_heart', name: 'Heart', note: 'warm, American' },
  { id: 'af_bella', name: 'Bella', note: 'bright, American' },
  { id: 'af_nicole', name: 'Nicole', note: 'soft, close' },
  { id: 'am_michael', name: 'Michael', note: 'calm, American' },
  { id: 'am_fenrir', name: 'Fenrir', note: 'deep, American' },
  { id: 'bf_emma', name: 'Emma', note: 'gentle, British' },
  { id: 'bm_george', name: 'George', note: 'steady, British' },
] as const

type Status = 'idle' | 'loading' | 'speaking'
interface VoiceState { status: Status; progress: number; kokoro: 'unknown' | 'ready' | 'failed'; speakingId: string | null; notice: string | null }

let vs: VoiceState = { status: 'idle', progress: 0, kokoro: 'unknown', speakingId: null, notice: null }
const listeners = new Set<() => void>()
function set(patch: Partial<VoiceState>) { vs = { ...vs, ...patch }; listeners.forEach((l) => l()) }

export function useVoice() {
  return useSyncExternalStore((l) => { listeners.add(l); return () => listeners.delete(l) }, () => vs)
}
export const useVoiceId = () => useStore((s) => s.voice)
export function chooseVoice(id: string) { update((s) => ({ ...s, voice: id })) }

let worker: Worker | null = null
let audio: AudioContext | null = null
let at = 0
let job = 0
let sources: AudioBufferSourceNode[] = []
let pending = 0
let finished = false

function getWorker() {
  if (worker) return worker
  worker = new Worker(new URL('./voice.worker.ts', import.meta.url), { type: 'module' })
  worker.onmessage = (e) => {
    const m = e.data
    if (m.type === 'progress') set({ progress: m.value })
    if (m.type === 'ready') set({ kokoro: 'ready' })
    if (m.type === 'chunk' && m.id === job) { set({ kokoro: 'ready', status: 'speaking' }); play(m.samples, m.rate) }
    if (m.type === 'done' && m.id === job) { finished = true; if (!pending) end() }
    if (m.type === 'error') {
      console.warn('[leu] Kokoro voice unavailable, using the system voice:', m.message)
      set({ kokoro: 'failed', notice: 'The Kokoro voice could not be downloaded, so your system voice is reading.' })
      if (m.id === job && vs.status === 'loading') systemSpeak(lastText)
    }
  }
  return worker
}

function play(samples: Float32Array, rate: number) {
  audio ??= new AudioContext()
  const fade = Math.min(120, samples.length >> 2)
  for (let i = 0; i < fade; i++) { samples[i] *= i / fade; samples[samples.length - 1 - i] *= i / fade }
  const buffer = audio.createBuffer(1, samples.length, rate)
  buffer.copyToChannel(samples as Float32Array<ArrayBuffer>, 0)
  const node = audio.createBufferSource()
  node.buffer = buffer
  node.connect(audio.destination)
  at = Math.max(at, audio.currentTime + 0.05)
  node.start(at)
  at += buffer.duration
  pending++
  sources.push(node)
  node.onended = () => { pending--; if (finished && !pending) end() }
}

function end() { set({ status: 'idle', speakingId: null }) }

let lastText = ''
/** Read a passage aloud. `id` lets a button know it is the one speaking. */
export function speak(text: string, id = 'passage') {
  stop()
  lastText = text
  job++
  finished = false
  set({ status: 'loading', speakingId: id })
  audio ??= new AudioContext()
  void audio.resume()
  at = 0
  if (vs.kokoro === 'failed') { systemSpeak(text); return }
  getWorker().postMessage({ type: 'speak', id: job, text, voice: getState().voice, speed: 1 })
}

export function stop() {
  job++
  worker?.postMessage({ type: 'cancel' })
  sources.forEach((s) => { try { s.stop() } catch { /* already done */ } })
  sources = []; pending = 0
  speechSynthesis?.cancel()
  if (vs.status !== 'idle') end()
}

/** Start fetching the voice ahead of time (from the Voice panel). */
export function dismissNotice() { set({ notice: null }) }

export function prepareVoice() { set({ status: vs.status }); getWorker().postMessage({ type: 'load' }) }

function systemSpeak(text: string) {
  if (!('speechSynthesis' in window)) { end(); return }
  const u = new SpeechSynthesisUtterance(text)
  u.rate = 0.98
  u.onstart = () => set({ status: 'speaking' })
  u.onend = end
  u.onerror = (e) => {
    if (e.error !== 'interrupted' && e.error !== 'canceled') set({ notice: 'This browser could not read aloud. Check that a system voice is installed.' })
    end()
  }
  speechSynthesis.speak(u)
}
