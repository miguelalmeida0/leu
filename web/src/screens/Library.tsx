import { useMemo, useState } from 'react'
import { Patch, Progress, countWords } from '../components/ui'
import { importAllSamples, samples } from '../lib/library'
import { go, href } from '../lib/router'
import { readFraction, useStore, type Book } from '../lib/store'

/** Library (04): the felt quilt. A shelf index, what's on the needle, and every book as a patch. */
export function Library({ shelf, onBring }: { shelf?: string; onBring: () => void }) {
  const books = useStore((s) => s.books)
  const [query, setQuery] = useState('')
  const [adding, setAdding] = useState(false)
  const [importError, setImportError] = useState('')
  const addSamples = async () => {
    setAdding(true); setImportError('')
    try { await importAllSamples() }
    catch (error) {
      console.warn('[leu] Sample import failed:', error)
      setImportError('Could not add all samples. Please try again.')
    } finally { setAdding(false) }
  }
  const shelves = useMemo(() => {
    const counts = new Map<string, number>()
    for (const b of books) counts.set(b.shelf, (counts.get(b.shelf) ?? 0) + 1)
    return [...counts.entries()].sort((a, b) => (a[0] === 'Unsorted' ? 1 : b[0] === 'Unsorted' ? -1 : a[0].localeCompare(b[0])))
  }, [books])
  const shown = books
    .filter((b) => !shelf || b.shelf === shelf)
    .filter((b) => !query.trim() || b.title.toLowerCase().includes(query.trim().toLowerCase()))
    .sort((a, b) => (b.lastOpenedAt ?? b.addedAt) - (a.lastOpenedAt ?? a.addedAt))
  const needle = books.filter((b) => b.lastOpenedAt && b.page > 1 && b.page < b.pages).sort((a, b) => b.lastOpenedAt! - a.lastOpenedAt!).slice(0, 3)
  const missingSamples = samples.filter((s) => !books.some((b) => b.title === s)).length

  return (
    <div className="library page fade-in">
      <aside className="shelf-index" aria-label="Your shelves">
        <p className="eyebrow">Your shelves</p>
        <ul>
          <li><a href={href({ name: 'library' })} aria-current={!shelf ? 'page' : undefined}><span>All books</span><span className="count">{books.length}</span></a></li>
          {shelves.map(([name, n]) => (
            <li key={name}><a href={href({ name: 'library', shelf: name })} aria-current={shelf === name ? 'page' : undefined}><span>{name}</span><span className="count">{n}</span></a></li>
          ))}
        </ul>
        <div className="divider" style={{ margin: '22px 0' }} />
        <button className="btn soft" style={{ width: '100%' }} onClick={onBring}>Bring a PDF</button>
        <p className="muted small" style={{ marginTop: 10 }}>or drop one anywhere on this page.</p>
        {missingSamples > 0 && (
          <button className="link small" style={{ marginTop: 14 }} disabled={adding} onClick={() => void addSamples()}>
            {adding ? 'Adding the samples…' : `Add the ${missingSamples === samples.length ? 'six' : missingSamples} sample books`}
          </button>
        )}
        {importError && <p className="import-error" role="alert">{importError}</p>}
      </aside>

      <section className="library-main">
        <div className="library-head">
          <div>
            <p className="eyebrow">{shelf ? `Library / ${shelf}` : 'Library'}</p>
            <h1 className="display" style={{ fontSize: 52, marginTop: 10 }}>{shelf ?? 'Your library'}</h1>
            <p className="muted" style={{ marginTop: 8 }}>{countWords(shown.length, 'book')}{!shelf ? ` on ${countWords(shelves.length, 'shelf', 'shelves').toLowerCase()}` : ''}.</p>
          </div>
          <label className="find">
            <span className="sr-only">Find a book</span>
            <svg width="16" height="16" viewBox="0 0 24 24" aria-hidden="true"><circle cx="10.5" cy="10.5" r="6.5" fill="none" stroke="currentColor" strokeWidth="2.2" /><path d="M15.5 15.5 20 20" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" /></svg>
            <input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Find a book" />
          </label>
        </div>

        {needle.length > 0 && !shelf && !query && (
          <div className="needle">
            <p className="eyebrow">On the needle</p>
            <div className="needle-row">
              {needle.map((b) => <NeedleCard key={b.id} book={b} />)}
            </div>
          </div>
        )}

        <div className="quilt" role="list">
          {shown.map((b, i) => (
            <div role="listitem" key={b.id} className={`quilt-cell ${span(b, i)}`}>
              <Patch book={b} size={span(b, i) === 'big' ? 'l' : 'm'} onClick={() => go({ name: 'book', id: b.id })} label={`${b.title}, ${b.pages} pages`} />
            </div>
          ))}
          {shown.length === 0 && <p className="muted">{query ? 'No book by that name on this shelf.' : 'Nothing on this shelf yet.'}</p>}
        </div>
      </section>
    </div>
  )
}

/** Quilt rhythm: longer books take bigger patches, and the pattern never repeats in a row. */
function span(b: Book, i: number): string {
  if (i === 0 && b.pages >= 150) return 'big'
  // Rows of three patches, one of them wide, the wide one stepping along each row.
  return i % 3 === Math.floor(i / 3) % 3 ? 'wide' : ''
}

function NeedleCard({ book }: { book: Book }) {
  const p = readFraction(book)
  return (
    <button className="needle-card card" onClick={() => go({ name: 'read', id: book.id, page: book.page })}>
      <Patch book={book} size="s"><span /></Patch>
      <span className="needle-text">
        <strong>{book.title}</strong>
        <span className="muted small tabular">page {book.page} of {book.pages}</span>
        <Progress value={p} width={160} />
      </span>
    </button>
  )
}
