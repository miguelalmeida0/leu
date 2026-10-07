import { useSyncExternalStore } from 'react'
import { extract, openPdf } from './pdf'
import { allText, getState, palettes, saveOutline, savePdf, saveText, uid, update, type Book, type Palette } from './store'
import { words } from './text'

/* Bringing PDFs in: read locally with pdf.js, text and outline kept in IndexedDB, and the
   book sewn to the ones that share its ideas. Nothing leaves the browser. */

export const samples = ['Computer Science Essentials', 'React Notes', 'JavaScript Deep Dive', 'Design Patterns', 'System Design', 'Coding Interviews']

export interface Sewing {
  bookId: string
  title: string
  read: number // pages read so far
  pages: number
  done: boolean
  neighbours: { bookId: string; term: string }[]
  error?: string
}

let sewing: Sewing | null = null
const listeners = new Set<() => void>()
const emit = (next: Sewing | null) => { sewing = next; listeners.forEach((l) => l()) }
export const useSewing = () => useSyncExternalStore((l) => { listeners.add(l); return () => listeners.delete(l) }, () => sewing)
export const closeSewing = () => emit(null)

const order = Object.keys(palettes) as Palette[]

export async function importFiles(files: File[], quiet = false) {
  const pdfs = files.filter((f) => f.type === 'application/pdf' || f.name.toLowerCase().endsWith('.pdf'))
  for (const file of pdfs) await importOne(file.name.replace(/\.pdf$/i, ''), await file.arrayBuffer(), quiet || pdfs.length > 1)
  return pdfs.length
}

export async function importSample(name: string, quiet = false) {
  const existing = getState().books.find((b) => b.title === name)
  if (existing) return existing.id
  const response = await fetch(`/samples/${encodeURIComponent(name)}.pdf`)
  return importOne(name, await response.arrayBuffer(), quiet, true)
}

export async function importAllSamples() {
  for (const name of samples) await importSample(name, true)
}

async function importOne(fallbackTitle: string, data: ArrayBuffer, quiet: boolean, sample = false): Promise<string> {
  const id = uid()
  const doc = await openPdf(data)
  const meta = await doc.getMetadata().catch(() => null)
  const metaTitle = (meta?.info as { Title?: string } | undefined)?.Title?.trim()
  const title = metaTitle && metaTitle.length > 3 && !/untitled|microsoft word|\.docx?$/i.test(metaTitle) ? metaTitle : tidy(fallbackTitle)
  const count = getState().books.length
  const book: Book = {
    id, title, pages: doc.numPages, addedAt: Date.now(), page: 1,
    palette: order[count % order.length], shelf: sample ? 'Programming' : 'Unsorted', sample,
  }
  if (!quiet) emit({ bookId: id, title, read: 0, pages: doc.numPages, done: false, neighbours: [] })
  await savePdf(id, data)
  const { pages, outline } = await extract(doc, (n) => { if (!quiet && sewing?.bookId === id) emit({ ...sewing, read: n }) })
  await Promise.all([saveText(id, pages), saveOutline(id, outline)])
  update((s) => ({ ...s, books: [...s.books, book] }))
  void doc.loadingTask.destroy()
  if (!quiet) { const near = await neighbours(id); if (sewing?.bookId === id) emit({ ...sewing, done: true, neighbours: near }) }
  return id
}

function tidy(name: string) {
  const t = name.replace(/[_-]+/g, ' ').replace(/\s+/g, ' ').trim()
  return t.charAt(0).toUpperCase() + t.slice(1)
}

/** Books that share ideas with this one, each named by the strongest word they share. */
export async function neighbours(id: string): Promise<{ bookId: string; term: string }[]> {
  const library = await allText()
  const profile = (pages: string[]) => {
    const counts = new Map<string, number>()
    for (const w of words(pages.join(' '))) counts.set(w, (counts.get(w) ?? 0) + 1)
    return counts
  }
  const profiles = new Map([...library].map(([bookId, pages]) => [bookId, profile(pages)]))
  const df = new Map<string, number>()
  for (const p of profiles.values()) for (const w of p.keys()) df.set(w, (df.get(w) ?? 0) + 1)
  const mine = profiles.get(id)
  if (!mine) return []
  const result: { bookId: string; term: string; score: number }[] = []
  for (const [other, theirs] of profiles) {
    if (other === id) continue
    let best = '', bestScore = 0, total = 0
    for (const [w, n] of mine) {
      const m = theirs.get(w)
      if (!m || w.length < 5) continue
      const idf = Math.log(profiles.size / (df.get(w) ?? 1)) + 0.3
      const s = Math.min(n, m) * idf
      total += s
      if (s > bestScore) { bestScore = s; best = w }
    }
    if (total > 6 && best) result.push({ bookId: other, term: best, score: total })
  }
  return result.sort((a, b) => b.score - a.score).slice(0, 4)
}

/** The book you were last in, or the newest one. */
export function lastBook(books: Book[]): Book | undefined {
  return [...books].sort((a, b) => (b.lastOpenedAt ?? 0) - (a.lastOpenedAt ?? 0) || b.addedAt - a.addedAt)[0]
}
