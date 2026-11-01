import { useEffect, useMemo, useState } from 'react'
import { ReaderContents } from '../components/ReaderContents'
import { Empty, Patch, fractionWords } from '../components/ui'
import { go, href } from '../lib/router'
import { loadOutline, loadText, memoryState, readFraction, removeBook, useStore, type Outline } from '../lib/store'
import { sentences } from '../lib/text'

interface Chapter { number: number; title: string; from: number; to: number; sections: Outline[]; outlineIndex?: number }

/** Chapters from the outline (or one per stretch of pages when there is none). */
function chapters(outline: Outline[], pages: number): Chapter[] {
  const top = outline.filter((o) => o.depth === 0)
  const heads = top.length >= 2 ? top : outline.length >= 2 ? outline : []
  if (!heads.length) {
    const size = Math.max(1, Math.ceil(pages / Math.min(6, pages)))
    return Array.from({ length: Math.ceil(pages / size) }, (_, i) => ({ number: i + 1, title: `Pages ${i * size + 1}–${Math.min(pages, (i + 1) * size)}`, from: i * size + 1, to: Math.min(pages, (i + 1) * size), sections: [] }))
  }
  return heads.map((h, i) => {
    const to = i + 1 < heads.length ? Math.max(h.page, heads[i + 1].page - 1) : pages
    return { number: i + 1, title: h.title, from: h.page, to, outlineIndex: outline.indexOf(h), sections: outline.filter((o) => o.depth > 0 && o.page >= h.page && o.page <= to && o !== h) }
  })
}

