import { useSyncExternalStore } from 'react'
import { del, get, set } from 'idb-keyval'

/* Leu's library, kept in this browser: book metadata, notes, trails and study memory in
   localStorage; the PDFs themselves and their extracted text in IndexedDB. */

export type Palette = 'denim' | 'moss' | 'oat' | 'teal' | 'butter' | 'tomato' | 'blush'

export interface Book {
  id: string
  title: string
  pages: number
  addedAt: number
  lastOpenedAt?: number
  page: number // 1-based reading position
  palette: Palette
  shelf: string
  sample?: boolean
}

/** How far through a book you are: page 1 is the start, the last page is the end. */
export const readFraction = (b: Book) => (b.pages > 1 ? (b.page - 1) / (b.pages - 1) : b.lastOpenedAt ? 1 : 0)

export interface Note { id: string; bookId: string; page: number; quote: string; note: string; createdAt: number }
export interface Stop { id: string; bookId: string; page: number; title: string }
export interface Trail { id: string; title: string; createdAt: number; stops: Stop[]; current: number }
/** What you wrote for a page in "In your own words", and which of its ideas got across. */
export interface Attempt { key: string; text: string; across: string[]; checkedAt?: number }
/** A recall card from a page, with a simple spaced schedule. */
export interface Memory { id: string; bookId: string; page: number; prompt: string; answer: string; due: number; strength: number }

export interface State {
  books: Book[]
  notes: Note[]
  trails: Trail[]
  attempts: Record<string, Attempt>
  memory: Memory[]
  intention: string
  voice: string
}

export const palettes: Record<Palette, { bg: string; fg: string; muted: string }> = {
  denim: { bg: '#4A6A8A', fg: '#F8F1DE', muted: '#E3E9EE' },
  moss: { bg: '#4D6A3C', fg: '#F8F1DE', muted: '#E2EAD8' },
  oat: { bg: '#ECDFBF', fg: '#24301F', muted: '#4A4030' },
  teal: { bg: '#35706A', fg: '#F8F1DE', muted: '#DDEBE8' },
  butter: { bg: '#E7B843', fg: '#24301F', muted: '#4A3A10' },
  tomato: { bg: '#A94B35', fg: '#F8F1DE', muted: '#F6E2DA' },
  blush: { bg: '#EBB5A3', fg: '#24301F', muted: '#5A3328' },
}

const KEY = 'leu.web.v1'
const empty: State = { books: [], notes: [], trails: [], attempts: {}, memory: [], intention: '', voice: 'af_heart' }

let state: State = load()
const listeners = new Set<() => void>()

function load(): State {
  try {
    const raw = localStorage.getItem(KEY)
    return raw ? { ...empty, ...JSON.parse(raw) } : empty
  } catch {
    return empty
  }
}

export function getState(): State { return state }

export function update(change: (draft: State) => State): void {
  state = change(state)
  try { localStorage.setItem(KEY, JSON.stringify(state)) } catch { /* private mode: keep in memory */ }
  listeners.forEach((l) => l())
}

export function useStore<T>(select: (s: State) => T): T {
  return useSyncExternalStore(
    (l) => { listeners.add(l); return () => listeners.delete(l) },
    () => select(state),
  )
}

export const uid = () => Math.random().toString(36).slice(2, 10) + Date.now().toString(36).slice(-4)

// ---- books ----

export function patchBook(id: string, patch: Partial<Book>) {
  update((s) => ({ ...s, books: s.books.map((b) => (b.id === id ? { ...b, ...patch } : b)) }))
}

export async function removeBook(id: string) {
  update((s) => ({
    ...s,
    books: s.books.filter((b) => b.id !== id),
    notes: s.notes.filter((n) => n.bookId !== id),
    memory: s.memory.filter((m) => m.bookId !== id),
  }))
  await Promise.all([del(`pdf:${id}`), del(`text:${id}`), del(`outline:${id}`)])
}

// ---- blobs ----

export interface Outline { title: string; page: number; depth: number }
export const savePdf = (id: string, data: ArrayBuffer) => set(`pdf:${id}`, data)
export const loadPdf = (id: string) => get<ArrayBuffer>(`pdf:${id}`)
export const saveText = async (id: string, pages: string[]) => {
  await set(`text:${id}`, pages)
  // Indexing may complete after Search/Study cached an empty array.
  forgetText(id)
}
export const loadText = async (id: string) => (await get<string[]>(`text:${id}`)) ?? []
export const saveOutline = (id: string, outline: Outline[]) => set(`outline:${id}`, outline)
export const loadOutline = async (id: string) => (await get<Outline[]>(`outline:${id}`)) ?? []

/** All extracted text, cached in memory once read (for search, explore and study). */
const textCache = new Map<string, string[]>()
export async function allText(): Promise<Map<string, string[]>> {
  for (const b of state.books) {
    if (!textCache.has(b.id)) textCache.set(b.id, await loadText(b.id))
  }
  for (const id of [...textCache.keys()]) if (!state.books.some((b) => b.id === id)) textCache.delete(id)
  return textCache
}
export function forgetText(id: string) { textCache.delete(id) }

// ---- notes, trails, study ----

export function addNote(n: Omit<Note, 'id' | 'createdAt'>) {
  update((s) => ({ ...s, notes: [{ ...n, id: uid(), createdAt: Date.now() }, ...s.notes] }))
}
export function removeNote(id: string) { update((s) => ({ ...s, notes: s.notes.filter((n) => n.id !== id) })) }

export function saveTrail(t: Trail) {
  update((s) => ({ ...s, trails: s.trails.some((x) => x.id === t.id) ? s.trails.map((x) => (x.id === t.id ? t : x)) : [t, ...s.trails] }))
}

export function saveAttempt(a: Attempt) { update((s) => ({ ...s, attempts: { ...s.attempts, [a.key]: a } })) }

export function upsertMemory(items: Memory[]) {
  update((s) => {
    const known = new Set(s.memory.map((m) => m.id))
    return { ...s, memory: [...s.memory, ...items.filter((m) => !known.has(m.id))] }
  })
}

export function reviewMemory(id: string, remembered: boolean) {
  const day = 86_400_000
  update((s) => ({
    ...s,
    memory: s.memory.map((m) => {
      if (m.id !== id) return m
      const strength = remembered ? Math.min(m.strength + 1, 6) : Math.max(m.strength - 1, 0)
      return { ...m, strength, due: Date.now() + (remembered ? day * 2 ** strength : day / 4) }
    }),
  }))
}

export type MemoryState = 'new' | 'held' | 'fading' | 'due'
export function memoryState(m: Memory, now = Date.now()): MemoryState {
  if (m.strength === 0 && m.due === 0) return 'new'
  if (m.due <= now) return m.strength <= 1 ? 'fading' : 'due'
  return 'held'
}
