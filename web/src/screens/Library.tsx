import { CaretRightIcon, MagnifyingGlassIcon, PlusIcon } from '@phosphor-icons/react'
import { useMemo, useState } from 'react'
import { BookCover } from '../components/BookCover'
import { importAllSamples, samples } from '../lib/library'
import { go, href } from '../lib/router'
import { useStore } from '../lib/store'
import './ReadingRoom.css'

export function Library({ shelf, onBring }: { shelf?: string; onBring: () => void }) {
  const books = useStore((s) => s.books)
  const [query, setQuery] = useState('')
  const [adding, setAdding] = useState(false)
  const [importError, setImportError] = useState('')
  const addSamples = async () => {
    if (adding) return
    setAdding(true); setImportError('')
    try { await importAllSamples() }
    catch (error) {
      console.warn('[leu] Sample import failed:', error)
      setImportError('Could not add all samples. Please try again.')
    } finally { setAdding(false) }
  }
  const collections = useMemo(() => {
    const counts = new Map<string, number>()
    for (const book of books) counts.set(book.shelf, (counts.get(book.shelf) ?? 0) + 1)
    return [...counts.entries()].sort(([a], [b]) => a.localeCompare(b))
  }, [books])
  const shown = books.filter((book) => (!shelf || book.shelf === shelf)
    && book.title.toLocaleLowerCase().includes(query.trim().toLocaleLowerCase()))
    .sort((a, b) => (b.lastOpenedAt ?? b.addedAt) - (a.lastOpenedAt ?? a.addedAt))
  const missingSamples = samples.filter((title) => !books.some((book) => book.title === title)).length
  return <div className="reading-library fade-in">
    <header className="reading-library-heading">
      <h1 className="display">Your library</h1>
      <p className="muted">{books.length} {books.length === 1 ? 'book' : 'books'}, ready to read.</p>
    </header>
    <nav className="library-filters" aria-label="Book collections">
      <a href={href({ name: 'library' })} aria-current={!shelf ? 'page' : undefined}><span>All books</span><span>{books.length}</span></a>
      {collections.map(([name, count]) => <a key={name} href={href({ name: 'library', shelf: name })} aria-current={shelf === name ? 'page' : undefined}><span>{name}</span><span>{count}</span></a>)}
    </nav>
    <label className="find library-find">
      <MagnifyingGlassIcon size={22} aria-hidden="true" /><span className="sr-only">Find a book</span>
      <input type="search" value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Find a book" />
    </label>
    <div className="quilt library-books" role="list" aria-label={shelf ? `${shelf} books` : 'All books'}>
      {shown.map((book) => <div role="listitem" key={book.id} className="quilt-cell library-book">
        <div className="library-cover-slot"><button className="library-cover-button" onClick={() => go({ name: 'book', id: book.id })} aria-label={`${book.title}, ${book.pages} pages`}><BookCover book={book} /></button></div>
        <h2>{book.title}</h2>
        <p className="muted tabular">{book.pages} pages · Page {book.page}</p>
        <button className="library-continue" onClick={() => go({ name: 'read', id: book.id, page: book.page })}>Continue reading <CaretRightIcon size={18} aria-hidden="true" /></button>
      </div>)}
      <div className="library-import-cell" role="listitem"><div className="library-cover-slot"><button className="library-import" onClick={onBring}><PlusIcon size={32} aria-hidden="true" /><span>Import a PDF</span></button></div></div>
    </div>
    {shown.length === 0 && <p className="library-empty" role="status">{query ? 'No matching books. Try another title.' : 'No books in this collection yet.'}</p>}
    {missingSamples > 0 && <button className="library-samples" disabled={adding} onClick={() => void addSamples()}><span>{adding ? 'Adding sample PDFs…' : `Try ${missingSamples} sample ${missingSamples === 1 ? 'PDF' : 'PDFs'}`}</span><CaretRightIcon size={22} aria-hidden="true" /></button>}
    {importError && <p className="import-error" role="alert">{importError}</p>}
  </div>
}
