import { useSyncExternalStore } from 'react'
import { getState, update, useStore } from './store'

/* Reading aloud, gap-free and quick to start.

   Kokoro renders in a worker (see voice.worker.ts for how it starts fast). Each sentence's own
   silence is trimmed and sentences are joined with short, even breaths; playback starts as soon
   as enough is ready that it can never stall. `position()` says which sentence is being heard
   and how far through it, which is what the page uses to follow along. Pause, resume, skip and
   seek work on sentences. Until Kokoro is ready, or where it can't run, the system voice reads. */

export const voices = [
  { id: 'af_heart', name: 'Heart', note: 'warm, American' },
  { id: 'af_bella', name: 'Bella', note: 'bright, American' },
  { id: 'af_nicole', name: 'Nicole', note: 'soft, close' },
  { id: 'am_michael', name: 'Michael', note: 'calm, American' },
  { id: 'am_fenrir', name: 'Fenrir', note: 'deep, American' },
  { id: 'bf_emma', name: 'Emma', note: 'gentle, British' },
  { id: 'bm_george', name: 'George', note: 'steady, British' },
] as const

type Status = 'idle' | 'loading' | 'speaking' | 'paused'
interface VoiceState {
  status: Status
  /** First-time download, in bytes; null when nothing is downloading. */
  download: { loaded: number; total: number } | null
  kokoro: 'unknown' | 'loading' | 'ready' | 'failed'
  speakingId: string | null
  notice: string | null
  engine: 'webgpu' | 'wasm' | null
  speed: number
  count: number
}

let vs: VoiceState = { status: 'idle', download: null, kokoro: 'unknown', speakingId: null, notice: null, engine: null, speed: readSpeed(), count: 0 }
const listeners = new Set<() => void>()
function set(patch: Partial<VoiceState>) { vs = { ...vs, ...patch }; listeners.forEach((l) => l()) }

export function useVoice() {
  return useSyncExternalStore((l) => { listeners.add(l); return () => listeners.delete(l) }, () => vs)
}
export const useVoiceId = () => useStore((s) => s.voice)
export function chooseVoice(id: string) { update((s) => ({ ...s, voice: id })) }
export function dismissNotice() { set({ notice: null }) }

function readSpeed() { try { return Number(localStorage.getItem('leu.voice.speed')) || 1 } catch { return 1 } }
const USED = 'leu.voice.used'
const hasListened = () => { try { return localStorage.getItem(USED) === '1' } catch { return false } }

