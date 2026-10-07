import { useMemo, useState } from 'react'
import { Modal, Patch, countWords } from '../components/ui'
import { closeSewing, type Sewing } from '../lib/library'
import { go } from '../lib/router'
import { patchBook, useStore } from '../lib/store'

/** Bring a PDF (02b): the book being sewn in, then the books it already shares ideas with. */
export function Sewn({ sewing }: { sewing: Sewing }) {
  const books = useStore((s) => s.books)
  const book = books.find((b) => b.id === sewing.bookId)
  const shelves = useMemo(() => [...new Set(books.map((b) => b.shelf).filter((s) => s !== 'Unsorted'))], [books])
  const [naming, setNaming] = useState(false)
  const [name, setName] = useState('')
  const fraction = sewing.pages ? sewing.read / sewing.pages : 0
  const near = sewing.neighbours.map((n) => ({ ...n, book: books.find((b) => b.id === n.bookId) })).filter((n) => n.book)

  return (
    <Modal label={`Sewing in ${sewing.title}`} onClose={closeSewing} width={720}>
      <div className="sewn">
        <p className="eyebrow paper">{sewing.done ? 'Sewn in' : 'Sewing it in'}</p>
        <h2 className="display" style={{ fontSize: 38, marginTop: 10 }}>{sewing.title}</h2>
        <div className="sewn-thread" role="progressbar" aria-label="Reading the book" aria-valuemin={0} aria-valuemax={sewing.pages} aria-valuenow={sewing.read}>
          <svg width="100%" height="6" preserveAspectRatio="none" aria-hidden="true">
            <line x1="2" y1="3" x2="100%" y2="3" stroke="rgba(36,48,31,.18)" strokeWidth="2" strokeDasharray="7 5" />
          </svg>
          <svg className="sewn-thread-red" width="100%" height="6" preserveAspectRatio="none" aria-hidden="true" style={{ clipPath: `inset(0 ${(1 - fraction) * 100}% 0 0)` }}>
            <line x1="2" y1="3" x2="100%" y2="3" stroke="var(--red-thread)" strokeWidth="2.4" strokeLinecap="round" strokeDasharray="7 5" />
          </svg>
        </div>
        <p className="muted" aria-live="polite">
          {!sewing.done
            ? `Reading page ${Math.max(1, sewing.read)} of ${sewing.pages}…`
            : near.length
              ? `It already shares ideas with ${countWords(near.length, 'of your books', 'of your books').toLowerCase()}.`
              : books.length > 1 ? "It doesn't share ideas with your other books yet." : 'Your first book. Links to the next ones appear as you bring them.'}
        </p>
        {sewing.done && near.length > 0 && book && (
          <ul className="sewn-near">
            {near.map((n) => (
              <li key={n.bookId}>
                <Patch book={book} size="s"><span /></Patch>
                <span className="sewn-join"><span className="sewn-term">{n.term}</span></span>
                <Patch book={n.book!} size="s"><span /></Patch>
              </li>
            ))}
          </ul>
        )}
        {sewing.done && book && (
          <>
            <p className="eyebrow paper" style={{ marginTop: 28 }}>{book.shelf === 'Unsorted' ? 'Put it on a shelf' : 'Put it on another shelf'}</p>
            <div className="chips" style={{ marginTop: 10 }}>
              {shelves.map((s) => <button key={s} className={`chip${book.shelf === s ? ' on' : ''}`} aria-pressed={book.shelf === s} onClick={() => patchBook(book.id, { shelf: s })}>{s}</button>)}
              {naming ? (
                <form onSubmit={(e) => { e.preventDefault(); if (name.trim()) { patchBook(book.id, { shelf: name.trim() }); setNaming(false); setName('') } }}>
                  <input className="field chip-field" autoFocus value={name} onChange={(e) => setName(e.target.value)} placeholder="A new shelf" aria-label="New shelf name" />
                </form>
              ) : <button className="chip" onClick={() => setNaming(true)}>+ New shelf</button>}
            </div>
            <div className="row" style={{ marginTop: 30, gap: 18 }}>
              <button className="btn ink" onClick={() => { closeSewing(); go({ name: 'read', id: book.id, page: 1 }) }}>Open {book.title.length > 28 ? 'it' : book.title}</button>
              <button className="quiet-link" onClick={() => { closeSewing(); go({ name: 'library' }) }}>Back to the library</button>
            </div>
          </>
        )}
      </div>
    </Modal>
  )
}
