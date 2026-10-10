import { openPdf, pageBlocks, pdfDeadline } from './pdf'
import { getState, loadPdf, loadText, saveText } from './store'

export interface SearchIndexProgress {
  completed: number
  total: number
  checking: string | null
  page: number
  pages: number
  repaired: number
  errors: number
  done: boolean
}

/**
 * Search must work for books imported before Safari text extraction was repaired.
 * The PDF is already stored on this device; rebuild missing pages on demand,
 * publishing each recovered page immediately so results appear without waiting
 * for an entire book to finish. Never claim "no results" during this process.
 *
 * Does not remove or change any PDFs, user notes or reading positions.
 */
export async function prepareSearchIndex(
  publish: (index: Map<string, string[]>, status: SearchIndexProgress) => void,
  signal?: AbortSignal,
): Promise<void> {
  const books = [...getState().books]
  const index = new Map<string, string[]>()
  const status: SearchIndexProgress = {
    completed: 0, total: books.length, checking: null, page: 0, pages: 0,
    repaired: 0, errors: 0, done: false,
  }
  const emit = () => publish(new Map(index), { ...status })
  emit()

  for (const book of books) {
    if (signal?.aborted) break
    status.checking = book.title
    status.page = 0
    status.pages = book.pages
    let stored: string[] = []
    try {
      stored = await loadText(book.id)
    } catch (error) {
      console.warn('[leu] Could not read text index:', book.title, error)
      status.errors++
    }
    // Publish existing usable pages before repairing the missing ones.
    const pages = Array.from({ length: book.pages }, (_, i) => stored[i] ?? '')
    index.set(book.id, pages.slice())
    emit()

    const missing = pages.some((text) => !text.trim())
    if (missing && !signal?.aborted) {
      let document: Awaited<ReturnType<typeof openPdf>> | undefined
      try {
        const source = await loadPdf(book.id)
        if (!source) throw new Error('Local PDF is unavailable')
        document = await pdfDeadline(openPdf(source), 15000)
        for (let i = 0; i < book.pages && !signal?.aborted; i++) {
          status.page = i + 1
          if (!pages[i].trim()) {
            try {
              const blocks = await pdfDeadline(pageBlocks(document, i + 1), 12000)
              const recovered = blocks.map((block) => block.text).join('\n\n').trim()
              if (recovered) { pages[i] = recovered; status.repaired++ }
            } catch (error) {
              status.errors++
              console.warn(`[leu] Could not reindex ${book.title}, page ${i + 1}:`, error)
            }
          }
          index.set(book.id, pages.slice())
          emit()
        }
        // Merge with any background import that might have completed meanwhile.
        const latest = await loadText(book.id).catch(() => [])
        const merged = pages.map((text, i) => text.trim() ? text : (latest[i] ?? ''))
        await saveText(book.id, merged)
        index.set(book.id, merged)
      } catch (error) {
        status.errors++
        console.warn('[leu] Search reindex unavailable:', book.title, error)
      } finally {
        if (document) void document.loadingTask.destroy()
      }
    }

    status.completed++
    status.checking = null
    status.page = 0
    status.pages = 0
    emit()
  }

  status.done = !signal?.aborted
  emit()
}
