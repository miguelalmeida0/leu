import { ArrowRightIcon, CaretRightIcon, FolderIcon, PlusCircleIcon } from '@phosphor-icons/react'
import { BookCover } from '../components/BookCover'
import { Progress } from '../components/ui'
import { lastBook } from '../lib/library'
import { go } from '../lib/router'
import { readFraction, useStore } from '../lib/store'
import { NookScene } from '../scenes/NookScene'
import './ReadingRoom.css'

function greeting(d = new Date()) {
  const h = d.getHours()
  return h >= 5 && h < 12 ? 'Good morning' : h < 17 && h >= 12 ? 'Good afternoon' : h >= 17 && h < 22 ? 'Good evening' : 'Late night'
}

export function Home({ onBring }: { onBring: () => void }) {
  const books = useStore((s) => s.books)
  const book = lastBook(books)
  return <div className="reading-home fade-in">
    <section className="home-story" aria-labelledby="home-title">
      <p className="eyebrow">{greeting()}</p>
      <h1 id="home-title" className="display">Make room for<br />a few pages.</h1>
      <div className="home-scene"><NookScene autoplay /></div>
    </section>
    <section className="home-resume" aria-label="Continue reading">
      <p className="eyebrow">Pick up where you left off</p>
      {book && <>
        <div className="resume-book">
          <BookCover book={book} />
          <div className="resume-details">
            <h2>{book.title}</h2>
            <p className="muted tabular">Page {book.page} of {book.pages}</p>
            <Progress value={readFraction(book)} />
          </div>
        </div>
        <button className="btn ink resume-action" onClick={() => go({ name: 'read', id: book.id, page: book.page })}>
          Continue reading <ArrowRightIcon size={22} aria-hidden="true" />
        </button>
      </>}
      <div className="home-shortcuts">
        <button onClick={() => go({ name: 'library' })}>
          <FolderIcon size={24} aria-hidden="true" />
          <span><strong>Your library</strong><span className="muted"> · {books.length} {books.length === 1 ? 'book' : 'books'}</span></span>
          <CaretRightIcon size={20} aria-hidden="true" />
        </button>
        <button onClick={onBring}>
          <PlusCircleIcon size={24} aria-hidden="true" /><strong>Import a PDF</strong><CaretRightIcon size={20} aria-hidden="true" />
        </button>
      </div>
    </section>
  </div>
}
