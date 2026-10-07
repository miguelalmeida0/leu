import { useSyncExternalStore } from 'react'
import { getState, update, useStore } from './store'

/* Reading aloud, gap-free. Kokoro renders sentence by sentence in a worker. Each sentence's own
   leading and trailing silence is trimmed and replaced by a short, even breath, and playback
   only starts once enough is ready that it can never catch up with the voice: on a fast
   machine that is the first sentence; on a slow one it waits a moment longer, once, rather
   than stopping mid-paragraph. Until Kokoro is ready, or where it can't run, the system voice
   reads instead. `position()` says which sentence is being heard, and how far through it. */

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
interface VoiceState { status: Status; progress: number; kokoro: 'unknown' | 'ready' | 'failed'; speakingId: string | null; notice: string | null; engine: 'webgpu' | 'wasm' | null }

let vs: VoiceState = { status: 'idle', progress: 0, kokoro: 'unknown', speakingId: null, notice: null, engine: null }
const listeners = new Set<() => void>()
function set(patch: Partial<VoiceState>) { vs = { ...vs, ...patch }; listeners.forEach((l) => l()) }

export function useVoice() {
  return useSyncExternalStore((l) => { listeners.add(l); return () => listeners.delete(l) }, () => vs)
}
export const useVoiceId = () => useStore((s) => s.voice)
export function chooseVoice(id: string) { update((s) => ({ ...s, voice: id })) }
export function dismissNotice() { set({ notice: null }) }

