import { useEffect, useState } from 'react'
import { Empty, Swatch, countWords } from '../components/ui'
import { go, href } from '../lib/router'
import { allText, saveTrail, uid, useStore } from '../lib/store'
import { concepts, isStop, quoteAround } from '../lib/text'

type Concept = ReturnType<typeof concepts>[number]

/** Explore (12): ideas your books share, and the passages that say them. Only from your PDFs. */
export function Explore({ term }: { term?: string }) {
  const books = useStore((s) => s.books)
  const [list, setList] = useState<Concept[] | null>(null)
  const [making, setMaking] = useState(false)

  useEffect(() => { void allText().then((lib) => setList(concepts(lib, 10))) }, [books.length])

  if (!books.length) return <div className="page"><Empty title="Ideas show up here once two pages agree."><p className="muted">Bring a PDF or two first.</p></Empty></div>
  if (!list) return <div className="page"><p className="muted" aria-live="polite">Leu is still reading your books.</p></div>
  if (!list.length) return <div className="page"><Empty title="Ideas show up here once two pages agree."><p className="muted">Explore is built only from your own PDFs: the ideas they share and the passages that say them.</p></Empty></div>

  const current = list.find((c) => c.term === term) ?? list[0]
  const perBook = new Map<string, Concept['hits'][number]>()
  for (const h of current.hits) if (!perBook.has(h.bookId)) perBook.set(h.bookId, h)
  const passages = [...perBook.values()].slice(0, 6)
  const titles = passages.map((p) => books.find((b) => b.id === p.bookId)?.title).filter(Boolean) as string[]

  const makeTrail = () => {
    setMaking(true)
    const trail = { id: uid(), title: cap(current.term), createdAt: Date.now(), current: 0, stops: passages.map((p) => { const q = quoteAround(p.text, current.term); return { id: uid(), bookId: p.bookId, page: p.page, title: q.length > 120 ? q.slice(0, 117).trimEnd() + '…' : q } }) }
    saveTrail(trail)
    setTimeout(() => go({ name: 'trails', id: trail.id }), 500)
  }

  return (
    <div className="explore page fade-in">
      <p className="eyebrow">Ideas across your books</p>
      <div className="concepts scroll-x" role="tablist" aria-label="Ideas">
        {list.map((c) => (
          <a key={c.term} role="tab" aria-selected={c === current} className={`chip${c === current ? ' on' : ''}`} href={href({ name: 'explore', term: c.term })}>{c.term}</a>
        ))}
      </div>
      <h1 className="idea-sentence display">
        <span className="idea-word">{cap(current.term)}</span>{' '}
        {titles.length > 1 ? <>runs through {countWords(titles.length, 'of your books', 'of your books').toLowerCase()}.</> : <>comes up across {titles[0] ? <em>{titles[0]}</em> : 'one book'}.</>}
      </h1>
      <p className="eyebrow" style={{ marginTop: 34 }}>Where your books say it</p>
      <div className="passages">
        {passages.map((p, i) => {
          const book = books.find((b) => b.id === p.bookId)
          const quote = quoteAround(p.text, current.term)
          return (
            <article key={i} className="passage card">
              <p className="eyebrow paper row" style={{ gap: 8 }}>{book && <Swatch book={book} size={8} />}{book?.title} · p. {p.page}</p>
              <blockquote className="serif">“{mark(quote, current.term)}”</blockquote>
              <a className="link small" href={href({ name: 'read', id: p.bookId, page: p.page })}>Read the passage</a>
            </article>
          )
        })}
      </div>
      <div className="row" style={{ gap: 16, marginTop: 28 }}>
        <button className="btn ink" disabled={making || passages.length < 2} onClick={makeTrail}>{making ? 'Making the trail…' : 'Make it a trail'}</button>
        <span className="muted small">{passages.length < 2 ? `Only ${titles[0] ?? 'one book'} says it so far.` : 'Puts one passage from each book in order, as a trail you can walk.'}</span>
      </div>
      <p className="muted small" style={{ marginTop: 26 }}>Explore is built only from your own PDFs: the ideas they share and the passages that say them.</p>
    </div>
  )
}

const cap = (s: string) => s.charAt(0).toUpperCase() + s.slice(1)

export function mark(text: string, term: string) {
  const words = term.split(/[^A-Za-z0-9.-]+/).filter((w) => w.length > 2 && !isStop(w)).map((w) => w.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'))
  if (!words.length) return text
  const parts = text.split(new RegExp(`(\\b(?:${words.join('|')})[a-z]*)`, 'gi'))
  return parts.map((part, i) => (i % 2 ? <mark key={i}>{part}</mark> : part))
}
