// The legacy build carries polyfills (Map.getOrInsertComputed and friends) that current
// Safari, Firefox and Chrome do not all ship yet; it is the same pdf.js otherwise.
import * as pdfjs from 'pdfjs-dist/legacy/build/pdf.mjs'
import type { PDFDocumentProxy, TextItem } from 'pdfjs-dist/types/src/display/api'
import workerUrl from 'pdfjs-dist/legacy/build/pdf.worker.min.mjs?url'
import type { Outline } from './store'

pdfjs.GlobalWorkerOptions.workerSrc = workerUrl

export type { PDFDocumentProxy }

export async function openPdf(data: ArrayBuffer): Promise<PDFDocumentProxy> {
  // pdf.js takes ownership of the buffer it is given, so it gets a copy.
  return pdfjs.getDocument({ data: new Uint8Array(data.slice(0)) }).promise
}

export interface Block { kind: 'heading' | 'p'; text: string }

/** A page rebuilt for reading: lines joined into paragraphs, larger type as headings, and the
    running header, footer and page number left out. */
export async function pageBlocks(doc: PDFDocumentProxy, n: number): Promise<Block[]> {
  const page = await doc.getPage(n)
  const height = page.getViewport({ scale: 1 }).height
  const content = await page.getTextContent()
  const items = content.items.filter((i): i is TextItem => 'str' in i && i.str.trim().length > 0)
  if (!items.length) return []
  const lines: { y: number; size: number; text: string }[] = []
  for (const item of items) {
    const y = item.transform[5], size = Math.hypot(item.transform[2], item.transform[3])
    const last = lines[lines.length - 1]
    if (last && Math.abs(last.y - y) < size * 0.5) {
      last.text += (last.text.endsWith('-') || item.str.startsWith(' ') ? '' : ' ') + item.str
    } else {
      lines.push({ y, size, text: item.str })
    }
  }
  // Margins: short lines in the top or bottom 7% of the page are running heads and folios.
  const body = lines.filter((l) => {
    const t = l.text.trim()
    const margin = l.y > height * 0.93 || l.y < height * 0.07
    return !(margin && t.length < 70) && !/^\d{1,4}$/.test(t)
  })
  // A short line in capitals at the very top or bottom is a running head too.
  const shouty = (t: string) => t.length < 48 && !/[a-z]/.test(t) && /[A-Z]/.test(t)
  while (body.length && shouty(body[0].text.trim())) body.shift()
  while (body.length && shouty(body[body.length - 1].text.trim())) body.pop()
  const sizes = body.map((l) => l.size).sort((a, b) => a - b)
  const median = sizes[Math.floor(sizes.length / 2)] || 10
  const blocks: Block[] = []
  let prev: (typeof lines)[number] | undefined
  for (const line of body) {
    const text = line.text.replace(/\s+/g, ' ').trim()
    if (!text) continue
    // Larger type is a heading only if it reads like one: short, and not a full sentence.
    const heading = line.size > median * 1.18 && text.length < 90 && !(/[.!?:]$/.test(text) && text.split(' ').length > 6)
    const gap = prev ? prev.y - line.y : Infinity
    const near = prev !== undefined && gap > 0 && gap < prev.size * 1.75
    const last = blocks[blocks.length - 1]
    if (heading) {
      if (last?.kind === 'heading' && near && gap < line.size * 1.6) last.text += ' ' + text
      else blocks.push({ kind: 'heading', text })
    } else if (last?.kind === 'p' && near && Math.abs(prev!.size - line.size) < 1.5) {
      last.text = last.text.endsWith('-') ? last.text.slice(0, -1) + text : last.text + ' ' + text
    } else {
      blocks.push({ kind: 'p', text })
    }
    prev = line
  }
  return blocks
}

/** Bound slow or unresolved PDF worker requests without blocking the UI forever. */
export async function pdfDeadline<T>(work: Promise<T>, milliseconds: number): Promise<T> {
  let timer: ReturnType<typeof setTimeout> | undefined
  try {
    return await Promise.race([
      work,
      new Promise<never>((_, reject) => {
        timer = setTimeout(() => reject(new Error('PDF operation timed out')), milliseconds)
      }),
    ])
  } finally {
    if (timer !== undefined) clearTimeout(timer)
  }
}

/** Every page as plain text, and the outline (embedded, or found from headings). */
export async function extract(doc: PDFDocumentProxy, onPage?: (n: number) => void): Promise<{ pages: string[]; outline: Outline[] }> {
  const pages: string[] = []
  const found: Outline[] = []
  for (let n = 1; n <= doc.numPages; n++) {
    try {
      // On iOS Safari individual pdf.js text requests can stall indefinitely.
      // Skip a stalled page rather than blocking the entire library import.
      const blocks = await pdfDeadline(pageBlocks(doc, n), 12000)
      pages.push(blocks.map((b) => b.text).join('\n\n'))
      blocks.filter((b) => b.kind === 'heading').slice(0, 3).forEach((b, i) => found.push({ title: b.text, page: n, depth: i === 0 ? 0 : 1 }))
    } catch (error) {
      console.warn(`[leu] Could not index page ${n}; original PDF remains available:`, error)
      pages.push('')
    }
    onPage?.(n)
  }
  let embedded: Outline[] = []
  try { embedded = await pdfDeadline(embeddedOutline(doc), 12000) }
  catch (error) { console.warn('[leu] Could not read the PDF outline:', error) }
  return { pages, outline: embedded.length >= 2 ? embedded : found }
}

async function embeddedOutline(doc: PDFDocumentProxy): Promise<Outline[]> {
  const result: Outline[] = []
  const walk = async (nodes: Awaited<ReturnType<PDFDocumentProxy['getOutline']>>, depth: number) => {
    for (const node of nodes ?? []) {
      try {
        const dest = typeof node.dest === 'string' ? await doc.getDestination(node.dest) : node.dest
        const ref = dest?.[0]
        const index = ref && typeof ref === 'object' ? await doc.getPageIndex(ref) : null
        if (index !== null && node.title.trim()) result.push({ title: node.title.trim(), page: index + 1, depth })
      } catch { /* a broken entry is skipped */ }
      if (depth < 3) await walk(node.items, depth + 1)
    }
  }
  await walk(await doc.getOutline(), 0)
  return result
}

/** The original page, drawn at a width, sharp on high-density screens. */
export async function renderPage(doc: PDFDocumentProxy, n: number, canvas: HTMLCanvasElement, width: number) {
  const page = await doc.getPage(n)
  const base = page.getViewport({ scale: 1 })
  const ratio = window.devicePixelRatio || 1
  const viewport = page.getViewport({ scale: (width / base.width) * ratio })
  canvas.width = viewport.width
  canvas.height = viewport.height
  canvas.style.width = `${width}px`
  canvas.style.height = `${(viewport.height / ratio)}px`
  await page.render({ canvas, viewport }).promise
}
