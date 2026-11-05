import { useEffect, useMemo, useRef, useState } from 'react'
import { Swatch } from '../components/ui'
import { go } from '../lib/router'
import { useStore } from '../lib/store'
import { prepareSearchIndex, type SearchIndexProgress } from '../lib/searchIndex'
import { search } from '../lib/text'
import { mark } from './Explore'

/** Search (14): ask your books anything. The best answer first, searched words marked, and
    Return opens it. */
export function Search({ onClose }: { onClose: () => void }) {
  const books = useStore((s) => s.books)
  const [q, setQ] = useState('')
  const [lib, setLib] = useState<Map<string, string[]> | null>(null)
  const [active, setActive] = useState(0)
  const [retry, setRetry] = useState(0)
  const [progress, setProgress] = useState<SearchIndexProgress>({
    completed: 0, total: books.length, checking: null, page: 0,
    pages: 0, repaired: 0, errors: 0, done: false,
  })
  const dialog = useRef<HTMLDivElement>(null)
  useEffect(() => {
    const previous = document.activeElement as HTMLElement | null
    const oldOverflow = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    const trap = (event: KeyboardEvent) => {
      if (event.key !== 'Tab' || !dialog.current) return
      const controls = [...dialog.current.querySelectorAll<HTMLElement>('input, button, [href]')]
        .filter((item) => !item.hasAttribute('disabled'))
      if (!controls.length) return
      const first = controls[0], last = controls[controls.length - 1]
      if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus() }
      else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus() }
    }
    document.addEventListener('keydown', trap)
    return () => { document.body.style.overflow = oldOverflow; document.removeEventListener('keydown', trap); previous?.focus() }
  }, [])
  useEffect(() => {
    const controller = new AbortController()
    void prepareSearchIndex((index, status) => {
      if (controller.signal.aborted) return
      setLib(index)
      setProgress(status)
    }, controller.signal).catch((error) => {
      if (controller.signal.aborted) return
      console.warn('[leu] Search could not finish indexing:', error)
      setProgress((old) => ({ ...old, done: true, errors: old.errors + 1 }))
    })
    return () => controller.abort()
  }, [books.length, retry])
  const results = useMemo(() => {
    if (!lib || q.trim().length <= 1) return []
    const found = search(lib, q)
    // Find a matching book title even when that PDF contains no extractable text.
    const titleHits = books
      .filter((book) => book.title.toLocaleLowerCase().includes(q.trim().toLocaleLowerCase()))
      .filter((book) => !found.some((item) => item.bookId === book.id))
      .map((book) => ({ bookId: book.id, page: 1, score: 1, snippet: book.title }))
    return [...found, ...titleHits].slice(0, 30)
  }, [lib, q, books])
  const searching = !progress.done
  useEffect(() => setActive(0), [q])

  const open = (i: number) => { const r = results[i]; if (!r) return; onClose(); go({ name: 'read', id: r.bookId, page: r.page }) }
  useEffect(() => {
    const key = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose() }
    window.addEventListener('keydown', key)
    return () => window.removeEventListener('keydown', key)
  }, [onClose])
  const best = results[0], more = results.slice(1, 8)
  const bookOf = (id: string) => books.find((b) => b.id === id)

  return (
    <div className="scrim search-scrim" onPointerDown={(e) => { if (e.target === e.currentTarget) onClose() }}>
      <div ref={dialog} className="search" role="dialog" aria-modal="true" aria-label="Search your books">
        <div className="search-field">
          <svg width="22" height="22" viewBox="0 0 24 24" aria-hidden="true"><circle cx="10.5" cy="10.5" r="6.5" fill="none" stroke="currentColor" strokeWidth="2.2" /><path d="M15.5 15.5 20 20" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" /></svg>
          <input
            autoFocus
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="Ask your books anything"
            aria-label="Ask your books anything"
            aria-controls="search-results"
            aria-activedescendant={results.length ? `result-${active}` : undefined}
            onKeyDown={(e) => {
              if (e.key === 'Enter') open(active)
              if (e.key === 'ArrowDown') { e.preventDefault(); setActive((a) => Math.min(a + 1, Math.max(0, Math.min(results.length, 8) - 1))) }
              if (e.key === 'ArrowUp') { e.preventDefault(); setActive((a) => Math.max(a - 1, 0)) }
            }}
          />
          <button className="search-close" onClick={onClose} aria-label="Close search" title="Close (Esc)">
            <svg width="16" height="16" viewBox="0 0 24 24" aria-hidden="true"><path d="M6 6l12 12M18 6 6 18" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" /></svg>
          </button>
        </div>
        <div id="search-results" role="listbox" aria-label="Results" className="search-results">
          {!q.trim() && <p className="muted search-hint">Find passages, chapters and ideas across your own PDFs. Results always open the original source page.</p>}
          {searching && (
            <div className="search-progress" role="status" aria-live="polite">
              <span className="search-progress-dot" aria-hidden="true" />
              <span>
                {progress.checking
                  ? `Checking ${progress.checking}${progress.pages ? ` · page ${progress.page} of ${progress.pages}` : ''}`
                  : 'Preparing your searchable library…'}
                <span className="search-progress-count">{progress.completed} / {progress.total} books</span>
              </span>
            </div>
          )}
          {q.trim().length > 1 && lib && !results.length && !searching && (
            <div className="search-empty">
              <p className="muted search-hint">No matching passage in your indexed books. Try a shorter phrase or check the spelling.</p>
              <button className="link small" onClick={() => setRetry((n) => n + 1)}>Check the PDFs again</button>
            </div>
          )}
          {!searching && progress.errors > 0 && (
            <p className="muted small" role="status">
              Some PDF pages could not be indexed. Text-based PDFs remain searchable; image-only pages need OCR.
            </p>
          )}
          {best && (
            <>
              <p className="eyebrow paper">Best answer, from your own library</p>
              <button id="result-0" role="option" aria-selected={active === 0} className={`best${active === 0 ? ' active' : ''}`} onClick={() => open(0)} onMouseEnter={() => setActive(0)}>
                <span className="serif best-quote">“{mark(best.snippet, q)}”</span>
                <span className="result-place small">{bookOf(best.bookId) && <Swatch book={bookOf(best.bookId)!} size={8} />}{bookOf(best.bookId)?.title} · p. {best.page}<span className="return-hint">Return opens it</span></span>
              </button>
            </>
          )}
          {more.length > 0 && <p className="eyebrow paper" style={{ marginTop: 18 }}>More passages · {more.length}</p>}
          {more.map((r, i) => (
            <button key={`${r.bookId}:${r.page}`} id={`result-${i + 1}`} role="option" aria-selected={active === i + 1} className={`result${active === i + 1 ? ' active' : ''}`} onClick={() => open(i + 1)} onMouseEnter={() => setActive(i + 1)}>
              <span className="result-place small">{bookOf(r.bookId) && <Swatch book={bookOf(r.bookId)!} size={8} />}{bookOf(r.bookId)?.title} · p. {r.page}</span>
              <span className="serif">{mark(r.snippet.length > 220 ? r.snippet.slice(0, 220) + '…' : r.snippet, q)}</span>
            </button>
          ))}
        </div>
      </div>
    </div>
  )
}
