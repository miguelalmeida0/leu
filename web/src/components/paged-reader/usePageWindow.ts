import { useEffect, useMemo, useState } from 'react'
import { pageBlocks, pdfDeadline, type PDFDocumentProxy } from '../../lib/pdf'
import type { PageData } from './types'

/** Only the current source page and its neighbours retain prepared content. */
export function usePageWindow(doc: PDFDocumentProxy, page: number) {
  const cache = useMemo(() => new Map<number, Promise<PageData>>(), [doc])
  const [loaded, setLoaded] = useState<{ doc: PDFDocumentProxy; pages: Map<number, PageData> }>({ doc, pages: new Map() })
  useEffect(() => {
    let live = true
    const wanted = [page - 1, page, page + 1].filter((n) => n >= 1 && n <= doc.numPages)
    for (const n of cache.keys()) if (!wanted.includes(n)) cache.delete(n)
    setLoaded((old) => ({ doc, pages: new Map([...old.pages].filter(([n]) => old.doc === doc && wanted.includes(n))) }))
    for (const n of wanted) {
      let work = cache.get(n)
      if (!work) {
        const text = pageBlocks(doc, n).then((blocks) => ({ blocks, textError: undefined as string | undefined }))
          .catch(() => ({ blocks: [], textError: 'The text could not be prepared. Choose Original page to keep reading.' }))
        work = Promise.all([text, pdfDeadline(doc.getPage(n), 12000)])
          .then(([content, source]) => {
            const viewport = source.getViewport({ scale: 1 })
            return { ...content, aspect: viewport.width / viewport.height }
          })
        cache.set(n, work)
      }
      void work.then((data) => {
        if (live) setLoaded((old) => ({ doc, pages: new Map(old.pages).set(n, data) }))
      }).catch(() => {
        cache.delete(n)
        if (live) setLoaded((old) => ({ doc, pages: new Map(old.pages).set(n, { blocks: [], aspect: .707, error: 'This page could not be opened. Try opening the book again.' }) }))
      })
    }
    return () => { live = false }
  }, [cache, doc, page])
  return loaded.doc === doc ? loaded.pages : new Map<number, PageData>()
}
