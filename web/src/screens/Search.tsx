import { useEffect, useMemo, useState } from 'react'
import { Swatch } from '../components/ui'
import { go } from '../lib/router'
import { allText, useStore } from '../lib/store'
import { search } from '../lib/text'
import { mark } from './Explore'

/** Search (14): ask your books anything. The best answer first, searched words marked, and
    Return opens it. */
export function Search({ onClose }: { onClose: () => void }) {
  const books = useStore((s) => s.books)
  const [q, setQ] = useState('')
  const [lib, setLib] = useState<Map<string, string[]> | null>(null)
  const [active, setActive] = useState(0)
  useEffect(() => { void allText().then(setLib) }, [])
  const results = useMemo(() => (lib && q.trim().length > 1 ? search(lib, q) : []), [lib, q])
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
    <div className="scrim search-scrim" onMouseDown={(e) => { if (e.target === e.currentTarget) onClose() }}>
      <div className="search" role="dialog" aria-modal="true" aria-label="Search your books">
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
              if (e.key === 'ArrowDown') { e.preventDefault(); setActive((a) => Math.min(a + 1, Math.min(results.length, 8) - 1)) }
              if (e.key === 'ArrowUp') { e.preventDefault(); setActive((a) => Math.max(a - 1, 0)) }
            }}
          />
          <button className="search-close" onClick={onClose} aria-label="Close search" title="Close (Esc)">
            <svg width="16" height="16" viewBox="0 0 24 24" aria-hidden="true"><path d="M6 6l12 12M18 6 6 18" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" /></svg>
          </button>
        </div>
        <div id="search-results" role="listbox" aria-label="Results" className="search-results">
          {!q.trim() && <p className="muted search-hint">Search across the ideas inside your library. Ask it like a question, or use the exact term.</p>}
          {q.trim().length > 1 && lib && !results.length && <p className="muted search-hint">Nothing in your books says that yet. Try fewer words, or the word the book would use.</p>}
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