/** Cut a passage into the pieces that are spoken (and lit) one at a time. */
export function speechPieces(text: string): string[] {
  return text
    .split(/\n{2,}/)
    .flatMap((block) => block.replace(/\s+/g, ' ').trim().split(/(?<=[.!?]["”’')]?)\s+(?=["“(]?[A-Z0-9])/))
    .map((s) => s.trim())
    .filter(Boolean)
}

// ---- playback ----

interface Segment { index: number; start: number; duration: number }
let worker: Worker | null = null
let audio: AudioContext | null = null
let job = 0
let pieces: string[] = []
let segments: Segment[] = []
let sources: AudioBufferSourceNode[] = []
let pending: { index: number; buffer: AudioBuffer }[] = []
let at = 0
let started = false
let finished = false
let made = { seconds: 0, chars: 0, ms: 0 }
let system: { index: number; start: number; char: number } | null = null

const BREATH = 0.16 // between sentences
const BREATH_LONG = 0.34 // after a heading or a paragraph's last sentence

function getWorker() {
  if (worker) return worker
  worker = new Worker(new URL('./voice.worker.ts', import.meta.url), { type: 'module' })
  worker.onmessage = (e) => {
    const m = e.data
    if (m.type === 'engine') set({ engine: m.engine })
    if (m.type === 'progress') set({ progress: m.value })
    if (m.type === 'ready') set({ kokoro: 'ready' })
    if (m.type === 'chunk' && m.id === job) { set({ kokoro: 'ready' }); receive(m.index, m.samples, m.rate, m.ms ?? 0) }
    if (m.type === 'done' && m.id === job) { finished = true; if (!started) begin(); if (!sources.length && !pending.length) end() }
    if (m.type === 'error') {
      console.warn('[leu] Kokoro voice unavailable, using the system voice:', m.message)
      set({ kokoro: 'failed', notice: 'The Kokoro voice could not be downloaded, so your system voice is reading.' })
      if (m.id === job && vs.status !== 'idle') systemSpeak(job, pieces.slice(segments.length))
    }
  }
  return worker
}

/** Trim each sentence's own silence, so the gaps between them are ours and even. */
function trim(samples: Float32Array, rate: number): Float32Array {
  const floor = 0.008, keep = Math.round(rate * 0.025)
  let a = 0, b = samples.length - 1
  while (a < b && Math.abs(samples[a]) < floor) a++
  while (b > a && Math.abs(samples[b]) < floor) b--
  const out = samples.slice(Math.max(0, a - keep), Math.min(samples.length, b + keep))
  const fade = Math.min(Math.round(rate * 0.012), out.length >> 2)
  for (let i = 0; i < fade; i++) { const k = i / fade; out[i] *= k; out[out.length - 1 - i] *= k }
  return out
}

function receive(index: number, raw: Float32Array, rate: number, ms: number) {
  audio ??= new AudioContext()
  const samples = raw.length ? trim(raw, rate) : new Float32Array(Math.round(rate * 0.05))
  const buffer = audio.createBuffer(1, Math.max(1, samples.length), rate)
  buffer.copyToChannel(samples as Float32Array<ArrayBuffer>, 0)
  made.seconds += buffer.duration + BREATH
  made.chars += pieces[index]?.length ?? 0
  made.ms += ms
  pending.push({ index, buffer })
  if (started) flush()
  else if (ready()) begin()
}

/** Is there enough made that playback will never overtake the voice? */
function ready(): boolean {
  if (finished) return true
  // Seconds of speech made per second of rendering (download and warm-up excluded).
  const speed = made.seconds / Math.max(made.ms / 1000, 0.001)
  const total = pieces.reduce((n, p) => n + p.length, 0)
  const expected = made.seconds * (total / Math.max(made.chars, 1))
  if (speed >= 1.2) return true
  return made.seconds >= expected * (1 - speed) * 1.15
}

function begin() {
  if (!audio) return
  started = true
  set({ status: 'speaking' })
  at = audio.currentTime + 0.08
  flush()
}

function flush() {
  if (!audio) return
  for (const { index, buffer } of pending) {
    if (at < audio.currentTime + 0.03) at = audio.currentTime + 0.05 // only if the voice fell behind
    const node = audio.createBufferSource()
    node.buffer = buffer
    node.connect(audio.destination)
    node.start(at)
    segments.push({ index, start: at, duration: buffer.duration })
    sources.push(node)
    node.onended = () => {
      sources = sources.filter((s) => s !== node)
      if (finished && !sources.length && !pending.length) end()
    }
    const text = pieces[index] ?? ''
    at += buffer.duration + (/[.!?]["”’')]?$/.test(text) ? BREATH : BREATH_LONG)
  }
  pending = []
}

function end() { set({ status: 'idle', speakingId: null }); segments = []; system = null }

/** Read a passage aloud. `id` lets a button or a page know it is the one speaking. */
export function speak(text: string | string[], id = 'passage') {
  stop()
  pieces = Array.isArray(text) ? text : speechPieces(text)
  if (!pieces.length) return
  job++
  segments = []; pending = []; started = false; finished = false
  made = { seconds: 0, chars: 0, ms: 0 }
  set({ status: 'loading', speakingId: id })
  audio ??= new AudioContext()
  void audio.resume()
  if (vs.kokoro === 'failed') { systemSpeak(job, pieces); return }
  getWorker().postMessage({ type: 'speak', id: job, pieces, voice: getState().voice, speed: 1 })
}

export function stop() {
  job++
  worker?.postMessage({ type: 'cancel' })
  sources.forEach((s) => { try { s.onended = null; s.stop() } catch { /* already done */ } })
  sources = []; pending = []
  if ('speechSynthesis' in window) speechSynthesis.cancel()
  if (vs.status !== 'idle') end()
}

/** Which piece is being heard right now, and how far through it (0…1). */
export function position(): { index: number; fraction: number } | null {
  if (vs.status !== 'speaking') return null
  if (system) {
    const text = pieces[system.index] ?? ''
    return { index: system.index, fraction: Math.min(1, system.char / Math.max(1, text.length)) }
  }
  if (!audio) return null
  const now = audio.currentTime
  for (const s of segments) if (now >= s.start && now < s.start + s.duration) return { index: s.index, fraction: (now - s.start) / s.duration }
  // In a breath between sentences: hold the last one fully read.
  const last = [...segments].reverse().find((s) => s.start <= now)
  return last ? { index: last.index, fraction: 1 } : null
}

/** Start fetching the voice ahead of time. */
export function prepareVoice() { getWorker().postMessage({ type: 'load' }) }

function systemSpeak(token: number, list: string[]) {
  if (!('speechSynthesis' in window) || !list.length) { end(); return }
  const offset = pieces.length - list.length
  let i = 0
  const next = () => {
    if (token !== job) return
    if (i >= list.length) { end(); return }
    const index = offset + i
    const u = new SpeechSynthesisUtterance(list[i++])
    u.rate = 0.98
    u.onstart = () => { system = { index, start: performance.now(), char: 0 }; set({ status: 'speaking' }) }
    u.onboundary = (e) => { if (system) system.char = e.charIndex + (e.charLength || 0) }
    u.onend = next
    u.onerror = (e) => {
      if (e.error !== 'interrupted' && e.error !== 'canceled') { set({ notice: 'This browser could not read aloud. Check that a system voice is installed.' }); end() }
    }
    speechSynthesis.speak(u)
  }
  next()
}
