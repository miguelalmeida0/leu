import { useEffect, useMemo, useState } from 'react'
import { pageBlocks, pdfDeadline, type PDFDocumentProxy } from '../../lib/pdf'
import type { PageData } from './types'

/** Prepare only the current PDF sheet and its neighbours. Source-page metadata
 * resolves independently from text extraction so the original can appear first. */
export function usePageWindow(doc: PDFDocumentProxy, page: number) {
  const cache = useMemo(() => new Map<number, {
    source: Promise<Pick<PageData, 'aspect'>>
    content: Promise<Pick<PageData, 'blocks' | 'textError'>>
  }>(), [doc])
  const [loaded, setLoaded] = useState<{ doc: PDFDocumentProxy; pages: Map<number, PageData> }>({ doc, pages: new Map() })

  useEffect(() => {
    let live = true
    const wanted = [page - 1, page, page + 1].filter((n) => n >= 1 && n <= doc.numPages)
    for (const n of cache.keys()) if (!wanted.includes(n)) cache.delete(n)
    setLoaded((old) => ({ doc, pages: new Map([...old.pages].filter(([n]) => old.doc === doc && wanted.includes(n))) }))

    for (const n of wanted) {
      let work = cache.get(n)
      if (!work) {
        const source = pdfDeadline(doc.getPage(n), 12000).then((pdfPage) => {
          const viewport = pdfPage.getViewport({ scale: 1 })
          return { aspect: viewport.width / viewport.height }
        })
        const content = pageBlocks(doc, n)
          .then((blocks) => ({ blocks, textError: undefined as string | undefined }))
          .catch(() => ({ blocks: [], textError: 'The text could not be prepared. Choose Original page to keep reading.' }))
        work = { source, content }
        cache.set(n, work)
      }
      const publish = (data: PageData) => {
        if (!live) return
        setLoaded((old) => {
          const pages = old.doc === doc ? new Map(old.pages) : new Map<number, PageData>()
          pages.set(n, data)
          return { doc, pages }
        })
      }
      // Text extraction can be slow or fail without blocking source page turns.
      void work.source.then((source) => publish({ ...source, blocks: [], textPending: true })).catch(() => {
        cache.delete(n)
        publish({ blocks: [], aspect: .707, error: 'This page could not be opened. Try opening the book again.' })
      })
      void Promise.all([work.source, work.content])
        .then(([source, content]) => publish({ ...source, ...content }))
        .catch(() => { /* The source-page failure was already reported. */ })
    }
    return () => { live = false }
  }, [cache, doc, page])
  return loaded.doc === doc ? loaded.pages : new Map<number, PageData>()
}
