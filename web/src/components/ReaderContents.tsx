import { useEffect, useId, useMemo, useRef, useState } from 'react'
import { createPortal } from 'react-dom'
import { Modal } from './ui'
import type { Outline } from '../lib/store'
import './ReaderContents.css'

/** Closest source destination, preferring the last heading on the same page. */
export function currentOutlineIndex(entries: Outline[], page: number) {
  let current = 0, closest = -Infinity
  for (let index = 0; index < entries.length; index++) {
    if (entries[index].page <= page && entries[index].page >= closest) {
      current = index; closest = entries[index].page
    }
  }
  return current
}

/** Shared, bounded navigation for the book overview and both reader layouts. */
export function ReaderContents({ entries, currentIndex, onChoose }: {
  entries: Outline[]; currentIndex: number; onChoose: (index: number) => void
}) {
  const [open, setOpen] = useState(false), [query, setQuery] = useState('')
  const searchId = useId()
  const trigger = useRef<HTMLButtonElement>(null), resultsElement = useRef<HTMLElement>(null), returning = useRef(false)
  useEffect(() => {
    if (open) { returning.current = true; return }
    if (!returning.current) return
    returning.current = false
    // Route focus runs after a page jump; return to the persistent disclosure
    // once those effects finish, without scrolling the page behind the dialog.
    const frame = requestAnimationFrame(() => trigger.current?.focus({ preventScroll: true }))
    return () => cancelAnimationFrame(frame)
  }, [open])
  const results = useMemo(() => {
    const needle = query.trim().toLocaleLowerCase()
    return entries.map((entry, index) => ({ entry, index }))
      .filter(({ entry, index }) => !needle || `${index + 1} ${entry.title} ${entry.page}`.toLocaleLowerCase().includes(needle))
  }, [entries, query])
  useEffect(() => {
    if (!open || !resultsElement.current) return
    if (query.trim()) resultsElement.current.scrollTop = 0
    else resultsElement.current.querySelector<HTMLElement>('[aria-current]')?.scrollIntoView({ block: 'nearest', behavior: 'instant' })
  }, [open, entries, currentIndex, query])
  const current = entries[currentIndex]
  return <>
    <button ref={trigger} type="button" className="contents-trigger" aria-label={`Contents, ${currentIndex + 1} of ${entries.length}`} aria-haspopup="dialog" aria-expanded={open} disabled={!entries.length}
      onClick={() => { setQuery(''); setOpen(true) }}>
      <svg aria-hidden="true" width="18" height="18" viewBox="0 0 24 24"><path d="M5 6h14M5 12h14M5 18h14" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" /></svg><span>Contents</span><span className="contents-location">{currentIndex + 1} / {entries.length}</span>
    </button>
    {open && createPortal(<Modal label="Contents" onClose={() => setOpen(false)} width={600}>
      <div className="reader-contents">
        <h2 className="display">Contents</h2>
        {current && <p className="contents-current">Current: {current.title} · p. {current.page}</p>}
        <label htmlFor={searchId} className="eyebrow">Search chapters</label>
        <input className="field" id={searchId} type="search" value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Title, chapter or page" />
        <p className="muted small" role="status">{results.length} of {entries.length} entries</p>
        <nav ref={resultsElement} aria-label="Chapters" className="contents-results">
          <ol>{results.map(({ entry, index }) => <li key={index}>
            <button type="button" aria-current={index === currentIndex ? 'location' : undefined}
              style={{ paddingInlineStart: 10 + Math.min(entry.depth, 3) * 12 }}
              onClick={() => { onChoose(index); setOpen(false) }}>
              <span className="contents-title">{entry.title}</span><span className="contents-page tabular">p. {entry.page}</span>
            </button>
          </li>)}</ol>
          {!results.length && <p className="muted">No matching chapters.</p>}
        </nav>
      </div>
    </Modal>, document.body)}
  </>
}