/** A book (05): the whole book chapter by chapter, where you left off, and what's loose. */
export function BookOverview({ id }: { id: string }) {
  const book = useStore((s) => s.books.find((b) => b.id === id))
  const memory = useStore((s) => s.memory)
  const attempts = useStore((s) => s.attempts)
  const trails = useStore((s) => s.trails)
  const [outline, setOutline] = useState<Outline[] | null>(null)
  const [text, setText] = useState<string[]>([])
  const [selected, setSelected] = useState(0)
  const [chosenEntry, setChosenEntry] = useState<Outline | null>(null)
  const [selectedEntryIndex, setSelectedEntryIndex] = useState<number | null>(null)

  useEffect(() => { void loadOutline(id).then(setOutline); void loadText(id).then(setText) }, [id])
  useEffect(() => { if (book) document.title = `${book.title} · Leu` }, [book])
  const list = useMemo(() => (outline && book ? chapters(outline, book.pages) : []), [outline, book])

  useEffect(() => {
    if (!book || !list.length) return
    const here = list.findIndex((c) => book.page >= c.from && book.page <= c.to)
    setSelected(Math.max(0, here)); setChosenEntry(null); setSelectedEntryIndex(null)
  }, [list, book?.id])

  if (!book) return <div className="page"><Empty title="That book isn't here any more."><a className="link" href={href({ name: 'library' })}>Back to the library</a></Empty></div>

  const mine = memory.filter((m) => m.bookId === id)
  const fading = mine.filter((m) => { const s = memoryState(m); return s === 'fading' || s === 'due' })
  const loose = Object.entries(attempts).filter(([k, a]) => k.startsWith(id + ':') && a.checkedAt && a.across.length < 3)
  const understood = Object.entries(attempts).filter(([k, a]) => k.startsWith(id + ':') && a.across.length >= 3).length
  const read = readFraction(book)
  const entries = outline?.length ? outline : list.map((c) => ({ title: c.title, page: c.from, depth: 0 }))
  const chapter = chosenEntry ? { number: selected + 1, title: chosenEntry.title, from: chosenEntry.page, to: chosenEntry.page, sections: [] } : list[selected]
  const leftOff = text[book.page - 1] ? sentences(text[book.page - 1]).find((s) => s.length > 50) : undefined
  const onTrails = trails.filter((t) => t.stops.some((s) => s.bookId === id))
  const questions = Math.max(1, Math.min(8, mine.length || 5))

  return (
    <div className="book page fade-in">
      <nav className="crumbs" aria-label="Breadcrumb">
        <a href={href({ name: 'library' })}>Library</a><span aria-hidden="true">/</span>
        <a href={href({ name: 'library', shelf: book.shelf })}>{book.shelf}</a>
      </nav>
      <div className="book-head">
        <Patch book={book} size="m"><span /></Patch>
        <div>
          <h1 className="display" style={{}}>{book.title}</h1>
          <p className="muted" style={{ marginTop: 10 }}>
            {book.pages} pages · {book.lastOpenedAt ? (read > 0 ? `You've read ${fractionWords(read)} of it` : 'Just started') : 'Not started yet'}
            {understood > 0 ? ` · you've explained ${understood} page${understood > 1 ? 's' : ''} in your own words` : ''}.
          </p>
        </div>
      </div>

      <div className="book-grid">
        <section aria-labelledby="chapters-h">
          <h2 id="chapters-h" className="eyebrow">The whole book, chapter by chapter</h2>
          <ReaderContents entries={entries} currentIndex={selectedEntryIndex ?? list[selected]?.outlineIndex ?? selected}
            onChoose={(index) => {
              const entry = entries[index]
              setSelectedEntryIndex(index)
              const heading = outline?.length ? list.findIndex((c) => c.outlineIndex === index) : index
              setChosenEntry(heading < 0 ? entry : null)
              const target = heading >= 0 ? heading : list.reduce((found, c, i) => c.from <= entry.page ? i : found, 0)
              setSelected(Math.max(0, target))
            }} />
          {chapter && (
            <div className="chapter-card card">
              <p className="eyebrow paper">Chapter {chapter.number} · {chapter.from === chapter.to ? `page ${chapter.from}` : `pages ${chapter.from}–${chapter.to}`}</p>
              <h3 className="display" style={{ fontSize: 30, marginTop: 8 }}>{chapter.title}</h3>
              {chapter.sections.length ? <ReaderContents entries={chapter.sections} currentIndex={0}
                onChoose={(index) => go({ name: 'read', id, page: chapter.sections[index].page })} />
                : <p className="muted" style={{ marginTop: 12 }}>This chapter has no smaller sections in its outline.</p>}
              <div className="row" style={{ gap: 16, marginTop: 20 }}>
                <button className="btn ink" onClick={() => go({ name: 'read', id, page: chapter.from })}>Read this chapter</button>
                <button className="quiet-link" onClick={() => go({ name: 'words', id, page: chapter.from })}>Explain it in your own words</button>
              </div>
            </div>
          )}
        </section>

        <aside className="book-side">
          <div className="card side-card">
            <p className="eyebrow paper">{book.lastOpenedAt ? 'Where you left off' : 'Where it begins'}</p>
            <p className="serif left-off">{leftOff ? `“${leftOff}”` : 'The first page is waiting.'}</p>
            <button className="btn ink" style={{ marginTop: 16 }} onClick={() => go({ name: 'read', id, page: book.page })}>{book.page > 1 ? `Continue on p. ${book.page}` : 'Start reading'}</button>
          </div>
          <div className="side-block">
            <h2 className="eyebrow">Loose ends · {fading.length + loose.length}</h2>
            {fading.length + loose.length === 0 ? <p className="muted">{mine.length ? 'Nothing fading from this book.' : "Leu hasn't asked you about it yet."}</p> : (
              <ul className="loose">
                {loose.slice(0, 4).map(([k]) => { const page = Number(k.split(':')[1]); return <li key={k}><a href={href({ name: 'words', id, page })}>An idea on page {page} didn't get across yet</a></li> })}
                {fading.slice(0, 4).map((m) => <li key={m.id}><a href={href({ name: 'read', id, page: m.page })}>Fading: page {m.page}</a></li>)}
              </ul>
            )}
            <button className="btn soft" style={{ marginTop: 12 }} onClick={() => go({ name: 'study' })}>Ask me {questions} question{questions > 1 ? 's' : ''}</button>
          </div>
          <div className="side-block">
            <h2 className="eyebrow">Also lives in</h2>
            <ul className="lives">
              <li><a href={href({ name: 'library', shelf: book.shelf })}>Shelf: {book.shelf}</a></li>
              {onTrails.map((t) => <li key={t.id}><a href={href({ name: 'trails', id: t.id })}>Trail: {t.title}</a></li>)}
            </ul>
            {!onTrails.length && <p className="muted small">Only in your library so far.</p>}
          </div>
          <button type="button" className="quiet-link small" style={{ justifySelf: 'start', display: 'inline-flex', alignItems: 'center', gap: 8, minHeight: 44 }}
            onClick={async () => { if (confirm(`Delete ${book.title}? This also deletes its notes.`)) { await removeBook(id); go({ name: 'library' }) } }}>
            <svg data-icon="material-delete-outline" aria-hidden="true" width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
              <path d="M6 19c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2V7H6v12zm2-10h8v10H8V9zm7.5-6h-7l-1 1H5v2h14V4h-2.5l-1-1z" />
            </svg>
            Delete PDF
          </button>
        </aside>
      </div>
    </div>
  )
}
