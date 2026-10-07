import { useState } from 'react'
import { Swatch, countWords } from '../components/ui'
import { href } from '../lib/router'
import { useStore, type Book, type Note } from '../lib/store'

/** Notes (11b): a notebook spread of what you kept, each tied to its page. */
export function Notes() {
  const notes = useStore((s) => s.notes)
  const books = useStore((s) => s.books)
  const [view, setView] = useState<'all' | 'books'>('all')
  const week = Date.now() - 7 * 86_400_000
  const recent = notes.filter((n) => n.createdAt >= week)
  const earlier = notes.filter((n) => n.createdAt < week)
  const byBook = books.map((b) => ({ book: b, notes: notes.filter((n) => n.bookId === b.id) })).filter((g) => g.notes.length)
  const title = notes.length ? `${countWords(notes.length, 'thing')} worth keeping.` : 'Nothing kept yet.'

  const left = (
    <>
      <p className="eyebrow paper">Your notebook</p>
      <h1 className="display" style={{ fontSize: 44, marginTop: 10 }}>{title}</h1>
      <div className="segmented on-paper" role="radiogroup" aria-label="Arrange notes" style={{ marginTop: 18 }}>
        <button role="radio" aria-checked={view === 'all'} className={view === 'all' ? 'on' : ''} onClick={() => setView('all')}>All notes</button>
        <button role="radio" aria-checked={view === 'books'} className={view === 'books' ? 'on' : ''} onClick={() => setView('books')}>Books</button>
      </div>
      {!notes.length && <p className="paper-muted" style={{ marginTop: 22 }}>Select a line while you read and choose “Keep a note”. It lands here, tied to its page.</p>}
    </>
  )

  const entries: { heading?: string; note?: Note; empty?: string }[] = view === 'all'
    ? [{ heading: 'This week' }, ...(recent.length ? recent.map((note) => ({ note })) : [{ empty: 'Nothing new this week.' }]), { heading: 'Earlier' }, ...(earlier.length ? earlier.map((note) => ({ note })) : [{ empty: 'Nothing from before this week.' }])]
    : byBook.flatMap((g) => [{ heading: g.book.title }, ...g.notes.map((note) => ({ note }))])
  const half = Math.ceil(entries.length / 2) + 1
  const render = (list: typeof entries) => list.map((e, i) =>
    e.heading ? <h2 key={i} className="eyebrow paper notebook-h">{e.heading}</h2>
      : e.empty ? <p key={i} className="paper-muted small">{e.empty}</p>
        : <Entry key={e.note!.id} note={e.note!} book={books.find((b) => b.id === e.note!.bookId)} />)

  return (
    <div className="notes page fade-in">
      <div className="notebook">
        <section className="notebook-page left">{left}{notes.length > 0 && render(entries.slice(0, Math.max(2, half - 2)))}</section>
        <div className="notebook-spine" aria-hidden="true" />
        <section className="notebook-page right">{notes.length > 0 ? render(entries.slice(Math.max(2, half - 2))) : <p className="paper-muted serif" style={{ fontStyle: 'italic', marginTop: 60, textAlign: 'center' }}>The right-hand page is waiting.</p>}</section>
      </div>
    </div>
  )
}

function Entry({ note, book }: { note: Note; book?: Book }) {
  const place = `${book?.title ?? 'A book'}, p. ${note.page}`
  return (
    <article className="entry">
      <p className="entry-place small">{book && <Swatch book={book} size={8} />}{place}</p>
      <blockquote className="serif">“{note.quote.length > 260 ? note.quote.slice(0, 260) + '…' : note.quote}”</blockquote>
      {note.note && <p className="entry-note">{note.note}</p>}
      <a className="link small" href={href({ name: 'read', id: note.bookId, page: note.page })} aria-label={`Open ${place}`}>Open the page</a>
    </article>
  )
}