/** Cut a passage into the pieces that are spoken (and followed) one at a time. */
export function speechPieces(text: string): string[] {
  return text
    .split(/\n{2,}/)
    .flatMap((block) => block.replace(/\s+/g, ' ').trim().split(/(?<=[.!?]["”’')]?)\s+(?=["“(]?[A-Z0-9])/))
    .map((s) => s.trim())
    .filter(Boolean)
}

// ---- the worker ----

let worker: Worker | null = null
function getWorker() {
  if (worker) return worker
  worker = new Worker(new URL('./voice.worker.ts', import.meta.url), { type: 'module' })
  worker.onmessage = (e) => {
    const m = e.data
    if (m.type === 'engine') set({ engine: m.engine })
    if (m.type === 'progress') set({ download: { loaded: m.loaded, total: m.total } })
    if (m.type === 'loaded') set({ download: null })
    if (m.type === 'ready') set({ kokoro: 'ready', download: null })
    if (m.type === 'chunk' && m.id === job) receive(m.index, m.from, m.to, m.samples, m.rate, m.ms)
    if (m.type === 'done' && m.id === job) { finished = true; if (!started) begin(); else if (!sources.length && !pending.length) end() }
    if (m.type === 'error') {
      console.warn('[leu] Kokoro voice unavailable, using the system voice:', m.message)
      set({ kokoro: 'failed', download: null, notice: 'The Kokoro voice could not be downloaded, so your system voice is reading.' })
      if (m.id === job && vs.status !== 'idle') systemSpeak(job, firstUnheard())
    }
  }
  return worker
}

/** Load and warm the voice in the background, once you've listened before (or when asked). */
export function warmVoice(force = false) {
  if (vs.kokoro === 'ready' || vs.kokoro === 'loading' || vs.kokoro === 'failed') return
  if (!force && !hasListened()) return
  set({ kokoro: 'loading' })
  getWorker().postMessage({ type: 'warm' })
}

/** Render the first sentences of a page ahead of time, so Read aloud starts at once. */
export function prefetch(list: string[]) {
  if (!hasListened() || vs.kokoro === 'failed') return
  warmVoice()
  getWorker().postMessage({ type: 'prefetch', pieces: list.slice(0, 2), voice: getState().voice, speed: vs.speed })
}

// ---- playback ----

interface Segment { index: number; from: number; to: number; start: number; duration: number }
let audio: AudioContext | null = null
let job = 0
let pieces: string[] = []
let offset = 0 // index of the first piece in this run, within the passage
let segments: Segment[] = []
let sources: AudioBufferSourceNode[] = []
let pending: { index: number; from: number; to: number; buffer: AudioBuffer }[] = []
let at = 0
let started = false
let finished = false
let made = { seconds: 0, chars: 0, ms: 0 }
let system: { index: number; char: number } | null = null
let passage: string[] = []
let onDone: (() => void) | null = null

const BREATH = 0.16 // between sentences
const BREATH_LONG = 0.34 // after a heading
const BREATH_PART = 0.02 // where the first sentence was split to start sooner

/** Trim each sentence's own silence, so the gaps between them are ours and even. */
function trim(samples: Float32Array, rate: number, head: boolean, tail: boolean): Float32Array {
  const floor = 0.008, keep = Math.round(rate * 0.025)
  let a = 0, b = samples.length - 1
  if (head) while (a < b && Math.abs(samples[a]) < floor) a++
  if (tail) while (b > a && Math.abs(samples[b]) < floor) b--
  const out = samples.slice(head ? Math.max(0, a - keep) : 0, tail ? Math.min(samples.length, b + keep) : samples.length)
  const fade = Math.min(Math.round(rate * 0.012), out.length >> 2)
  for (let i = 0; i < fade; i++) { const k = i / fade; out[i] *= k; out[out.length - 1 - i] *= k }
  return out
}

function receive(index: number, from: number, to: number, raw: Float32Array, rate: number, ms: number) {
  audio ??= new AudioContext()
  const samples = raw.length ? trim(raw, rate, true, true) : new Float32Array(Math.round(rate * 0.05))
  const buffer = audio.createBuffer(1, Math.max(1, samples.length), rate)
  buffer.copyToChannel(samples as Float32Array<ArrayBuffer>, 0)
  made.seconds += buffer.duration + BREATH
  if (to >= 1) made.chars += pieces[index]?.length ?? 0
  made.ms += ms
  pending.push({ index, from, to, buffer })
  if (started) flush()
  else if (ready()) begin()
}

/** Is there enough made that playback will never overtake the voice? */
function ready(): boolean {
  if (finished) return true
  const speed = made.seconds / Math.max(made.ms / 1000, 0.001) // seconds of speech per second of rendering
  if (speed >= 1.2) return true
  const total = pieces.reduce((n, p) => n + p.length, 0)
  const expected = made.seconds * (total / Math.max(made.chars, 1))
  return made.seconds >= expected * (1 - speed) * 1.15
}

function begin() {
  if (!audio) return
  started = true
  set({ status: 'speaking' })
  at = audio.currentTime + 0.06
  flush()
}

function flush() {
  if (!audio) return
  for (const { index, from, to, buffer } of pending) {
    if (at < audio.currentTime + 0.03) at = audio.currentTime + 0.05
    const node = audio.createBufferSource()
    node.buffer = buffer
    node.connect(audio.destination)
    node.start(at)
    segments.push({ index: offset + index, from, to, start: at, duration: buffer.duration })
    sources.push(node)
    node.onended = () => {
      sources = sources.filter((s) => s !== node)
      if (finished && !sources.length && !pending.length) end()
    }
    const text = pieces[index] ?? ''
    at += buffer.duration + (to < 1 ? BREATH_PART : /[.!?]["”’')]?$/.test(text) ? BREATH : BREATH_LONG)
  }
  pending = []
}

function end(naturally = true) {
  const done = naturally && finished ? onDone : null
  onDone = null
  set({ status: 'idle', speakingId: null }); segments = []; system = null
  done?.()
}

function firstUnheard(): string[] {
  const heard = new Set(segments.filter((s) => s.to >= 1).map((s) => s.index - offset))
  const first = pieces.findIndex((_, i) => !heard.has(i))
  return first < 0 ? [] : pieces.slice(first)
}

/** Read a passage aloud from piece `from`. `id` lets a page know it is the one speaking. */
export function speak(text: string | string[], id = 'passage', from = 0, then?: () => void) {
  stop()
  onDone = then ?? null
  passage = Array.isArray(text) ? text : speechPieces(text)
  offset = Math.min(Math.max(0, from), Math.max(0, passage.length - 1))
  pieces = passage.slice(offset)
  if (!pieces.length) return
  try { localStorage.setItem(USED, '1') } catch { /* fine */ }
  void navigator.storage?.persist?.()
  job++
  segments = []; pending = []; started = false; finished = false
  made = { seconds: 0, chars: 0, ms: 0 }
  set({ status: 'loading', speakingId: id, count: passage.length })
  audio ??= new AudioContext()
  void audio.resume()
  if (vs.kokoro === 'failed') { systemSpeak(job, pieces); return }
  if (vs.kokoro === 'unknown') set({ kokoro: 'loading' })
  getWorker().postMessage({ type: 'speak', id: job, pieces, voice: getState().voice, speed: vs.speed })
}

export function stop() {
  job++
  worker?.postMessage({ type: 'cancel' })
  sources.forEach((s) => { try { s.onended = null; s.stop() } catch { /* already done */ } })
  sources = []; pending = []
  if ('speechSynthesis' in window) speechSynthesis.cancel()
  void audio?.resume()
  if (vs.status !== 'idle') end(false)
}

export function pause() {
  if (vs.status !== 'speaking') return
  if (system) speechSynthesis.pause(); else void audio?.suspend()
  set({ status: 'paused' })
}

export function resume() {
  if (vs.status !== 'paused') return
  if (system) speechSynthesis.resume(); else void audio?.resume()
  set({ status: 'speaking' })
}

/** Jump to a sentence of the passage being read (or step: -1 back, +1 on). */
export function seek(index: number) {
  if (!passage.length || !vs.speakingId) return
  const then = onDone
  speak(passage, vs.speakingId, Math.min(Math.max(0, index), passage.length - 1), then ?? undefined)
}

export function setSpeed(speed: number) {
  set({ speed })
  try { localStorage.setItem('leu.voice.speed', String(speed)) } catch { /* fine */ }
  const here = position()
  if (here && vs.speakingId) seek(here.index)
}

/** Which piece of the passage is being heard right now, and how far through it (0…1). */
export function position(): { index: number; fraction: number } | null {
  if (vs.status !== 'speaking' && vs.status !== 'paused') return null
  if (system) {
    const text = passage[system.index] ?? ''
    return { index: system.index, fraction: Math.min(1, system.char / Math.max(1, text.length)) }
  }
  if (!audio) return null
  const now = audio.currentTime
  for (const s of segments) if (now >= s.start && now < s.start + s.duration) return { index: s.index, fraction: s.from + ((now - s.start) / s.duration) * (s.to - s.from) }
  const last = [...segments].reverse().find((s) => s.start <= now)
  return last ? { index: last.index, fraction: last.to } : { index: offset, fraction: 0 }
}

function systemSpeak(token: number, list: string[]) {
  if (!('speechSynthesis' in window) || !list.length) { end(); return }
  const first = passage.length - list.length
  let i = 0
  const next = () => {
    if (token !== job) return
    if (i >= list.length) { finished = true; end(); return }
    const index = first + i
    const u = new SpeechSynthesisUtterance(list[i++])
    u.rate = 0.98 * vs.speed
    u.onstart = () => { system = { index, char: 0 }; set({ status: 'speaking' }) }
    u.onboundary = (e) => { if (system) system.char = e.charIndex + (e.charLength || 0) }
    u.onend = next
    u.onerror = (e) => {
      if (e.error !== 'interrupted' && e.error !== 'canceled') { set({ notice: 'This browser could not read aloud. Check that a system voice is installed.' }); end() }
    }
    speechSynthesis.speak(u)
  }
  next()
}
